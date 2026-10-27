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
        XCTAssertEqual(selection.tertiary, .clock)
        XCTAssertTrue(selection.overflow.isEmpty)
        selection.update(available: [.sports, .music, .clock], preferred: .clock)
        XCTAssertEqual(selection.primary, .sports)
        XCTAssertEqual(selection.secondary, .music)
        XCTAssertEqual(selection.tertiary, .clock)
        XCTAssertTrue(selection.overflow.isEmpty)
        for _ in 0..<100 { selection.update(available: [.clock, .music, .sports]) }
        XCTAssertEqual(selection.primary, .sports)
        selection.update(available: [.music])
        XCTAssertEqual(selection.primary, .music)
        XCTAssertNil(selection.secondary)
        XCTAssertTrue(selection.overflow.isEmpty)
        selection.update(available: [])
        XCTAssertNil(selection.primary)
    }
    func testSportsReturnsToMainAndOnlyMediaOrClockSplit() {
        for preferred in IslandActivity.allCases {
            var slots = ActivitySelection()
            slots.update(available: [.music, .clock], preferred: .music)
            slots.update(available: Set(IslandActivity.allCases), preferred: preferred)
            XCTAssertEqual(slots.primary, .sports)
            XCTAssertEqual(Set([slots.secondary, slots.tertiary].compactMap { $0 }), [.music, .clock])
            XCTAssertTrue(slots.overflow.isEmpty)
            slots.update(available: [.sports, .approval, .calendar])
            XCTAssertEqual(slots.primary, .sports)
            XCTAssertNil(slots.secondary)
            XCTAssertNil(slots.tertiary)
        }
    }
    func testUnsupportedPreferenceDoesNotCreateSyntheticActivity() {
        var selection = ActivitySelection()
        selection.update(available: [.sports], preferred: .clock)
        XCTAssertEqual(selection.primary, .sports)
        XCTAssertNil(selection.secondary)
    }
    func testCalendarIsBrowseOnlyEvenWhenPreferredOrAlone() {
        var slots = ActivitySelection()
        slots.update(available: [.sports, .music, .clock, .calendar], preferred: .calendar)
        XCTAssertEqual(slots.primary, .sports)
        XCTAssertEqual(slots.secondary, .music)
        XCTAssertEqual(slots.tertiary, .clock)
        XCTAssertTrue(slots.overflow.isEmpty)
        slots.update(available: [.calendar], preferred: .calendar)
        XCTAssertNil(slots.primary)
        XCTAssertNil(slots.secondary)
        XCTAssertNil(slots.tertiary)
        XCTAssertTrue(slots.overflow.isEmpty)
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
        XCTAssertEqual(PollPolicy.discovery(browsing: false, lowPower: false, failures: 0), 900)
        XCTAssertEqual(PollPolicy.detail(live: true, completed: false, expanded: true, lowPower: false, failures: 0), 10)
        XCTAssertEqual(PollPolicy.detail(live: true, completed: false, expanded: false, lowPower: false, failures: 0), 10)
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
