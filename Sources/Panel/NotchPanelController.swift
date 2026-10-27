import AppKit
import SwiftUI
import Combine
import IslandCore

private final class IslandPanel: NSPanel {
    var acceptsKeyboard = false
    override var canBecomeKey: Bool { acceptsKeyboard }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class NotchPanelController {
    private var panel: IslandPanel!
    private var secondaryPanel: IslandPanel!
    private var tertiaryPanel: IslandPanel!
    private let hoverState = HoverState()
    private let dataManager: SportsDataManager
    private let media: NowPlayingManager
    private let calendar: CalendarManager
    private let clock: NativeClockManager
    let presentation: IslandPresentation
    private var cancellables = Set<AnyCancellable>()
    private var screen: NSScreen?
    private var updateQueued = false
    private var keyboardOpened = false
    private var previousApplication: NSRunningApplication?
    private var lastExpanded = false
    private var lastDetailPresentation: String?
    private var selectedDisplayID: CGDirectDisplayID?

    init(dataManager: SportsDataManager, media: NowPlayingManager,
         clock: NativeClockManager, calendar: CalendarManager, presentation: IslandPresentation) {
        self.dataManager = dataManager; self.media = media
        self.clock = clock; self.calendar = calendar; self.presentation = presentation
    }

    func setupPanel() {
        panel = makePanel()
        secondaryPanel = makePanel()
        tertiaryPanel = makePanel()
        let primary = HoverTrackingHostingView(rootView: NotchContentView(hoverState: hoverState,
            dataManager: dataManager, nowPlayingManager: media, clockManager: clock, calendarManager: calendar, presentation: presentation))
        primary.hoverState = hoverState
        primary.onScrollPull = { [weak self] in self?.presentation.pullDown() }
        panel.contentView = primary
        let secondary = HoverTrackingHostingView(rootView: SecondaryActivityView(
            dataManager: dataManager, media: media, clock: clock, calendar: calendar, presentation: presentation, third: false))
        secondaryPanel.contentView = secondary
        let tertiary = HoverTrackingHostingView(rootView: SecondaryActivityView(
            dataManager: dataManager, media: media, clock: clock, calendar: calendar, presentation: presentation, third: true))
        tertiaryPanel.contentView = tertiary
        observe()
        repositionForScreen()
        refreshActivities()
    }

    private func makePanel() -> IslandPanel {
        let result = IslandPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        result.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        result.backgroundColor = .clear
        result.isOpaque = false
        result.hasShadow = false
        result.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        result.hidesOnDeactivate = false
        result.isMovable = false
        result.becomesKeyOnlyIfNeeded = true
        return result
    }

    private func observe() {
        hoverState.$isHovered.removeDuplicates().sink { [weak self] hovered in
            guard let self, !self.presentation.pinned else { return }
            self.presentation.expanded = hovered
        }.store(in: &cancellables)
        dataManager.$activeMatch.map { $0 != nil }.removeDuplicates().sink { [weak self] _ in
            self?.queueUpdate()
        }.store(in: &cancellables)
        dataManager.$activeMatch.map { $0?.sportType }.removeDuplicates().sink { [weak self] _ in
            self?.queueUpdate()
        }.store(in: &cancellables)
        dataManager.$showMatchSelector.removeDuplicates().sink { [weak self] _ in self?.queueUpdate() }.store(in: &cancellables)
        dataManager.$forceNotchLayout.removeDuplicates().dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.repositionForScreen() }
        }.store(in: &cancellables)
        media.$currentTrack.map { $0 != nil }.removeDuplicates().sink { [weak self] _ in self?.queueUpdate() }.store(in: &cancellables)
        calendar.$currentEvent.map { $0 != nil }.removeDuplicates().sink { [weak self] _ in self?.queueUpdate() }.store(in: &cancellables)
        clock.$timers.map { !$0.isEmpty }.removeDuplicates().sink { [weak self] _ in self?.queueUpdate() }.store(in: &cancellables)
        presentation.objectWillChange.sink { [weak self] in self?.queueUpdate() }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.repositionForScreen() }.store(in: &cancellables)
    }

    private func queueUpdate() {
        guard !updateQueued else { return }
        updateQueued = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateQueued = false
            self.refreshActivities()
            self.updateFrames()
        }
    }

    private func refreshActivities() {
        presentation.update(sports: dataManager.activeMatch != nil,
                            music: media.currentTrack != nil, clock: !clock.timers.isEmpty, calendar: calendar.currentEvent != nil)
    }

    func repositionForScreen() {
        screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 && CGDisplayIsBuiltin(displayID($0) ?? 0) != 0 })
            ?? NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 && displayID($0) == selectedDisplayID })
            ?? NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.screens.first(where: { displayID($0) == selectedDisplayID }) ?? NSScreen.main
        guard let screen else { return }
        selectedDisplayID = displayID(screen)
        let geometry = NotchGeometry.layout(screen: screen.frame, safeTop: screen.safeAreaInsets.top,
            leftArea: screen.auxiliaryTopLeftArea, rightArea: screen.auxiliaryTopRightArea,
            simulated: dataManager.forceNotchLayout, expanded: false, contentHeight: 0)
        dataManager.hasNotch = geometry.cameraHeight > 0
        dataManager.notchWidth = geometry.cameraWidth
        if presentation.cameraHeight != geometry.cameraHeight { presentation.cameraHeight = geometry.cameraHeight }
        updateFrames(animated: false)
    }

    private func displayID(_ screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    private var expandedHeight: CGFloat {
        if presentation.selectedTab == .calendar { return 470 }
        if presentation.selectedTab == .clock { return 310 }
        if presentation.selectedTab == .music { return 280 }
        if dataManager.showMatchSelector { return 330 }
        guard let match = dataManager.activeMatch else { return 280 }
        switch match {
        case .cricket: return 410
        case .tennis: return 260
        case .soccer: return 270
        case .lacrosse: return 230
        case .f1: return 370
        case .nfl, .collegeFootball: return 290
        default: return 250
        }
    }

    private func updateFrames(animated: Bool = true) {
        guard let panel, let secondaryPanel, let tertiaryPanel, let screen else { return }
        guard !presentation.suspended else { hide(); return }
        let layout = NotchGeometry.layout(screen: screen.frame, safeTop: screen.safeAreaInsets.top,
            leftArea: screen.auxiliaryTopLeftArea, rightArea: screen.auxiliaryTopRightArea,
            simulated: dataManager.forceNotchLayout, expanded: presentation.expanded, contentHeight: expandedHeight)
        let animate = animated && !presentation.reduceMotion && !presentation.lowPower
        setFrame(panel, layout.primary, animated: animate)
        setFrame(secondaryPanel, layout.secondary, animated: animate)
        setFrame(tertiaryPanel, layout.tertiary, animated: animate)
        panel.acceptsKeyboard = presentation.expanded
        if !panel.isVisible { panel.orderFrontRegardless() }
        showSatellite(secondaryPanel, visible: presentation.selection.secondary != nil, animated: animate)
        showSatellite(tertiaryPanel, visible: presentation.selection.tertiary != nil, animated: animate)
        let policy = "\(presentation.expanded && presentation.selectedTab == .sports):\(presentation.lowPower)"
        if policy != lastDetailPresentation {
            lastDetailPresentation = policy
            dataManager.setPresentation(expanded: presentation.expanded && presentation.selectedTab == .sports,
                                        lowPower: presentation.lowPower)
        }
        if lastExpanded && !presentation.expanded && keyboardOpened {
            previousApplication?.activate(options: [])
            keyboardOpened = false
            panel.resignKey()
        }
        lastExpanded = presentation.expanded
    }

    private func showSatellite(_ window: NSWindow, visible: Bool, animated: Bool) {
        guard visible else { if window.isVisible { window.orderOut(nil) }; return }
        guard !window.isVisible else { return }
        window.alphaValue = animated ? 0 : 1
        window.orderFrontRegardless()
        if animated { NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            window.animator().alphaValue = 1
        } }
    }

    private func setFrame(_ window: NSWindow, _ frame: NSRect, animated: Bool) {
        guard window.frame != frame else { return }
        if animated && window.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.32
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
            }
        } else { window.setFrame(frame, display: true) }
    }

    func open(_ activity: IslandActivity) {
        previousApplication = NSWorkspace.shared.frontmostApplication
        keyboardOpened = true
        presentation.open(activity)
        updateFrames()
        panel.makeKeyAndOrderFront(nil)
    }
    func show() { presentation.suspended = false; updateFrames(animated: false) }
    func hide() { panel?.orderOut(nil); secondaryPanel?.orderOut(nil); tertiaryPanel?.orderOut(nil) }
    func toggle() { if panel.isVisible { presentation.suspended = true; hide() } else { show() } }
}

