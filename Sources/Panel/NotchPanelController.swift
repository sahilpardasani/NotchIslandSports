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
        let primary = HoverTrackingHostingView(rootView: NotchContentView(hoverState: hoverState,
            dataManager: dataManager, nowPlayingManager: media, clockManager: clock, calendarManager: calendar, presentation: presentation))
        primary.hoverState = hoverState
        panel.contentView = primary
        let secondary = HoverTrackingHostingView(rootView: SecondaryActivityView(
            dataManager: dataManager, media: media, clock: clock, calendar: calendar, presentation: presentation))
        secondary.hoverState = hoverState
        secondaryPanel.contentView = secondary
        observe()
        repositionForScreen()
        refreshActivities()
    }

    private func makePanel() -> IslandPanel {
        let result = IslandPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        result.level = .floating
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
        screen = NSScreen.screens.first(where: { displayID($0) == selectedDisplayID })
            ?? NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
        guard let screen else { return }
        selectedDisplayID = displayID(screen)
        let cutout = screen.auxiliaryTopRightArea.flatMap { right in
            screen.auxiliaryTopLeftArea.map { right.minX - $0.maxX }
        } ?? 0
        dataManager.hasNotch = screen.safeAreaInsets.top > 0 || dataManager.forceNotchLayout
        dataManager.notchWidth = max(cutout, dataManager.forceNotchLayout ? 150 : 0)
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
        guard let panel, let secondaryPanel, let screen else { return }
        guard !presentation.suspended else { hide(); return }
        let hasSecondary = presentation.selection.secondary != nil
        let width: CGFloat
        if presentation.expanded { width = dataManager.hasNotch ? 660 : 560 }
        else {
            switch presentation.selection.primary ?? .sports {
            case .sports: width = dataManager.hasNotch ? max(600, dataManager.notchWidth + 500) : 540
            case .music: width = 420
            case .clock: width = 240
            case .calendar: width = 420
            }
        }
        let bubbleWidth: CGFloat = 76
        let gap: CGFloat = 8
        let available = max(200, screen.frame.width - 32 - (hasSecondary ? bubbleWidth + gap : 0))
        let actualWidth = min(width, available)
        let height = presentation.expanded ? min(expandedHeight, screen.visibleFrame.height - 16) : 36
        // Place every interactive pixel below the hardware cutout/menu bar.
        // A distinct secondary window leaves the split gap click-through.
        let top = min(screen.frame.maxY - screen.safeAreaInsets.top, screen.visibleFrame.maxY) - 4
        let x = min(max(screen.frame.midX - actualWidth / 2, screen.frame.minX + 16),
                    screen.frame.maxX - actualWidth - (hasSecondary ? bubbleWidth + gap : 0) - 16)
        let frame = NSRect(x: x, y: top - height, width: actualWidth, height: height)
        let secondaryFrame = NSRect(x: x + actualWidth + gap, y: top - 36, width: bubbleWidth, height: 36)
        let animate = animated && !presentation.reduceMotion && !presentation.lowPower
        setFrame(panel, frame, animated: animate)
        setFrame(secondaryPanel, secondaryFrame, animated: animate)
        panel.acceptsKeyboard = presentation.expanded
        if !panel.isVisible { panel.orderFrontRegardless() }
        if hasSecondary {
            if !secondaryPanel.isVisible {
                secondaryPanel.alphaValue = animate ? 0 : 1
                secondaryPanel.orderFrontRegardless()
                if animate {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.24
                        secondaryPanel.animator().alphaValue = 1
                    }
                }
            }
        } else if secondaryPanel.isVisible { secondaryPanel.orderOut(nil) }
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
    func hide() { panel?.orderOut(nil); secondaryPanel?.orderOut(nil) }
    func toggle() { if panel.isVisible { presentation.suspended = true; hide() } else { show() } }
}

private struct SecondaryActivityView: View {
    @ObservedObject var dataManager: SportsDataManager
    @ObservedObject var media: NowPlayingManager
    @ObservedObject var clock: NativeClockManager
    @ObservedObject var calendar: CalendarManager
    @ObservedObject var presentation: IslandPresentation
    var body: some View {
        Button {
            if let activity = presentation.selection.secondary { presentation.promote(activity) }
        } label: {
            Group {
                switch presentation.selection.secondary {
                case .music:
                    HStack(spacing: 5) {
                        Image(systemName: media.currentTrack?.isPlaying == true ? "music.note" : "pause.fill")
                        if !presentation.selection.overflow.isEmpty { Text("+\(presentation.selection.overflow.count)").font(.caption2) }
                    }.foregroundColor(media.currentTrack?.dominantColor ?? .purple)
                case .calendar: CalendarCompactView(manager: calendar, minimal: true)
                case .clock: NativeClockCompactView(manager: clock, minimal: true)
                case .sports:
                    Text(dataManager.activeMatch?.sportType.icon ?? "🏟️")
                case nil: EmptyView()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .background(Capsule().fill(Color.black))
        .accessibilityLabel("Open \(presentation.selection.secondary?.rawValue ?? "activity") activity")
        .accessibilityValue(presentation.selection.secondary == .music ? (media.currentTrack?.title ?? "") : "")
    }
}
