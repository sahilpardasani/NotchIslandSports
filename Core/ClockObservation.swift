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
    public let controlIdentifier: String?
    public var canControl: Bool { controlIdentifier != nil }
    public init(id: String, remaining: TimeInterval, paused: Bool, controlIdentifier: String? = nil) {
        self.id = id; self.remaining = remaining; self.paused = paused; self.controlIdentifier = controlIdentifier
    }
}

public enum ClockTimerParser {
    /// Conservative English UI prototype. Never parse clocks/stopwatches or presets as live timers.
    public static func parse(_ root: ClockAXNode) -> [ObservedClockTimer] {
        var results: [ObservedClockTimer] = []
        func visit(_ node: ClockAXNode, path: String, depth: Int) {
            guard depth < 12 else { return }
            // Prefer the smallest recognizable card, never an application/window-wide action target.
            let priorCount = results.count
            for (index, child) in node.children.enumerated() { visit(child, path: "\(path).\(index)", depth: depth + 1) }
            if results.count > priorCount { return }
            // A timer card must contain an unambiguous pause/resume control AND cancel.
            let descendants = flatten(node, depth: 3)
            let buttons = descendants.filter { $0.role == "AXButton" }.map { $0.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            let hasPause = buttons.contains("pause") || buttons.contains("pause timer")
            let hasResume = buttons.contains("resume") || buttons.contains("resume timer")
            let hasCancel = buttons.contains("cancel") || buttons.contains("cancel timer")
            let times = descendants.filter { $0.role == "AXStaticText" }.compactMap { duration($0.text) }
            if hasCancel, hasPause != hasResume, times.count == 1 {
                results.append(.init(id: node.identifier.isEmpty ? path : node.identifier,
                                     remaining: times[0], paused: hasResume,
                                     controlIdentifier: !node.identifier.isEmpty && ["AXGroup", "AXLayoutItem"].contains(node.role) ? node.identifier : nil))
                return
            }
        }
        visit(root, path: "clock", depth: 0)
        // Ambiguous duplicate identifiers must not become duplicate SwiftUI identities.
        let counts = Dictionary(grouping: results, by: \.id).mapValues(\.count)
        var seen = Set<String>()
        return results.filter { seen.insert($0.id).inserted }.map { timer in
            counts[timer.id] == 1 ? timer : ObservedClockTimer(id: timer.id, remaining: timer.remaining, paused: timer.paused)
        }
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

public enum NativeClockCommand: String, Sendable { case pause, resume, cancel }

public enum ClockControlPolicy {
    /// Do not dispatch against a stale/replaced timer or an unexpected pause/resume state.
    public static func accepts(previous: ObservedClockTimer, current: ObservedClockTimer,
                               age: TimeInterval, command: NativeClockCommand) -> Bool {
        guard age >= 0, age <= 5, previous.canControl, current.canControl,
              previous.controlIdentifier == current.controlIdentifier, previous.id == current.id,
              previous.paused == current.paused else { return false }
        let drift = previous.remaining - current.remaining
        guard drift >= -1, drift <= (previous.paused ? 1 : age + 2) else { return false }
        return command == .cancel || (command == .pause && !current.paused) || (command == .resume && current.paused)
    }
}
