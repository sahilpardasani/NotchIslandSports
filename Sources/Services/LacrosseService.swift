import Foundation
import os

// MARK: - Lacrosse Service

final class LacrosseService {

    private let apiClient = APIClient.shared
    private let logger = Logger(subsystem: "com.notchisland.sports", category: "LacrosseService")

    static let leagueEndpoints: [(slug: String, name: String)] = [
        ("pll", "Premier Lacrosse League"),
        ("college-lacrosse", "College Lacrosse"),
        ("mens-college-lacrosse", "NCAA Men's Lacrosse"),
        ("womens-college-lacrosse", "NCAA Women's Lacrosse")
    ]

    // MARK: - Fetch Games

    func fetchGames() async throws -> [LacrosseGame] {
        var allGames: [LacrosseGame] = []
        var seenIds = Set<String>()

        await withTaskGroup(of: [LacrosseGame].self) { group in
            for league in Self.leagueEndpoints {
                group.addTask { [self] in
                    do {
                        let urlString = "https://site.api.espn.com/apis/site/v2/sports/lacrosse/\(league.slug)/scoreboard"
                        guard let url = URL(string: urlString) else { return [] }
                        let json = try await apiClient.fetchRawJSON(from: url)
                        return parseScoreboard(json: json, leagueName: league.name, leagueSlug: league.slug)
                    } catch {
                        logger.warning("Lacrosse \(league.name) fetch failed: \(error.localizedDescription)")
                        return []
                    }
                }
            }

            for await games in group {
                for game in games {
                    if !seenIds.contains(game.id) {
                        seenIds.insert(game.id)
                        allGames.append(game)
                    }
                }
            }
        }

        logger.info("Parsed \(allGames.count) lacrosse games")
        return allGames
    }

    // MARK: - Fetch Game Detail

