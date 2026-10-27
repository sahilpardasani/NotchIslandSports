import AppKit
import Combine
import IslandCore

@MainActor
final class IslandPresentation: ObservableObject {
    @Published private(set) var selection = ActivitySelection()
    @Published var selectedTab: IslandActivity = .sports
    @Published var cameraHeight: CGFloat = 0
    @Published var expanded = false
    @Published var pinned = false
    @Published var suspended = false
    @Published var lowPower = false
    @Published var reduceMotion = false
    private var available = Set<IslandActivity>()

    func update(sports: Bool, music: Bool, clock: Bool, calendar: Bool = false) {
        available = []
        if sports { available.insert(.sports) }
        if music { available.insert(.music) }
        if clock { available.insert(.clock) }
        if calendar { available.insert(.calendar) }
        var next = selection
        next.update(available: available)
        if next != selection { selection = next }
        if !expanded, selectedTab != (next.primary ?? .sports) { selectedTab = next.primary ?? .sports }
    }
    func open(_ activity: IslandActivity, pin: Bool = true) {
        selectedTab = activity
        pinned = pin
        expanded = true
    }
    func promote(_ activity: IslandActivity) {
        var next = selection
        next.update(available: available, preferred: activity)
        selection = next
        open(activity)
    }
    func cyclePrimary() {
        let slots = [selection.primary, selection.secondary, selection.tertiary].compactMap { $0 } + selection.overflow
        guard slots.count > 1 else { return }
        var next = selection
        next.update(available: available, preferred: slots[1])
        if next != selection { selection = next }
        if let primary = next.primary, selectedTab != primary { selectedTab = primary }
    }
    func pullDown() { open(selection.primary ?? .sports) }
    func handleDrag(horizontal: CGFloat, vertical: CGFloat) {
        if abs(vertical) > abs(horizontal), abs(vertical) > 18 {
            if vertical > 0 { pullDown() } else { collapse() }
        } else if abs(horizontal) > 20 { cyclePrimary() }
    }
    func collapse() { pinned = false; expanded = false; selectedTab = selection.primary ?? .sports }
}
