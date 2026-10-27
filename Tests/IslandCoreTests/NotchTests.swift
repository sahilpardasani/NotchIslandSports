import XCTest
import CoreGraphics
@testable import IslandCore

final class NotchTests: XCTestCase {
    func testTopAnchorAndCameraCenterSurviveExpansion() {
        let screen = CGRect(x:-1512,y:500,width:1512,height:982)
        let compact = NotchGeometry.layout(screen:screen,safeTop:32,leftArea:nil,rightArea:nil,expanded:false,contentHeight:410)
        let expanded = NotchGeometry.layout(screen:screen,safeTop:32,leftArea:nil,rightArea:nil,expanded:true,contentHeight:410)
        XCTAssertEqual(compact.primary.height,32)
        XCTAssertEqual(compact.primary.minY,screen.maxY - 32)
        XCTAssertEqual(compact.primary.maxY,screen.maxY)
        XCTAssertEqual(compact.primary.midX,screen.midX)
        XCTAssertEqual(expanded.primary.maxY,compact.primary.maxY)
        XCTAssertEqual(expanded.primary.midX,compact.primary.midX)
        XCTAssertLessThan(compact.primary.width,600)
        XCTAssertLessThan(compact.secondary.maxX,compact.primary.minX)
        XCTAssertGreaterThan(compact.tertiary.minX,compact.primary.maxX)
    }
    func testCalendarNeverDisplacesThreeLiveActivities() {
        var slots = ActivitySelection()
        slots.update(available:[.sports,.clock,.calendar])
        XCTAssertEqual(slots.primary,.sports)
        XCTAssertEqual(slots.secondary,.clock)
        XCTAssertNil(slots.tertiary)
        XCTAssertTrue(slots.overflow.isEmpty)
        slots.update(available:[.sports,.music,.clock,.calendar])
        XCTAssertEqual(slots.tertiary,.music)
        XCTAssertTrue(slots.overflow.isEmpty)
    }
    func testTimerPanelHasCompactSizeWithSameCameraAnchor() {
        let screen = CGRect(x:0,y:0,width:1512,height:982)
        let timer = NotchGeometry.layout(screen:screen,safeTop:32,leftArea:nil,rightArea:nil,expanded:true,contentHeight:120,expandedWidth:440)
        XCTAssertEqual(timer.primary.width,440)
        XCTAssertEqual(timer.primary.height,170)
        XCTAssertEqual(timer.primary.midX,screen.midX)
        XCTAssertEqual(timer.primary.maxY,screen.maxY)
    }
    func testControlsRequireFreshIdentifiedMatchingTimerAndState() {
        let old = ObservedClockTimer(id:"tea",remaining:120,paused:false,controlIdentifier:"tea")
        let fresh = ObservedClockTimer(id:"tea",remaining:118,paused:false,controlIdentifier:"tea")
        XCTAssertTrue(ClockControlPolicy.accepts(previous:old,current:fresh,age:2,command:.pause))
        XCTAssertFalse(ClockControlPolicy.accepts(previous:old,current:fresh,age:6,command:.cancel))
        XCTAssertFalse(ClockControlPolicy.accepts(previous:old,current:fresh,age:2,command:.resume))
        let other = ObservedClockTimer(id:"other",remaining:118,paused:false,controlIdentifier:"other")
        XCTAssertFalse(ClockControlPolicy.accepts(previous:old,current:other,age:2,command:.cancel))
    }
}
