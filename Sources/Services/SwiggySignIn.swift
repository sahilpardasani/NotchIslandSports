import Foundation
import Network
import IslandCore

/// Short-lived IPv4 loopback callback, protected by OAuth state and PKCE.
@MainActor
final class SwiggySignIn {
    private let state: String
    private var listener: NWListener?
    private var startContinuation: CheckedContinuation<String, Error>?
    private var codeContinuation: CheckedContinuation<String, Error>?
    private var result: Result<String, Error>?
    private var connections: [NWConnection] = []
    private var timeout: Task<Void, Never>?
    init(state: String) { self.state = state }

    func start() async throws -> String {
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: params)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in self?.receive(connection) }
        }
        listener.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor in
                guard let self else { return }
                switch newState {
                case .ready:
                    if let port = self.listener?.port {
                        self.startContinuation?.resume(returning: "http://localhost:\(port.rawValue)/callback")
                        self.startContinuation = nil
                    }
                case .failed: self.cancel()
                default: break
                }
            }
        }
        timeout = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 180_000_000_000); self?.cancel() } catch {}
        }
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                startContinuation = continuation; listener.start(queue: .main)
            }
        }, onCancel: { Task { @MainActor in self.cancel() } })
    }
    func code() async throws -> String {
        if let result { return try result.get() }
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { codeContinuation = $0 }
        }, onCancel: { Task { @MainActor in self.cancel() } })
    }
    func cancel() { finish(.failure(SwiggyError.callback)) }
    private func finish(_ result: Result<String, Error>) {
        guard self.result == nil else { return }
        self.result = result
        startContinuation?.resume(throwing: SwiggyError.callback); startContinuation = nil
        codeContinuation?.resume(with: result); codeContinuation = nil
        timeout?.cancel(); timeout = nil
        listener?.cancel(); listener = nil
        connections.forEach { $0.cancel() }; connections.removeAll()
    }
    private func receive(_ connection: NWConnection) {
        guard result == nil, connections.count < 8 else { connection.cancel(); return }
        connections.append(connection)
        connection.start(queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { connection.cancel() }
        read(connection, buffer: Data())
    }
    private func read(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] bytes, _, complete, error in
            Task { @MainActor in
                guard let self else { connection.cancel(); return }
                let data = buffer + (bytes ?? Data())
                guard error == nil, data.count <= 8192 else { self.close(connection); return }
                guard let header = String(data: data, encoding: .utf8), header.contains("\r\n\r\n") else {
                    if complete { self.close(connection) } else { self.read(connection, buffer: data) }
                    return
                }
                let parts = header.components(separatedBy: "\r\n").first?.split(separator: " ") ?? []
                let code = parts.count == 3 && parts[0] == "GET" ? SwiggyReadPolicy.callbackCode(target: String(parts[1]), state: self.state) : nil
                let body = code == nil ? "Sign-in response not accepted. Return to Swiggy sign-in." : "Swiggy connected. You can close this tab and return to NotchIslandSports."
                let response = "HTTP/1.1 \(code == nil ? "400 Bad Request" : "200 OK")\r\nContent-Type: text/plain; charset=utf-8\r\nCache-Control: no-store\r\nContent-Security-Policy: default-src 'none'\r\nConnection: close\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
                connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                    Task { @MainActor in
                        self.close(connection)
                        if let code { self.finish(.success(code)) }
                    }
                })
            }
        }
    }
    private func close(_ connection: NWConnection) {
        connection.cancel(); connections.removeAll { $0 === connection }
    }
}
