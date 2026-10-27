import Foundation

public enum IslandActivity: String, CaseIterable, Codable, Sendable {
    case sports, music, clock, calendar, approval

    /// Calendar is a browse page, never a live split activity.
    public var occupiesLiveSlot: Bool { self != .calendar }
}

/// Pure selection: content updates never reorder slots; explicit selection can.
public struct ActivitySelection: Equatable, Sendable {
    public private(set) var primary: IslandActivity?
    public private(set) var secondary: IslandActivity?
    public private(set) var tertiary: IslandActivity?
    public private(set) var overflow: [IslandActivity] = []
    public init() {}

    public mutating func update(available: Set<IslandActivity>, preferred: IslandActivity? = nil) {
        let available = available.filter(\.occupiesLiveSlot)
        let existing = [primary, secondary, tertiary].compactMap { $0 } + overflow
        var ordered: [IslandActivity] = []
        if let preferred, available.contains(preferred) { ordered.append(preferred) }
        for activity in existing + IslandActivity.allCases where available.contains(activity) {
            if !ordered.contains(activity) { ordered.append(activity) }
        }
        // Pending attention uses a satellite without stealing the primary under review.
        if available.contains(.approval), ordered.first != .approval {
            ordered.removeAll { $0 == .approval }
            ordered.insert(.approval, at: min(1, ordered.count))
        }
        primary = ordered.first
        secondary = ordered.dropFirst().first
        tertiary = ordered.dropFirst(2).first
        overflow = Array(ordered.dropFirst(3))
    }
}

public struct RequestGeneration: Equatable, Sendable {
    public private(set) var value: UInt64 = 0
    public init() {}
    @discardableResult public mutating func invalidate() -> UInt64 {
        value &+= 1
        return value
    }
    public func accepts(_ token: UInt64) -> Bool { value == token }
}

public enum PollPolicy {
    public static func discovery(browsing: Bool, lowPower: Bool, failures: Int) -> TimeInterval {
        backoff(base: browsing ? 120 : 900, lowPower: lowPower, failures: failures)
    }
    public static func detail(live: Bool, completed: Bool, expanded: Bool,
                              lowPower: Bool, failures: Int) -> TimeInterval {
        backoff(base: completed ? 900 : (live ? (expanded ? 15 : 30) : 120),
                lowPower: lowPower, failures: failures)
    }
    private static func backoff(base: TimeInterval, lowPower: Bool, failures: Int) -> TimeInterval {
        min(1800, base * (lowPower ? 2 : 1) * pow(2, Double(min(4, max(0, failures)))))
    }
}

/// Position is anchored, never incremented by UI timer ticks.
public struct PlaybackAnchor: Sendable {
    public let position: TimeInterval
    public let instant: TimeInterval
    public let rate: Double
    public let duration: TimeInterval
    public init(position: TimeInterval, instant: TimeInterval, rate: Double, duration: TimeInterval) {
        self.position = position.isFinite ? max(0, position) : 0
        self.instant = instant
        self.rate = rate.isFinite ? max(0, rate) : 0
        self.duration = duration.isFinite ? max(0, duration) : 0
    }
    public func value(at now: TimeInterval) -> TimeInterval {
        let value = max(0, position + max(0, now - instant) * rate)
        return duration > 0 ? min(duration, value) : value
    }
}
