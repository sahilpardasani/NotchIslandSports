import Foundation
import CoreGraphics
import IslandCore

@main struct NotchChecks {
    static func main() {
        var count = 0
        func check(_ condition: Bool, _ name: String) { precondition(condition, name); count += 1 }
        let screen = CGRect(x: 0,y: 0,width: 1512,height: 982)
        let left = CGRect(x:0,y:950,width:666,height:32)
        let right = CGRect(x:846,y:950,width:666,height:32)
        let compact = NotchGeometry.layout(screen:screen,safeTop:32,leftArea:left,rightArea:right,expanded:false,contentHeight:410)
        check(compact.primary.height == 32 && compact.secondary.height == 32 && compact.tertiary.height == 32, "No collapsed spill below camera band")
        check(compact.primary.maxY == screen.maxY, "Not below the menu bar")
        check(compact.primary.midX == 756 && compact.cameraWidth == 180, "Physical camera center")
        check(compact.primary.width == 500, "Bound compact sports width")
        check(compact.secondary.maxY == screen.maxY && compact.tertiary.maxY == screen.maxY, "All three top anchored")
        check(compact.secondary.maxX < compact.primary.minX && compact.tertiary.minX > compact.primary.maxX, "Gaps do not overlap")
        let expanded = NotchGeometry.layout(screen:screen,safeTop:32,leftArea:left,rightArea:right,expanded:true,contentHeight:470)
        check(expanded.primary.midX == compact.primary.midX && expanded.primary.maxY == compact.primary.maxY, "Expand down from camera")
        check(expanded.primary.height == 520, "Expanded header protects camera")
        check(expanded.secondary.minX >= screen.minX && expanded.tertiary.maxX <= screen.maxX, "Three panels stay on screen")
        let other = CGRect(x:-1512,y:500,width:1512,height:982)
        let negative = NotchGeometry.layout(screen:other,safeTop:32,leftArea:nil,rightArea:nil,expanded:false,contentHeight:410)
        check(negative.primary.midX == other.midX && negative.primary.maxY == other.maxY, "Negative-coordinate display")
        let malformed = NotchGeometry.layout(screen:screen,safeTop:32,leftArea:left,rightArea:CGRect(x:1400,y:950,width:112,height:32),expanded:false,contentHeight:410)
        check(malformed.cameraWidth == 180 && malformed.primary.width == 500, "Reject oversized notch measurement")
        let plain = NotchGeometry.layout(screen:screen,safeTop:0,leftArea:nil,rightArea:nil,expanded:false,contentHeight:410)
        check(plain.cameraHeight == 0 && plain.primary.maxY == 978, "Non-notched display fallback")
        let scaled = NotchGeometry.layout(screen:screen,safeTop:24,leftArea:nil,rightArea:nil,expanded:false,contentHeight:410)
        check(scaled.primary.height == 24, "Scaled camera bands do not inherit the old minimum height")
        var selection = ActivitySelection()
        selection.update(available:[.sports,.clock,.calendar])
        check(selection.primary == .sports && selection.secondary == .clock && selection.tertiary == nil && selection.overflow.isEmpty, "Calendar cannot create third split")
        selection.update(available:[.sports,.clock,.calendar,.music])
        check(selection.tertiary == .music && selection.overflow.isEmpty, "Three live activities, Calendar outside slots")
        selection.update(available:[.sports,.calendar])
        check(selection.secondary == nil && selection.tertiary == nil, "Merge when timer ends, even with calendar")
        func observed(_ id:String = "tea", _ seconds:Double = 120, paused:Bool = false, identity:String? = "tea") -> ObservedClockTimer {
            .init(id:id,remaining:seconds,paused:paused,controlIdentifier:identity)
        }
        check(ClockControlPolicy.accepts(previous:observed(),current:observed("tea",118),age:2,command:.pause), "Fresh pause")
        check(!ClockControlPolicy.accepts(previous:observed(),current:observed("tea",118),age:2,command:.resume), "No wrong-state action")
        check(!ClockControlPolicy.accepts(previous:observed(),current:observed("other",118,identity:"other"),age:2,command:.cancel), "No other timer action")
        check(!ClockControlPolicy.accepts(previous:observed(),current:observed(),age:6,command:.cancel), "No stale controls")
        check(!ClockControlPolicy.accepts(previous:observed(identity:nil),current:observed(),age:1,command:.pause), "No path-only controls")
        check(!ClockControlPolicy.accepts(previous:observed(),current:observed("tea",300),age:1,command:.pause), "Reject changed countdown")
        check(ClockControlPolicy.accepts(previous:observed(paused:true),current:observed(paused:true),age:2,command:.resume), "Fresh resume")
        func card(_ id:String) -> ClockAXNode { .init(role:"AXGroup",identifier:id,children:[.init(role:"AXStaticText",text:"02:00"),.init(role:"AXButton",text:"Pause"),.init(role:"AXButton",text:"Cancel")]) }
        let timers = ClockTimerParser.parse(.init(role:"AXApplication",children:[card("tea")]))
        check(timers.first?.controlIdentifier == "tea", "Target smallest card, not application")
        let duplicate = ClockTimerParser.parse(.init(role:"AXApplication",children:[card("tea"),card("tea")]))
        check(duplicate.count == 1 && !duplicate[0].canControl, "Ambiguous identities disable commands")
        print("Passed \(count) notch geometry and native-control checks.")
    }
}
