// NotchPanelController.swift
// NotchIslandSports
//
// Manages the NSPanel overlay that sits at the notch (or top-center
// for non-notch Macs). Handles positioning, sizing, and animating
// between collapsed and expanded states.

import AppKit
import SwiftUI
import Combine

@MainActor
final class NotchPanelController {
    
    // MARK: - Properties
    
    private var panel: NSPanel!
    private let hoverState: HoverState
    private let dataManager: SportsDataManager
    private var hostingView: HoverTrackingHostingView<NotchContentView>?
    private var cancellables = Set<AnyCancellable>()
    
    /// The notch center X position on screen
    private var notchCenterX: CGFloat = 0
    /// The top Y position of the notch (top of screen)
    private var notchTopY: CGFloat = 0
    /// Whether this machine has a notch
    private var hasNotch: Bool = false
    
    // MARK: - Layout Constants
    
    private enum Layout {
        static let collapsedHeight: CGFloat = 36
        static let expandedHeight: CGFloat = 360
        static let notchOffset: CGFloat = 0  // Vertical offset below notch (0 to sit flush under camera bezel)
        static let horizontalAdjustment: CGFloat = 0.0  // Mathematically centered around notch
        static let animationDuration: TimeInterval = 0.35
    }
    
    /// Dynamic width that automatically expands for notches to prevent truncation of live scores/overs
    private var panelWidth: CGFloat {
        if hasNotch {
            return 600
        } else {
            return 500
        }
    }
    
    private var expandedHeight: CGFloat {
        if dataManager.showMatchSelector {
            return 280
        }
        
        guard let match = dataManager.activeMatch else {
            return 240
        }
        
        switch match {
        case .cricket:
            return 360
        case .tennis:
            return 210
        case .soccer:
            return 220
        case .lacrosse:
            return 180
        case .f1:
            return 320
        case .nfl, .collegeFootball:
            return 240
        default:
            return 200
        }
    }
    
    // MARK: - Init
    
    init(dataManager: SportsDataManager) {
        self.dataManager = dataManager
        self.hoverState = HoverState()
    }
    
    // MARK: - Setup
    
    func setupPanel() {
        detectNotchPosition()
        createPanel()
        embedContent()
        observeHoverState()
        observeForceNotchLayout()
        observeScreenChanges()
        updatePanelFrame(expanded: false, animated: false)
        panel.orderFrontRegardless()
    }
    
    // MARK: - Notch Detection
    
    private func detectNotchPosition() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        
        var detectedWidth: CGFloat = 150
        
        if dataManager.forceNotchLayout {
            hasNotch = true
            notchCenterX = frame.midX
            notchTopY = frame.maxY
            dataManager.hasNotch = true
            dataManager.notchWidth = 150
            return
        }
        
        // macOS 12+: check safeAreaInsets
        if #available(macOS 12.0, *) {
            let topInset = screen.safeAreaInsets.top
            hasNotch = topInset > 0
        } else {
            hasNotch = false
        }
        
        if hasNotch {
            // On notch Macs, the notch is centered at the top of the screen.
            // Use auxiliaryTopLeftArea and auxiliaryTopRightArea to find notch bounds.
            if #available(macOS 12.0, *) {
                let leftArea = screen.auxiliaryTopLeftArea
                let rightArea = screen.auxiliaryTopRightArea
                
                if let left = leftArea, let right = rightArea, left.width > 0, right.width > 0 {
                    // The notch occupies the gap between left and right auxiliary areas.
                    let notchLeft = left.maxX
                    let notchRight = right.minX
                    notchCenterX = (notchLeft + notchRight) / 2.0
                    detectedWidth = notchRight - notchLeft
                } else {
                    // Fallback to physical screen center if auxiliary areas are unavailable
                    notchCenterX = frame.midX
                }
            } else {
                notchCenterX = frame.midX
            }
            notchTopY = frame.maxY
        } else {
            // No notch: floating capsule at top center
            notchCenterX = frame.midX
            notchTopY = frame.maxY
        }
        
        dataManager.hasNotch = hasNotch
        dataManager.notchWidth = detectedWidth
    }
    
    // MARK: - Panel Creation
    
    private func createPanel() {
        let contentRect = NSRect(
            x: 0, y: 0,
            width: panelWidth,
            height: Layout.collapsedHeight
        )
        
        panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Panel configuration for overlay behavior
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = false
        
        // Ensure the panel ignores mouse events outside content
        panel.ignoresMouseEvents = false
    }
    
    // MARK: - Content Embedding
    
    private func embedContent() {
        let contentView = NotchContentView(
            hoverState: hoverState,
            dataManager: dataManager
        )
        
        let hosting = HoverTrackingHostingView(rootView: contentView)
        hosting.hoverState = hoverState
        hosting.translatesAutoresizingMaskIntoConstraints = false
        
        // Make the hosting view's layer transparent
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        
        panel.contentView = hosting
        self.hostingView = hosting
    }
    
    // MARK: - Frame Animation
    
    func updatePanelFrame(expanded: Bool, animated: Bool = true) {
        let targetWidth = panelWidth
        let targetHeight = expanded ? expandedHeight : Layout.collapsedHeight
        
        // Calculate origin: centered horizontally on notch with a micro-adjustment, growing downward
        let originX = notchCenterX - targetWidth / 2.0 + Layout.horizontalAdjustment
        let originY: CGFloat
        
        if hasNotch {
            // Position just below the notch area
            originY = notchTopY - targetHeight - Layout.notchOffset
        } else {
            // Float at top center with a small gap
            originY = notchTopY - targetHeight - 4
        }
        
        let targetFrame = NSRect(
            x: originX,
            y: originY,
            width: targetWidth,
            height: targetHeight
        )
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Layout.animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel.setFrame(targetFrame, display: true)
        }
    }
    
    // MARK: - Observers
    
    private func observeHoverState() {
        hoverState.$isHovered
            .removeDuplicates()
            .sink { [weak self] isHovered in
                self?.updatePanelFrame(expanded: isHovered)
            }
            .store(in: &cancellables)
            
        dataManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    if let self = self {
                        self.updatePanelFrame(expanded: self.hoverState.isHovered)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func observeForceNotchLayout() {
        dataManager.$forceNotchLayout
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.repositionForScreen()
            }
            .store(in: &cancellables)
    }
    
    private func observeScreenChanges() {
        NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.repositionForScreen()
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Reposition
    
    func repositionForScreen() {
        detectNotchPosition()
        updatePanelFrame(expanded: hoverState.isHovered, animated: false)
    }
    
    // MARK: - Show / Hide
    
    func show() {
        panel.orderFrontRegardless()
    }
    
    func hide() {
        panel.orderOut(nil)
    }
    
    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }
}
