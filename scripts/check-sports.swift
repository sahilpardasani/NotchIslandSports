import AppKit
import Foundation
import IslandCore

@main struct SportsChecks {
    @MainActor static func main() async throws {
        var count = 0
        func check(_ condition: Bool, _ label: String) { precondition(condition, label); count += 1 }
        let live: [String: Any] = ["type": ["state": "in", "description": "Live"], "period": 2]
        let final: [String: Any] = ["type": ["state": "post"]]
        let competition: [String: Any] = ["status": live]
        let status = ESPNStatusParser.summaryStatus(competition: competition, event: ["status": final], root: [:])
        check((status["period"] as? Int) == 2, "Competition live status takes precedence over event status")
        check(ESPNStatusParser.parseState((status["type"] as? [String: Any])?["state"] as? String ?? "") == .live, "Selected live match retains live refresh cadence")
        check(!ESPNStatusParser.summaryStatus(competition: ["status": [:]], event: ["status": live], root: [:]).isEmpty, "Empty competition status falls through")
        check(!ESPNStatusParser.summaryStatus(competition: nil, event: nil, root: ["status": live]).isEmpty, "Legacy root status accepted")
        check(ESPNStatusParser.summaryStatus(competition: nil, event: nil, root: [:]).isEmpty, "Missing status is not invented")
        let summary = URL(string: "https://example.test/basketball/nba/summary?event=1")!
        let board = URL(string: "https://example.test/tennis/wta/scoreboard?dates=20261027")!
        check(SportsRequestPolicy.request(summary).cachePolicy == .reloadIgnoringLocalCacheData, "Selected summaries bypass stale local cache")
        check(SportsRequestPolicy.request(board, fresh: true).value(forHTTPHeaderField: "Cache-Control") == "no-cache", "Tennis selected scoreboard requests server revalidation")
        check(!SportsRequestPolicy.isSelectedDetail(board) && SportsRequestPolicy.isSelectedDetail(summary), "Selected score uses reserved network lane")
        check(SportsRequestPolicy.request(board).cachePolicy == .useProtocolCachePolicy, "Unselected catalog keeps cache efficiency")
        check(PollPolicy.detail(live:true,completed:false,expanded:false,lowPower:false,failures:99) == 60, "Live retry never backs off beyond one minute")
        check(PollPolicy.detail(live:true,completed:false,expanded:false,lowPower:true,failures:99) == 60, "Low-power retry remains bounded")
        check(PollPolicy.detail(live:false,completed:true,expanded:false,lowPower:false,failures:0) == 900, "Finished matches stay battery-efficient")
        for expanded in [false, true] {
            for lowPower in [false, true] {
                check(PollPolicy.detail(live:true, completed:false, expanded:expanded, lowPower:lowPower, failures:0) == 10,
                    "Selected live score stays fast across presentation and power modes")
            }
        }
        func tennis(_ id: String, home: Int, state: String = "in") -> [String: Any] {
            ["id": id, "date": "2026-10-27T12:00Z", "status": ["type": ["state": state, "description": "Live"]],
             "competitors": [
                ["athlete": ["displayName": "Player One"], "score": home, "point": "40", "possession": true, "linescores": [["value": 6.0], ["value": 3.0]]],
                ["athlete": ["displayName": "Player Two"], "score": "0", "point": "30", "linescores": [["value": 4.0], ["value": 2.0]]]]]
        }
        var reads = 0
        let service = TennisService { url, fresh in
            reads += 1
            check(url.path.contains("/wta/scoreboard") && url.query == "dates=20261027" && fresh, "Tennis refresh loads one selected tour/day with fresh cache policy")
            let completed = (0..<25).map { tennis(String($0), home: 1, state: "post") }
            return ["events": [["name": "Fixture tournament", "groupings": [["competitions": completed + [tennis("selected", home: reads)]]]]]]
        }
        let day = ISO8601DateFormatter().date(from: "2026-10-27T12:00:00Z")!
        let first = try await service.fetchMatchDetail(eventId: "selected", isWTA: true, eventDate: day)
        let second = try await service.fetchMatchDetail(eventId: "selected", isWTA: true, eventDate: day)
        check(first.homeScore == "1" && second.homeScore == "2" && second.isWTA, "Consecutive selected tennis refreshes publish new scores")
        check(second.status == .live && second.sets.count == 2 && second.sets[0].player1Games == 6, "Live status and set scores survive selected refresh")
        check(second.currentGameScore?.player1Points == "40" && second.servingPlayer == 1, "Tennis point score and server parsed")
        _ = try await service.fetchMatchDetail(eventId: "24", isWTA: true, eventDate: day)
        check(reads == 3, "Selected completed match is not lost to the catalog's twenty-result cap")
        do { _ = try await service.fetchMatchDetail(eventId: "missing", isWTA: true, eventDate: day); preconditionFailure("Missing identity must fail") }
        catch { check(true, "Missing selected identity cannot become a placeholder or another match") }

        // Exercise the real manager's timer callback, async publication and re-arm,
        // using an injected detail provider for every supported sport.
        var detailReads = 0
        let manager = SportsDataManager { match in detailReads += 1; return match }
        for match in MockDataProvider.getMockMatches() {
            manager.beginDetailFixture(match)
            check(manager.detailFixtureDeadline != nil, "Selected sport has an automatic refresh deadline")
            let before = detailReads
            manager.fireDetailFixture()
            for _ in 0..<100 where detailReads == before || manager.lastDetailUpdate == nil {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            // Await the existing in-flight task, not a separate provider request.
            await Task.yield()
            check(detailReads == before + 1 && manager.lastDetailUpdate != nil, "Timer updates selected \(match.sportType.rawValue)")
            let deadline = manager.detailFixtureDeadline
            check(deadline != nil, "Selected detail re-arms automatically")
            manager.setPresentation(expanded: manager.isExpanded, lowPower: manager.lowPowerMode)
            check(manager.detailFixtureDeadline == deadline, "Unchanged presentation cannot postpone score refresh")
            manager.stopPolling()
            check(manager.detailFixtureDeadline == nil, "Sleep stops automatic score work")
        }
        let suite = "SportsSelectionChecks." + UUID().uuidString
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        var loadedSports: [SportType] = []
        let switching = SportsDataManager(selectionDefaults: preferences) { match in
            loadedSports.append(match.sportType); return match
        }
        switching.allMatches = MockDataProvider.getMockMatches()
        switching.beginDetailFixture(switching.allMatches.last!)
        for sport in SportType.allCases {
            switching.selectedSportFilter = sport
            check(switching.activeMatch?.sportType == sport, "Sport filter immediately changes displayed \(sport.rawValue)")
            for _ in 0..<100 where loadedSports.last != sport { try await Task.sleep(nanoseconds: 1_000_000) }
            check(loadedSports.last == sport, "Sport selection immediately uses its own detail provider")
        }
        switching.stopPolling()
        switching.allMatches = switching.allMatches.filter { $0.sportType == .tennis }
        switching.selectedSportFilter = .cricket
        check(switching.activeMatch == nil, "Empty selected sport cannot leave another sport's score displayed")
        switching.selectedSportFilter = .tennis
        check(switching.activeMatch?.sportType == .tennis, "Available sport recovers immediately after empty selection")
        switching.selectedSportFilter = nil
        check(switching.activeMatch?.sportType == .tennis, "All Sports preserves the explicit selected match")

        let samples = MockDataProvider.getMockMatches()
        let cricket = samples.first { $0.sportType == .cricket }!
        let tennisMatch = samples.first { $0.sportType == .tennis }!
        var oldResponse: CheckedContinuation<AnyMatch, Never>?
        let racing = SportsDataManager(selectionDefaults: preferences) { match in
            if match.identity == cricket.identity {
                return await withCheckedContinuation { oldResponse = $0 }
            }
            return match
        }
        racing.allMatches = [cricket, tennisMatch]
        racing.beginDetailFixture(cricket)
        let oldTask = Task { await racing.fetchActiveMatchDetail() }
        for _ in 0..<100 where oldResponse == nil { try await Task.sleep(nanoseconds: 1_000_000) }
        precondition(oldResponse != nil)
        racing.selectedSportFilter = .tennis
        for _ in 0..<100 where racing.lastDetailUpdate == nil { try await Task.sleep(nanoseconds: 1_000_000) }
        check(racing.activeMatch?.identity == tennisMatch.identity && racing.lastDetailUpdate != nil,
            "New sport refresh does not wait for old in-flight provider")
        oldResponse?.resume(returning: cricket)
        await oldTask.value
        check(racing.activeMatch?.identity == tennisMatch.identity, "Late cricket response cannot overwrite selected tennis")
        racing.stopPolling()
        print("Passed \(count) sports refresh checks; fixtures exercise real parsers and timer callbacks, not live score latency.")
    }
}
