import Foundation

/// A bounded, non-sensitive projection of Clock's accessibility tree.
public struct ClockAXNode: Equatable, Sendable {
    public var role: String
    public var identifier: String
    public var text: String
    public var children: [ClockAXNode]
    public init(role: String, identifier: String = "", text: String = "", children: [ClockAXNode] = []) {
        self.role = role; self.identifier = identifier; self.text = text; self.children = children
    }
}

public struct ObservedClockTimer: Equatable, Identifiable, Sendable {
    public let id: String
    public let remaining: TimeInterval
    public let paused: Bool
    public init(id: String, remaining: TimeInterval, paused: Bool) {
        self.id = id; self.remaining = remaining; self.paused = paused
    }
}

public enum ClockTimerParser {
    /// Conservative English UI prototype. Never parse clocks/stopwatches or presets as live timers.
    public static func parse(_ root: ClockAXNode) -> [ObservedClockTimer] {
        var results: [ObservedClockTimer] = []
        func visit(_ node: ClockAXNode, path: String, depth: Int) {
            guard depth < 12 else { return }
            // A timer card must contain an unambiguous pause/resume control AND cancel.
            let descendants = flatten(node, depth: 3)
            let buttons = descendants.filter { $0.role == "AXButton" }.map { $0.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            let hasPause = buttons.contains("pause") || buttons.contains("pause timer")
            let hasResume = buttons.contains("resume") || buttons.contains("resume timer")
            let hasCancel = buttons.contains("cancel") || buttons.contains("cancel timer")
            let times = descendants.filter { $0.role == "AXStaticText" }.compactMap { duration($0.text) }
            if hasCancel, hasPause != hasResume, times.count == 1 {
                results.append(.init(id: node.identifier.isEmpty ? path : node.identifier,
                                     remaining: times[0], paused: hasResume))
                return
            }
            for (index, child) in node.children.enumerated() { visit(child, path: "\(path).\(index)", depth: depth + 1) }
        }
        visit(root, path: "clock", depth: 0)
        // Ambiguous duplicate identifiers must not become duplicate SwiftUI identities.
        var seen = Set<String>()
        return results.filter { seen.insert($0.id).inserted }
    }

    public static func duration(_ text: String) -> TimeInterval? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: #"^\d{1,3}:\d{2}(:\d{2})?$"#, options: .regularExpression) != nil else { return nil }
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard (2...3).contains(parts.count), parts.dropFirst().allSatisfy({ $0 < 60 }) else { return nil }
        return TimeInterval(parts.reduce(0) { $0 * 60 + $1 })
    }

    private static func flatten(_ node: ClockAXNode, depth: Int) -> [ClockAXNode] {
        guard depth > 0 else { return [node] }
        return [node] + node.children.flatMap { flatten($0, depth: depth - 1) }
    }
}
