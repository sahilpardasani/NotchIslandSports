import Foundation

/// A bounded, non-sensitive projection of Clock's accessibility tree.
public struct ClockAXNode: Equatable, Sendable {
    public var role: String
    public var identifier: String
    public var text: String
    public var children: [ClockAXNode]
    public var selected: Bool
    public init(role: String, identifier: String = "", text: String = "", children: [ClockAXNode] = [], selected: Bool = false) {
        self.role = role; self.identifier = identifier; self.text = text; self.children = children; self.selected = selected
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
        let selected = selectedDetail(root)
        var results: [ObservedClockTimer] = []
        func visit(_ node: ClockAXNode, path: String, depth: Int) {
            guard depth < 20 else { return }
            // Prefer the smallest recognizable card, never an application/window-wide action target.
            let priorCount = results.count
            for (index, child) in node.children.enumerated() { visit(child, path: "\(path).\(index)", depth: depth + 1) }
            if results.count > priorCount { return }
            // A timer card must contain an unambiguous pause/resume control AND cancel.
            guard ["AXGroup", "AXLayoutItem", "AXRow"].contains(node.role) else { return }
            let descendants = flatten(node, depth: 5)
            let buttons = descendants.filter { $0.role == "AXButton" }.map { $0.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            let hasPause = buttons.contains("pause") || buttons.contains("pause timer")
            let hasResume = buttons.contains("resume") || buttons.contains("resume timer")
            let hasCancel = buttons.contains("cancel") || buttons.contains("cancel timer")
            let times = Array(Set(descendants.filter { $0.role == "AXStaticText" }.compactMap { duration($0.text) }))
            // Current Clock places active/paused timers in UUID sidebar cards,
            // while Cancel lives in a separate detail pane. Recent Start presets
            // must never create a live activity. Observing a card grants no control.
            if UUID(uuidString: node.identifier) != nil, hasPause != hasResume {
                let summaries = descendants.filter { $0.role == "AXStaticText" }
                    .compactMap { summaryDuration($0.text) }
                let distinct = Set(summaries)
                if distinct.count == 1, let remaining = distinct.first {
                    results.append(.init(id: node.identifier, remaining: remaining, paused: hasResume))
                    return
                }
            }
            if hasCancel, hasPause != hasResume, times.count == 1 {
                results.append(.init(id: node.identifier.isEmpty ? path : node.identifier,
                                     remaining: times[0], paused: hasResume,
                                     controlIdentifier: !node.identifier.isEmpty && ["AXGroup", "AXLayoutItem"].contains(node.role) ? node.identifier : nil))
                return
            }
        }
        visit(root, path: "clock", depth: 0)
        if let selected {
            results.removeAll { $0.id == selected.timer.id || $0.id == selected.detailPath }
            // The selected detail and its sidebar summary represent one timer.
            results.insert(selected.timer, at: 0)
        }
        // Ambiguous duplicate identifiers must not become duplicate SwiftUI identities.
        let counts = Dictionary(grouping: results, by: \.id).mapValues(\.count)
        var seen = Set<String>()
        return results.filter { seen.insert($0.id).inserted }.map { timer in
            counts[timer.id] == 1 ? timer : ObservedClockTimer(id: timer.id, remaining: timer.remaining, paused: timer.paused)
        }
    }

    /// The installed Clock UI separates a selected sidebar timer from its detail controls.
    /// Pair only one selected UUID card with one matching detail group in the SAME window.
    /// Paths are snapshot lookup keys, not timer identities; the semantic UUID is rechecked.
    public static func selectedDetail(_ root: ClockAXNode) -> ClockSelectedDetail? {
        var matches: [ClockSelectedDetail] = []
        for (windowIndex, window) in root.children.enumerated() where window.role == "AXWindow" {
            var nodes: [(ClockAXNode, String)] = []
            func walk(_ node: ClockAXNode, _ path: String, _ depth: Int) {
                guard depth < 20 else { return }
                nodes.append((node, path))
                for (index, child) in node.children.enumerated() { walk(child, "\(path).\(index)", depth + 1) }
            }
            walk(window, "clock.\(windowIndex)", 0)
            let selected = nodes.filter { node, _ in
                node.selected && ["AXGroup", "AXLayoutItem"].contains(node.role) && UUID(uuidString: node.identifier) != nil
            }
            guard selected.count == 1 else { continue }
            let (card, selectionPath) = selected[0]
            let cardNodes = flatten(card, depth: 5)
            let summaries = cardNodes.filter { $0.role == "AXStaticText" && $0.identifier == card.identifier }
            let states = cardNodes.filter { $0.role == "AXButton" }.map { normalizedAction($0.text) }
            guard summaries.count == 1, states.count == 1, ["pause", "resume"].contains(states[0]),
                  let remaining = summaryDuration(summaries[0].text) else { continue }
            let paused = states[0] == "resume"
            let candidates = nodes.compactMap { node, path -> (String, TimeInterval)? in
                guard ["AXGroup", "AXLayoutItem"].contains(node.role) else { return nil }
                let detailNodes = flatten(node, depth: 5)
                let buttons = detailNodes.filter { $0.role == "AXButton" }
                let cancel = buttons.filter { $0.identifier == "CancelButton" && normalizedAction($0.text) == "cancel" }
                let toggle = buttons.filter { $0.identifier == "PauseResumeButton" && normalizedAction($0.text) == states[0] }
                let times = Array(Set(detailNodes.filter { $0.role == "AXStaticText" }.compactMap { duration($0.text) }))
                guard cancel.count == 1, toggle.count == 1, buttons.count == 2, times.count == 1,
                      abs(times[0] - remaining) <= (paused ? 0 : 1) else { return nil }
                return (path, times[0])
            }
            let details = candidates.filter { candidate in
                !candidates.contains { $0.0.hasPrefix(candidate.0 + ".") }
            }
            guard details.count == 1 else { continue }
            matches.append(.init(timer: .init(id: card.identifier, remaining: details[0].1, paused: paused,
                controlIdentifier: "selected-detail/" + card.identifier), detailPath: details[0].0, selectionPath: selectionPath))
        }
        return matches.count == 1 ? matches[0] : nil
    }

    public static func normalizedAction(_ text: String) -> String {
        let value = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return ["pause timer": "pause", "resume timer": "resume", "cancel timer": "cancel"][value] ?? value
    }

    private static func summaryDuration(_ text: String) -> TimeInterval? {
        guard let first = text.split(separator: ",", maxSplits: 1).first else { return nil }
        return duration(String(first))
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

public struct ClockSelectedDetail: Sendable {
    public let timer: ObservedClockTimer
    public let detailPath: String
    public let selectionPath: String
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

/// A failed/partial AX read is different from a successful empty Timers page.
/// Brief failures retain a read-only display; stale controls are never retained.
public struct ClockObservationCache: Sendable {
    public private(set) var timers: [ObservedClockTimer] = []
    private var lastSuccess: Date?
    public init() {}
    public func remainingLifetime(at now: Date) -> TimeInterval {
        guard !timers.isEmpty, let lastSuccess else { return 0 }
        return max(0, 10 - now.timeIntervalSince(lastSuccess))
    }
    public mutating func update(_ snapshot: [ObservedClockTimer]?, now: Date) {
        if let snapshot { timers = snapshot; lastSuccess = now; return }
        guard let lastSuccess, (0..<10).contains(now.timeIntervalSince(lastSuccess)) else {
            timers = []; return
        }
        timers = timers.map { .init(id: $0.id, remaining: $0.remaining, paused: $0.paused) }
    }
}
