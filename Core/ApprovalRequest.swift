import Foundation

public enum ApprovalProvider: String, Codable, CaseIterable, Sendable {
    case codex, claudeCode = "claude-code"
    public var label: String { self == .codex ? "Codex / local ChatGPT" : "Claude Code" }
}
public enum ApprovalDecision: String, Sendable { case allow, deny, passthrough }

/// Only a real synchronous PermissionRequest can receive a decision.
public struct ApprovalRequest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let provider: ApprovalProvider
    public let session: String
    public let tool: String
    public let details: String
    public let summary: String
    public let expires: Date
    public static let maximumBytes = 262_144
    public static func decode(_ data: Data, secret: String, now: Date = Date()) -> Self? {
        guard data.count <= maximumBytes,
              let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              envelope["version"] as? Int == 1, secret.count >= 32,
              envelope["token"] as? String == secret,
              let idText = envelope["id"] as? String, let id = UUID(uuidString: idText),
              let name = envelope["provider"] as? String, let provider = ApprovalProvider(rawValue: name),
              let created = envelope["created"] as? Double, created.isFinite,
              abs(now.timeIntervalSince1970 - created) <= 10,
              let hook = envelope["hook"] as? [String: Any],
              hook["hook_event_name"] as? String == "PermissionRequest",
              let session = hook["session_id"] as? String, !session.isEmpty, session.count <= 1024,
              let tool = hook["tool_name"] as? String, !tool.isEmpty, tool.count <= 256,
              hook["tool_input"] != nil,
              let formatted = try? JSONSerialization.data(withJSONObject: hook, options: [.prettyPrinted, .sortedKeys]),
              let details = String(data: formatted, encoding: .utf8) else { return nil }
        return .init(id: id, provider: provider, session: session, tool: tool, details: details, summary: ApprovalSummary.line(tool: tool, input: hook["tool_input"]),
                     expires: Date(timeIntervalSince1970: created + 120))
    }
    public static func response(id: UUID, decision: ApprovalDecision) -> Data {
        let value: [String: Any] = ["id": id.uuidString, "decision": decision.rawValue]
        return (try? JSONSerialization.data(withJSONObject: value)) ?? Data()
    }
    public static func hookOutput(_ response: Data, expectedID: UUID) -> Data? {
        guard let value = try? JSONSerialization.jsonObject(with: response) as? [String: Any],
              value["id"] as? String == expectedID.uuidString,
              let raw = value["decision"] as? String, let decision = ApprovalDecision(rawValue: raw),
              decision != .passthrough else { return nil }
        var decisionObject: [String: String] = ["behavior": decision.rawValue]
        if decision == .deny { decisionObject["message"] = "Declined by the user in NotchIslandSports." }
        return try? JSONSerialization.data(withJSONObject: ["hookSpecificOutput": [
            "hookEventName": "PermissionRequest", "decision": decisionObject]])
    }
}

public enum ApprovalHookConfiguration {
    public static func command(helper: String, provider: ApprovalProvider) -> String {
        let quoted = "'" + helper.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return "\(quoted) --notch-approval \(provider.rawValue)"
    }
    /// Preserve all unrelated settings/hooks. Never change permission modes or trust.
    public static func merge(_ data: Data?, command: String, previousCommand: String? = nil, remove: Bool = false) throws -> Data {
        var root: [String: Any] = [:]
        if let data {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw CocoaError(.fileReadCorruptFile) }
            root = parsed
        }
        if let existing = root["hooks"], !(existing is [String: Any]) { throw CocoaError(.fileReadCorruptFile) }
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        if let existing = hooks["PermissionRequest"], !(existing is [[String: Any]]) { throw CocoaError(.fileReadCorruptFile) }
        var groups = hooks["PermissionRequest"] as? [[String: Any]] ?? []
        groups = groups.compactMap { group in
            var group = group
            guard let entries = group["hooks"] as? [[String: Any]] else { return group }
            let kept = entries.filter { entry in
                let text = entry["command"] as? String
                return text != command && (previousCommand == nil || text != previousCommand)
            }
            if kept.isEmpty && !entries.isEmpty { return nil }
            group["hooks"] = kept; return group
        }
        if !remove { groups.append(["matcher": "*", "hooks": [["type": "command", "command": command, "timeout": 130]]]) }
        hooks["PermissionRequest"] = groups; root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }
}

/// A deterministic preview of the actual action; the full request is always retained.
public enum ApprovalSummary {
    public static func line(tool: String, input: Any?) -> String {
        let fields = input as? [String: Any] ?? [:]
        func clean(_ text: String) -> String {
            String(text.replacingOccurrences(of: "\n", with: " ↵ ")
                .replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\t", with: " ").prefix(300))
        }
        if let command = (fields["command"] ?? fields["cmd"]) as? String, !command.isEmpty {
            return "Run: " + clean(command)
        }
        if let permissions = fields["permissions"] as? [String: Any] {
            var scopes: [String] = []
            if let files = permissions["file_system"] as? [String: Any] {
                for key in ["read", "write"] {
                    if let paths = files[key] as? [String], !paths.isEmpty {
                        scopes.append("\(key): " + paths.joined(separator: ", "))
                    }
                }
            }
            if (permissions["network"] as? [String: Any])?["enabled"] as? Bool == true { scopes.append("network access") }
            if !scopes.isEmpty { return "Allow " + clean(scopes.joined(separator: "; ")) }
        }
        if let path = (fields["file_path"] ?? fields["path"]) as? String, !path.isEmpty {
            return clean(tool + ": " + path)
        }
        if let patch = input as? String, tool.contains("patch") {
            let paths = patch.components(separatedBy: "\n").filter {
                $0.hasPrefix("*** Update File:") || $0.hasPrefix("*** Add File:") || $0.hasPrefix("*** Delete File:")
            }.map { $0.replacingOccurrences(of: "*** ", with: "") }
            if !paths.isEmpty { return clean(paths.joined(separator: "; ")) }
        }
        let normalized = tool.replacingOccurrences(of: "mcp__codex_apps__", with: "")
            .replacingOccurrences(of: "mcp__github__", with: "github_")
        let repository = (fields["repository_full_name"] ?? fields["repo_full_name"]) as? String
        let target = repository.map { " · " + $0 } ?? ""
        switch normalized {
        case "github_create_tree":
            let count = (fields["tree_elements"] as? [Any])?.count
            return clean(count.map { "Prepare \($0) file changes" } ?? "Prepare file changes") + clean(target)
        case "github_create_commit": return clean("Create a commit" + target)
        case "github_update_ref":
            let branch = fields["branch_name"] as? String ?? "branch"
            let verb = fields["force"] as? Bool == true ? "Force-update " : "Update "
            return clean(verb + branch + target)
        case "github_create_pull_request": return clean("Open a pull request" + target)
        default: break
        }
        if tool.hasPrefix("mcp__") {
            // Preserve the service and operation, but remove machine-only separators.
            // Unknown operations are not guessed to be read-only or harmless.
            let segments = tool.components(separatedBy: "__").dropFirst()
                .filter { $0 != "codex_apps" && $0 != "codex_app" }
            let words = segments.joined(separator: " ").replacingOccurrences(of: "_", with: " ")
            return clean(words.prefix(1).uppercased() + words.dropFirst())
        }
        return "Use " + clean(tool)
    }
}
