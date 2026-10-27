import AppKit
import ApplicationServices
import SwiftUI
import Combine
import IslandCore

// MARK: - AppDelegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation, NSWindowDelegate {
    
    private var statusItem: NSStatusItem!
    private var panelController: NotchPanelController!
    private let dataManager = SportsDataManager()
    private let media = NowPlayingManager()
    private let clock = NativeClockManager()
    private let calendar = CalendarManager()
    private let presentation = IslandPresentation()
    private var setupWindow: NSWindow?
    private var systemSleeping = false
    private var displaySleeping = false
    private var sessionInactive = false
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        setupPanelController()
        resumeProviders()
        observeSystemEvents()
        if !UserDefaults.standard.bool(forKey: "IslandSetupCompleted") || !clock.setupChoiceMade || (clock.enabled && !clock.configurationReady) { showSetup() }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        suspendProviders()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }
    
    // MARK: - Status Bar
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sportscourt.fill", accessibilityDescription: "NotchIslandSports")
            button.image?.size = NSSize(width: 18, height: 18)
        }
        
        let menu = NSMenu()
        
        func item(_ title: String, _ action: Selector, key: String = "", in parent: NSMenu) {
            let value = NSMenuItem(title: title, action: action, keyEquivalent: key)
            value.target = self
            parent.addItem(value)
        }
        let widgets = NSMenu()
        let widgetItem = NSMenuItem(title: "Select Widget", action: nil, keyEquivalent: "")
        widgetItem.submenu = widgets
        for (title, activity) in [("Sports", IslandActivity.sports), ("Music", .music), ("Apple Clock", .clock), ("Calendar Agenda", .calendar)] {
            let value = NSMenuItem(title: title, action: #selector(selectWidget(_:)), keyEquivalent: "")
            value.target = self
            value.representedObject = activity.rawValue
            widgets.addItem(value)
        }
        let sportMenu = NSMenu()
        let sportItem = NSMenuItem(title: "Filter Sports", action: nil, keyEquivalent: "")
        sportItem.submenu = sportMenu
        item("All Sports", #selector(filterAllSports), in: sportMenu)
        for sport in SportType.allCases {
            let value = NSMenuItem(title: "\(sport.icon) \(sport.rawValue)", action: #selector(filterSport(_:)), keyEquivalent: "")
            value.target = self; value.representedObject = sport
            sportMenu.addItem(value)
        }
        widgets.addItem(.separator())
        widgets.addItem(sportItem)
        menu.addItem(widgetItem)
        menu.addItem(.separator())
        item("Select Match…", #selector(toggleMatchSelector), key: "m", in: menu)
        menu.addItem(.separator())

        // Refresh
        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshData), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Simulate Notch Layout
        let simulateNotchItem = NSMenuItem(title: "Simulate Notch Layout", action: #selector(toggleNotchSimulation(_:)), keyEquivalent: "n")
        simulateNotchItem.target = self
        simulateNotchItem.state = dataManager.forceNotchLayout ? .on : .off
        menu.addItem(simulateNotchItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // About
        let aboutItem = NSMenuItem(title: "About NotchIslandSports", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit NotchIslandSports", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    // MARK: - Panel Controller
    
    private func setupPanelController() {
        panelController = NotchPanelController(dataManager: dataManager, media: media, clock: clock, calendar: calendar, presentation: presentation)
        panelController.setupPanel()
    }
    
    private func resumeProviders() {
        guard !systemSleeping, !displaySleeping, !sessionInactive else { return }
        presentation.suspended = false
        updatePowerPolicy()
        dataManager.startPolling()
        media.startPolling()
        clock.start()
        calendar.start()
        panelController.show()
    }

    private func suspendProviders() {
        presentation.suspended = true
        presentation.collapse()
        dataManager.stopPolling()
        media.stopPolling()
        clock.stop()
        calendar.stop()
        panelController?.hide()
    }

    private func updatePowerPolicy() {
        presentation.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled ||
            ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical
        presentation.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        dataManager.setPresentation(expanded: presentation.expanded && presentation.selectedTab == .sports,
                                    lowPower: presentation.lowPower)
    }

    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        func observe(_ name: Notification.Name, _ handler: @escaping (AppDelegate) -> Void) {
            workspace.publisher(for: name).receive(on: DispatchQueue.main).sink { [weak self] _ in
                guard let self else { return }
                handler(self)
            }.store(in: &cancellables)
        }
        observe(NSWorkspace.willSleepNotification) { $0.systemSleeping = true; $0.suspendProviders() }
        observe(NSWorkspace.didWakeNotification) { $0.systemSleeping = false; $0.resumeProviders() }
        observe(NSWorkspace.screensDidSleepNotification) { $0.displaySleeping = true; $0.suspendProviders() }
        observe(NSWorkspace.screensDidWakeNotification) { $0.displaySleeping = false; $0.resumeProviders() }
        observe(NSWorkspace.sessionDidResignActiveNotification) { $0.sessionInactive = true; $0.suspendProviders() }
        observe(NSWorkspace.sessionDidBecomeActiveNotification) { $0.sessionInactive = false; $0.resumeProviders() }
        observe(NSWorkspace.accessibilityDisplayOptionsDidChangeNotification) { $0.updatePowerPolicy() }
        for name in [Notification.Name.NSProcessInfoPowerStateDidChange, ProcessInfo.thermalStateDidChangeNotification] {
            NotificationCenter.default.publisher(for: name).receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.updatePowerPolicy() }.store(in: &cancellables)
        }
    }

    // MARK: - Menu Actions
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleSplit): menuItem.state = presentation.merged ? .off : .on
        case #selector(selectWidget(_:)):
            let selected = presentation.expanded ? presentation.selectedTab : presentation.selection.primary
            menuItem.state = (menuItem.representedObject as? String) == selected?.rawValue ? .on : .off
        case #selector(toggleMedia(_:)): menuItem.state = media.enabled ? .on : .off
        case #selector(connectCalendar): return !calendar.enabled || !calendar.hasAccess
        case #selector(refreshCalendar): return calendar.enabled && calendar.hasAccess
        case #selector(disconnectCalendar): return calendar.enabled
        case #selector(enableClock): return !clock.enabled || !AXIsProcessTrusted()
        case #selector(refreshClock), #selector(disableClock): return clock.enabled
        default: break
        }
        return true
    }

    @objc private func selectWidget(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let activity = IslandActivity(rawValue: raw) else { return }
        panelController.open(activity)
    }
    @objc private func toggleSplit() { presentation.setMerged(!presentation.merged) }
    @objc private func connectCalendar() { calendar.connect() }
    @objc private func refreshCalendar() { calendar.refresh() }
    @objc private func disconnectCalendar() { calendar.enabled = false }
    @objc private func launchCalendar() { calendar.openCalendar() }
    @objc private func enableClock() { clock.requestPermission() }
    @objc private func refreshClock() { clock.refresh() }
    @objc private func disableClock() { clock.enabled = false }
    @objc private func showClockStatus() {
        let alert = NSAlert()
        alert.messageText = "Native Clock — Experimental"
        var details = clock.status
        if let observed = clock.observedAt { details += "\nLast observed: " + observed.formatted(date: .omitted, time: .standard) }
        if let message = clock.controlMessage { details += "\n" + message }
        details += "\n\nControls require readable, uniquely identified native Clock buttons. No in-app timer is created."
        alert.informativeText = details
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    @objc private func launchClock() { clock.openClock() }

    @objc private func filterAllSports() {
        dataManager.selectedSportFilter = nil
    }
    
    @objc private func filterSport(_ sender: NSMenuItem) {
        if let sport = sender.representedObject as? SportType {
            dataManager.selectedSportFilter = sport
        }
    }
    
    @objc private func toggleMatchSelector() {
        dataManager.showMatchSelector = true
        dataManager.requestDiscovery()
        panelController.open(.sports)
    }
    
    @objc private func openIsland() { panelController.open(presentation.selection.primary ?? .sports) }
    @objc private func openNativeCalendar() { panelController.open(.calendar) }
    @objc private func openNativeClock() { panelController.open(.clock) }
    @objc private func toggleMedia(_ sender: NSMenuItem) {
        media.enabled.toggle()
        sender.state = media.enabled ? .on : .off
    }

    @objc private func refreshData() {
        clock.refresh(); calendar.refresh(); media.updateNowPlayingInfo()
        Task { @MainActor in
            await dataManager.refresh()
        }
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "NotchIslandSports"
        alert.informativeText = "Live sports scores in your MacBook notch.\n\nAll 13 existing sports • Music • Calendar • Native Clock observation\n\nVersion 1.6 Preview (build 8)\n© 2026 NotchIslandSports"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Configure…")
        if alert.runModal() == .alertSecondButtonReturn { showSetup() }
    }

    private func showSetup() {
        clock.beginSetupObservation()
        if let setupWindow { setupWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 490, height: 600),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Set up NotchIslandSports"
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: IslandSetupView(clock: clock, calendar: calendar,
            media: media, presentation: presentation, done: { [weak self] in
                guard self?.clock.configurationReady == true else { return }
                UserDefaults.standard.set(true, forKey: "IslandSetupCompleted")
                self?.setupWindow?.close()
            }))
        setupWindow = window
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === setupWindow { clock.endSetupObservation() }
    }

    @objc private func toggleNotchSimulation(_ sender: NSMenuItem) {
        dataManager.forceNotchLayout.toggle()
        sender.state = dataManager.forceNotchLayout ? .on : .off
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

