import Foundation
import os

// MARK: - College Football Service

final class CollegeFootballService {

    private let apiClient = APIClient.shared
    private let logger = Logger(subsystem: "com.notchisland.sports", category: "CollegeFootballService")

    private let scoreboardURL = "https://site.api.espn.com/apis/site/v2/sports/football/college-football/scoreboard?limit=50"
    private let summaryBaseURL = "https://site.api.espn.com/apis/site/v2/sports/football/college-football/summary"

    // MARK: - Fetch Games

    func fetchGames() async throws -> [CollegeFootballGame] {
        guard let url = URL(string: scoreboardURL) else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: url)
        return parseScoreboard(json: json)
    }

    // MARK: - Fetch Game Detail

    func fetchGameDetail(eventId: String) async throws -> CollegeFootballGame {
        guard let url = URL(string: "\(summaryBaseURL)?event=\(eventId)") else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: url)
        return parseGameSummary(json: json, eventId: eventId)
    }

    // MARK: - Parse Scoreboard

    private func parseScoreboard(json: [String: Any]) -> [CollegeFootballGame] {
        guard let events = json["events"] as? [[String: Any]] else {
            return []
        }

        var games: [CollegeFootballGame] = []

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

            // Find home and away competitors
            let home = competitors.first(where: { ($0["homeAway"] as? String) == "home" }) ?? competitors[0]
            let away = competitors.first(where: { ($0["homeAway"] as? String) == "away" }) ?? competitors[1]

            let homeInfo = parseTeamInfo(from: home)
            let awayInfo = parseTeamInfo(from: away)

            // Parse quarter scores from linescores
            let homeLinescores = home["linescores"] as? [[String: Any]] ?? []
            let awayLinescores = away["linescores"] as? [[String: Any]] ?? []
            var quarterScores: [QuarterScore] = []
            for i in 0..<max(homeLinescores.count, awayLinescores.count) {
                let hs = i < homeLinescores.count ? (homeLinescores[i]["value"] as? Int ?? Int(homeLinescores[i]["value"] as? Double ?? 0)) : 0
                let as_ = i < awayLinescores.count ? (awayLinescores[i]["value"] as? Int ?? Int(awayLinescores[i]["value"] as? Double ?? 0)) : 0
                quarterScores.append(QuarterScore(quarter: i + 1, homeScore: hs, awayScore: as_))
            }

            // Parse conference
            let groups = (competition["groups"] as? [String: Any])?["name"] as? String

            let game = CollegeFootballGame(
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
                conference: groups
            )

            games.append(game)
        }

        logger.info("Parsed \(games.count) college football games")
        return games
    }

    // MARK: - Parse Summary

    private func parseGameSummary(json: [String: Any], eventId: String) -> CollegeFootballGame {
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

        // Parse situation
        var situation: GameSituation?
        if let sitDict = json["situation"] as? [String: Any] {
            let down = sitDict["down"] as? Int ?? 0
            let distance = sitDict["distance"] as? Int ?? 0
            let yardLine = sitDict["yardLine"] as? Int ?? 0
            let possession = sitDict["possession"] as? String ?? ""
            let isRedZone = sitDict["isRedZone"] as? Bool ?? false
            let yardsToEndzone = sitDict["yardsToEndzone"] as? Int ?? 0
            situation = GameSituation(
                down: down, distance: distance, yardLine: yardLine,
                possession: possession, isRedZone: isRedZone, yardsToEndzone: yardsToEndzone
            )
        }

        // Parse last play
        let lastPlay = (json["drives"] as? [String: Any])?["previous"] as? [[String: Any]]
        let lastPlayText = lastPlay?.last?["description"] as? String

        return CollegeFootballGame(
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
            situation: situation,
            lastPlay: lastPlayText
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
