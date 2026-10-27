import Foundation

/// Reconciliation is a fallback; lifecycle and source events still refresh immediately.
public enum EnergyPolicy {
    /// Fast first recovery, bounded retries during persistent adapter failure.
    public static func mediaRetry(failures: Int) -> TimeInterval {
        [1.0, 2, 5, 15, 30][min(4, max(0, failures - 1))]
    }

    public static func clockInterval(trusted: Bool, appRunning: Bool, setupVisible: Bool,
                                     hasTimers: Bool, runningTimer: Bool, lowPower: Bool) -> TimeInterval? {
        if !trusted { return setupVisible ? 1 : nil }
        guard appRunning else { return nil }
        if !hasTimers { return lowPower ? 60 : 30 }
        // Keep snapshots within the five-second native control freshness window,
        // including the timer's 20% tolerance. Never loosen control validation.
        return runningTimer && !lowPower ? 2 : 4
    }

    public static func discoveryNeeded(age: TimeInterval?, browsing: Bool, lowPower: Bool) -> Bool {
        guard let age, age >= 0 else { return true }
        return age >= PollPolicy.discovery(browsing: browsing, lowPower: lowPower, failures: 0)
    }

    /// Routine position ticks need no model publication; seeks/rate changes still do.
    public static func positionChanged(previous: PlaybackAnchor, next: PlaybackAnchor, now: TimeInterval) -> Bool {
        previous.rate != next.rate || previous.duration != next.duration ||
            abs(previous.value(at: now) - next.value(at: now)) > 0.75
    }
}
