import Foundation
import IslandCore

final class MemoryCredentials: SwiggyCredentialStore {
    var value: SwiggyCredentials?
    var saves = 0
    init() { value = SwiggyCredentials(accessToken: "fixture-token", refreshToken: "fixture-refresh", clientID: "fixture-client", expiresAt: Date().addingTimeInterval(3600), addressID: "address-fixture") }
    func load() throws -> SwiggyCredentials? { value }
    func save(_ value: SwiggyCredentials) throws { self.value = value; saves += 1 }
    func clear() throws { value = nil }
}
final class FixtureHTTP: URLProtocol {
    static var handler: ((URLRequest, [String: Any]) -> (Int, String, [String: Any]))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(contentsOf: buffer.prefix(n)) }
        }
        let body = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let (status, mime, payload) = Self.handler(request, body)
        var encoded = try! JSONSerialization.data(withJSONObject: payload)
        if mime == "text/event-stream" { encoded = Data("event: message\ndata: \(String(data: encoded, encoding: .utf8)!)\n\n".utf8) }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": mime, "Mcp-Session-Id": "fixture-session", "Retry-After": "95"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: encoded); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main struct DeliveryChecks {
    @MainActor static func main() async throws {
        setbuf(stdout, nil)
        var count = 0
        func check(_ value: Bool, _ message: String) { precondition(value, message); count += 1 }
        check(SwiggyClient.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", "RFC 7636 S256 vector")
        if ProcessInfo.processInfo.environment["NOTCH_APPROVAL_POLICY_ONLY"] != "1" {
            let callback = SwiggySignIn(state: "fixture-state")
            let redirect = try await callback.start()
            let (_, badResponse) = try await URLSession.shared.data(from: URL(string: redirect + "?code=fixture-code&state=wrong")!)
            check((badResponse as? HTTPURLResponse)?.statusCode == 400, "Loopback rejects wrong OAuth state")
            async let code = callback.code()
            let (_, response) = try await URLSession.shared.data(from: URL(string: redirect + "?code=fixture-code&state=fixture-state")!)
            check((response as? HTTPURLResponse)?.statusCode == 200, "Loopback accepts valid OAuth callback")
            let received = try await code
            check(received == "fixture-code", "Loopback delivers authorization code once")
        }
        let random = try SwiggyClient.randomURLToken()
        check(random.count == 43 && !random.contains("="), "Cryptographic URL-safe state")
        check(SwiggyReadPolicy.callbackCode(target: "/callback?code=abc&state=s", state: "s") == "abc", "Matching callback")
        for target in ["/callback?code=abc&state=bad", "/wrong?code=abc&state=s", "/callback?code=&state=s", "/callback?code=x&code=y&state=s", "/callback?code=x&state=s&state=s", "/callback?code=x&state=s&error=denied"] {
            check(SwiggyReadPolicy.callbackCode(target: target, state: "s") == nil, "Reject incorrect or ambiguous OAuth callback")
        }
        do { try SwiggyReadPolicy.validate(tool: "place_food_order"); preconditionFailure("Write tool allowed") } catch { count += 1 }
        let payload = try SwiggyReadPolicy.payload(["structuredContent": ["success": true, "data": ["orders": []]]])
        check((try JSONDecoder().decode(SwiggyOrderList.self, from: payload)).orders.isEmpty, "Empty successful orders is valid")
        for bad: [String: Any] in [["isError": true], ["structuredContent": ["success": false, "data": ["orders": []]]], ["content": [["type": "text", "text": "Your order should arrive soon"]]]] {
            do { _ = try SwiggyReadPolicy.payload(bad); preconditionFailure("Unsupported payload accepted") } catch { count += 1 }
        }
        func status(_ extra: [String: Any] = [:]) throws -> SwiggyDeliveryStatus {
            var data: [String: Any] = ["orderId": "order-fixture", "serverNow": 100_000, "deliveryBy": 700_000, "pollIntervalSec": 45, "statusText": "On the way"]
            data.merge(extra) { _, next in next }
            return try JSONDecoder().decode(SwiggyDeliveryStatus.self, from: JSONSerialization.data(withJSONObject: data))
        }
        let now = Date(timeIntervalSince1970: 2_000_000)
        var activity = DeliveryActivity(id: "order-fixture", restaurant: "Fixture", status: "Preparing", now: now)
        try activity.apply(status(), now: now)
        check(activity.eta == "10 min", "ETA uses provider serverNow, not local clock")
        check(activity.nextRefresh == now.addingTimeInterval(45), "Honor provider polling interval")
        try activity.apply(status(["deliveryBy": NSNull()]), now: now)
        check(activity.eta == nil, "Missing ETA clears previous estimate")
        try activity.apply(status(["etaText": "12–17 min"]), now: now)
        check(activity.eta == "12–17 min", "Prefer supplied ETA text")
        check(try status(["delivered": true]).terminal, "Delivered is terminal")
        check(try status(["cancelled": true]).terminal, "Cancelled is terminal")
        do { try activity.apply(status(["orderId": "other"]), now: now); preconditionFailure("Wrong order accepted") } catch { count += 1 }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [FixtureHTTP.self]
        let store = MemoryCredentials(), session = URLSession(configuration: config)
        let client = SwiggyClient(store: store, session: session)
        try client.restore()
        let url = client.authorizeURL(clientID: "test", redirect: "http://localhost:123/callback", verifier: "verifier", state: "state")
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        check(query.contains(URLQueryItem(name: "code_challenge_method", value: "S256")), "Authorization always uses PKCE")
        check(!url.absoluteString.contains("code_verifier"), "Verifier never exposed to authorization URL")
        var methods: [String] = [], calls: [String] = []
        var terminal = false, forceUnauthorized = false, useSSE = false, rateLimit = false
        FixtureHTTP.handler = { req, body in
            precondition(req.url!.host == "mcp.swiggy.com")
            if req.url!.path == "/auth/token" {
                precondition(body["grant_type"] as? String == "refresh_token")
                return (200, "application/json", ["access_token": "rotated-fixture", "refresh_token": "rotated-refresh", "expires_in": 3600, "token_type": "Bearer"])
            }
            precondition(req.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true)
            let method = body["method"] as! String; methods.append(method)
            if method == "notifications/initialized" { return (202, "application/json", [:]) }
            if method == "initialize" { return (200, "application/json", ["jsonrpc": "2.0", "id": body["id"]!, "result": ["protocolVersion": "2025-03-26", "capabilities": [:]]]) }
            let params = body["params"] as! [String: Any], name = params["name"] as! String
            calls.append(name)
            if forceUnauthorized { forceUnauthorized = false; return (401, "application/json", [:]) }
            if rateLimit { return (429, "application/json", [:]) }
            let value: [String: Any]
            if name == "get_food_orders" {
                precondition((params["arguments"] as! [String: Any])["activeOnly"] as? Bool == true)
                value = ["orders": [["orderId": "order-fixture", "restaurantName": "Fixture restaurant", "orderStatus": "Preparing", "isActiveOrder": true]]]
            } else {
                precondition(name == "get_food_delivery_status")
                value = ["orderId": "order-fixture", "serverNow": 100_000, "deliveryBy": 700_000, "pollIntervalSec": 45, "statusText": "On the way", "delivered": terminal]
            }
            return (200, useSSE ? "text/event-stream" : "application/json", ["jsonrpc": "2.0", "id": body["id"]!, "result": ["structuredContent": ["success": true, "data": value]]])
        }
        let result = try await client.call("get_food_delivery_status", arguments: ["orderId": "order-fixture"], as: SwiggyDeliveryStatus.self)
        check(result.orderId == "order-fixture", "JSON MCP reply decoded")
        check(methods.prefix(2) == ["initialize", "notifications/initialized"], "MCP initialization completes before tools")
        useSSE = true
        _ = try await client.call("get_food_delivery_status", arguments: ["orderId": "order-fixture"], as: SwiggyDeliveryStatus.self)
        check(methods.filter { $0 == "initialize" }.count == 1, "Reuse session instead of reinitializing per poll")
        forceUnauthorized = true
        _ = try await client.call("get_food_delivery_status", arguments: ["orderId": "order-fixture"], as: SwiggyDeliveryStatus.self)
        check(store.value?.accessToken == "rotated-fixture" && store.value?.refreshToken == "rotated-refresh", "401 refresh rotates saved credentials")
        check(store.value?.addressID == "address-fixture", "Refresh keeps chosen address")
        rateLimit = true
        do { _ = try await client.call("get_food_delivery_status", as: SwiggyDeliveryStatus.self); preconditionFailure("Rate limit ignored") }
        catch SwiggyError.rateLimited(let delay) { check(delay == 95, "Respect Retry-After") }
        rateLimit = false
        var clock = now
        let manager = DeliveryManager(client: client, now: { clock })
        try await manager.refreshForTesting()
        check(manager.orders.count == 1 && manager.orders[0].eta == "10 min", "Real manager publishes active delivery and ETA")
        let before = calls.count
        try await manager.refreshForTesting()
        check(calls.count == before, "No poll before provider deadline")
        terminal = true; clock = clock.addingTimeInterval(46)
        try await manager.refreshForTesting()
        check(manager.orders.isEmpty, "Terminal delivery removed immediately")
        let statusCalls = calls.filter { $0 == "get_food_delivery_status" }.count
        clock = clock.addingTimeInterval(60); try await manager.refreshForTesting()
        check(manager.orders.isEmpty && calls.filter { $0 == "get_food_delivery_status" }.count == statusCalls, "Stale order list cannot restart completed tracking")
        manager.disconnect()
        check(store.value == nil && !manager.connected && manager.orders.isEmpty, "Disconnect removes credentials and visible orders")
        let beforeWrite = calls.count
        do { _ = try await client.call("place_food_order", as: SwiggyOrderList.self); preconditionFailure("Write reached network") } catch { check(calls.count == beforeWrite, "Write blocked before network") }
        print("Passed \(count) delivery checks; OAuth/HTTP/manager fixtures, not a signed-in real order.")
    }
}
