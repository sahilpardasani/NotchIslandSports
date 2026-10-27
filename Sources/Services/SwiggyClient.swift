import Foundation
import Security
import CryptoKit
import IslandCore

enum SwiggyError: Error, LocalizedError {
    case signIn, unavailable, rateLimited(TimeInterval), invalidResponse, storage, callback
    var errorDescription: String? {
        switch self {
        case .signIn: return "Connect Swiggy again to continue tracking."
        case .rateLimited: return "Swiggy asked us to wait. Tracking will retry automatically."
        case .storage: return "Could not save the Swiggy connection in Keychain."
        case .callback: return "Swiggy sign-in was cancelled or timed out. Try connecting again."
        case .invalidResponse: return "Swiggy returned an unsupported response. No delivery estimate was inferred."
        case .unavailable: return "Swiggy is unavailable. Tracking will retry automatically."
        }
    }
}

struct SwiggyCredentials: Codable {
    let accessToken: String
    let refreshToken: String?
    let clientID: String
    let expiresAt: Date
    var addressID: String?
}

protocol SwiggyCredentialStore {
    func load() throws -> SwiggyCredentials?
    func save(_ value: SwiggyCredentials) throws
    func clear() throws
}
struct SwiggyKeychain: SwiggyCredentialStore {
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "NotchIslandSports.Swiggy", kSecAttrAccount as String: "tracking"]
    }
    func load() throws -> SwiggyCredentials? {
        var q = query; q[kSecReturnData as String] = true
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw SwiggyError.storage }
        return try JSONDecoder().decode(SwiggyCredentials.self, from: data)
    }
    func save(_ value: SwiggyCredentials) throws {
        let data = try JSONEncoder().encode(value)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var q = query; q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw SwiggyError.storage }
        } else if status != errSecSuccess { throw SwiggyError.storage }
    }
    func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SwiggyError.storage }
    }
}

/// Tokens go only to the verified Swiggy origin. Redirects must never forward them.
private final class SwiggyRedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

