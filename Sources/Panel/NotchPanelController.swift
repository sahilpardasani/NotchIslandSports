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
    private var satelliteVisibility: [ObjectIdentifier: Bool] = [:]
    private var targetFrames: [ObjectIdentifier: CGRect] = [:]
    private var frameEpochs: [ObjectIdentifier: Int] = [:]
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
        let primary = IslandGestureHostingView(rootView: NotchContentView(
            dataManager: dataManager, nowPlayingManager: media, clockManager: clock, calendarManager: calendar, presentation: presentation))
        primary.onScrollPull = { [weak self] in self?.presentation.pullDown() }
        primary.onScrollPush = { [weak self] in self?.presentation.collapse() }
        primary.onHorizontalSwipe = { [weak self] forward, held in self?.scrollSideways(forward: forward, held: held) }
        panel.contentView = primary
        let secondary = IslandGestureHostingView(rootView: SecondaryActivityView(
            dataManager: dataManager, media: media, clock: clock, calendar: calendar, presentation: presentation, third: false))
        secondary.onScrollPull = { [weak self] in
            guard let self, let activity = self.presentation.selection.secondary else { return }
            self.presentation.open(activity)
        }
        secondary.onScrollPush = { [weak self] in self?.presentation.collapse() }
        secondary.onHorizontalSwipe = { [weak self] forward, held in self?.scrollSideways(forward: forward, held: held) }
        secondaryPanel.contentView = secondary
        let tertiary = IslandGestureHostingView(rootView: SecondaryActivityView(
            dataManager: dataManager, media: media, clock: clock, calendar: calendar, presentation: presentation, third: true))
        tertiary.onScrollPull = { [weak self] in
            guard let self, let activity = self.presentation.selection.tertiary else { return }
            self.presentation.open(activity)
        }
        tertiary.onScrollPush = { [weak self] in self?.presentation.collapse() }
        tertiary.onHorizontalSwipe = { [weak self] forward, held in self?.scrollSideways(forward: forward, held: held) }
        tertiaryPanel.contentView = tertiary
        observe()
        repositionForScreen()
        refreshActivities()
    }

    private func scrollSideways(forward: Bool, held: Bool) {
        if held { presentation.setMerged(!presentation.merged); presentation.collapse() }
        else { presentation.cyclePrimary(forward: forward) }
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
        media.$controlError.removeDuplicates().sink { [weak self] _ in self?.queueUpdate() }.store(in: &cancellables)
        media.$currentTrack.map { $0?.sourceBundleID }.removeDuplicates().sink { [weak self] _ in self?.queueUpdate() }.store(in: &cancellables)
        calendar.$currentEvent.map { $0 != nil }.removeDuplicates().sink { [weak self] _ in self?.queueUpdate() }.store(in: &cancellables)
        clock.$timers.map { min($0.count, 2) }.removeDuplicates().sink { [weak self] _ in self?.queueUpdate() }.store(in: &cancellables)
        presentation.$expanded.removeDuplicates().dropFirst().sink { [weak self] expanded in
            guard !expanded else { return }
            self?.dataManager.showMatchSelector = false
        }.store(in: &cancellables)
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
        if presentation.selectedTab == .calendar { return 420 }
        if presentation.selectedTab == .clock { return NativeClockView.contentHeight(timerCount: clock.timers.count) }
        if presentation.selectedTab == .music {
            let hasMessage = media.controlError != nil || (media.currentTrack != nil && !media.canControl)
            return hasMessage ? 206 : 180
        }
        if dataManager.showMatchSelector { return 330 }
        guard let match = dataManager.activeMatch else { return 280 }
        switch match {
        case .cricket: return 320
        case .tennis: return 210
        case .soccer: return 220
        case .lacrosse: return 180
        case .f1: return 320
        case .nfl, .collegeFootball: return 240
        default: return 200
        }
    }

    private func updateFrames(animated: Bool = true) {
        guard let panel, let secondaryPanel, let tertiaryPanel, let screen else { return }
        guard !presentation.suspended else { hide(); return }
        let layout = NotchGeometry.layout(screen: screen.frame, safeTop: screen.safeAreaInsets.top,
            leftArea: screen.auxiliaryTopLeftArea, rightArea: screen.auxiliaryTopRightArea,
            simulated: dataManager.forceNotchLayout, expanded: presentation.expanded, contentHeight: expandedHeight,
            expandedWidth: presentation.selectedTab == .clock ? 440 : 600)
        if presentation.expanded {
            if presentation.expandedPanelHeight != layout.primary.height { presentation.expandedPanelHeight = layout.primary.height }
            if presentation.expandedPanelWidth != layout.primary.width { presentation.expandedPanelWidth = layout.primary.width }
            if !presentation.expandedContentMounted { presentation.expandedContentMounted = true }
        }
        (panel.contentView as? IslandGestureHostingView<NotchContentView>)?.swipeHeaderHeight = presentation.cameraHeight + 8
        let animate = animated && !presentation.reduceMotion && !presentation.lowPower
        setFrame(panel, layout.primary, animated: animate, completion: { [weak self] in self?.presentation.finishResize() })
        panel.acceptsKeyboard = presentation.expanded
        if !panel.isVisible { panel.orderFrontRegardless() }
        showSatellite(secondaryPanel, frame: layout.secondary, visible: presentation.showsSecondary, animated: animate)
        showSatellite(tertiaryPanel, frame: layout.tertiary, visible: presentation.showsTertiary, animated: animate)
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

    private func showSatellite(_ window: NSWindow, frame: CGRect, visible: Bool, animated: Bool) {
        let key = ObjectIdentifier(window)
        guard satelliteVisibility[key] != visible else {
            if visible { setFrame(window, frame, animated: animated) }
            return
        }
        satelliteVisibility[key] = visible
        let epoch = (frameEpochs[key] ?? 0) + 1
        frameEpochs[key] = epoch
        targetFrames[key] = frame
        let tucked = frame.offsetBy(dx: frame.midX < panel.frame.midX ? 32 : -32, dy: 0)
        guard animated else {
            window.setFrame(frame, display: true); window.alphaValue = 1
            if visible { window.orderFrontRegardless() } else { window.orderOut(nil) }
            return
        }
        if visible && !window.isVisible {
            window.setFrame(tucked, display: true); window.alphaValue = 0
            window.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.20, 0, 0.20, 1)
            window.animator().setFrame(visible ? frame : tucked, display: true)
            window.animator().alphaValue = visible ? 1 : 0
        } completionHandler: { [weak self, weak window] in
            Task { @MainActor in
                guard let self, let window, self.frameEpochs[key] == epoch,
                      self.satelliteVisibility[key] == visible else { return }
                if !visible {
                    window.orderOut(nil); window.setFrame(frame, display: false); window.alphaValue = 1
                }
            }
        }
    }

    private func setFrame(_ window: NSWindow, _ frame: NSRect, animated: Bool, completion: (() -> Void)? = nil) {
        let key = ObjectIdentifier(window)
        // Provider publications must not restart an in-flight resize toward the same target.
        guard targetFrames[key] != frame else { return }
        targetFrames[key] = frame
        let epoch = (frameEpochs[key] ?? 0) + 1
        frameEpochs[key] = epoch
        guard window.frame != frame else { completion?(); return }
        if animated && window.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = presentation.expanded ? 0.38 : 0.32
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.20, 0.0, 0.20, 1.0)
                window.animator().setFrame(frame, display: true)
            } completionHandler: { [weak self] in
                Task { @MainActor in
                    guard self?.targetFrames[key] == frame, self?.frameEpochs[key] == epoch else { return }
                    completion?()
                }
            }
        } else { window.setFrame(frame, display: true); completion?() }
    }

    func open(_ activity: IslandActivity) {
        previousApplication = NSWorkspace.shared.frontmostApplication
        keyboardOpened = true
        presentation.open(activity)
        updateFrames()
        panel.makeKeyAndOrderFront(nil)
    }
    func show() { presentation.suspended = false; updateFrames(animated: false) }
    func hide() {
        panel?.orderOut(nil); secondaryPanel?.orderOut(nil); tertiaryPanel?.orderOut(nil)
        satelliteVisibility.removeAll()
        targetFrames.removeAll()
        for key in Array(frameEpochs.keys) { frameEpochs[key, default: 0] += 1 }
    }
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
          GeometryReader { proxy in
            Group {
                switch activity {
                case .music:
                    HStack(spacing: 5) {
                        DynamicIslandWaveform(isPlaying: media.currentTrack?.isPlaying == true,
                            color: media.currentTrack?.dominantColor ?? .cyan, barCount: 5,
                            animationAllowed: MediaMotion.allowed(playing: media.currentTrack?.isPlaying == true,
                                active: media.isActive, visible: !presentation.suspended && !presentation.merged,
                                reduceMotion: presentation.reduceMotion, lowPower: presentation.lowPower))
                        if !presentation.selection.overflow.isEmpty { Text("+\(presentation.selection.overflow.count)").font(.caption2) }
                    }.foregroundColor(media.currentTrack?.dominantColor ?? .purple)
                case .calendar: EmptyView() // Calendar never occupies a live slot.
                case .clock: NativeClockCompactView(manager: clock, minimal: true)
                case .sports:
                    VStack(spacing: 1) {
                        Text("\(dataManager.activeMatch?.homeTeamAbbrev ?? "") · \(dataManager.activeMatch?.awayTeamAbbrev ?? "")")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(CompactActivityText.score(dataManager.activeMatch?.homeScore ?? "")) · \(CompactActivityText.score(dataManager.activeMatch?.awayScore ?? ""))")
                            .font(.system(size: 9, weight: .medium))
                    }.foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.9).truncationMode(.tail)
                case nil: EmptyView()
                }
            }.frame(width: max(0, proxy.size.width - 16), height: proxy.size.height)
                .padding(.horizontal, 8).clipped()
          }
        }
        .buttonStyle(.plain)
        .modifier(IslandSwipeGesture(presentation: presentation, pullDownActivity: activity))
        .background(Capsule().fill(Color.black))
        .clipShape(Capsule())
        .accessibilityLabel("Open \(activity?.rawValue ?? "activity") activity")
        .accessibilityValue(activity == .music ? (media.currentTrack?.title ?? "") : "")
    }
}
