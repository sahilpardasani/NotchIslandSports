import Foundation

public struct DeliveryActivity: Identifiable, Equatable, Sendable {
    public let id: String
    public let restaurant: String
    public var status: String
    public var eta: String?
    public var observedAt: Date
    public var nextRefresh: Date
    public var expiresAt: Date
    public init(id: String, restaurant: String, status: String, now: Date) {
        self.id = id; self.restaurant = restaurant; self.status = status
        observedAt = now; nextRefresh = now; expiresAt = now.addingTimeInterval(180)
    }
    public mutating func apply(_ update: SwiggyDeliveryStatus, now: Date) throws {
        guard update.orderId == id else { throw SwiggyDataError.wrongOrder }
        guard update.pollIntervalSec.isFinite, update.pollIntervalSec >= 0, update.pollIntervalSec <= 86_400 else { throw SwiggyDataError.invalidResponse }
        status = update.statusText?.nilIfBlank ?? status
        eta = update.etaText?.nilIfBlank
        // Use the provider's clock to avoid an incorrect ETA on a skewed Mac.
        if eta == nil, let by = update.deliveryBy, by.isFinite, update.serverNow.isFinite, by > update.serverNow {
            eta = "\(Int(min(10080, ceil((by - update.serverNow) / 60_000)))) min"
        }
        observedAt = now
        let interval = max(15, update.pollIntervalSec)
        nextRefresh = now.addingTimeInterval(interval)
        expiresAt = now.addingTimeInterval(max(180, interval * 2))
    }
}

public enum SwiggyDataError: Error { case invalidResponse, wrongOrder, disallowedTool }
public struct SwiggyDeliveryStatus: Decodable, Sendable {
    public let orderId: String
    public let deliveryBy: Double?
    public let serverNow: Double
    public let etaText: String?
    public let cancelled: Bool?
    public let delivered: Bool?
    public let statusText: String?
    public let pollIntervalSec: Double
    public var terminal: Bool { cancelled == true || delivered == true }
}
public struct SwiggyOrderList: Decodable {
    public struct Order: Decodable {
        public let orderId: String
        public let restaurantName: String
        public let orderStatus: String
        public let orderDeliveryStatus: String?
        public let isActiveOrder: Bool
    }
    public let orders: [Order]
}
public struct SwiggyAddressList: Decodable {
    public struct Address: Decodable, Identifiable {
        public let id: String
        public let addressLine: String
        public let addressTag: String?
    }
    public struct Pagination: Decodable { public let page: Int; public let total: Int; public let hasMore: Bool }
    public let addresses: [Address]
    public let pagination: Pagination
}

public enum SwiggyReadPolicy {
    public static let tools: Set<String> = ["get_addresses", "get_food_orders", "get_food_delivery_status"]
    public static func validate(tool: String) throws {
        guard tools.contains(tool) else { throw SwiggyDataError.disallowedTool }
    }
    public static func callbackCode(target: String, state: String) -> String? {
        guard let url = URLComponents(string: "http://localhost" + target), url.path == "/callback",
              url.queryItems?.filter({ $0.name == "state" }).count == 1,
              url.queryItems?.first(where: { $0.name == "state" })?.value == state,
              url.queryItems?.filter({ $0.name == "code" }).count == 1,
              let code = url.queryItems?.first(where: { $0.name == "code" })?.value, !code.isEmpty,
              !url.queryItems!.contains(where: { $0.name == "error" }) else { return nil }
        return code
    }
    /// Accept only a successful structured MCP result. Never interpret prose as order data.
    public static func payload(_ result: [String: Any]) throws -> Data {
        guard result["isError"] as? Bool != true else { throw SwiggyDataError.invalidResponse }
        var envelope = result["structuredContent"] as? [String: Any]
        if envelope == nil, let contents = result["content"] as? [[String: Any]] {
            for item in contents where item["type"] as? String == "text" {
                if let text = item["text"] as? String, let data = text.data(using: .utf8),
                   let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    envelope = object; break
                }
            }
        }
        guard let envelope, envelope["success"] as? Bool == true,
              let data = envelope["data"] as? [String: Any] else { throw SwiggyDataError.invalidResponse }
        return try JSONSerialization.data(withJSONObject: data)
    }
}

private extension String {
    var nilIfBlank: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}
