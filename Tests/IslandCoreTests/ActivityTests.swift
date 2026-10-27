import XCTest
@testable import IslandCore

final class ActivityTests: XCTestCase {
    func testSplitStaysStableThroughRefreshAndOverflow() {
        var selection = ActivitySelection()
        selection.update(available: [.sports, .music])
        XCTAssertEqual(selection.primary, .sports)
        XCTAssertEqual(selection.secondary, .music)
        selection.update(available: [.music, .clock, .sports])
        XCTAssertEqual(selection.primary, .sports)
        XCTAssertEqual(selection.secondary, .music)
        XCTAssertEqual(selection.overflow, [.clock])
        selection.update(available: [.sports, .music, .clock], preferred: .clock)
        XCTAssertEqual(selection.primary, .clock)
        XCTAssertEqual(selection.secondary, .sports)
        XCTAssertEqual(selection.overflow, [.music])
        for _ in 0..<100 { selection.update(available: [.clock, .music, .sports]) }
        XCTAssertEqual(selection.primary, .clock)
        selection.update(available: [.music])
        XCTAssertEqual(selection.primary, .music)
        XCTAssertNil(selection.secondary)
        XCTAssertTrue(selection.overflow.isEmpty)
        selection.update(available: [])
        XCTAssertNil(selection.primary)
    }
    func testUnsupportedPreferenceDoesNotCreateSyntheticActivity() {
        var selection = ActivitySelection()
        selection.update(available: [.sports], preferred: .clock)
        XCTAssertEqual(selection.primary, .sports)
        XCTAssertNil(selection.secondary)
    }
    func testOldRequestCannotPublishAfterSelectionChangesAndReturns() {
        var generation = RequestGeneration()
        let requestA = generation.value
        generation.invalidate() // A -> B
        generation.invalidate() // B -> A; identity alone is insufficient.
        XCTAssertFalse(generation.accepts(requestA))
        XCTAssertTrue(generation.accepts(generation.value))
    }
    func testPollingPreservesLiveDetailButBacksOffDiscovery() {
        XCTAssertEqual(PollPolicy.discovery(browsing: false, lowPower: false, failures: 0), 300)
        XCTAssertEqual(PollPolicy.detail(live: true, completed: false, expanded: true, lowPower: false, failures: 0), 15)
        XCTAssertEqual(PollPolicy.detail(live: true, completed: false, expanded: false, lowPower: false, failures: 0), 30)
        XCTAssertEqual(PollPolicy.detail(live: false, completed: true, expanded: false, lowPower: true, failures: 10), 1800)
        XCTAssertGreaterThan(PollPolicy.discovery(browsing: false, lowPower: true, failures: 1), 300)
    }
    func testPlaybackUsesElapsedTimeNotNumberOfTicks() {
        let playing = PlaybackAnchor(position: 10, instant: 100, rate: 1, duration: 120)
        XCTAssertEqual(playing.value(at: 135), 45) // No UI ticks during a stall.
        XCTAssertEqual(playing.value(at: 1000), 120)
        XCTAssertEqual(playing.value(at: 90), 10)
        let paused = PlaybackAnchor(position: 45, instant: 135, rate: 0, duration: 120)
        XCTAssertEqual(paused.value(at: 1000), 45)
    }
}