@MainActor
final class SwiggyClient {
    private let session: URLSession
    private let store: SwiggyCredentialStore
    private(set) var credentials: SwiggyCredentials?
    private var sessionID: String?
    private var protocolVersion = "2025-03-26"
    private var generation = 0
    init(store: SwiggyCredentialStore = SwiggyKeychain(), session: URLSession? = nil) {
        self.store = store
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 25; config.timeoutIntervalForResource = 30
        config.httpCookieStorage = nil; config.urlCache = nil
        self.session = session ?? URLSession(configuration: config, delegate: SwiggyRedirectGuard(), delegateQueue: nil)
    }
    func restore() throws { credentials = try store.load(); sessionID = nil }
    func disconnect() throws {
        generation += 1; credentials = nil; sessionID = nil
        try store.clear()
    }
    func chooseAddress(_ id: String) throws {
        guard var value = credentials else { throw SwiggyError.signIn }
        value.addressID = id; try store.save(value); credentials = value
    }
    static func randomURLToken() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw SwiggyError.unavailable }
        return Data(bytes).base64URL
    }
    static func challenge(_ verifier: String) -> String { Data(SHA256.hash(data: Data(verifier.utf8))).base64URL }
    func register(redirect: String) async throws -> String {
        let result = try await request(path: "/auth/register", body: ["client_name": "NotchIslandSports",
            "redirect_uris": [redirect], "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"], "token_endpoint_auth_method": "none"])
        guard let id = result["client_id"] as? String, !id.isEmpty else { throw SwiggyError.invalidResponse }
        return id
    }
    func authorizeURL(clientID: String, redirect: String, verifier: String, state: String) -> URL {
        var url = URLComponents(string: "https://mcp.swiggy.com/auth/authorize")!
        url.queryItems = ["response_type": "code", "client_id": clientID, "redirect_uri": redirect,
            "code_challenge": Self.challenge(verifier), "code_challenge_method": "S256", "state": state,
            "scope": "mcp:tools", "resource": "https://mcp.swiggy.com"].map { URLQueryItem(name: $0.key, value: $0.value) }
        return url.url!
    }
    func exchange(code: String, clientID: String, redirect: String, verifier: String) async throws {
        let epoch = generation
        let result = try await request(path: "/auth/token", body: ["grant_type": "authorization_code",
            "client_id": clientID, "code": code, "code_verifier": verifier, "redirect_uri": redirect])
        try Task.checkCancellation(); guard generation == epoch else { throw CancellationError() }
        try installToken(result, clientID: clientID, previous: nil)
    }
    private func installToken(_ json: [String: Any], clientID: String, previous: SwiggyCredentials?) throws {
        guard let token = json["access_token"] as? String, !token.isEmpty,
              let lifetime = json["expires_in"] as? Double, lifetime.isFinite, lifetime > 0,
              (json["token_type"] as? String)?.lowercased() == "bearer" else { throw SwiggyError.invalidResponse }
        let value = SwiggyCredentials(accessToken: token, refreshToken: json["refresh_token"] as? String ?? previous?.refreshToken,
            clientID: clientID, expiresAt: Date().addingTimeInterval(lifetime), addressID: previous?.addressID)
        try store.save(value); credentials = value; sessionID = nil
    }
    private func refresh() async throws {
        guard let old = credentials, let refresh = old.refreshToken else { throw SwiggyError.signIn }
        let epoch = generation
        let result = try await request(path: "/auth/token", body: ["grant_type": "refresh_token",
            "refresh_token": refresh, "client_id": old.clientID])
        try Task.checkCancellation(); guard epoch == generation else { throw CancellationError() }
        try installToken(result, clientID: old.clientID, previous: old)
    }
    func call<T: Decodable>(_ tool: String, arguments: [String: Any] = [:], as type: T.Type) async throws -> T {
        try SwiggyReadPolicy.validate(tool: tool)
        guard credentials != nil else { throw SwiggyError.signIn }
        if credentials!.expiresAt.timeIntervalSinceNow <= 60 { try await refresh() }
        for attempt in 0...1 {
            do {
                if sessionID == nil { try await initialize() }
                let result = try await rpc(method: "tools/call", params: ["name": tool, "arguments": arguments])
                return try JSONDecoder().decode(type, from: SwiggyReadPolicy.payload(result))
            } catch SwiggyError.signIn where attempt == 0 { try await refresh() }
        }
        throw SwiggyError.signIn
    }
    private func initialize() async throws {
        let result = try await rpc(method: "initialize", params: ["protocolVersion": protocolVersion,
            "capabilities": [:], "clientInfo": ["name": "NotchIslandSports", "version": "1.6.0"]])
        guard let version = result["protocolVersion"] as? String,
              ["2024-11-05", "2025-03-26", "2025-06-18"].contains(version) else { throw SwiggyError.invalidResponse }
        protocolVersion = version
        _ = try await request(path: "/food", body: ["jsonrpc": "2.0", "method": "notifications/initialized"],
                              token: credentials?.accessToken, notification: true)
        // Stateless MCP servers don't issue a session ID; empty marks initialization complete.
        if sessionID == nil { sessionID = "" }
    }
    private func rpc(method: String, params: [String: Any]) async throws -> [String: Any] {
        let id = UUID().uuidString
        let envelope = try await request(path: "/food", body: ["jsonrpc": "2.0", "id": id, "method": method, "params": params],
                                         token: credentials?.accessToken, rpcID: id)
        if let error = envelope["error"] as? [String: Any] {
            if error["code"] as? Int == -32001 { throw SwiggyError.signIn }
            throw SwiggyError.invalidResponse
        }
        guard envelope["id"] as? String == id, let result = envelope["result"] as? [String: Any] else { throw SwiggyError.invalidResponse }
        return result
    }
    private func request(path: String, body: [String: Any], token: String? = nil,
                         rpcID: String? = nil, notification: Bool = false) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "https://mcp.swiggy.com" + path)!)
        request.httpMethod = "POST"; request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if path == "/food" {
            request.setValue(protocolVersion, forHTTPHeaderField: "MCP-Protocol-Version")
            if let sessionID, !sessionID.isEmpty { request.setValue(sessionID, forHTTPHeaderField: "Mcp-Session-Id") }
        }
        let epoch = generation
        let (bytes, response) = try await session.bytes(for: request)
        defer { bytes.task.cancel() }
        try Task.checkCancellation(); guard epoch == generation else { throw CancellationError() }
        guard let response = response as? HTTPURLResponse else { throw SwiggyError.unavailable }
        if response.statusCode == 401 || response.statusCode == 419 || (path == "/auth/token" && response.statusCode == 400) { throw SwiggyError.signIn }
        if response.statusCode == 429 {
            let delay = Double(response.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 120
            throw SwiggyError.rateLimited(delay.isFinite ? max(60, min(86_400, delay)) : 120)
        }
        if response.statusCode == 404, path == "/food" { sessionID = nil }
        guard (200..<300).contains(response.statusCode) else { throw SwiggyError.unavailable }
        if let id = response.value(forHTTPHeaderField: "Mcp-Session-Id") { sessionID = id }
        if notification { return [:] }
        var data = Data()
        let sse = response.value(forHTTPHeaderField: "Content-Type")?.contains("text/event-stream") == true
        if sse {
            var event = Data(); var count = 0
            // AsyncBytes.lines drops blank lines on some Foundation releases;
            // SSE event boundaries must be parsed from the original bytes.
            for try await byte in bytes {
                try Task.checkCancellation(); count += 1; event.append(byte)
                guard count < 2_000_000 else { throw SwiggyError.invalidResponse }
                if event.suffix(2) == Data([10, 10]) || event.suffix(4) == Data([13, 10, 13, 10]) {
                    let payload = String(decoding: event, as: UTF8.self).components(separatedBy: .newlines)
                        .filter { $0.hasPrefix("data:") }.map { String($0.dropFirst(5)).trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
                    if let value = payload.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: value) as? [String: Any],
                       json["id"] as? String == rpcID { return json }
                    event.removeAll(keepingCapacity: true)
                }
            }
            throw SwiggyError.invalidResponse
        }

        for try await byte in bytes {
            data.append(byte)
            guard data.count < 2_000_000 else { throw SwiggyError.invalidResponse }
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw SwiggyError.invalidResponse }
        return json
    }
}
private extension Data {
    var base64URL: String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
}
