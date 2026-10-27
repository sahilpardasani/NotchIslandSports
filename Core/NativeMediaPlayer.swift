import Foundation

/// Explicit native destinations; browser sources must never fall through to Spotify.
public enum NativeMediaPlayer: String, Sendable, CaseIterable {
    case music = "com.apple.Music"
    case spotify = "com.spotify.client"
    public enum Command: Sendable { case playPause, next, previous, forward, backward }
    public func script(for command: Command) -> String {
        let action: String
        switch command {
        case .playPause: action = "playpause"
        case .next: action = "next track"
        case .previous: action = "previous track"
        case .forward: action = "set player position to (player position + 15)"
        case .backward: action = "set newPosition to (player position - 15)\nif newPosition < 0 then set newPosition to 0\nset player position to newPosition"
        }
        return "tell application id \"\(rawValue)\"\n\(action)\nend tell"
    }
    /// Only numeric positions and an escaped, exact track title enter the script.
    public func seekScript(position: Double, title: String) -> String? {
        guard position.isFinite, position >= 0, !title.isEmpty else { return nil }
        let literal = title.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r")
        return "tell application id \"\(rawValue)\"\nif name of current track is not \"\(literal)\" then error \"The current track changed\"\nset player position to \(position)\nend tell"
    }

}