struct SecondaryActivityView: View {
    @ObservedObject var dataManager: SportsDataManager
    @ObservedObject var media: NowPlayingManager
    @ObservedObject var clock: NativeClockManager
    @ObservedObject var calendar: CalendarManager
    @ObservedObject var presentation: IslandPresentation
    var third: Bool
    private var activity: IslandActivity? { third ? presentation.selection.tertiary : presentation.selection.secondary }
    var body: some View {
        Button {
            if let activity { presentation.open(activity) }
        } label: {
            Group {
                switch activity {
                case .music:
                    HStack(spacing: 5) {
                        Image(systemName: media.currentTrack?.isPlaying == true ? "music.note" : "pause.fill")
                        if !presentation.selection.overflow.isEmpty { Text("+\(presentation.selection.overflow.count)").font(.caption2) }
                    }.foregroundColor(media.currentTrack?.dominantColor ?? .purple)
                case .calendar: CalendarCompactView(manager: calendar, minimal: true)
                case .clock: NativeClockCompactView(manager: clock, minimal: true)
                case .sports:
                    VStack(spacing: 1) {
                        Text("\(dataManager.activeMatch?.homeTeamAbbrev ?? "") · \(dataManager.activeMatch?.awayTeamAbbrev ?? "")")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(dataManager.activeMatch?.homeScore ?? "") – \(dataManager.activeMatch?.awayScore ?? "")")
                            .font(.system(size: 9, weight: .medium))
                    }.foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                case nil: EmptyView()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 18).onEnded { value in
            if value.translation.height > 18, let activity { presentation.open(activity) }
        })
        .background(Capsule().fill(Color.black))
        .accessibilityLabel("Open \(activity?.rawValue ?? "activity") activity")
        .accessibilityValue(activity == .music ? (media.currentTrack?.title ?? "") : "")
    }
}
