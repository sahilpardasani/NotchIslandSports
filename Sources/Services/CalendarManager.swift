import AppKit
import Combine
import EventKit
import IslandCore

@MainActor
final class CalendarManager: ObservableObject {
    @Published private(set) var events: [AgendaEvent] = []
    @Published private(set) var currentEvent: AgendaEvent?
    @Published private(set) var now = Date()
    @Published private(set) var status = "Connect Apple Calendar to see your agenda."
    @Published private(set) var isLoading = false
    @Published private(set) var hasAccess = false
    @Published var enabled: Bool {
        didSet {
            defaults.set(enabled, forKey: "NativeCalendarEnabled")
            if enabled { refresh() } else { clear(); status = "Calendar is off." }
        }
    }
    private let defaults: UserDefaults
    private let reader = CalendarReader()
    private var snapshot: [AgendaEvent] = []
    private var running = false
    private var generation = 0
    private var boundaryTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var refreshQueued = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.bool(forKey: "NativeCalendarEnabled")
    }

    func start() {
        guard !running else { return }
        running = true
        let center = NotificationCenter.default
        for name in [Notification.Name.EKEventStoreChanged, .NSCalendarDayChanged,
                     .NSSystemTimeZoneDidChange, Notification.Name("NSSystemClockDidChangeNotification")] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
        // Permission can change in System Settings while the island remains alive.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.enabled, self.hasAccess != CalendarReader.canRead else { return }
                    self.refresh()
                }
            })
        refresh()
    }
    func stop() {
        running = false
        for token in observers {
            NotificationCenter.default.removeObserver(token)
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        observers.removeAll()
        clear()
    }
    private func clear() {
        generation += 1
        boundaryTimer?.invalidate(); boundaryTimer = nil
        snapshot = []; events = []; currentEvent = nil
        isLoading = false; refreshQueued = false
    }
    func connect() {
        reader.requestAccess { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                self.enabled = granted
                self.hasAccess = granted
                if !granted { self.status = "Allow Calendar access in System Settings → Privacy & Security → Calendars, then reconnect." }
            }
        }
    }
    func openCalendar() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
    }
    func refresh() {
        guard running, enabled else { return }
        hasAccess = CalendarReader.canRead
        guard hasAccess else {
            clear(); status = "Calendar permission is unavailable. Reconnect to allow access."; return
        }
        if isLoading { refreshQueued = true; return }
        isLoading = true
        let token = generation
        reader.fetch(now: Date()) { [weak self] items in
            Task { @MainActor in
                guard let self, self.running, self.enabled, token == self.generation else { return }
                self.isLoading = false
                guard CalendarReader.canRead else {
                    self.hasAccess = false; self.clear(); self.status = "Calendar access was removed."; return
                }
                self.snapshot = items
                self.reconcile(at: Date())
                self.status = items.isEmpty ? "No upcoming events in the next 14 days." : "Apple Calendar · next 14 days"
                if self.refreshQueued { self.refreshQueued = false; self.refresh() }
            }
        }
    }
    private func reconcile(at date: Date) {
        now = date
        let nextEvents = CalendarAgenda.remaining(snapshot, at: date)
        let next = CalendarAgenda.currentOrNext(snapshot, at: date)
        if events != nextEvents { events = nextEvents }
        if currentEvent != next { currentEvent = next }
        boundaryTimer?.invalidate()
        guard running, enabled, let boundary = CalendarAgenda.nextBoundary(snapshot, after: date) else { return }
        let timer = Timer(fire: boundary, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.running, self.enabled else { return }
                guard CalendarReader.canRead else { self.refresh(); return }
                // Switch immediately from the in-memory agenda, even with no Calendar change notification.
                let previousDay = Calendar.current.startOfDay(for: self.now)
                self.reconcile(at: Date())
                if Calendar.current.startOfDay(for: self.now) != previousDay { self.refresh() }
            }
        }
        timer.tolerance = 0.1
        boundaryTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}

/// All EventKit object access stays on this serial queue. Only immutable values cross it.
private final class CalendarReader {
    private let queue = DispatchQueue(label: "com.notchislandsports.calendar", qos: .utility)
    private lazy var store = EKEventStore()
    static var canRead: Bool {
        if #available(macOS 14.0, *) { return EKEventStore.authorizationStatus(for: .event) == .fullAccess }
        return EKEventStore.authorizationStatus(for: .event) == .authorized
    }
    func requestAccess(completion: @escaping (Bool) -> Void) {
        queue.async {
            if #available(macOS 14.0, *) {
                self.store.requestFullAccessToEvents { granted, _ in completion(granted) }
            } else { self.store.requestAccess(to: .event) { granted, _ in completion(granted) } }
        }
    }
    func fetch(now: Date, completion: @escaping ([AgendaEvent]) -> Void) {
        queue.async {
            guard Self.canRead else { completion([]); return }
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: now)
            guard let end = calendar.date(byAdding: .day, value: 14, to: start) else { completion([]); return }
            let predicate = self.store.predicateForEvents(withStart: start, end: end, calendars: nil)
            var seen = Set<String>()
            let events = self.store.events(matching: predicate).compactMap { event -> AgendaEvent? in
                guard event.status != .canceled, let start = event.startDate, let end = event.endDate,
                      end > now, end > start,
                      !(event.attendees?.contains(where: { $0.isCurrentUser && $0.participantStatus == .declined }) ?? false)
                else { return nil }
                let id = (event.eventIdentifier ?? event.calendarItemIdentifier) + ":" + String(start.timeIntervalSince1970)
                guard seen.insert(id).inserted else { return nil }
                let color = NSColor(cgColor: event.calendar.cgColor)?.usingColorSpace(.deviceRGB)
                let hex = color.map { String(format: "%02X%02X%02X", Int($0.redComponent * 255), Int($0.greenComponent * 255), Int($0.blueComponent * 255)) } ?? "44BCE8"
                return AgendaEvent(id: id, title: event.title?.isEmpty == false ? event.title : "Untitled event",
                    start: start, end: end, allDay: event.isAllDay,
                    calendarName: event.calendar.title, colorHex: hex)
            }
            completion(CalendarAgenda.remaining(events, at: now))
        }
    }
}
