import AppKit
import ApplicationServices
import Combine
import IslandCore

/// Native Clock adapter. Controls invoke only verified native buttons on an explicit user click.
@MainActor
final class NativeClockManager: ObservableObject {
    @Published private(set) var timers: [ObservedClockTimer] = []
    @Published private(set) var status = "Native Clock observation is off"
    @Published private(set) var observedAt: Date?
    @Published private(set) var controlBusy = false
    @Published private(set) var controlMessage: String?
    @Published var enabled: Bool {
        didSet {
            defaults.set(enabled, forKey: "NativeClockObservation")
            if enabled && running { refresh() } else { clear("Native Clock observation is off") }
        }
    }
    private let defaults: UserDefaults
    private let reader = ClockAccessibilityReader()
    private var poll: Timer?
    private var lastTrusted = AXIsProcessTrusted()
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
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                Task { @MainActor in
                    guard let self else { return }
                    let trusted = AXIsProcessTrusted()
                    if app?.bundleIdentifier == "com.apple.clock" || trusted != self.lastTrusted {
                        self.lastTrusted = trusted
                        self.refresh()
                    }
                }
            })
        }
        refresh()
    }

    func stop() {
        running = false
        generation += 1
        controlBusy = false
        poll?.invalidate(); poll = nil
        reader.detach()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
        reading = false
        controlBusy = false
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
        controlBusy = false
        poll?.invalidate(); poll = nil
        timers = []; observedAt = nil; status = message
        reader.detach()
        reading = false
    }

    func refresh() {
        guard running, enabled else { return }
        lastTrusted = AXIsProcessTrusted()
        guard lastTrusted else {
            clear("Allow NotchIslandSports in System Settings → Privacy & Security → Accessibility. Observation resumes automatically.")
            schedule(after: 15)
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
                self.timers = snapshot ?? []
                self.observedAt = self.timers.isEmpty ? nil : Date()
                self.status = self.timers.isEmpty
                    ? "No readable timers. Keep Clock’s Timers view open. This experimental adapter currently recognizes English timer controls."
                    : "Observed in Apple Clock"
                self.schedule(after: self.timers.isEmpty ? 15 : (ProcessInfo.processInfo.isLowPowerModeEnabled ? 5 : 2))
            }
        }
    }

    func control(_ command: NativeClockCommand, timer: ObservedClockTimer) {
        guard running, enabled, !controlBusy, timer.canControl, AXIsProcessTrusted(),
              let observedAt, Date().timeIntervalSince(observedAt) <= 5,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.clock").first else {
            controlMessage = "Native controls are unavailable. Open Clock to manage this timer."; return
        }
        guard let latest = timers.first(where: { $0.id == timer.id }),
              latest.controlIdentifier == timer.controlIdentifier,
              command == .cancel || latest.paused == timer.paused else {
            controlMessage = "This timer changed. Try its current control."; return
        }
        controlBusy = true
        controlMessage = nil
        let token = generation
        reader.perform(command, timer: latest, observedAt: observedAt, pid: app.processIdentifier) { [weak self] success in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                self.controlBusy = false
                self.controlMessage = success ? nil : "Clock’s timer changed or its controls are unavailable. Refresh or open Clock."
                self.refresh()
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
    private var cards: [String: [AXUIElement]] = [:]
    private var snapshotElements: [String: AXUIElement] = [:]
    private var selectedAnchors: [String: AXUIElement] = [:]
    private let controlLock = NSLock()
    private var controlEpoch = 0
    private func epoch() -> Int { controlLock.lock(); defer { controlLock.unlock() }; return controlEpoch }
    private func invalidateControls() { controlLock.lock(); controlEpoch += 1; controlLock.unlock() }


    func detach() { invalidateControls(); queue.async { self.removeObserver(); self.cards = [:]; self.snapshotElements = [:]; self.selectedAnchors = [:] } }

    private func removeObserver() {
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        observer = nil; application = nil; processID = nil
    }

    func read(pid: pid_t, completion: @escaping ([ObservedClockTimer]?) -> Void) {
        queue.async {
            self.cards = [:]; self.snapshotElements = [:]; self.selectedAnchors = [:]
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
            // Hidden/minimized Clock may still expose its native timer tree. Read what
            // Clock exposes and validate identities; foreground visibility is not a capability.
            var windows: CFTypeRef?
            guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows) == .success,
                  let elements = windows as? [AXUIElement], !elements.isEmpty else { completion(nil); return }
            var budget = 200
            let deadline = Date().addingTimeInterval(0.8)
            var exhausted = elements.count > 2
            let children = elements.prefix(2).enumerated().compactMap { windowIndex, window -> ClockAXNode? in
                return self.node(window, path: "clock.\(windowIndex)", depth: 0, budget: &budget, deadline: deadline, exhausted: &exhausted)
            }
            // Partial trees must never imply that a previously seen timer was cancelled.
            guard !exhausted else { self.cards = [:]; self.snapshotElements = [:]; self.selectedAnchors = [:]; completion(nil); return }
            let root = ClockAXNode(role: "AXApplication", children: children)
            if let selected = ClockTimerParser.selectedDetail(root), let id = selected.timer.controlIdentifier,
               let detail = self.snapshotElements[selected.detailPath], let anchor = self.snapshotElements[selected.selectionPath] {
                self.cards[id] = [detail]
                self.selectedAnchors[id] = anchor
            }
            self.snapshotElements = [:]
            let controlDeadline = Date().addingTimeInterval(0.3)
            let timers = ClockTimerParser.parse(root).enumerated().map { index, timer in
                guard index < 3, Date() < controlDeadline, let id = timer.controlIdentifier, let cards = self.cards[id], cards.count == 1,
                      let buttons = self.buttons(in: cards[0]), buttons[timer.paused ? .resume : .pause] != nil,
                      buttons[.cancel] != nil else {
                    return ObservedClockTimer(id: timer.id, remaining: timer.remaining, paused: timer.paused)
                }
                return timer
            }
            completion(timers)
        }
    }

    func perform(_ command: NativeClockCommand, timer: ObservedClockTimer,
                 observedAt: Date, pid: pid_t, completion: @escaping (Bool) -> Void) {
        let token = epoch()
        queue.async {
            guard AXIsProcessTrusted(), self.processID == pid,
                  let id = timer.controlIdentifier, let oldCards = self.cards[id], oldCards.count == 1,
                  let oldButton = self.buttons(in: oldCards[0])?[command] else { completion(false); return }
            let oldCard = oldCards[0]
            let oldAnchor = self.selectedAnchors[id]
            self.read(pid: pid) { fresh in
                guard self.epoch() == token, AXIsProcessTrusted(),
                      NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.apple.clock",
                      let matches = fresh?.filter({ $0.id == timer.id }), matches.count == 1,
                      ClockControlPolicy.accepts(previous: timer, current: matches[0],
                          age: Date().timeIntervalSince(observedAt), command: command),
                      let newCards = self.cards[id], newCards.count == 1, CFEqual(oldCard, newCards[0]),
                      let newButton = self.buttons(in: newCards[0])?[command], CFEqual(oldButton, newButton)
                else { completion(false); return }
                // Selected-detail controls must still belong to the exact same selected native card.
                if let oldAnchor {
                    guard let newAnchor = self.selectedAnchors[id], CFEqual(oldAnchor, newAnchor) else { completion(false); return }
                    var selected: CFTypeRef?
                    guard AXUIElementCopyAttributeValue(newAnchor, kAXSelectedAttribute as CFString, &selected) == .success,
                          (selected as? Bool) == true else { completion(false); return }
                } else if self.selectedAnchors[id] != nil { completion(false); return }
                completion(AXUIElementPerformAction(newButton, kAXPressAction as CFString) == .success)
            }
        }
    }

    private func buttons(in card: AXUIElement) -> [NativeClockCommand: AXUIElement]? {
        var found: [NativeClockCommand: [AXUIElement]] = [:]
        var budget = 40
        let deadline = Date().addingTimeInterval(0.25)
        var complete = true
        func visit(_ element: AXUIElement, depth: Int) {
            guard depth <= 3, budget > 0, Date() < deadline else { complete = false; return }
            budget -= 1
            func value(_ key: String) -> CFTypeRef? {
                var result: CFTypeRef?
                _ = AXUIElementCopyAttributeValue(element, key as CFString, &result)
                return result
            }
            if value(kAXRoleAttribute) as? String == "AXButton" {
                let label = ([kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute]
                    .compactMap { value($0) as? String }.first { !$0.isEmpty } ?? "")
                    .lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let command = NativeClockCommand.allLabels[label]
                var actions: CFArray?
                if let command, value(kAXEnabledAttribute) as? Bool == true,
                   AXUIElementCopyActionNames(element, &actions) == .success,
                   (actions as? [String])?.contains(kAXPressAction) == true {
                    found[command, default: []].append(element)
                }
            }
            let children = value(kAXChildrenAttribute) as? [AXUIElement] ?? []
            if depth == 3 { if !children.isEmpty { complete = false }; return }
            for child in children { visit(child, depth: depth + 1) }
        }
        visit(card, depth: 0)
        guard complete, found.values.allSatisfy({ $0.count == 1 }) else { return nil }
        return found.mapValues { $0[0] }
    }

    private func node(_ element: AXUIElement, path: String, depth: Int, budget: inout Int,
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
        snapshotElements[path] = element
        if !identifier.isEmpty, ["AXGroup", "AXLayoutItem"].contains(role) { cards[identifier, default: []].append(element) }
        let selected = UUID(uuidString: identifier) != nil && ["AXGroup", "AXLayoutItem"].contains(role)
            ? (attribute(kAXSelectedAttribute) as? Bool ?? false) : false
        let value = attribute(kAXValueAttribute) as? String
        let title = attribute(kAXTitleAttribute) as? String
        let description = attribute(kAXDescriptionAttribute) as? String
        let text = [value, title, description].compactMap { $0 }.first(where: { !$0.isEmpty }) ?? ""
        let children = attribute(kAXChildrenAttribute) as? [AXUIElement] ?? []
        if children.count > 80 { exhausted = true }
        return ClockAXNode(role: role, identifier: identifier, text: String(text.prefix(128)),
            children: children.prefix(80).enumerated().compactMap { index, child in
                node(child, path: "\(path).\(index)", depth: depth + 1, budget: &budget, deadline: deadline, exhausted: &exhausted)
            }, selected: selected)
    }
}

private extension NativeClockCommand {
    static let allLabels: [String: NativeClockCommand] = ["pause": .pause, "pause timer": .pause,
        "resume": .resume, "resume timer": .resume, "cancel": .cancel, "cancel timer": .cancel]
}

#if DEBUG
extension NativeClockManager {
    static func visualFixture(paused: Bool = false, controllable: Bool = true, count: Int = 1, remaining: TimeInterval = 197) -> NativeClockManager {
        let model = NativeClockManager(defaults: UserDefaults(suiteName: "NotchIsland.ClockVisualFixture")!)
        model.timers = (0..<count).map { index in
            .init(id: "fixture-\(index)", remaining: remaining + Double(index * 60), paused: paused,
                  controlIdentifier: controllable ? "fixture-\(index)" : nil)
        }
        model.status = "Visual fixture · no native timer is controlled"
        model.observedAt = Date()
        return model
    }
}
#endif
