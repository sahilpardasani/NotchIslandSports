import AppKit
import Combine
import IslandCore

@MainActor
final class DeliveryManager: ObservableObject {
    static let shared = DeliveryManager()
    @Published private(set) var orders: [DeliveryActivity] = []
    @Published private(set) var connected = false
    @Published private(set) var connecting = false
    @Published private(set) var status = "Connect Swiggy to show active food deliveries."
    @Published private(set) var addresses: [SwiggyAddressList.Address] = []
    @Published private(set) var hasMoreAddresses = false
    private let client: SwiggyClient
    private let now: () -> Date
    private var loop: Task<Void, Never>?
    private var signInTask: Task<Void, Never>?
    private var callback: SwiggySignIn?
    private var running = false
    private var restored = false
    private var epoch = 0
    private var addressPage = 0
    private var tracked: [String: DeliveryActivity] = [:]
    private var terminal = Set<String>()
    private var discoverAfter = Date.distantPast
    private var failures = 0
    private var lowPower = false
    init(client: SwiggyClient? = nil, now: @escaping () -> Date = Date.init) { self.client = client ?? SwiggyClient(); self.now = now }

    func start() {
        guard !running else { return }; running = true
        if !restored {
            restored = true
            do { try client.restore(); connected = client.credentials != nil }
            catch { status = error.localizedDescription }
        }
        schedule()
    }
    func stop() {
        running = false; epoch += 1; loop?.cancel(); loop = nil
        cancelSignIn(); orders = []
    }
    func setLowPower(_ value: Bool) { lowPower = value }
    func connect() {
        guard !connecting else { return }
        epoch += 1; loop?.cancel(); loop = nil
        connecting = true; status = "Finish Swiggy sign-in in your browser."
        let generation = epoch
        signInTask = Task {
            defer { if generation == epoch { connecting = false; signInTask = nil; callback = nil } }
            do {
                let state = try SwiggyClient.randomURLToken(), verifier = try SwiggyClient.randomURLToken()
                let callback = SwiggySignIn(state: state); self.callback = callback
                defer { callback.cancel() }
                let redirect = try await callback.start()
                let id = try await client.register(redirect: redirect)
                try Task.checkCancellation()
                guard NSWorkspace.shared.open(client.authorizeURL(clientID: id, redirect: redirect, verifier: verifier, state: state)) else { throw SwiggyError.callback }
                let code = try await callback.code()
                try await client.exchange(code: code, clientID: id, redirect: redirect, verifier: verifier)
                try Task.checkCancellation(); guard generation == epoch else { return }
                connected = true; restored = true; addresses = []; addressPage = 0
                tracked = [:]; terminal = []; discoverAfter = .distantPast
                status = "Connected to Swiggy."
                connecting = false; schedule()
            } catch {
                guard generation == epoch, !Task.isCancelled else { return }
                status = (error as? SwiggyError)?.localizedDescription ?? "Swiggy sign-in could not finish. Try connecting again."
            }
        }
    }
    func cancelSignIn() {
        signInTask?.cancel(); signInTask = nil; callback?.cancel(); callback = nil; connecting = false
    }
    func disconnect() {
        epoch += 1; loop?.cancel(); loop = nil; cancelSignIn()
        tracked = [:]; orders = []; addresses = []; hasMoreAddresses = false; addressPage = 0; terminal = []
        connected = false
        do { try client.disconnect(); status = "Swiggy disconnected." }
        catch { status = "Connection stopped, but Keychain removal failed. Try Disconnect again." }
    }
    func selectAddress(_ id: String) {
        guard addresses.contains(where: { $0.id == id }) else { return }
        do {
            try client.chooseAddress(id); addresses = []; hasMoreAddresses = false
            discoverAfter = .distantPast; schedule()
        } catch { status = error.localizedDescription }
    }
    func moreAddresses() {
        guard loop == nil, connected, hasMoreAddresses else { return }
        let generation = epoch
        loop = Task {
            defer { if generation == epoch { loop = nil } }
            do { try await loadAddresses(page: addressPage + 1, generation: generation) }
            catch { if generation == epoch { status = "Could not load more addresses. Try again." } }
        }
    }
    private func loadAddresses(page: Int, generation: Int) async throws {
        let response = try await client.call("get_addresses", arguments: ["page": page], as: SwiggyAddressList.self)
        try Task.checkCancellation(); guard epoch == generation else { throw CancellationError() }
        addressPage = response.pagination.page; hasMoreAddresses = response.pagination.hasMore
        addresses += response.addresses.filter { address in !addresses.contains { $0.id == address.id } }
        if response.pagination.total == 1, let address = response.addresses.first {
            try client.chooseAddress(address.id); addresses = []; hasMoreAddresses = false
            status = "Using \(address.addressTag ?? address.addressLine) for Swiggy tracking."
        } else {
            status = response.pagination.total == 0 ? "Add a saved address in Swiggy, then reconnect." : "Choose a saved address once to connect order tracking. Orders from all addresses will appear."
        }
    }
    private func schedule() {
        guard running, connected, !connecting, loop == nil else { return }
        let generation = epoch
        loop = Task {
            defer { if generation == epoch { loop = nil } }
            while !Task.isCancelled, generation == epoch, running, connected {
                var wait: TimeInterval = 60
                do {
                    if client.credentials?.addressID == nil {
                        if addresses.isEmpty { try await loadAddresses(page: 1, generation: generation) }
                        if client.credentials?.addressID == nil { return }
                    }
                    try await refresh(generation: generation)
                    failures = 0
                    let due = tracked.values.map(\.nextRefresh).min() ?? discoverAfter
                    wait = max(1, min(due, discoverAfter).timeIntervalSinceNow)
                } catch is CancellationError { return }
                catch SwiggyError.signIn {
                    guard generation == epoch else { return }
                    connected = false; orders = []; tracked = [:]
                    status = SwiggyError.signIn.localizedDescription; return
                } catch {
                    guard generation == epoch, !Task.isCancelled else { return }
                    failures += 1; wait = min(900, 30 * pow(2, Double(min(5, failures))))
                    if case SwiggyError.rateLimited(let delay) = error { wait = max(wait, delay) }
                    publish()
                    status = (error as? SwiggyError)?.localizedDescription ?? "Delivery updates are delayed. Trying again."
                }
                // Expire old estimates during a long backoff without extra network work.
                let until = now().addingTimeInterval(wait)
                repeat {
                    let expiry = orders.map(\.expiresAt).min() ?? until
                    let nap = max(0.1, min(expiry, until).timeIntervalSinceNow)
                    do { try await Task.sleep(nanoseconds: UInt64(min(nap, 86_400) * 1_000_000_000)) } catch { return }
                    guard generation == epoch else { return }; publish()
                } while now() < until
            }
        }
    }
    private func refresh(generation: Int) async throws {
        if now() >= discoverAfter, let address = client.credentials?.addressID {
            let response = try await client.call("get_food_orders", arguments: ["addressId": address, "activeOnly": true, "orderCount": 15], as: SwiggyOrderList.self)
            try Task.checkCancellation(); guard epoch == generation else { throw CancellationError() }
            let active = response.orders.filter { $0.isActiveOrder && !$0.orderId.isEmpty }
            let ids = Set(active.map(\.orderId))
            terminal.formIntersection(ids)
            tracked = tracked.filter { ids.contains($0.key) && !terminal.contains($0.key) }
            for order in active where tracked[order.orderId] == nil && !terminal.contains(order.orderId) {
                tracked[order.orderId] = DeliveryActivity(id: order.orderId, restaurant: order.restaurantName,
                    status: order.orderDeliveryStatus ?? order.orderStatus, now: now())
            }
            discoverAfter = now().addingTimeInterval(lowPower && active.isEmpty ? 300 : 60)
            publish()
        }
        for id in tracked.keys.sorted() {
            guard let current = tracked[id], current.nextRefresh <= now() else { continue }
            let update = try await client.call("get_food_delivery_status", arguments: ["orderId": id], as: SwiggyDeliveryStatus.self)
            try Task.checkCancellation(); guard epoch == generation else { throw CancellationError() }
            guard update.orderId == id else { throw SwiggyDataError.wrongOrder }
            if update.terminal { terminal.insert(id); tracked.removeValue(forKey: id) }
            else { var next = current; try next.apply(update, now: now()); tracked[id] = next }
            publish()
        }
        status = orders.isEmpty ? "Connected · no active Swiggy deliveries." : "Swiggy tracking is up to date."
    }
    private func publish() {
        let next = tracked.values.filter { $0.expiresAt > now() }.sorted { $0.id < $1.id }
        if orders != next { orders = next }
    }
    #if DEBUG
    func refreshForTesting() async throws {
        try client.restore(); connected = true
        try await refresh(generation: epoch)
    }
    static func visualFixture() -> DeliveryManager {
        let manager = DeliveryManager()
        var order = DeliveryActivity(id: "fixture", restaurant: "The Curry Kitchen", status: "Your food is on the way", now: Date())
        order.eta = "12–17 min"; manager.orders = [order]; manager.connected = true
        return manager
    }
    #endif
}
