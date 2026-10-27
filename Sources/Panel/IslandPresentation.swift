import AppKit
import Combine
import IslandCore

@MainActor
final class IslandPresentation: ObservableObject {
    @Published private(set) var selection = ActivitySelection()
    @Published private(set) var merged: Bool
    @Published private(set) var compactCalendar = false
    @Published private(set) var compactMedia = false
    var collapsedActivity: IslandActivity {
        // Pending approvals remain visible without creating a split pill or
        // demoting sports. The selected sports page returns when they clear.
        if available.contains(.approval) { return .approval }
        if compactMedia && available.contains(.music) { return .music }
        return compactCalendar ? .calendar : (selection.primary ?? .sports)
    }
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
    @Published private var available = Set<IslandActivity>()
    private var clockStates: [String: Bool] = [:]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        merged = defaults.bool(forKey: "IslandActivitiesMerged")
    }
    private func companionVisible(_ activity: IslandActivity?) -> Bool {
        guard let activity else { return false }
        if expanded && selectedTab == activity { return false }
        return !(compactMedia && activity == .music)
    }
    var showsSecondary: Bool { !merged && secondaryFits && companionVisible(selection.secondary) }
    var showsTertiary: Bool { !merged && tertiaryFits && companionVisible(selection.tertiary) }


    func update(sports: Bool, music: Bool, clock: Bool, calendar: Bool = false, approval: Bool = false) {
        let clockStarted = !available.contains(.clock) && clock
        let musicEnded = available.contains(.music) && !music
        let musicStarted = !available.contains(.music) && music
        var nextAvailable = Set<IslandActivity>()
        if sports { nextAvailable.insert(.sports) }
        if music { nextAvailable.insert(.music) }
        if clock { nextAvailable.insert(.clock) }
        if approval { nextAvailable.insert(.approval) }
        if available != nextAvailable { available = nextAvailable }
        // Calendar availability never changes the live slots or their ordering.
        var next = selection
        next.update(available: available)
        if next != selection { selection = next }
        if musicStarted || clockStarted { setMerged(false) }
        if musicEnded && compactMedia { compactMedia = false }
        if musicEnded, expanded, selectedTab == .music { collapse() }
        if !expanded, selectedTab != collapsedActivity { selectedTab = collapsedActivity }
    }
    /// Native observation confirms the transition, whether Resume was pressed
    /// in Clock or in this app. Never optimistically split on a failed command.
    func observeClock(_ states: [ClockPlaybackState], fresh: Bool) {
        if states.isEmpty { clockStates.removeAll(); return }
        guard fresh else { return }
        let resumed = states.contains { !$0.paused && clockStates[$0.id] == true }
        clockStates = states.reduce(into: [:]) { $0[$1.id] = $1.paused }
        guard resumed else { return }
        setMerged(false)
        // Return from Clock controls to the score + timer split. Leave another
        // expanded page (especially an approval under review) undisturbed.
        if expanded && selectedTab == .clock { collapse() }
    }

    func open(_ activity: IslandActivity, pin: Bool = true) {
        if compactCalendar != (activity == .calendar) { compactCalendar = activity == .calendar }
        if activity != .music && compactMedia { compactMedia = false }
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
        let pages = IslandActivity.allCases.filter { activity in
            if !expanded && available.contains(.sports) {
                return activity == .sports || activity == .calendar || (activity == .music && available.contains(.music)) || (activity == .approval && available.contains(.approval))
            }
            return available.contains(activity) || activity == .calendar
        }
        let current: IslandActivity? = expanded ? selectedTab : collapsedActivity
        let index = current.flatMap { pages.firstIndex(of: $0) }
        let nextIndex = index.map { ($0 + (forward ? 1 : pages.count - 1)) % pages.count } ?? (forward ? 0 : pages.count - 1)
        let activity = pages[nextIndex]
        if expanded { open(activity) }
        else {
            if compactCalendar != (activity == .calendar) { compactCalendar = activity == .calendar }
            if compactMedia != (activity == .music) { compactMedia = activity == .music }
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
    /// A held swipe from the media browse page tucks media back into its pill.
    /// Otherwise retain the existing merge/restore toggle.
    func toggleSplitGesture() {
        if compactMedia && available.contains(.sports) {
            compactMedia = false; compactCalendar = false
            setMerged(false); collapse()
        } else { setMerged(!merged); collapse() }
    }
    func mergeActivities() { setMerged(true); collapse() }
    func pullDown() { open(collapsedActivity) }
    func handleDrag(horizontal: CGFloat, vertical: CGFloat, held: Bool = false) {
        if abs(horizontal) > abs(vertical), abs(horizontal) > 20 {
            if held { toggleSplitGesture() }
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
