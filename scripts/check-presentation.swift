import Combine
import IslandCore

@main struct PresentationChecks {
    @MainActor static func main() {
        let model = IslandPresentation()
        var publications = 0
        let subscription = model.objectWillChange.sink { publications += 1 }
        model.update(sports: true, music: true, clock: true)
        let initial = publications
        for _ in 0..<100 { model.update(sports: true, music: true, clock: true) }
        precondition(publications == initial, "Unchanged availability must not schedule another layout update")
        model.cyclePrimary()
        precondition(model.selection.primary == .music, "Swipe preserves access to music")
        model.open(.clock)
        model.update(sports: true, music: true, clock: false)
        precondition(model.selectedTab == .clock && model.expanded, "Keep unavailable Clock guidance open")
        model.collapse()
        model.update(sports: false, music: false, clock: false)
        precondition(model.selection.primary == nil && model.selectedTab == .sports, "Quiet empty state")
        let empty = publications
        for _ in 0..<100 { model.update(sports: false, music: false, clock: false) }
        precondition(publications == empty, "Empty state must not loop")
        withExtendedLifetime(subscription) {}
        print("Passed 5 presentation checks, including no repeated layout publications.")
    }
}
