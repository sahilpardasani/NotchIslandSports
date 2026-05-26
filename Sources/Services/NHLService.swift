import Foundation
import os

// MARK: - NHL Service

final class NHLService {

    private let apiClient = APIClient.shared
    private let logger = Logger(subsystem: "com.notchisland.sports", category: "NHLService")

    private let scoreboardURL = "https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/scoreboard"
    private let summaryBaseURL = "https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/summary"

    // MARK: - Fetch All Games

    func fetchGames() async throws -> [NHLGame] {
        guard let url = URL(string: scoreboardURL) else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: url)
        return parseScoreboard(json: json)
    }

    // MARK: - Fetch Game Detail

    func fetchGameDetail(eventId: String) async throws -> NHLGame {
        guard let url = URL(string: "\(summaryBaseURL)?event=\(eventId)") else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: url)
        return parseGameSummary(json: json, eventId: eventId)
    }

    // MARK: - Parse Scoreboard

    private func parseScoreboard(json: [String: Any]) -> [NHLGame] {
        guard let events = json["events"] as? [[String: Any]] else {
            logger.warning("No events found in NHL scoreboard")
            return []
        }

        var games: [NHLGame] = []

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

            // Parse period scores
            let homeLinescores = homeCompetitor["linescores"] as? [[String: Any]] ?? []
            let awayLinescores = awayCompetitor["linescores"] as? [[String: Any]] ?? []
            var periodScores: [PeriodScore] = []
            for i in 0..<max(homeLinescores.count, awayLinescores.count) {
                let hs = i < homeLinescores.count ? (homeLinescores[i]["value"] as? Int ?? Int(homeLinescores[i]["value"] as? Double ?? 0)) : 0
                let as_ = i < awayLinescores.count ? (awayLinescores[i]["value"] as? Int ?? Int(awayLinescores[i]["value"] as? Double ?? 0)) : 0
                periodScores.append(PeriodScore(period: i + 1, homeScore: hs, awayScore: as_))
            }

            let period = statusDict?["period"] as? Int ?? 1
            let clock = statusDict?["displayClock"] as? String ?? ""

            // Shots on Goal
            let homeSOG = parseSOG(from: homeCompetitor)
            let awaySOG = parseSOG(from: awayCompetitor)

            let situation = competition["situation"] as? [String: Any] ?? [:]
            var powerPlayStr: String? = nil
            if let onPowerPlay = situation["onPowerPlay"] as? Bool, onPowerPlay {
                powerPlayStr = "PP"
            }

            let lastPlayText = (situation["lastPlay"] as? [String: Any])?["text"] as? String

            let game = NHLGame(
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
                periodScores: periodScores,
                currentPeriod: period,
                gameClock: clock,
                homeShotsOnGoal: homeSOG,
                awayShotsOnGoal: awaySOG,
                powerPlay: powerPlayStr,
                lastPlay: lastPlayText
            )

            games.append(game)
        }

        return games
    }

    // MARK: - Parse Game Summary

    private func parseGameSummary(json: [String: Any], eventId: String) -> NHLGame {
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
        var periodScores: [PeriodScore] = []
        var homeSOG = 0, awaySOG = 0

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
                quarterScoresFallback(period: i + 1, home: hs, away: as_) // populates local array
            }
            
            periodScores = parseLinescores(home: homeLinescores, away: awayLinescores)

            homeSOG = parseSOG(from: home)
            awaySOG = parseSOG(from: away)
        }

        let period = statusDict["period"] as? Int ?? 1
        let clock = statusDict["displayClock"] as? String ?? ""

        let situation = json["situation"] as? [String: Any] ?? (competition?["situation"] as? [String: Any] ?? [:])
        var powerPlayStr: String? = nil
        if let onPowerPlay = situation["onPowerPlay"] as? Bool, onPowerPlay {
            powerPlayStr = "PP"
        }

        let lastPlayText = (situation["lastPlay"] as? [String: Any])?["text"] as? String

        return NHLGame(
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
            periodScores: periodScores,
            currentPeriod: period,
            gameClock: clock,
            homeShotsOnGoal: homeSOG,
            awayShotsOnGoal: awaySOG,
            powerPlay: powerPlayStr,
            lastPlay: lastPlayText
        )
    }

    // MARK: - Helpers

    private func parseLinescores(home: [[String: Any]], away: [[String: Any]]) -> [PeriodScore] {
        var scores: [PeriodScore] = []
        for i in 0..<max(home.count, away.count) {
            let hs = i < home.count ? (home[i]["value"] as? Int ?? Int(home[i]["value"] as? Double ?? 0)) : 0
            let as_ = i < away.count ? (away[i]["value"] as? Int ?? Int(away[i]["value"] as? Double ?? 0)) : 0
            scores.append(PeriodScore(period: i + 1, homeScore: hs, awayScore: as_))
        }
        return scores
    }

    private func quarterScoresFallback(period: Int, home: Int, away: Int) {}

    private func parseSOG(from competitor: [String: Any]) -> Int {
        if let stats = competitor["statistics"] as? [[String: Any]] {
            for stat in stats {
                if let name = stat["name"] as? String, name == "shotsOnGoal" {
                    return stat["value"] as? Int ?? Int(stat["displayValue"] as? String ?? "") ?? 0
                }
            }
        }
        return competitor["shotsOnGoal"] as? Int ?? Int(competitor["shotsOnGoal"] as? String ?? "") ?? 0
    }

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
