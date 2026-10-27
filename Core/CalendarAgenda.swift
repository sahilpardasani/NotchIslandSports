import Foundation

/// Values copied from EventKit; no managed objects or personal data leave the device.
public struct AgendaEvent: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let allDay: Bool
    public let calendarName: String
    public let colorHex: String
    public init(id: String, title: String, start: Date, end: Date, allDay: Bool = false,
                calendarName: String = "Calendar", colorHex: String = "44BCE8") {
        self.id = id; self.title = title; self.start = start; self.end = end
        self.allDay = allDay; self.calendarName = calendarName; self.colorHex = colorHex
    }
}

public enum CalendarAgenda {
    /// End-exclusive: at 1:00 PM an event ending at 1:00 PM is already over.
    public static func remaining(_ events: [AgendaEvent], at now: Date) -> [AgendaEvent] {
        events.filter { $0.end > now && $0.end > $0.start }.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.id < $1.id
        }
    }
    public static func currentOrNext(_ events: [AgendaEvent], at now: Date,
                                     calendar: Calendar = .current) -> AgendaEvent? {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return nil }
        // The collapsed island shows only today: never advance to tomorrow's appointment.
        // An overnight event already in progress still belongs to today's agenda.
        let eligible = remaining(events, at: now).filter { $0.start < tomorrow }
        // All-day events stay in the agenda without blocking timed appointments.
        return eligible.first(where: { !$0.allDay }) ?? eligible.first
    }
    /// One scheduled wakeup for a meaningful transition, not a repeating second/minute poll.
    public static func nextBoundary(_ events: [AgendaEvent], after now: Date,
                                    calendar: Calendar = .current) -> Date? {
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        return (events.flatMap { [$0.start, $0.end] } + [midnight].compactMap { $0 })
            .filter { $0 > now }.min()
    }
}
