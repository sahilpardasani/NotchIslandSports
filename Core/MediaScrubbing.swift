import Foundation

public struct MediaPlaybackIdentity: Equatable, Sendable {
    public let bundleID: String
    public let title: String
    public let artist: String
    public let duration: Double
    public init(bundleID: String, title: String, artist: String, duration: Double) {
        self.bundleID = bundleID; self.title = title; self.artist = artist; self.duration = duration
    }
}

public struct MediaScrubSession: Sendable {
    public let identity: MediaPlaybackIdentity
    public private(set) var target: Double?
    public private(set) var cancelled = false
    public init(identity: MediaPlaybackIdentity) { self.identity = identity }
    public mutating func update(x: Double, width: Double, current: MediaPlaybackIdentity) {
        guard !cancelled, current == identity else { cancel(); return }
        target = Self.position(x: x, width: width, duration: identity.duration)
    }
    public mutating func cancel() { cancelled = true; target = nil }
    public func destination(current: MediaPlaybackIdentity) -> Double? {
        !cancelled && current == identity ? target : nil
    }
    public static func position(x: Double, width: Double, duration: Double) -> Double? {
        guard x.isFinite, width.isFinite, width > 0, duration.isFinite, duration > 0 else { return nil }
        return min(1, max(0, x / width)) * duration
    }
}
