import Foundation

/// Do not resurrect a browser's cached paused item on app startup.
/// A session observed playing remains present while paused until withdrawn.
public struct MediaSessionPresence {
    private var identity: String?
    public init() {}
    public mutating func update(bundleID: String?, title: String?, playing: Bool) -> Bool {
        guard let bundleID, let title, !bundleID.isEmpty, !title.isEmpty else {
            identity = nil
            return false
        }
        let next = bundleID + "\u{0}" + title
        if playing { identity = next; return true }
        if identity == next { return true }
        identity = nil
        return false
    }
    public mutating func clear() { identity = nil }
}
