import Foundation

/// Complete snapshots only; malformed or diff packets cannot resurrect old metadata.
public struct MediaSnapshot: Equatable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let bundleID: String
    public let playing: Bool
    public let duration: Double
    public let elapsed: Double
    public let rate: Double
    public let timestamp: Double?
    public let artwork: Data?

    public static func decode(_ data: Data) -> MediaSnapshot? {
        guard data.count <= 8_000_000,
              let packet = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              packet["type"] as? String == "data",
              packet["diff"] as? Bool == false,
              let value = packet["payload"] as? [String: Any],
              let title = value["title"] as? String, !title.trimmingCharacters(in: .whitespaces).isEmpty,
              let bundle = value["bundleIdentifier"] as? String, !bundle.isEmpty,
              let playing = value["playing"] as? Bool else { return nil }
        func number(_ key: String) -> Double {
            let n = (value[key] as? NSNumber)?.doubleValue ?? 0
            return n.isFinite ? max(0, n) : 0
        }
        let timestamp = (value["timestampEpochMicros"] as? NSNumber)?.doubleValue
        let art = (value["artworkData"] as? String).flatMap { encoded -> Data? in
            guard encoded.utf8.count <= 5_400_000, let data = Data(base64Encoded: encoded), data.count <= 4_000_000 else { return nil }
            return data
        }
        return MediaSnapshot(title: String(title.prefix(1024)), artist: String((value["artist"] as? String ?? "").prefix(512)),
            album: String((value["album"] as? String ?? "").prefix(512)), bundleID: bundle,
            playing: playing, duration: number("durationMicros") / 1_000_000,
            elapsed: number("elapsedTimeMicros") / 1_000_000, rate: playing ? (value["playbackRate"] == nil ? 1 : number("playbackRate")) : 0,
            timestamp: timestamp.flatMap { $0.isFinite ? $0 / 1_000_000 : nil }, artwork: art)
    }
    public func position(now: Double) -> Double {
        let delta = timestamp.map { max(0, min(3600, now - $0)) } ?? 0
        let position = elapsed + delta * rate
        return duration > 0 ? min(duration, position) : position
    }
}
