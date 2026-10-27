import Foundation
import IslandCore

@main struct MediaChecks {
    static func main() throws {
        var count = 0
        func check(_ condition: Bool, _ label: String) { precondition(condition, label); count += 1 }
        var payload: [String: Any] = ["title": "Test video", "bundleIdentifier": "com.apple.Safari", "playing": true,
            "durationMicros": 120_000_000, "elapsedTimeMicros": 20_000_000,
            "timestampEpochMicros": 1_000_000_000, "playbackRate": 1]
        func packet(_ payload: [String: Any], diff: Bool = false) throws -> Data {
            try JSONSerialization.data(withJSONObject: ["type": "data", "diff": diff, "payload": payload])
        }
        let playing = MediaSnapshot.decode(try packet(payload))!
        check(playing.bundleID == "com.apple.Safari" && playing.title == "Test video", "Browser media is accepted")
        check(playing.playing && playing.duration == 120 && playing.elapsed == 20, "Microseconds converted")
        check(playing.position(now: 1005) == 25, "Running anchor follows elapsed time")
        check(playing.position(now: 2000) == 120, "No progress beyond duration")
        check(playing.position(now: 999) == 20, "Backward wall clock doesn't subtract time")
        payload["playing"] = false
        let paused = MediaSnapshot.decode(try packet(payload))!
        check(paused.position(now: 1010) == 20 && paused.rate == 0, "Paused media stays paused")
        check(MediaSnapshot.decode(try packet([:])) == nil, "Empty snapshot clears activity")
        check(MediaSnapshot.decode(try packet(payload, diff: true)) == nil, "Diff rejected to prevent stale metadata")
        payload.removeValue(forKey: "bundleIdentifier")
        check(MediaSnapshot.decode(try packet(payload)) == nil, "Unidentified source rejected")
        check(MediaSnapshot.decode(Data("not json".utf8)) == nil, "Invalid JSON rejected")
        check(MediaSnapshot.decode(Data(repeating: 1, count: 8_000_001)) == nil, "Oversized packet bounded")
        payload["bundleIdentifier"] = "com.apple.Safari"; payload["title"] = "  "
        check(MediaSnapshot.decode(try packet(payload)) == nil, "Blank title rejected")
        print("Passed \(count) media snapshot checks, including Safari video, pause, clearing and payload limits.")
    }
}
