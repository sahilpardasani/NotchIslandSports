import SwiftUI
import IslandCore

/// The scroll viewport, background and clipping share exactly the same bounds.
/// Rendering this view with fixtures never requires Calendar access.
struct CalendarAgendaView: View {
    let events: [AgendaEvent]
    let currentEvent: AgendaEvent?
    let now: Date
    private var days: [Date] {
        Array(Set(events.map { Calendar.current.startOfDay(for: max($0.start, now)) })).sorted()
    }
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your agenda").font(.system(size: 20, weight: .semibold))
                        Text(now, format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                    }
                    Spacer(minLength: 10)
                    Image(systemName: "calendar")
                        .font(.system(size: 22, weight: .medium)).foregroundColor(.cyan)
                        .accessibilityHidden(true)
                }
                if events.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "calendar.badge.checkmark").font(.system(size: 28)).foregroundColor(.cyan)
                        Text("You're all caught up").font(.headline)
                        Text("No upcoming events in the next 14 days.")
                            .font(.caption).foregroundColor(.white.opacity(0.6))
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(days, id: \.self) { day in
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(dayTitle(day)).font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.55)).textCase(.uppercase)
                                    ForEach(events.filter { Calendar.current.isDate(max($0.start, now), inSameDayAs: day) }) { event in
                                        eventRow(event)
                                    }
                                }
                            }
                        }.padding(.trailing, 8).padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .accessibilityLabel("Upcoming calendar events")
                    Text("Scroll for more · Island shows today’s next event")
                        .font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .background(Color.black)
            .clipped()
        }
        .foregroundColor(.white)
        .preferredColorScheme(.dark)
    }
    private func dayTitle(_ day: Date) -> String {
        if Calendar.current.isDate(day, inSameDayAs: now) { return "Today" }
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
           Calendar.current.isDate(day, inSameDayAs: tomorrow) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
    private func eventRow(_ event: AgendaEvent) -> some View {
        HStack(alignment: .top, spacing: 11) {
            RoundedRectangle(cornerRadius: 2).fill(agendaColor(event.colorHex)).frame(width: 3)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 8) {
                    Text(event.title).font(.system(size: 13, weight: .semibold))
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if event.id == currentEvent?.id {
                        Text(event.start <= now ? (event.allDay ? "TODAY" : "NOW") : "NEXT")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.cyan)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Capsule().fill(Color.cyan.opacity(0.12)))
                    }
                }
                Text(agendaEventTime(event, now: now)).font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7)).lineLimit(2)
                Text(event.calendarName).font(.system(size: 10)).foregroundColor(.white.opacity(0.45)).lineLimit(1)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.055)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            event.id == currentEvent?.id ? Color.cyan.opacity(0.35) : Color.white.opacity(0.04), lineWidth: 1))
        .help(event.title + "\n" + agendaEventTime(event, now: now))
        .accessibilityElement(children: .combine)
    }
}

func agendaColor(_ hex: String) -> Color {
    let rgb = UInt32(hex, radix: 16) ?? 0x44BCE8
    return Color(red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
}
func agendaEventTime(_ event: AgendaEvent, now: Date) -> String {
    let sameDay = Calendar.current.isDate(event.start, inSameDayAs: now)
    let dayPrefix = sameDay ? "" : event.start.formatted(.dateTime.month(.abbreviated).day()) + " · "
    if event.allDay { return dayPrefix + "All day" }
    let start = event.start.formatted(date: .omitted, time: .shortened)
    let end = event.end.formatted(date: .omitted, time: .shortened)
    let endDay = Calendar.current.isDate(event.start, inSameDayAs: event.end) ? "" : event.end.formatted(.dateTime.month(.abbreviated).day()) + " "
    return dayPrefix + start + " – " + endDay + end
}
