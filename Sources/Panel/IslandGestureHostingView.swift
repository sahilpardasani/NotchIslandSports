import AppKit
import SwiftUI

/// Gesture input only. Pointer entry and exit never alter island presentation.
final class IslandGestureHostingView<Content: View>: NSHostingView<Content> {
    var onScrollPull: (() -> Void)?
    var onScrollPush: (() -> Void)?
    var onHorizontalSwipe: ((Bool, Bool) -> Void)?
    var swipeHeaderHeight: CGFloat = 92
    private var scrollSwipe: CGFloat = 0
    private var swiped = false
    private var scrollPull: CGFloat = 0

    override func scrollWheel(with event: NSEvent) {
        if event.phase == .began { scrollSwipe = 0; swiped = false }
        let point = convert(event.locationInWindow, from: nil)
        let fromTop = isFlipped ? point.y : bounds.height - point.y
        let onHandle = fromTop <= swipeHeaderHeight || fromTop >= bounds.height - 22
        if onHandle, event.momentumPhase.isEmpty,
           abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            scrollSwipe += event.scrollingDeltaX
            if !swiped, abs(scrollSwipe) > 24 {
                onHorizontalSwipe?(scrollSwipe < 0, NSEvent.pressedMouseButtons & 1 != 0)
                swiped = true
            }
            if event.phase.isEmpty || event.phase == .ended || event.phase == .cancelled {
                scrollSwipe = 0; swiped = false
            }
            return
        }
        // Vertical scroll on the header opens/closes the island; content lists keep scrolling.
        if onHandle, event.momentumPhase.isEmpty {
            if event.phase == .began { scrollPull = 0 }
            scrollPull += event.scrollingDeltaY
            if !swiped, abs(scrollPull) > 12 {
                if scrollPull < 0 { onScrollPull?() } else { onScrollPush?() }
                swiped = true
            }
            if event.phase.isEmpty || event.phase == .ended || event.phase == .cancelled {
                scrollPull = 0; swiped = false
            }
            return
        }
        super.scrollWheel(with: event)
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
