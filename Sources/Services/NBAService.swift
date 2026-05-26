import Foundation
import os

// MARK: - NBA Service

final class NBAService {

    private let apiClient = APIClient.shared
    private let logger = Logger(subsystem: "com.notchisland.sports", category: "NBAService")

    private let scoreboardURL = "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard"
    private let summaryBaseURL = "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/summary"

    // MARK: - Fetch All Games

    func fetchGames() async throws -> [NBAGame] {
        guard let url = URL(string: scoreboardURL) else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: url)
        return parseScoreboard(json: json)
    }

    // MARK: - Fetch Game Detail

    func fetchGameDetail(eventId: String) async throws -> NBAGame {
        guard let url = URL(string: "\(summaryBaseURL)?event=\(eventId)") else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: url)
        return parseGameSummary(json: json, eventId: eventId)
    }

    // MARK: - Parse Scoreboard

    private func parseScoreboard(json: [String: Any]) -> [NBAGame] {
        guard let events = json["events"] as? [[String: Any]] else {
            logger.warning("No events found in NBA scoreboard")
            return []
        }

        var games: [NBAGame] = []

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
            let statusDescription = statusType?["shortDetail"] as? String
                ?? statusType?["description"] as? String ?? ""
            let matchStatus = ESPNStatusParser.parseState(statusState)
            let eventDate = ESPNStatusParser.parseDate(event["date"] as? String)

            let homeCompetitor = competitors.first { ($0["homeAway"] as? String) == "home" } ?? competitors[0]
            let awayCompetitor = competitors.first { ($0["homeAway"] as? String) == "away" } ?? competitors[1]

            let homeInfo = parseTeamInfo(from: homeCompetitor)
            let awayInfo = parseTeamInfo(from: awayCompetitor)

            // Parse quarter scores
            let homeLinescores = homeCompetitor["linescores"] as? [[String: Any]] ?? []
            let awayLinescores = awayCompetitor["linescores"] as? [[String: Any]] ?? []
            var quarterScores: [QuarterScore] = []
            for i in 0..<max(homeLinescores.count, awayLinescores.count) {
                let hs = i < homeLinescores.count ? (homeLinescores[i]["value"] as? Int ?? Int(homeLinescores[i]["value"] as? Double ?? 0)) : 0
                let as_ = i < awayLinescores.count ? (awayLinescores[i]["value"] as? Int ?? Int(awayLinescores[i]["value"] as? Double ?? 0)) : 0
                quarterScores.append(QuarterScore(quarter: i + 1, homeScore: hs, awayScore: as_))
            }

            let period = statusDict?["period"] as? Int ?? 1
            let clock = statusDict?["displayClock"] as? String ?? ""

            let situation = competition["situation"] as? [String: Any] ?? [:]
            let lastPlayText = (situation["lastPlay"] as? [String: Any])?["text"] as? String

            let game = NBAGame(
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
                homeLeader: nil,
                awayLeader: nil,
                lastPlay: lastPlayText
            )

            games.append(game)
        }

        return games
    }

    // MARK: - Parse Game Summary

    private func parseGameSummary(json: [String: Any], eventId: String) -> NBAGame {
        let header = json["header"] as? [String: Any]
        let competitions = header?["competitions"] as? [[String: Any]]
        let competition = competitions?.first
        let competitors = competition?["competitors"] as? [[String: Any]] ?? []

        let statusDict = header?["status"] as? [String: Any] ?? (json["status"] as? [String: Any] ?? [:])
        let statusType = statusDict["type"] as? [String: Any]
        let statusState = statusType?["state"] as? String ?? ""
        let statusDescription = statusType?["shortDetail"] as? String
            ?? statusType?["description"] as? String ?? ""
        let matchStatus = ESPNStatusParser.parseState(statusState)
        let eventDate = ESPNStatusParser.parseDate(header?["date"] as? String)

        var homeTeam = "", awayTeam = ""
        var homeAbbrev = "", awayAbbrev = ""
        var homeScore = "", awayScore = ""
        var homeLogo: String?, awayLogo: String?
        var quarterScores: [QuarterScore] = []

        if competitors.count >= 2 {
            let home = competitors.first(where: { ($0["homeAway"] as? String) == "home" }) ?? competitors[0]
            let away = competitors.first(where: { ($0["homeAway"] as? String) == "away" }) ?? competitors[1]
            let h = parseTeamInfo(from: home)
            let a = parseTeamInfo(from: away)
            homeTeam = h.name; awayTeam = a.name
            homeAbbrev = h.abbreviation; awayAbbrev = a.abbreviation
            homeScore = h.score; awayScore = a.score
            homeLogo = h.logoURL; awayLogo = a.logoURL

            let homeLinescores = home["linescores"] as? [[String: Any]] ?? []
            let awayLinescores = away["linescores"] as? [[String: Any]] ?? []
            for i in 0..<max(homeLinescores.count, awayLinescores.count) {
                let hs = i < homeLinescores.count ? (homeLinescores[i]["value"] as? Int ?? Int(homeLinescores[i]["value"] as? Double ?? 0)) : 0
                let as_ = i < awayLinescores.count ? (awayLinescores[i]["value"] as? Int ?? Int(awayLinescores[i]["value"] as? Double ?? 0)) : 0
                quarterScores.append(QuarterScore(quarter: i + 1, homeScore: hs, awayScore: as_))
            }
        }

        let period = statusDict["period"] as? Int ?? 1
        let clock = statusDict["displayClock"] as? String ?? ""

        // Leaders (top scorers)
        var homeLeader: String?
        var awayLeader: String?
        if let leaders = json["leaders"] as? [[String: Any]] {
            for leader in leaders {
                if let type = leader["name"] as? String, type == "points",
                   let athletes = leader["leaders"] as? [[String: Any]],
                   let topAthleteDict = athletes.first,
                   let athlete = topAthleteDict["athlete"] as? [String: Any],
                   let name = athlete["displayName"] as? String,
                   let value = topAthleteDict["value"] as? Int ?? Int(topAthleteDict["value"] as? Double ?? 0) ?? Int(topAthleteDict["displayValue"] as? String ?? "") {
                    let teamId = topAthleteDict["teamId"] as? String ?? ""
                    let leaderStr = "\(name) (\(value) pts)"
                    
                    // Assign to home or away
                    if teamId == (competitors.first(where: { ($0["homeAway"] as? String) == "home" })?["id"] as? String ?? "home") {
                        homeLeader = leaderStr
                    } else {
                        awayLeader = leaderStr
                    }
                }
            }
        }

        let situation = json["situation"] as? [String: Any] ?? (competition?["situation"] as? [String: Any] ?? [:])
        let lastPlayText = (situation["lastPlay"] as? [String: Any])?["text"] as? String

        return NBAGame(
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
            eventDate: eventDate,
            quarterScores: quarterScores,
            currentQuarter: period,
            gameClock: clock,
            homeLeader: homeLeader,
            awayLeader: awayLeader,
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
