import Foundation

// Runs without XCTest, for Macs with only Command Line Tools installed.
@main struct CoreChecks {
    static func main() async throws {
        var checks = 0
        func check(_ condition: Bool, _ name: String) {
            precondition(condition, name)
            checks += 1
        }
        var selection = ActivitySelection()
        selection.update(available: [.sports, .music])
        check(selection.primary == .sports && selection.secondary == .music, "sports/music split")
        selection.update(available: [.music, .clock, .sports])
        check(selection.primary == .sports && selection.overflow == [.clock], "stable overflow")
        selection.update(available: [.sports, .music, .clock], preferred: .clock)
        for _ in 0..<100 { selection.update(available: [.music, .sports, .clock]) }
        check(selection.primary == .clock && selection.secondary == .sports, "stable explicit selection")
        selection.update(available: [.music])
        check(selection.primary == .music && selection.secondary == nil, "merge")
        selection.update(available: [])
        check(selection.primary == nil && selection.overflow.isEmpty, "empty state")
        var generation = RequestGeneration()
        let old = generation.value
        generation.invalidate(); generation.invalidate()
        check(!generation.accepts(old), "A/B/A race rejection")
        check(PollPolicy.discovery(browsing: false, lowPower: false, failures: 0) == 300, "discovery interval")
        check(PollPolicy.detail(live: true, completed: false, expanded: false, lowPower: false, failures: 0) == 30, "live compact freshness")
        check(PollPolicy.detail(live: true, completed: false, expanded: true, lowPower: false, failures: 0) == 15, "live expanded freshness")
        check(PollPolicy.discovery(browsing: false, lowPower: true, failures: 20) == 1800, "bounded backoff")
        let anchor = PlaybackAnchor(position: 10, instant: 100, rate: 1, duration: 120)
        check(anchor.value(at: 135) == 45, "no tick drift")
        check(anchor.value(at: 1000) == 120, "duration clamp")
        func timer(_ id: String, _ time: String, paused: Bool = false) -> ClockAXNode {
            .init(role: "AXGroup", identifier: id, children: [.init(role: "AXStaticText", text: time),
                .init(role: "AXButton", text: paused ? "Resume" : "Pause"), .init(role: "AXButton", text: "Cancel")])
        }
        let timers = ClockTimerParser.parse(.init(role: "AXApplication", children: [timer("tea", "03:17"), timer("oven", "1:02:03", paused: true)]))
        check(timers.count == 2 && timers[0].remaining == 197 && timers[1].paused, "multiple native observations")
        check(ClockTimerParser.duration("00:99") == nil, "reject invalid countdown")
        check(ClockTimerParser.duration("ends at 03:17") == nil, "reject prose")
        check(ClockTimerParser.parse(.init(role: "AXStaticText", text: "12:30")).isEmpty, "reject wall clock")
        check(ClockTimerParser.parse(.init(role: "AXGroup", children: [.init(role: "AXStaticText", text: "05:00"), .init(role: "AXButton", text: "Start")])).isEmpty, "reject preset")
        var ambiguous = timer("timer", "02:30")
        ambiguous.children.append(.init(role: "AXButton", text: "Resume"))
        check(ClockTimerParser.parse(ambiguous).isEmpty, "reject ambiguous state")
        let pool = AsyncPermitPool(limit: 1)
        try await pool.acquire()
        let waiting = Task { try await pool.acquire() }
        await Task.yield()
        waiting.cancel()
        await pool.release()
        var cancelled = false
        do { try await waiting.value } catch is CancellationError { cancelled = true }
        check(cancelled, "cancelled waiter")
        try await pool.acquire(); await pool.release()
        checks += 1 // Reacquisition would hang if the cancelled waiter leaked its permit.
        let parallelPool = AsyncPermitPool(limit: 3)
        let counter = Counter()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<30 {
                group.addTask {
                    try await parallelPool.acquire()
                    await counter.begin()
                    try await Task.sleep(nanoseconds: 1_000_000)
                    await counter.end()
                    await parallelPool.release()
                }
            }
            try await group.waitForAll()
        }
        let (peak, completed) = await counter.result()
        check(peak <= 3 && completed == 30, "bounded network fanout")
        print("Passed \(checks) core checks. Native Clock AX snapshots are synthetic contract fixtures, not a live compatibility test.")
    }
}
private actor Counter {
    var active = 0; var peak = 0; var completed = 0
    func begin() { active += 1; peak = max(peak, active) }
    func end() { active -= 1; completed += 1 }
    func result() -> (Int, Int) { (peak, completed) }
}
