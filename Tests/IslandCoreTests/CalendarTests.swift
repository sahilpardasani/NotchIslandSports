import XCTest
@testable import IslandCore

final class CalendarTests: XCTestCase {
    func testAdvanceWithoutAStoreChangeAtExactEnd() {
        let now = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let first = AgendaEvent(id: "first", title: "First", start: now, end: now.addingTimeInterval(60))
        let next = AgendaEvent(id: "next", title: "Next", start: first.end, end: first.end.addingTimeInterval(60))
        XCTAssertEqual(CalendarAgenda.currentOrNext([first,next], at: now)?.id, first.id)
        XCTAssertEqual(CalendarAgenda.currentOrNext([first,next], at: first.end)?.id, next.id)
        XCTAssertNil(CalendarAgenda.currentOrNext([first,next], at: next.end))
        XCTAssertEqual(CalendarAgenda.nextBoundary([first,next], after: first.end), next.end)
    }
    func testCollapsedSelectionStopsAtEndOfTodayWithoutRemovingCalendarData() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let today = calendar.date(from: DateComponents(year:2026,month:10,day:27,hour:13))!
        let tomorrow = calendar.date(from: DateComponents(year:2026,month:10,day:28,hour:9))!
        let event = AgendaEvent(id:"tomorrow",title:"Tomorrow",start:tomorrow,end:tomorrow.addingTimeInterval(3600))
        XCTAssertNil(CalendarAgenda.currentOrNext([event],at:today,calendar:calendar))
        XCTAssertEqual(CalendarAgenda.remaining([event],at:today),[event])
        XCTAssertEqual(CalendarAgenda.currentOrNext([event],at:tomorrow,calendar:calendar),event)
    }
    func testLateWakeAndAllDayDoNotKeepEndedAppointment() {
        let now = Calendar.current.startOfDay(for: Date())
        let ended = AgendaEvent(id:"ended", title:"Ended", start:now.addingTimeInterval(-3600), end:now)
        let future = AgendaEvent(id:"future", title:"Future", start:now.addingTimeInterval(3600), end:now.addingTimeInterval(7200))
        let allDay = AgendaEvent(id:"day",title:"Day",start:now.addingTimeInterval(-3600),end:now.addingTimeInterval(10000),allDay:true)
        XCTAssertEqual(CalendarAgenda.currentOrNext([ended,allDay,future],at:now)?.id,"future")
        XCTAssertEqual(CalendarAgenda.remaining([ended],at:now),[])
    }
}
