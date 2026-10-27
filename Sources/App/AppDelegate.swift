import AppKit
import SwiftUI
import Combine
import IslandCore

// MARK: - AppDelegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItem: NSStatusItem!
    private var panelController: NotchPanelController!
    private let dataManager = SportsDataManager()
    private let media = NowPlayingManager()
    private let clock = NativeClockManager()
    private let calendar = CalendarManager()
    private let presentation = IslandPresentation()
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
            button.toolTip = "NotchIslandSports"
        }
        
        let menu = NSMenu()
        
        // Sport selection submenu
        let sportMenu = NSMenu()
        let sportMenuItem = NSMenuItem(title: "Select Sport", action: nil, keyEquivalent: "")
        sportMenuItem.submenu = sportMenu
        
        let allItem = NSMenuItem(title: "All Sports", action: #selector(filterAllSports), keyEquivalent: "")
        allItem.target = self
        sportMenu.addItem(allItem)
        sportMenu.addItem(NSMenuItem.separator())
        
        for sport in SportType.allCases {
            let item = NSMenuItem(title: "\(sport.icon) \(sport.rawValue)", action: #selector(filterSport(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = sport
            sportMenu.addItem(item)
        }
        
        menu.addItem(sportMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        // Select Match
        let selectMatchItem = NSMenuItem(title: "Select Match...", action: #selector(toggleMatchSelector), keyEquivalent: "m")
        selectMatchItem.target = self
        menu.addItem(selectMatchItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let openItem = NSMenuItem(title: "Open Island", action: #selector(openIsland), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)
        let calendarItem = NSMenuItem(title: "Apple Calendar…", action: #selector(openNativeCalendar), keyEquivalent: "c")
        calendarItem.target = self
        menu.addItem(calendarItem)
        let clockItem = NSMenuItem(title: "Apple Clock…", action: #selector(openNativeClock), keyEquivalent: "t")
        clockItem.target = self
        menu.addItem(clockItem)
        let mediaItem = NSMenuItem(title: "Experimental System Media", action: #selector(toggleMedia(_:)), keyEquivalent: "")
        mediaItem.target = self
        mediaItem.state = media.enabled ? .on : .off
        menu.addItem(mediaItem)
        menu.addItem(NSMenuItem.separator())

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
        Task { @MainActor in
            await dataManager.refresh()
        }
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "NotchIslandSports"
        alert.informativeText = "Live sports scores in your MacBook notch.\n\nAll 13 existing sports • Music • Calendar • Native Clock observation\n\nVersion 1.3 Preview\n© 2026 NotchIslandSports"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func toggleNotchSimulation(_ sender: NSMenuItem) {
        dataManager.forceNotchLayout.toggle()
        sender.state = dataManager.forceNotchLayout ? .on : .off
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

