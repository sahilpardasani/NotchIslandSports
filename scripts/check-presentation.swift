import Combine
import Foundation
import IslandCore

@main struct PresentationChecks {
    @MainActor static func main() {
        let name = "NotchPresentationChecks." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let model = IslandPresentation(defaults: defaults)
        var count = 0
        func check(_ condition: Bool, _ label: String) { precondition(condition, label); count += 1 }
        var publications = 0
        let subscription = model.objectWillChange.sink { publications += 1 }
        model.update(sports: true, music: true, clock: true, calendar: true)
        let initial = publications
        for _ in 0..<100 { model.update(sports: true, music: true, clock: true, calendar: true) }
        check(publications == initial, "Unchanged availability must not schedule another layout update")
        check(model.selection.tertiary == .clock && model.showsSecondary && model.showsTertiary, "Three live activities")
        model.handleDrag(horizontal: -40, vertical: 0)
        check(model.selection.primary == .music && !model.expanded, "Swipe advances compact live content")
        model.handleDrag(horizontal: 40, vertical: 0)
        check(model.selection.primary == .sports, "Opposite swipe returns")
        let slots = model.selection
        model.handleDrag(horizontal: 40, vertical: 0)
        check(!model.expanded && model.collapsedActivity == .calendar && model.selection == slots, "Calendar swipe stays compact, preserves all slots")
        let calendarOpen = publications
        for _ in 0..<100 { model.update(sports: true, music: true, clock: true, calendar: false) }
        check(publications == calendarOpen && model.selectedTab == .calendar, "Event changes never steal page or re-layout")
        model.pullDown()
        check(model.expanded && model.selectedTab == .calendar, "Pull down explicitly opens agenda")
        model.collapse()
        check(model.selection == slots && model.collapsedActivity == .calendar, "Collapse returns to compact Calendar")
        model.cyclePrimary()
        check(model.collapsedActivity == .sports, "Swipe leaves Calendar for sports")
        model.handleDrag(horizontal: -45, vertical: 2, held: true)
        check(model.merged && !model.expanded && !model.showsSecondary && !model.showsTertiary, "Held swipe merges")
        check(model.selection == slots, "Held gesture does not also cycle the primary")
        model.update(sports: true, music: true, clock: true, calendar: true)
        check(model.merged && !model.showsSecondary, "Provider refresh cannot undo merge")
        check(IslandPresentation(defaults: defaults).merged, "Merge preference survives restart")
        model.handleDrag(horizontal: -40, vertical: 0)
        check(model.selection.primary == .music && model.merged, "Merged live activities still accessible")
        model.handleDrag(horizontal: 45, vertical: 0, held: true)
        check(model.showsSecondary && model.showsTertiary, "Menu restores all live slots")
        check(!IslandPresentation(defaults: defaults).merged, "Split preference persists")
        model.open(.clock)
        model.update(sports: true, music: true, clock: false)
        check(model.selectedTab == .clock && model.expanded, "Keep unavailable Clock guidance open")
        model.collapse()
        model.update(sports: false, music: false, clock: false, calendar: true)
        check(model.selection.primary == nil && !model.showsSecondary && !model.showsTertiary, "Calendar alone never creates live activity")
        let empty = publications
        for _ in 0..<100 { model.update(sports: false, music: false, clock: false, calendar: true) }
        check(publications == empty, "Empty state must not loop")
        model.cyclePrimary()
        check(!model.expanded && model.collapsedActivity == .calendar, "Compact Calendar reachable with no live activities")
        model.collapse()
        model.update(sports: true, music: false, clock: true, calendar: true)
        check(model.selection.tertiary == nil, "Calendar doesn't make a third satellite")
        model.handleDrag(horizontal: 0, vertical: 40)
        check(model.expanded && model.pinned, "Pull-down pins expansion")
        model.handleDrag(horizontal: 0, vertical: -40)
        check(!model.expanded && !model.pinned, "Push-up collapses")
        model.handleDrag(horizontal: 2, vertical: 40, held: true)
        check(!model.merged && !model.expanded, "Held vertical drag doesn't accidentally merge")
        model.handleDrag(horizontal: -10, vertical: 0, held: true)
        check(!model.merged, "Small drag doesn't merge")
        model.update(sports: true, music: false, clock: false)
        model.update(sports: true, music: true, clock: false)
        check(model.selection.primary == .sports && model.selection.secondary == .music && model.showsSecondary,
              "A newly observed browser video splits from the existing sports activity")
        model.open(.music)
        check(model.expanded && model.selectedTab == .music, "Media satellite opens its control panel")
        model.expandedContentMounted = true
        model.open(.clock)
        model.collapse()
        check(model.contentActivity == .clock && model.expandedContentMounted, "Closing retains the visible page instead of flashing the primary")
        model.open(.music)
        check(model.contentActivity == .music && model.expanded, "Reversing a close uses the new page")
        model.finishResize()
        check(model.expandedContentMounted, "A stale close must not unmount a reopened panel")
        model.collapse(); model.finishResize()
        check(!model.expandedContentMounted && model.closingTab == nil, "Settled collapse releases expanded content")
        model.open(.music)
        model.update(sports: true, music: false, clock: false)
        check(!model.expanded && !model.showsSecondary && model.selection.primary == .sports, "Session ending merges and closes the media panel")
        model.setMerged(true)
        model.update(sports: true, music: true, clock: false)
        check(model.showsSecondary && model.selection.secondary == .music, "A new playback session splits again after the previous session was merged")
        model.update(sports: true, music: true, clock: true, approval: true)
        check(model.selection.primary == .sports && model.selection.secondary == .approval, "Urgent request keeps sports primary and exposes approval satellite")
        check(model.selection.overflow == [.clock], "Fourth activity remains swipe reachable")
        model.open(.approval)
        model.update(sports: true, music: true, clock: false, approval: true)
        check(model.expanded && model.selectedTab == .approval, "Score/timer changes never steal approval under review")
        model.update(sports: true, music: true, clock: true, approval: false)
        check(model.selection.secondary == .music && model.selection.tertiary == .clock, "Resolving approvals restores ordinary slots")
        withExtendedLifetime(subscription) {}
        print("Passed \(count) presentation checks, including persistent merge, Calendar browsing and no repeated layout publications.")
    }
}
