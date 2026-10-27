import Foundation

public enum ClockSetupState: Equatable, Sendable {
    case off, needsPermission, connecting, ready, needsAttention
    public static func resolve(enabled: Bool, trusted: Bool, connecting: Bool, validated: Bool, failed: Bool) -> Self {
        guard enabled else { return .off }
        guard trusted else { return .needsPermission }
        if connecting { return .connecting }
        if failed || !validated { return .needsAttention }
        return .ready
    }
    public var canFinish: Bool { self == .off || self == .ready }
    public var label: String {
        switch self {
        case .off: return "Optional · enable to connect your native timers."
        case .needsPermission: return "Waiting for Accessibility permission in System Settings."
        case .connecting: return "Connecting to Apple Clock…"
        case .ready: return "Connected · native timers are ready to observe."
        case .needsAttention: return "Clock setup needs attention. Retry the connection below."
        }
    }
}
