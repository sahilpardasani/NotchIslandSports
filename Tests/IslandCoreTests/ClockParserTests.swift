import XCTest
@testable import IslandCore

final class ClockParserTests: XCTestCase {
    private func card(_ id: String, time: String, paused: Bool = false) -> ClockAXNode {
        .init(role: "AXGroup", identifier: id, children: [
            .init(role: "AXStaticText", text: time),
            .init(role: "AXButton", text: paused ? "Resume" : "Pause"),
            .init(role: "AXButton", text: "Cancel")
        ])
    }
    func testMultipleNativeTimersAndPausedState() {
        let tree = ClockAXNode(role: "AXApplication", children: [card("tea", time: "03:17"), card("oven", time: "1:02:03", paused: true)])
        let timers = ClockTimerParser.parse(tree)
        XCTAssertEqual(timers.count, 2)
        XCTAssertEqual(timers[0].remaining, 197)
        XCTAssertFalse(timers[0].paused)
        XCTAssertEqual(timers[1].remaining, 3723)
        XCTAssertTrue(timers[1].paused)
    }
    func testStopwatchClockAndPresetDoNotBecomeTimers() {
        let tree = ClockAXNode(role: "AXApplication", children: [
            .init(role: "AXStaticText", text: "12:30"),
            .init(role: "AXGroup", children: [.init(role: "AXStaticText", text: "05:00"), .init(role: "AXButton", text: "Start")]),
            .init(role: "AXGroup", children: [.init(role: "AXStaticText", text: "01:12"), .init(role: "AXButton", text: "Pause"), .init(role: "AXButton", text: "Lap")])
        ])
        XCTAssertTrue(ClockTimerParser.parse(tree).isEmpty)
    }
    func testAmbiguousControlAndDurationAreRejected() {
        var ambiguous = card("id", time: "03:17")
        ambiguous.children.append(.init(role: "AXButton", text: "Resume"))
        XCTAssertTrue(ClockTimerParser.parse(ambiguous).isEmpty)
        XCTAssertNil(ClockTimerParser.duration("Timer ends at 03:17"))
        XCTAssertNil(ClockTimerParser.duration("00:99"))
        XCTAssertNil(ClockTimerParser.duration("-01:20"))
    }
    func testUnknownLocaleFailsClosedAndDuplicateIDsAreBounded() {
        let unknown = ClockAXNode(role: "AXGroup", children: [.init(role: "AXStaticText", text: "03:17"), .init(role: "AXButton", text: "Pausar"), .init(role: "AXButton", text: "Cancelar")])
        XCTAssertTrue(ClockTimerParser.parse(unknown).isEmpty)
        let root = ClockAXNode(role: "AXApplication", children: [card("same", time: "01:20"), card("same", time: "02:30")])
        XCTAssertEqual(ClockTimerParser.parse(root).count, 1)
    }
}
