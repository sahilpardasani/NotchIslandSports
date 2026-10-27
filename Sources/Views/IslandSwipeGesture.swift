import SwiftUI
import IslandCore

/// Exclusive recognition prevents a held swipe from also changing the visible page.
/// Recognizers run only during interaction; there is no background gesture polling.
struct IslandSwipeGesture: ViewModifier {
    @ObservedObject var presentation: IslandPresentation
    var headerOnly = false
    var pullDownActivity: IslandActivity?

    func body(content: Content) -> some View {
        let held = LongPressGesture(minimumDuration: 0.35, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 20))
        let swipe = DragGesture(minimumDistance: 20)
        content.simultaneousGesture(held.exclusively(before: swipe).onEnded { result in
            switch result {
            case .first(.second(true, let drag?)): handle(drag, held: true)
            case .second(let drag): handle(drag, held: false)
            default: break
            }
        })
        .accessibilityAction(named: Text("Merge live activities")) { presentation.mergeActivities() }
        .accessibilityAction(named: Text("Show separate live activities")) { presentation.setMerged(false) }
        .accessibilityAction(named: Text("Next page")) { presentation.cyclePrimary() }
        .accessibilityAction(named: Text("Previous page")) { presentation.cyclePrimary(forward: false) }
    }

    private func handle(_ drag: DragGesture.Value, held: Bool) {
        // Preserve sliders and vertical scrolling inside the expanded content.
        guard !headerOnly || !presentation.expanded || drag.startLocation.y < presentation.cameraHeight + 60 else { return }
        if !held, drag.translation.height > 18, abs(drag.translation.height) > abs(drag.translation.width),
           let activity = pullDownActivity {
            presentation.open(activity)
            return
        }
        presentation.handleDrag(horizontal: drag.translation.width, vertical: drag.translation.height, held: held)
    }
}
