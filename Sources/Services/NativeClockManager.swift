import AppKit
import ApplicationServices
import Combine
import IslandCore

/// Read-only Clock adapter. It neither creates timers nor accesses Clock's private storage.
@MainActor
final class NativeClockManager: ObservableObject {
    @Published private(set) var timers: [ObservedClockTimer] = []
    @Published private(set) var status = "Native Clock observation is off"
    @Published private(set) var observedAt: Date?
    @Published var enabled: Bool {
        didSet {
            defaults.set(enabled, forKey: "NativeClockObservation")
            if enabled && running { refresh() } else { clear("Native Clock observation is off") }
        }
    }
    private let defaults: UserDefaults
    private let reader = ClockAccessibilityReader()
    private var poll: Timer?
    private var reading = false
    private var running = false
    private var generation = 0
    private var observers: [NSObjectProtocol] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.bool(forKey: "NativeClockObservation")
        reader.onChange = { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
    }

    func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        enabled = true
        refresh()
    }

    func start() {
        guard !running else { return }
        running = true
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.bundleIdentifier == "com.apple.clock" else { return }
                Task { @MainActor in self?.refresh() }
            })
        }
        refresh()
    }

    func stop() {
        running = false
        generation += 1
        poll?.invalidate(); poll = nil
        reader.detach()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
        reading = false
        timers = []
        observedAt = nil
        status = enabled ? "Clock observation paused" : "Native Clock observation is off"
    }

    func openClock() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.clock") else {
            status = "Apple Clock is not installed on this macOS version"; return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
    }

    private func clear(_ message: String) {
        generation += 1
        poll?.invalidate(); poll = nil
        timers = []; observedAt = nil; status = message
        reader.detach()
        reading = false
    }

    func refresh() {
        guard running, enabled else { return }
        guard AXIsProcessTrusted() else {
            clear("Allow Accessibility in System Settings, then choose Refresh Clock")
            return
        }
        guard !reading else { return }
        poll?.invalidate()
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.clock").first else {
            clear("Open Apple Clock and select Timers")
            schedule(after: 15)
            return
        }
        reading = true
        let token = generation
        reader.read(pid: app.processIdentifier) { [weak self] snapshot in
            Task { @MainActor in
                guard let self, self.running, self.enabled, token == self.generation else { return }
                self.reading = false
                self.timers = snapshot.map(ClockTimerParser.parse) ?? []
                self.observedAt = self.timers.isEmpty ? nil : Date()
                self.status = self.timers.isEmpty
                    ? "No readable timers. Keep Clock’s Timers view open. This experimental adapter currently recognizes English timer controls."
                    : "Observed in Apple Clock · read-only"
                self.schedule(after: self.timers.isEmpty ? 15 : (ProcessInfo.processInfo.isLowPowerModeEnabled ? 5 : 2))
            }
        }
    }

    private func schedule(after interval: TimeInterval) {
        guard running, enabled else { return }
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        poll?.tolerance = interval * 0.2
    }
}

/// AX messaging is bounded and serialized away from the UI thread.
private final class ClockAccessibilityReader: @unchecked Sendable {
    var onChange: (() -> Void)?
    private let queue = DispatchQueue(label: "com.notchislandsports.clock-observer", qos: .utility)
    private var observer: AXObserver?
    private var application: AXUIElement?
    private var processID: pid_t?
    private var lastSignal = Date.distantPast

    func detach() { queue.async { self.removeObserver() } }

    private func removeObserver() {
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        observer = nil; application = nil; processID = nil
    }

    func read(pid: pid_t, completion: @escaping (ClockAXNode?) -> Void) {
        queue.async {
            if self.processID != pid {
                self.removeObserver()
                let app = AXUIElementCreateApplication(pid)
                AXUIElementSetMessagingTimeout(app, 0.1)
                self.application = app; self.processID = pid
                var observer: AXObserver?
                let callback: AXObserverCallback = { _, _, _, context in
                    guard let context else { return }
                    let reader = Unmanaged<ClockAccessibilityReader>.fromOpaque(context).takeUnretainedValue()
                    // Coalesce value-change storms; the two-second reconciler handles seconds.
                    reader.queue.async {
                        guard Date().timeIntervalSince(reader.lastSignal) > 0.75 else { return }
                        reader.lastSignal = Date()
                        reader.onChange?()
                    }
                }
                if AXObserverCreate(pid, callback, &observer) == .success, let observer {
                    self.observer = observer
                    for name in [kAXWindowCreatedNotification, kAXUIElementDestroyedNotification,
                                 kAXFocusedUIElementChangedNotification, kAXValueChangedNotification] {
                        _ = AXObserverAddNotification(observer, app, name as CFString,
                            Unmanaged.passUnretained(self).toOpaque())
                    }
                    CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
                }
            }
            guard let app = self.application else { completion(nil); return }
            var hidden: CFTypeRef?
            _ = AXUIElementCopyAttributeValue(app, kAXHiddenAttribute as CFString, &hidden)
            guard (hidden as? Bool) != true else { completion(nil); return }
            var windows: CFTypeRef?
            guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows) == .success,
                  let elements = windows as? [AXUIElement], !elements.isEmpty else { completion(nil); return }
            var budget = 200
            let deadline = Date().addingTimeInterval(0.8)
            var exhausted = elements.count > 2
            let children = elements.prefix(2).compactMap { window -> ClockAXNode? in
                var minimized: CFTypeRef?
                _ = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized)
                guard (minimized as? Bool) != true else { return nil }
                return self.node(window, depth: 0, budget: &budget, deadline: deadline, exhausted: &exhausted)
            }
            // Partial trees must never imply that a previously seen timer was cancelled.
            completion(exhausted ? nil : ClockAXNode(role: "AXApplication", children: children))
        }
    }

    private func node(_ element: AXUIElement, depth: Int, budget: inout Int,
                      deadline: Date, exhausted: inout Bool) -> ClockAXNode? {
        guard depth < 12, budget > 0, Date() < deadline else { exhausted = true; return nil }
        budget -= 1
        func attribute(_ name: String) -> CFTypeRef? {
            var result: CFTypeRef?
            _ = AXUIElementCopyAttributeValue(element, name as CFString, &result)
            return result
        }
        let role = attribute(kAXRoleAttribute) as? String ?? ""
        let identifier = attribute(kAXIdentifierAttribute) as? String ?? ""
        let value = attribute(kAXValueAttribute) as? String
        let title = attribute(kAXTitleAttribute) as? String
        let description = attribute(kAXDescriptionAttribute) as? String
        let text = [value, title, description].compactMap { $0 }.first(where: { !$0.isEmpty }) ?? ""
        let children = attribute(kAXChildrenAttribute) as? [AXUIElement] ?? []
        if children.count > 80 { exhausted = true }
        return ClockAXNode(role: role, identifier: identifier, text: String(text.prefix(128)),
            children: children.prefix(80).compactMap {
                node($0, depth: depth + 1, budget: &budget, deadline: deadline, exhausted: &exhausted)
            })
    }
}
