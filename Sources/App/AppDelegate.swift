import AppKit
import SwiftUI
import Combine

// MARK: - AppDelegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItem: NSStatusItem!
    private var panelController: NotchPanelController!
    private let dataManager = SportsDataManager()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        setupPanelController()
        startDataPolling()
        observeSystemEvents()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        dataManager.stopPolling()
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
        panelController = NotchPanelController(dataManager: dataManager)
        panelController.setupPanel()
    }
    
    // MARK: - Data Polling
    
    private func startDataPolling() {
        dataManager.startPolling()
        
        // Initial fetch
        Task { @MainActor in
            await dataManager.fetchAllMatches()
        }
    }
    
    // MARK: - System Event Observers
    
    private func observeSystemEvents() {
        // Screen parameter changes (external display connect/disconnect)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.panelController.repositionForScreen()
            }
        }
        
        // Sleep/Wake notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.dataManager.stopPolling()
            }
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.dataManager.startPolling()
                Task { @MainActor [weak self] in
                    await self?.dataManager.refresh()
                }
            }
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
        dataManager.showMatchSelector.toggle()
    }
    
    @objc private func refreshData() {
        Task { @MainActor in
            await dataManager.refresh()
        }
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "NotchIslandSports"
        alert.informativeText = "Live sports scores in your MacBook notch.\n\nSupported: Cricket, Tennis, NFL, FIFA/Soccer\n\nVersion 1.0\n© 2026 NotchIslandSports"
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
