import AppKit
import Combine
import IslandCore

@MainActor final class ApprovalManager: ObservableObject {
    @Published private(set) var requests: [ApprovalRequest] = []
    @Published private(set) var status = "Connect local sessions once. No requests are approved automatically."
    @Published var enabled = UserDefaults.standard.bool(forKey: "IslandApprovalsEnabled") {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "IslandApprovalsEnabled")
            if enabled && active { startServer() } else { server.stop(); requests.removeAll() }
        }
    }
    private let server = ApprovalServer()
    private var active = false
    init() {
        server.onRequest = { [weak self] request in
            Task(priority: .userInitiated) { @MainActor in
                guard let self, self.active, self.enabled, request.expires > Date(),
                      !self.requests.contains(where: { $0.id == request.id }) else { return }
                self.requests.append(request)
                self.status = "Receiving \(request.provider.label) permission requests."
            }
        }
        server.onRemoval = { [weak self] id in
            Task { @MainActor in self?.requests.removeAll { $0.id == id } }
        }
        server.onError = { [weak self] message in Task { @MainActor in self?.status = message } }
    }
    func start() { active = true; if enabled { startServer() } }
    func stop() { active = false; server.stop(); requests.removeAll() }
    private func startServer() {
        // Keep an already connected helper current after replacing the app bundle.
        // This never installs new hooks, changes their definitions or grants source trust.
        let installed = ApprovalSocket.directory.appendingPathComponent("notch-approval-hook")
        if let existing = ApprovalSocket.privateFile(installed, maximum: 20_000_000),
           let bundled = Bundle.main.resourceURL?.appendingPathComponent("notch-approval-hook"),
           let replacement = try? Data(contentsOf: bundled), existing != replacement {
            do {
                try ApprovalSocket.ensurePrivateDirectory(ApprovalSocket.directory)
                try replacement.write(to: installed, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: installed.path)
            } catch { status = "Could not update the connected approval helper. Reconnect in About → Configure." }
        }
        server.start()
    }
    func decide(_ id: UUID, _ decision: ApprovalDecision) {
        guard active, enabled, let request = requests.first(where: { $0.id == id }), request.expires > Date() else { return }
        // Server checks the same ID and deadline against its still-open connection.
        server.decide(id, decision)
    }
    func connect(_ provider: ApprovalProvider) {
        do {
            let directory = ApprovalSocket.directory
            try ApprovalSocket.ensurePrivateDirectory(directory)
            guard let bundled = Bundle.main.resourceURL?.appendingPathComponent("notch-approval-hook"),
                  FileManager.default.isExecutableFile(atPath: bundled.path) else { throw CocoaError(.fileReadNoSuchFile) }
            let helper = directory.appendingPathComponent("notch-approval-hook")
            let binary = try Data(contentsOf: bundled)
            try binary.write(to: helper, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
            let home = FileManager.default.homeDirectoryForCurrentUser
            let config: URL
            if provider == .codex {
                let codexDirectory = ProcessInfo.processInfo.environment["CODEX_HOME"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? home.appendingPathComponent(".codex", isDirectory: true)
                config = codexDirectory.appendingPathComponent("hooks.json")
            } else { config = home.appendingPathComponent(".claude/settings.json") }
            try FileManager.default.createDirectory(at: config.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            if let attributes = try? FileManager.default.attributesOfItem(atPath: config.path),
               attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                status = "Settings use a symbolic link. Add the hook manually using the setup guide; the link was preserved."
                return
            }
            let existing = FileManager.default.fileExists(atPath: config.path) ? try Data(contentsOf: config) : nil
            let command = ApprovalHookConfiguration.command(helper: helper.path, provider: provider)
            let updated = try ApprovalHookConfiguration.merge(existing, command: command)
            if let existing, existing != updated {
                let backup = directory.appendingPathComponent("\(provider.rawValue)-settings-\(UUID().uuidString).json")
                try existing.write(to: backup, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
            }
            try updated.write(to: config, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.path)
            enabled = true
            status = provider == .codex ? "Hook installed, awaiting source trust. In Codex /hooks, review and trust notch-approval-hook; then restart the local chat." : "Claude Code hook installed. Restart the local Code session; review hooks if prompted."
        } catch { status = "Could not connect. Existing settings were preserved where possible. See the approval setup guide." }
    }
    #if DEBUG
    static func visualFixture() -> ApprovalManager {
        let manager = ApprovalManager()
        let packet: [String: Any] = ["version": 1, "id": UUID().uuidString, "provider": "claude-code", "token": String(repeating: "x", count: 64), "created": Date().timeIntervalSince1970,
            "hook": ["hook_event_name": "PermissionRequest", "session_id": "synthetic-preview", "cwd": "/example/project", "tool_name": "Bash", "tool_input": ["command": "npm test", "description": "Run the project's test suite"]]]
        manager.requests = [ApprovalRequest.decode(try! JSONSerialization.data(withJSONObject: packet), secret: String(repeating: "x", count: 64))!]
        return manager
    }
    #endif
}