    func fetchGameDetail(eventId: String, league: String) async throws -> LacrosseGame {
        let urlString = "https://site.api.espn.com/apis/site/v2/sports/lacrosse/\(league)/summary?event=\(eventId)"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: url)
        return parseGameSummary(json: json, eventId: eventId, leagueSlug: league)
    }

    // MARK: - Parse Scoreboard

    private func parseScoreboard(json: [String: Any], leagueName: String, leagueSlug: String) -> [LacrosseGame] {
        guard let events = json["events"] as? [[String: Any]] else {
            return []
        }

        var games: [LacrosseGame] = []

        for event in events {
            guard let eventId = event["id"] as? String,
                  let competitions = event["competitions"] as? [[String: Any]],
                  let competition = competitions.first,
                  let competitors = competition["competitors"] as? [[String: Any]],
                  competitors.count >= 2 else {
                continue
            }

            let statusDict = event["status"] as? [String: Any]
            let statusType = statusDict?["type"] as? [String: Any]
            let statusState = statusType?["state"] as? String ?? ""
            let statusDescription = statusType?["description"] as? String ?? ""
            let clock = statusDict?["displayClock"] as? String ?? ""
            let period = statusDict?["period"] as? Int ?? 0

            let matchStatus = ESPNStatusParser.parseState(statusState)
            let eventDate = ESPNStatusParser.parseDate(event["date"] as? String)

            let home = competitors.first(where: { ($0["homeAway"] as? String) == "home" }) ?? competitors[0]
            let away = competitors.first(where: { ($0["homeAway"] as? String) == "away" }) ?? competitors[1]

            let homeInfo = parseTeamInfo(from: home)
            let awayInfo = parseTeamInfo(from: away)

            // Parse quarter scores from linescores
            let homeLinescores = home["linescores"] as? [[String: Any]] ?? []
            let awayLinescores = away["linescores"] as? [[String: Any]] ?? []
            var quarterScores: [LacrosseQuarterScore] = []
            for i in 0..<max(homeLinescores.count, awayLinescores.count) {
                let hs = i < homeLinescores.count ? (homeLinescores[i]["value"] as? Int ?? Int(homeLinescores[i]["value"] as? Double ?? 0)) : 0
                let as_ = i < awayLinescores.count ? (awayLinescores[i]["value"] as? Int ?? Int(awayLinescores[i]["value"] as? Double ?? 0)) : 0
                quarterScores.append(LacrosseQuarterScore(quarter: i + 1, homeScore: hs, awayScore: as_))
            }

            let game = LacrosseGame(
                id: eventId,
                status: matchStatus,
                homeTeam: homeInfo.name,
                awayTeam: awayInfo.name,
                homeTeamAbbrev: homeInfo.abbreviation,
                awayTeamAbbrev: awayInfo.abbreviation,
                homeScore: homeInfo.score,
                awayScore: awayInfo.score,
                statusText: statusDescription,
                homeLogoURL: homeInfo.logoURL,
                awayLogoURL: awayInfo.logoURL,
                eventDate: eventDate,
                quarterScores: quarterScores,
                currentQuarter: period,
                gameClock: clock,
                leagueName: leagueName,
                leagueSlug: leagueSlug
            )

            games.append(game)
        }

        return games
    }

    // MARK: - Parse Summary

    private func parseGameSummary(json: [String: Any], eventId: String, leagueSlug: String) -> LacrosseGame {
        let header = json["header"] as? [String: Any]
        let competitions = header?["competitions"] as? [[String: Any]]
        let competition = competitions?.first
        let competitors = competition?["competitors"] as? [[String: Any]] ?? []

        let statusDict = header?["status"] as? [String: Any] ?? (json["status"] as? [String: Any] ?? [:])
        let statusType = statusDict["type"] as? [String: Any]
        let statusState = statusType?["state"] as? String ?? ""
        let statusDescription = statusType?["description"] as? String ?? ""
        let clock = statusDict["displayClock"] as? String ?? ""
        let period = statusDict["period"] as? Int ?? 0
        let matchStatus = ESPNStatusParser.parseState(statusState)

        var homeTeam = "", awayTeam = ""
        var homeAbbrev = "", awayAbbrev = ""
        var homeScore = "", awayScore = ""
        var homeLogo: String?, awayLogo: String?

        if competitors.count >= 2 {
            let home = competitors.first(where: { ($0["homeAway"] as? String) == "home" }) ?? competitors[0]
            let away = competitors.first(where: { ($0["homeAway"] as? String) == "away" }) ?? competitors[1]
            let h = parseTeamInfo(from: home)
            let a = parseTeamInfo(from: away)
            homeTeam = h.name; awayTeam = a.name
            homeAbbrev = h.abbreviation; awayAbbrev = a.abbreviation
            homeScore = h.score; awayScore = a.score
            homeLogo = h.logoURL; awayLogo = a.logoURL
        }

        return LacrosseGame(
            id: eventId,
            status: matchStatus,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            homeTeamAbbrev: homeAbbrev,
            awayTeamAbbrev: awayAbbrev,
            homeScore: homeScore,
            awayScore: awayScore,
            statusText: statusDescription,
            homeLogoURL: homeLogo,
            awayLogoURL: awayLogo,
            currentQuarter: period,
            gameClock: clock,
            leagueName: Self.leagueEndpoints.first(where: { $0.slug == leagueSlug })?.name,
            leagueSlug: leagueSlug
        )
    }

    // MARK: - Helpers

    private struct TeamInfo {
        let name: String
        let abbreviation: String
        let score: String
        let logoURL: String?
    }

    private func parseTeamInfo(from dict: [String: Any]) -> TeamInfo {
        let teamDict = dict["team"] as? [String: Any]
        let name = teamDict?["displayName"] as? String
            ?? teamDict?["name"] as? String
            ?? "Unknown"
        let abbreviation = teamDict?["abbreviation"] as? String ?? String(name.prefix(3)).uppercased()
        let score = dict["score"] as? String ?? "\(dict["score"] as? Int ?? 0)"
        let logoURL = (teamDict?["logos"] as? [[String: Any]])?.first?["href"] as? String
            ?? teamDict?["logo"] as? String
        return TeamInfo(name: name, abbreviation: abbreviation, score: score, logoURL: logoURL)
    }
}
