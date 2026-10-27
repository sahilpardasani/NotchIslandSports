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
        check(PollPolicy.detail(live:true,completed:false,expanded:false,lowPower:false,failures:99) == 120, "Live retry never backs off beyond two minutes")
        check(PollPolicy.detail(live:true,completed:false,expanded:false,lowPower:true,failures:99) == 240, "Low-power retry remains bounded")
        check(PollPolicy.detail(live:false,completed:true,expanded:false,lowPower:false,failures:0) == 900, "Finished matches stay battery-efficient")
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
        print("Passed \(count) sports refresh checks; fixtures exercise real parsers and timer callbacks, not live score latency.")
    }
}
