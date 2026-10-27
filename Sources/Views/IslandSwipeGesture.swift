import SwiftUI
import IslandCore

/// One press/drag recognizer, so long-press and swipe cannot race each other.
/// Expanded gestures live only on the header/handle, away from controls and lists.
struct IslandSwipeGesture: ViewModifier {
    @ObservedObject var presentation: IslandPresentation
    var headerOnly = false
    var pullDownActivity: IslandActivity?
    @State private var started: Date?
    @State private var committed = false
    @GestureState private var interacting = false

    func body(content: Content) -> some View {
        content.overlay {
            if headerOnly && presentation.expanded {
                VStack(spacing: 0) {
                    surface(bottomHandle: false).frame(height: presentation.cameraHeight + 8)
                    Spacer(minLength: 0).allowsHitTesting(false)
                    surface(bottomHandle: true).frame(height: 22)
                }
            } else { surface(bottomHandle: false) }
        }
        .onChange(of: interacting) { active in
            if !active { started = nil; committed = false }
        }
        .accessibilityAction(named: Text("Merge live activities")) { presentation.mergeActivities() }
        .accessibilityAction(named: Text("Show separate live activities")) { presentation.setMerged(false) }
        .accessibilityAction(named: Text("Next page")) { presentation.cyclePrimary() }
        .accessibilityAction(named: Text("Previous page")) { presentation.cyclePrimary(forward: false) }
    }

    private func surface(bottomHandle: Bool) -> some View {
        Color.clear.contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .updating($interacting) { _, active, _ in active = true }
                .onChanged { value in
                    if started == nil { started = value.time }
                    guard !committed, let started,
                          let intent = IslandDragIntent.resolve(horizontal: value.translation.width,
                            vertical: value.translation.height, heldFor: value.time.timeIntervalSince(started)) else { return }
                    committed = true
                    switch intent {
                    case .toggleMerge: presentation.setMerged(!presentation.merged); presentation.collapse()
                    case .next: presentation.cyclePrimary()
                    case .previous: presentation.cyclePrimary(forward: false)
                    case .open:
                        if let activity = pullDownActivity { presentation.open(activity) }
                        else { presentation.pullDown() }
                    case .close: presentation.collapse()
                    }
                }
                .onEnded { value in
                    if !committed, abs(value.translation.width) < 6, abs(value.translation.height) < 6 {
                        if bottomHandle { presentation.collapse() }
                        else if let activity = pullDownActivity { presentation.open(activity) }
                        else if !presentation.expanded { presentation.pullDown() }
                    }
                    started = nil; committed = false
                })
            .accessibilityHidden(true)
    }
}
