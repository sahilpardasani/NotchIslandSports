// HoverTrackingView.swift
// NotchIslandSports
//
// NSView subclass with NSTrackingArea for hover detection,
// plus an ObservableObject to bridge hover state into SwiftUI.

import AppKit
import SwiftUI
import Combine

// MARK: - HoverState

/// Observable object that bridges NSView hover tracking into SwiftUI.
/// Shared between the NSHostingView subclass and SwiftUI content views.
@MainActor
final class HoverState: ObservableObject {
    @Published var isHovered: Bool = false
    
    /// Debounce timer to prevent flickering on rapid enter/exit
    private var exitWorkItem: DispatchWorkItem?
    
    func mouseEntered() {
        exitWorkItem?.cancel()
        exitWorkItem = nil
        if !isHovered {
            isHovered = true
        }
    }
    
    func mouseExited() {
        exitWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.isHovered = false
        }
        exitWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }
}

// MARK: - HoverTrackingHostingView

/// An NSHostingView subclass that installs a tracking area covering the
/// entire visible rect and forwards mouseEntered/mouseExited events
/// to a shared `HoverState` object.
final class HoverTrackingHostingView<Content: View>: NSHostingView<Content> {
    
    /// The shared hover state object that SwiftUI views observe.
    var hoverState: HoverState?
    
    /// The active tracking area; recreated whenever the view's bounds change.
    private var hoverTrackingArea: NSTrackingArea?
    
    // MARK: - Tracking Area Management
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Remove any previously installed tracking area
        if let existing = hoverTrackingArea {
            removeTrackingArea(existing)
        }
        
        // Install a new tracking area that covers the entire visible rect
        let area = NSTrackingArea(
            rect: .zero,
            options: [
                .mouseEnteredAndExited,
                .activeAlways,
                .inVisibleRect
            ],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }
    
    // MARK: - Mouse Events
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        DispatchQueue.main.async { [weak self] in
            self?.hoverState?.mouseEntered()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        DispatchQueue.main.async { [weak self] in
            self?.hoverState?.mouseExited()
        }
    }
    
    /// Accept first mouse so the panel responds even when the app isn't focused.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    // MARK: - Hit Testing
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Allow clicks to pass through to SwiftUI content
        return super.hitTest(point)
    }
}
