import Foundation
import Darwin
import IslandCore

@main struct ApprovalChecks {
    static func main() throws {
        var count = 0
        func check(_ value: Bool, _ name: String) { precondition(value, name); count += 1 }
        let secret = String(repeating: "s", count: 64), id = UUID(), instant = Date()
        var hook: [String: Any] = ["hook_event_name": "PermissionRequest", "session_id": "synthetic-session", "tool_name": "Bash", "tool_input": ["command": "echo 'approval test'", "description": "Synthetic transport test"]]
        func packet(_ token: String = secret, id: UUID = id, provider: String = "codex", created: Date = instant) throws -> Data {
            try JSONSerialization.data(withJSONObject: ["version": 1, "id": id.uuidString, "provider": provider, "token": token, "created": created.timeIntervalSince1970, "hook": hook])
        }
        let accepted = ApprovalRequest.decode(try packet(), secret: secret, now: instant)!
        check(accepted.id == id && accepted.provider == .codex && accepted.tool == "Bash", "Valid local hook accepted")
        check(ApprovalRequest.decode(try packet(provider: "claude-code"), secret: secret, now: instant)?.provider == .claudeCode, "Claude contract accepted")
        check(ApprovalRequest.decode(try packet("wrong"), secret: secret, now: instant) == nil, "Forged token rejected")
        check(ApprovalRequest.decode(try packet(provider: "chatgpt-universal"), secret: secret, now: instant) == nil, "Unknown surface is not advertised as connected")
        check(ApprovalRequest.decode(try packet(created: instant.addingTimeInterval(-20)), secret: secret, now: instant) == nil, "Old replay rejected")
        check(ApprovalRequest.decode(try packet(created: instant.addingTimeInterval(20)), secret: secret, now: instant) == nil, "Future timestamp rejected")
        hook["hook_event_name"] = "Notification"
        check(ApprovalRequest.decode(try packet(), secret: secret, now: instant) == nil, "Approval words in a notification cannot create actionable request")
        hook["hook_event_name"] = "PermissionRequest"
        hook["tool_input"] = ["command": String(repeating: "x", count: 40000)]
        let large = ApprovalRequest.decode(try packet(), secret: secret, now: instant)!
        check(large.details.contains(String(repeating: "x", count: 40000)), "Full long request preserved without truncation")
        hook["tool_input"] = ["command": String(repeating: "x", count: 270000)]
        check(ApprovalRequest.decode(try packet(), secret: secret, now: instant) == nil, "Oversized request falls back instead of approving partial detail")
        hook["tool_input"] = ["command": "echo test"]
        check(ApprovalRequest.hookOutput(ApprovalRequest.response(id: UUID(), decision: .allow), expectedID: id) == nil, "Mismatched response never approves another request")
        check(ApprovalRequest.hookOutput(ApprovalRequest.response(id: id, decision: .passthrough), expectedID: id) == nil, "Normal prompt emits no decision")
        for decision in [ApprovalDecision.allow, .deny] {
            let result = ApprovalRequest.hookOutput(ApprovalRequest.response(id: id, decision: decision), expectedID: id)!
            let root = try JSONSerialization.jsonObject(with: result) as! [String: Any]
            let output = root["hookSpecificOutput"] as! [String: Any]
            let object = output["decision"] as! [String: Any]
            check(output["hookEventName"] as? String == "PermissionRequest" && object["behavior"] as? String == decision.rawValue, "Exact hook decision schema")
            check(object["updatedPermissions"] == nil && object["updatedInput"] == nil, "One request never changes permanent permission or command")
        }
        let command = ApprovalHookConfiguration.command(helper: "/tmp/a'b/helper", provider: .codex)
        check(command.contains("'\\''"), "Installer quotes paths without executing shell fragments")
        let existing = Data(#"{"permissions":{"defaultMode":"default"},"hooks":{"PermissionRequest":[{"matcher":"Bash","hooks":[{"type":"command","command":"existing-policy"}]}]}}"#.utf8)
        let first = try ApprovalHookConfiguration.merge(existing, command: command)
        let second = try ApprovalHookConfiguration.merge(first, command: command)
        check(first == second, "Reconnect does not duplicate hook")
        let restored = try ApprovalHookConfiguration.merge(second, command: command, remove: true)
        let restoredObject = try JSONSerialization.jsonObject(with: restored) as! NSDictionary
        check(restoredObject.isEqual(to: try JSONSerialization.jsonObject(with: existing) as! [AnyHashable: Any]), "Unrelated policies and settings preserved")
        do { _ = try ApprovalHookConfiguration.merge(Data("broken".utf8), command: command); check(false, "Invalid settings must not be overwritten") }
        catch { check(true, "Invalid settings preserved") }
        var pipes: [Int32] = [0, 0]; pipe(&pipes)
        let raw = Data("{\"hook\":true}".utf8)
        raw.withUnsafeBytes { _ = Darwin.write(pipes[1], $0.baseAddress, $0.count) }; close(pipes[1])
        check(ApprovalSocket.readLine(pipes[0], timeout: 1, maximum: 4096) == raw, "Hook stdin accepts JSON ending at EOF without newline")
        close(pipes[0])

        if ProcessInfo.processInfo.environment["NOTCH_APPROVAL_POLICY_ONLY"] == "1" {
            print("Passed \(count) approval policy/configuration checks; socket tests explicitly skipped in this sandbox.")
            return
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("notch-approval-test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let server = ApprovalServer(directory: directory)
        let arrived = DispatchSemaphore(value: 0)
        server.onRequest = { _ in arrived.signal() }
        server.onError = { print("IPC fixture: \($0)"); fflush(stdout) }
        try ApprovalSocket.ensurePrivateDirectory(directory)
        let unsafe = directory.appendingPathComponent("unsafe")
        try FileManager.default.createDirectory(at: unsafe, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o755])
        do { try ApprovalSocket.ensurePrivateDirectory(unsafe); check(false, "Public directory must be rejected") }
        catch { check(true, "Installer refuses a public credential directory") }
        server.start()
        let endpoint = directory.appendingPathComponent("endpoint.json")
        let deadline = Date().addingTimeInterval(3)
        while !FileManager.default.fileExists(atPath: endpoint.path) && Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
        guard let configData = ApprovalSocket.privateFile(endpoint),
              let config = try JSONSerialization.jsonObject(with: configData) as? [String: String] else {
            fatalError("Could not start local approval socket fixture")
        }
        func connect() -> Int32 {
            var address = ApprovalSocket.address(config["socket"]!)!
            let fd = socket(AF_UNIX, SOCK_STREAM, 0); ApprovalSocket.protect(fd)
            let result = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
            precondition(result == 0); return fd
        }
        let liveID = UUID(), fd = connect()
        _ = ApprovalSocket.send(try packet(config["token"]!, id: liveID, created: Date()), to: fd)
        check(arrived.wait(timeout: .now() + 2) == .success, "Real local socket delivers request")
        var pollState = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        check(poll(&pollState, 1, 30) == 0, "Pending socket never automatically approves")
        server.decide(UUID(), .allow)
        check(poll(&pollState, 1, 30) == 0, "Stale user action cannot affect live request")
        server.decide(liveID, .allow)
        let response = ApprovalSocket.readLine(fd, timeout: 2, maximum: 4096)!
        check(ApprovalRequest.hookOutput(response, expectedID: liveID) != nil, "Explicit exact-ID decision returns on the waiting connection")
        close(fd)
        let replay = connect()
        _ = ApprovalSocket.send(try packet(config["token"]!, id: liveID, created: Date()), to: replay)
        check(ApprovalSocket.readLine(replay, timeout: 2, maximum: 4096) == nil, "Duplicate nonce cannot create second approval")
        close(replay)
        let forged = connect()
        _ = ApprovalSocket.send(try packet("forged", id: UUID(), created: Date()), to: forged)
        check(ApprovalSocket.readLine(forged, timeout: 2, maximum: 4096) == nil, "Socket authentication rejects wrong token")
        close(forged)
        let waiting = connect(), waitingID = UUID()
        _ = ApprovalSocket.send(try packet(config["token"]!, id: waitingID, created: Date()), to: waiting)
        check(arrived.wait(timeout: .now() + 2) == .success, "Second session is independently pending")
        server.stop()
        let canceled = ApprovalSocket.readLine(waiting, timeout: 2, maximum: 4096)!
        check(ApprovalRequest.hookOutput(canceled, expectedID: waitingID) == nil, "Sleep/disconnect returns to normal prompt without approval")
        close(waiting)
        print("Passed \(count) approval policy, configuration and real local IPC checks. No agent action was approved.")
    }
}
