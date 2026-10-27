import Foundation
import IslandCore

@main struct CalendarChecks {
    static func main() {
        let zero = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        func date(_ seconds: Double) -> Date { zero.addingTimeInterval(seconds) }
        func event(_ id: String, _ start: Double, _ end: Double, allDay: Bool = false) -> AgendaEvent {
            AgendaEvent(id: id, title: id, start: date(start), end: date(end), allDay: allDay)
        }
        let a = event("a", 0, 3600), b = event("b", 3600, 7200), c = event("c", 10800, 14400)
        var count = 0
        func check(_ condition: Bool, _ label: String) { precondition(condition, label); count += 1 }
        check(CalendarAgenda.currentOrNext([b,a], at: date(3599.99))?.id == "a", "Current remains until end")
        check(CalendarAgenda.currentOrNext([a,b], at: date(3600))?.id == "b", "Advance exactly at end")
        check(CalendarAgenda.currentOrNext([a,c], at: date(3600))?.id == "c", "Gap shows upcoming event")
        check(CalendarAgenda.currentOrNext([a,b], at: date(7200)) == nil, "No stale last event")
        check(CalendarAgenda.currentOrNext([a,b,c], at: date(13000))?.id == "c", "Reconcile after sleeping across boundaries")
        check(CalendarAgenda.remaining([a,b], at: date(3600)).map(\.id) == ["b"], "Expanded list excludes ended event")
        let overlap = event("overlap", 1800, 5400)
        check(CalendarAgenda.currentOrNext([overlap,a,b], at: date(3600))?.id == "overlap", "Ongoing overlap before future")
        check(CalendarAgenda.currentOrNext([b], at: date(1800))?.id == "b", "Externally removed event absent from replacement snapshot")
        check(CalendarAgenda.currentOrNext([event("all-day", -3600, 86400, allDay:true),b], at: date(0))?.id == "b", "All-day does not mask timed event")
        check(CalendarAgenda.currentOrNext([event("all-day", -3600, 86400, allDay:true)], at: date(0))?.id == "all-day", "All-day fallback")
        check(CalendarAgenda.currentOrNext([event("invalid", 2, 1),event("zero", 0, 0)], at: date(0)) == nil, "Invalid intervals excluded")
        check(CalendarAgenda.currentOrNext([event("tomorrow", 86400, 90000)], at: date(0)) == nil, "Tomorrow excluded from collapsed island")
        check(CalendarAgenda.nextBoundary([a,b], after: date(1)) == date(3600), "One boundary instead of second polling")
        check(CalendarAgenda.nextBoundary([a,b], after: date(3600)) == date(7200), "No zero-delay timer loop")
        let overnight = event("overnight", -7200, 7200)
        check(CalendarAgenda.currentOrNext([overnight], at: date(0))?.id == "overnight", "Overnight ongoing event")
        check(CalendarAgenda.currentOrNext([event("same-b",0,100),event("same-a",0,100)], at: date(0))?.id == "same-a", "Deterministic equal starts")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let dst = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8))!
        let midnight = CalendarAgenda.nextBoundary([], after: dst, calendar: calendar)!
        check(midnight.timeIntervalSince(dst) == 23 * 3600, "DST midnight uses calendar days")
        let tomorrowEvent = event("tomorrow", 86400, 90000)
        check(CalendarAgenda.remaining([tomorrowEvent], at: date(0)).count == 1, "Tomorrow remains in expanded agenda")
        check(CalendarAgenda.currentOrNext([a,tomorrowEvent], at: date(3600)) == nil, "Final event today clears compact activity")
        check(CalendarAgenda.currentOrNext([tomorrowEvent], at: date(86400))?.id == "tomorrow", "New day makes that day's event eligible")
        var slots = ActivitySelection()
        slots.update(available: [.sports,.music,.clock,.calendar], preferred:.calendar)
        check(slots.primary == .sports && slots.tertiary == .clock && slots.overflow.isEmpty, "Calendar cannot displace a live activity")
        print("Passed \(count) calendar checks.")
    }
}
