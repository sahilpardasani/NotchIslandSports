import Foundation
import IslandCore

// Sanitized fixture based on the installed Clock's selected-sidebar/detail structure.
// IDs/durations here are synthetic. No AXPress or live timer operation occurs.
@main struct ClockDetailChecks {
    static func main() {
        let id = "00000000-0000-0000-0000-000000000001"
        let selected = ClockAXNode(role: "AXGroup", identifier: id, children: [
            .init(role: "AXStaticText", identifier: id, text: "03:17, 5 min"),
            .init(role: "AXButton", text: "Resume")], selected: true)
        let detail = ClockAXNode(role: "AXGroup", children: [
            .init(role: "AXStaticText", text: "03:17"),
            .init(role: "AXTextField", text: "Timer"),
            .init(role: "AXButton", identifier: "CancelButton", text: "Cancel"),
            .init(role: "AXButton", identifier: "PauseResumeButton", text: "Resume")])
        func root(_ card: ClockAXNode = selected, _ panel: ClockAXNode = detail, extra: [ClockAXNode] = []) -> ClockAXNode {
            .init(role: "AXApplication", children: [.init(role: "AXWindow", children: [
                .init(role: "AXGroup", children: [.init(role: "AXGroup", children: [card]), panel] + extra)])])
        }
        var count = 0
        func check(_ value: Bool, _ label: String) { precondition(value, label); count += 1 }
        let match = ClockTimerParser.selectedDetail(root())!
        check(match.timer.id == id && match.timer.remaining == 197 && match.timer.paused && match.timer.canControl,
              "Selected semantic ID binds matching paused detail")
        check(match.detailPath == "clock.0.0.1" && match.selectionPath == "clock.0.0.0.0", "Native snapshot lookup paths")
        check(ClockTimerParser.parse(root()).count == 1, "Do not display detail twice")
        var card = selected; card.selected = false
        check(ClockTimerParser.selectedDetail(root(card)) == nil, "Unselected summary cannot authorize controls")
        check(!ClockTimerParser.parse(root(card)).contains(where: \.canControl), "Generic fallback stays observation only")
        card = selected; card.identifier = "recent-timer-0"
        check(ClockTimerParser.selectedDetail(root(card)) == nil, "Preset IDs cannot become selected timers")
        card = selected; card.children[0].text = ""
        check(ClockTimerParser.selectedDetail(root(card)) == nil, "Empty summary is rejected safely")
        card = selected; card.children[0].text = "05:00, 5 min"
        check(ClockTimerParser.selectedDetail(root(card)) == nil, "Different duration rejects stale detail")
        var panel = detail; panel.children[3].text = "Pause"
        check(ClockTimerParser.selectedDetail(root(selected, panel)) == nil, "Mismatched paused state rejected")
        panel = detail; panel.children[2].identifier = "OtherCancel"
        check(ClockTimerParser.selectedDetail(root(selected, panel)) == nil, "Require native control IDs")
        check(ClockTimerParser.selectedDetail(root(extra: [selected])) == nil, "Multiple selected UUID cards rejected")
        check(ClockTimerParser.selectedDetail(root(extra: [detail])) == nil, "Multiple detail groups rejected")
        let separate = ClockAXNode(role: "AXApplication", children: [.init(role: "AXWindow", children: [selected]), .init(role: "AXWindow", children: [detail])])
        check(ClockTimerParser.selectedDetail(separate) == nil, "Never associate different Clock windows")
        card = selected; card.children[1].text = "Pause"
        panel = detail; panel.children[3].text = "Pause"; panel.children[0].text = "03:16"
        check(ClockTimerParser.selectedDetail(root(card, panel))?.timer.remaining == 196, "Allow one-second rollover during a running read")
        panel.children[0].text = "03:10"
        check(ClockTimerParser.selectedDetail(root(card, panel)) == nil, "Larger running drift rejected")
        let replacement = ObservedClockTimer(id: "replacement", remaining: 197, paused: true, controlIdentifier: "selected-detail/replacement")
        check(!ClockControlPolicy.accepts(previous: match.timer, current: replacement, age: 0, command: .resume), "Selection changes reject old click")
        print("Passed \(count) selected native Clock detail checks; no live timer action was performed.")
    }
}
