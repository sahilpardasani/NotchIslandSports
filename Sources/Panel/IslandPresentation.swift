import AppKit
import Combine
import IslandCore

@MainActor
final class IslandPresentation: ObservableObject {
    @Published private(set) var selection = ActivitySelection()
    @Published private(set) var merged: Bool
    @Published private(set) var compactCalendar = false
    var collapsedActivity: IslandActivity { compactCalendar ? .calendar : (selection.primary ?? .sports) }
    @Published var secondaryOnLeft = true
    @Published var tertiaryOnLeft = false
    @Published var secondaryFits = true
    @Published var tertiaryFits = true
    @Published var selectedTab: IslandActivity = .sports
    @Published var cameraHeight: CGFloat = 0
    @Published var expandedPanelHeight: CGFloat = 520
    @Published var expandedPanelWidth: CGFloat = 600
    @Published var expandedContentMounted = false
    @Published private(set) var closingTab: IslandActivity?
    var contentActivity: IslandActivity { expanded ? selectedTab : (closingTab ?? selectedTab) }
    func finishResize() {
        expandedContentMounted = expanded
        if !expanded { closingTab = nil }
    }
    @Published var expanded = false
    @Published var pinned = false
    @Published var suspended = false
    @Published var lowPower = false
    @Published var reduceMotion = false
    private var available = Set<IslandActivity>()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        merged = defaults.bool(forKey: "IslandActivitiesMerged")
    }
    var showsSecondary: Bool { !merged && secondaryFits && selection.secondary != nil }
    var showsTertiary: Bool { !merged && tertiaryFits && selection.tertiary != nil }

    func update(sports: Bool, music: Bool, clock: Bool, calendar: Bool = false, approval: Bool = false) {
        let approvalStarted = !available.contains(.approval) && approval
        let musicEnded = available.contains(.music) && !music
        let musicStarted = !available.contains(.music) && music
        available = []
        if sports { available.insert(.sports) }
        if music { available.insert(.music) }
        if clock { available.insert(.clock) }
        if approval { available.insert(.approval) }
        // Calendar availability never changes the live slots or their ordering.
        var next = selection
        next.update(available: available)
        if next != selection { selection = next }
        if musicStarted || approvalStarted { setMerged(false) }
        if musicEnded, expanded, selectedTab == .music { collapse() }
        if !expanded, selectedTab != collapsedActivity { selectedTab = collapsedActivity }
    }
    func open(_ activity: IslandActivity, pin: Bool = true) {
        if compactCalendar != (activity == .calendar) { compactCalendar = activity == .calendar }
        if selectedTab != activity { selectedTab = activity }
        if pinned != pin { pinned = pin }
        closingTab = nil
        if !expanded { expanded = true }
    }
    func promote(_ activity: IslandActivity) {
        var next = selection
        next.update(available: available, preferred: activity)
        if next != selection { selection = next }
        open(activity)
    }
    /// Calendar stays reachable even when empty or disconnected, without displacing live slots.
    func cyclePrimary(forward: Bool = true) {
        let pages = IslandActivity.allCases.filter { available.contains($0) || $0 == .calendar }
        let current: IslandActivity? = expanded ? selectedTab : collapsedActivity
        let index = current.flatMap { pages.firstIndex(of: $0) }
        let nextIndex = index.map { ($0 + (forward ? 1 : pages.count - 1)) % pages.count } ?? (forward ? 0 : pages.count - 1)
        let activity = pages[nextIndex]
        if expanded { open(activity) }
        else {
            if compactCalendar != (activity == .calendar) { compactCalendar = activity == .calendar }
            var next = selection
            next.update(available: available, preferred: activity)
            if next != selection { selection = next }
            if selectedTab != activity { selectedTab = activity }
        }
    }
    func setMerged(_ value: Bool) {
        guard merged != value else { return }
        merged = value
        defaults.set(value, forKey: "IslandActivitiesMerged")
    }
    func mergeActivities() { setMerged(true); collapse() }
    func pullDown() { open(collapsedActivity) }
    func handleDrag(horizontal: CGFloat, vertical: CGFloat, held: Bool = false) {
        if abs(horizontal) > abs(vertical), abs(horizontal) > 20 {
            if held { setMerged(!merged); collapse() }
            else { cyclePrimary(forward: horizontal < 0) }
        } else if !held, abs(vertical) > abs(horizontal), abs(vertical) > 18 {
            if vertical > 0 { pullDown() } else { collapse() }
        }
    }
    func collapse() {
        if pinned { pinned = false }
        if expanded { closingTab = selectedTab; expanded = false }
        let activity = collapsedActivity
        if selectedTab != activity { selectedTab = activity }
    }
}
