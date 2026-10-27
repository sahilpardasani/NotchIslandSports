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
        check(MediaMotion.allowed(playing: true, active: true, visible: true, reduceMotion: false, lowPower: false), "Visible playback animates")
        check(!MediaMotion.allowed(playing: false, active: true, visible: true, reduceMotion: false, lowPower: false), "Paused playback stops motion")
        check(!MediaMotion.allowed(playing: true, active: false, visible: true, reduceMotion: false, lowPower: false), "Stopped provider stops motion")
        check(!MediaMotion.allowed(playing: true, active: true, visible: false, reduceMotion: false, lowPower: false), "Hidden media stops motion")
        check(!MediaMotion.allowed(playing: true, active: true, visible: true, reduceMotion: true, lowPower: false), "Reduce Motion stops motion")
        check(!MediaMotion.allowed(playing: true, active: true, visible: true, reduceMotion: false, lowPower: true), "Low Power stops motion")
        check(MediaMotion.titleOffset(elapsed: 1, overflow: 220) == 0, "Read beginning before scrolling")
        check(abs(MediaMotion.titleOffset(elapsed: 6.6, overflow: 220) + 110) < 0.001, "Title travels across the clipped region")
        check(MediaMotion.titleOffset(elapsed: 12, overflow: 220) == -220, "Read ending before returning")
        check(abs(MediaMotion.titleOffset(elapsed: 23.2, overflow: 220)) < 0.001, "Title loop has no reset jump")
        check(MediaMotion.titleOffset(elapsed: 10, overflow: 0) == 0, "Fitting title remains stationary")
        check(MediaMotion.titleOffset(elapsed: -10, overflow: 220) == 0, "Clock correction cannot move title backwards")
        check(MediaMotion.titleOffset(elapsed: .infinity, overflow: 220) == 0, "Invalid time is bounded")
        check(MediaMotion.barHeight(elapsed: 10, index: 1, moving: false, playing: false) == 4, "Paused bars settle")
        check(MediaMotion.barHeight(elapsed: 10, index: 1, moving: false, playing: true) == MediaMotion.barHeight(elapsed: 20, index: 1, moving: false, playing: true), "Reduced-motion bars stay static")
        check((0..<300).allSatisfy { step in (0..<5).allSatisfy { index in (5...18).contains(MediaMotion.barHeight(elapsed: Double(step) / 30, index: index, moving: true, playing: true)) } }, "Animated bars remain within compact bounds")
        var session = MediaSessionPresence()
        check(!session.update(bundleID: "browser", title: "Old video", playing: false), "Ignore cached paused metadata at launch")
        check(session.update(bundleID: "browser", title: "Video", playing: true), "Playback creates a media activity")
        check(session.update(bundleID: "browser", title: "Video", playing: false), "Pause keeps the same media activity")
        check(!session.update(bundleID: nil, title: nil, playing: false), "Withdrawn session clears activity")
        check(!session.update(bundleID: "browser", title: "Video", playing: false), "A cleared session cannot resurrect from paused metadata")
        check(session.update(bundleID: "browser", title: "Video", playing: true), "New playback recreates a split")
        check(!session.update(bundleID: "browser", title: "Different video", playing: false), "Unplayed replacement is not live")
        _ = session.update(bundleID: "browser", title: "Video", playing: true)
        session.clear()
        check(!session.update(bundleID: "browser", title: "Video", playing: false), "Quit or sleep resets session identity")
        check(IslandDragIntent.resolve(horizontal: 30, vertical: 1, heldFor: 0.4) == .toggleMerge, "Hold and move merges without also paging")
        check(IslandDragIntent.resolve(horizontal: -30, vertical: 1, heldFor: 0.4) == .toggleMerge, "Either held direction toggles split")
        check(IslandDragIntent.resolve(horizontal: -30, vertical: 1, heldFor: 0.1) == .next, "Quick swipe changes page")
        check(IslandDragIntent.resolve(horizontal: 30, vertical: 1, heldFor: 0.1) == .previous, "Quick opposite swipe changes page")
        check(IslandDragIntent.resolve(horizontal: 1, vertical: 20, heldFor: 0.4) == .open, "Held pull still opens")
        check(IslandDragIntent.resolve(horizontal: 1, vertical: -20, heldFor: 0.4) == .close, "Held push still collapses")
        check(IslandDragIntent.resolve(horizontal: 5, vertical: 2, heldFor: 1) == nil, "Hold jitter never toggles")
        check(IslandDragIntent.resolve(horizontal: 20, vertical: 20, heldFor: 1) == nil, "Ambiguous diagonal waits for intent")
        for player in NativeMediaPlayer.allCases {
            var native = payload
            native["bundleIdentifier"] = player.rawValue; native["title"] = "Native song"
            native["artist"] = "Artist"; native["playing"] = true
            let snapshot = MediaSnapshot.decode(try packet(native))!
            check(snapshot.bundleID == player.rawValue && snapshot.artist == "Artist", "Native app metadata accepted")
            var nativeSession = MediaSessionPresence()
            check(nativeSession.update(bundleID: snapshot.bundleID, title: snapshot.title, playing: true), "Native playback creates activity")
            check(nativeSession.update(bundleID: snapshot.bundleID, title: snapshot.title, playing: false), "Native pause retains controls")
            check(!nativeSession.update(bundleID: "com.apple.Safari", title: "Old video", playing: false), "Switching source rejects cached paused browser")
            check(player.script(for: .playPause).contains("application id \"\(player.rawValue)\""), "Control targets exact native application")
            check(player.script(for: .backward).contains("if newPosition < 0"), "Native backwards seek cannot go negative")
            nativeSession.clear()
            check(!nativeSession.update(bundleID: snapshot.bundleID, title: snapshot.title, playing: false), "Quit native app cannot resurrect paused activity")
        }
        check(NativeMediaPlayer(rawValue: "com.apple.Safari") == nil, "Browser cannot fall through to native control")
        check(NativeMediaPlayer(rawValue: "com.spotify.client.helper") == nil, "Unknown helper is not a control destination")
        check(IslandDragIntent.isInward(horizontal: 24, vertical: 2, satelliteOnLeft: true), "Plain rightward drag merges left satellite")
        check(IslandDragIntent.isInward(horizontal: -24, vertical: 2, satelliteOnLeft: false), "Plain leftward drag merges relocated right satellite")
        check(!IslandDragIntent.isInward(horizontal: -24, vertical: 2, satelliteOnLeft: true), "Outward drag still pages")
        check(!IslandDragIntent.isInward(horizontal: 8, vertical: 2, satelliteOnLeft: true), "Jitter cannot merge")
        check(!IslandDragIntent.isInward(horizontal: 24, vertical: 30, satelliteOnLeft: true), "Pull down never merges")
        print("Passed \(count) media snapshot, lifecycle, motion and gesture checks.")
    }
}
