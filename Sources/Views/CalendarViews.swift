import SwiftUI
import IslandCore

struct NativeCalendarView: View {
    @ObservedObject var manager: CalendarManager
    var body: some View {
        VStack(spacing: 0) {
            if manager.enabled && manager.hasAccess {
                if manager.isLoading && manager.events.isEmpty {
                    ProgressView("Loading your agenda…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    CalendarAgendaView(events: manager.events, currentEvent: manager.currentEvent, now: manager.now)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "calendar").font(.system(size: 32)).foregroundColor(.cyan)
                    Text("Your calendar, at a glance").font(.headline)
                    Text(manager.status).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                    Text("Connect using the menu-bar menu → About → Configure.").font(.caption)
                    Text("Read on this Mac. Nothing is changed or uploaded. macOS calls the permission “Full Access” because reading events requires it.")
                        .font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
                }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
    }
}

struct CalendarCompactView: View {
    @ObservedObject var manager: CalendarManager
    var minimal = false
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar").foregroundColor(.cyan).accessibilityHidden(true)
            if let event = manager.currentEvent {
                if minimal {
                    Text(event.allDay ? "Today" : event.start.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 9, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        Text(agendaEventTime(event, now: manager.now)).font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.65)).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(event.start <= manager.now ? (event.allDay ? "TODAY" : "NOW") : "NEXT")
                        .font(.system(size: 9, weight: .bold)).foregroundColor(.cyan)
                }
            } else if !minimal { Text("No more events today").font(.caption) }
        }.padding(.horizontal, minimal ? 5 : 14)
        .foregroundColor(.white)
        .accessibilityElement(children: .combine)
    }
}
