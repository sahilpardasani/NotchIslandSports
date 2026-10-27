import AppKit
import Combine
import SwiftUI
import IslandCore

@main struct EnergyChecks {
    @MainActor static func main() {
        var checks = 0
        func check(_ value: Bool, _ name: String) { precondition(value, name); checks += 1 }
        for lowPower in [false, true] {
            check(EnergyPolicy.clockInterval(trusted: true, appRunning: false, setupVisible: false,
                hasTimers: false, runningTimer: false, lowPower: lowPower) == nil, "Closed Clock has no poll")
            check(EnergyPolicy.clockInterval(trusted: false, appRunning: true, setupVisible: false,
                hasTimers: false, runningTimer: false, lowPower: lowPower) == nil, "No permission has no background poll")
            check(EnergyPolicy.clockInterval(trusted: false, appRunning: false, setupVisible: true,
                hasTimers: false, runningTimer: false, lowPower: lowPower) == 1, "Setup still detects permission")
            check(EnergyPolicy.clockInterval(trusted: true, appRunning: true, setupVisible: false,
                hasTimers: false, runningTimer: false, lowPower: lowPower) == (lowPower ? 60 : 30), "Empty Clock fallback")
            for running in [false, true] {
                let interval = EnergyPolicy.clockInterval(trusted: true, appRunning: true, setupVisible: false,
                    hasTimers: true, runningTimer: running, lowPower: lowPower)!
                check(interval * 1.2 < 5, "Clock polling tolerance stays inside control freshness window")
            }
        }
        check(EnergyPolicy.discoveryNeeded(age: nil, browsing: false, lowPower: false), "Cold start discovers sports")
        check(!EnergyPolicy.discoveryNeeded(age: 30, browsing: false, lowPower: false), "Quick wake reuses completed discovery")
        check(EnergyPolicy.discoveryNeeded(age: -1, browsing: false, lowPower: false), "Clock rollback refreshes")
        check(EnergyPolicy.discoveryNeeded(age: 900, browsing: false, lowPower: false), "Expired background list refreshes")
        check(!EnergyPolicy.discoveryNeeded(age: 900, browsing: false, lowPower: true), "Power saving discovery backs off")
        check(EnergyPolicy.discoveryNeeded(age: 120, browsing: true, lowPower: false), "Browsing keeps freshness")
        check(PollPolicy.discovery(browsing: false, lowPower: false, failures: 0) == 900, "Four background sweeps per hour")
        check(PollPolicy.detail(live: true, completed: false, expanded: false, lowPower: false, failures: 0) == 10, "Live score refreshes every ten seconds")
        check(PollPolicy.detail(live: true, completed: false, expanded: true, lowPower: false, failures: 0) == 10, "Expanded score refreshes every ten seconds")

        let model = NowPlayingManager()
        var publications = 0
        let observation = model.$currentTrack.dropFirst().sink { _ in publications += 1 }
        func apply(position: Double, rate: Double = 1, title: String = "Track", artist: String = "Artist",
                   album: String = "Album", duration: Double = 100_000,
                   artwork: Data? = nil, bundle: String = "com.apple.Music") {
            let now = ProcessInfo.processInfo.systemUptime
            let track = NowPlayingTrack(title: title, artist: artist, album: album,
                duration: duration, elapsedTime: position, isPlaying: rate > 0,
                artwork: artwork, dominantColor: .purple, sourceBundleID: bundle)
            model.applyEnergyFixture(track, anchor: PlaybackAnchor(position: position, instant: now,
                rate: rate, duration: duration))
        }
        apply(position: 10)
        check(publications == 1, "Initial media appears")
        // Burst-test the real manager with coherent, equivalent advancing anchors.
        for _ in 0..<3600 { apply(position: model.elapsedTime()) }
        check(publications == 1, "3600 equivalent position events do not invalidate whole island")
        // Separately advance a synthetic monotonic clock through one hour.
        var previous = PlaybackAnchor(position: 10, instant: 0, rate: 1, duration: 100_000)
        var corrections = 0
        for second in 1...3600 {
            let next = PlaybackAnchor(position: 10 + Double(second), instant: Double(second), rate: 1, duration: 100_000)
            if EnergyPolicy.positionChanged(previous: previous, next: next, now: Double(second)) { corrections += 1 }
            previous = next
        }
        check(corrections == 0 && previous.value(at: 3600) == 3610, "One hour keeps exact progress without correction publications")
        apply(position: 80)
        check(publications == 2 && abs(model.elapsedTime() - 80) < 1, "Seek publishes and updates progress")
        apply(position: 80, rate: 0)
        check(publications == 3 && model.currentTrack?.isPlaying == false, "Pause publishes immediately")
        apply(position: 80, rate: 0)
        check(publications == 3, "Repeated paused state does no UI work")
        apply(position: 80)
        check(publications == 4, "Resume publishes")
        apply(position: 80, title: "New title")
        check(publications == 5, "New title publishes")
        apply(position: 80, title: "New title", artist: "New artist")
        check(publications == 6, "Artist publishes")
        apply(position: 80, title: "New title", artist: "New artist", album: "New album")
        check(publications == 7, "Album publishes")
        apply(position: 80, title: "New title", artist: "New artist", album: "New album", duration: 200)
        check(publications == 8, "Duration publishes")
        apply(position: 80, title: "New title", artist: "New artist", album: "New album", duration: 200, artwork: Data([1]))
        check(publications == 9, "Artwork publishes")
        apply(position: 80, bundle: "com.spotify.client")
        check(publications == 10 && model.currentTrack?.sourceBundleID == "com.spotify.client", "Source switch publishes")
        model.stopPolling()
        check(model.currentTrack == nil && !model.isActive, "Suspend clears media")
        withExtendedLifetime(observation) {}
        print("Passed \(checks) energy checks; synthetic workload, not a battery-life measurement.")
    }
}
