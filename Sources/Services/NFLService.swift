import Foundation
import os

// MARK: - NFL Service

final class NFLService {

    private let apiClient = APIClient.shared
    private let logger = Logger(subsystem: "com.notchisland.sports", category: "NFLService")

    private let scoreboardURL = "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard"
    private let summaryBaseURL = "https://site.api.espn.com/apis/site/v2/sports/football/nfl/summary"

    // MARK: - Fetch All Games

    func fetchGames() async throws -> [NFLGame] {
        guard let url = URL(string: scoreboardURL) else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: url)
        return parseScoreboard(json: json)
    }

    // MARK: - Fetch Game Detail

    func fetchGameDetail(eventId: String) async throws -> NFLGame {
        guard let url = URL(string: "\(summaryBaseURL)?event=\(eventId)") else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: url)
        return parseGameSummary(json: json, eventId: eventId)
    }

    // MARK: - Parse Scoreboard

    private func parseScoreboard(json: [String: Any]) -> [NFLGame] {
        guard let events = json["events"] as? [[String: Any]] else {
            logger.warning("No events found in NFL scoreboard")
            return []
        }

        var games: [NFLGame] = []

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

            // NFL: find home and away based on homeAway field
            let homeCompetitor = competitors.first { ($0["homeAway"] as? String) == "home" } ?? competitors[0]
            let awayCompetitor = competitors.first { ($0["homeAway"] as? String) == "away" } ?? competitors[1]

            let homeInfo = parseTeamInfo(from: homeCompetitor)
            let awayInfo = parseTeamInfo(from: awayCompetitor)

            // Parse quarter scores
            let homeLinescores = homeCompetitor["linescores"] as? [[String: Any]] ?? []
            let awayLinescores = awayCompetitor["linescores"] as? [[String: Any]] ?? []
            let quarterScores = parseQuarterScores(homeScores: homeLinescores, awayScores: awayLinescores)

            // Parse period and clock
            let period = statusDict?["period"] as? Int ?? 0
            let clock = statusDict?["displayClock"] as? String ?? ""

            let game = NFLGame(
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
                quarterScores: quarterScores,
                currentQuarter: period,
                gameClock: clock,
                eventDate: eventDate
            )

            games.append(game)
        }

        logger.info("Parsed \(games.count) NFL games")
        return games
    }

    // MARK: - Parse Game Summary

    private func parseGameSummary(json: [String: Any], eventId: String) -> NFLGame {
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

        // Find home and away
        let homeCompetitor = competitors.first { ($0["homeAway"] as? String) == "home" } ?? competitors.first ?? [:]
        let awayCompetitor = competitors.first { ($0["homeAway"] as? String) == "away" } ?? (competitors.count > 1 ? competitors[1] : [:])

        let homeInfo = parseTeamInfo(from: homeCompetitor)
        let awayInfo = parseTeamInfo(from: awayCompetitor)

        // Parse quarter scores
        let homeLinescores = homeCompetitor["linescores"] as? [[String: Any]] ?? []
        let awayLinescores = awayCompetitor["linescores"] as? [[String: Any]] ?? []
        let quarterScores = parseQuarterScores(homeScores: homeLinescores, awayScores: awayLinescores)

        let period = statusDict["period"] as? Int ?? 0
        let clock = statusDict["displayClock"] as? String ?? ""

        // Parse game situation
        var situation: GameSituation?
        if let situationDict = json["situation"] as? [String: Any] {
            situation = parseSituation(from: situationDict)
        }

        // Parse last play
        var lastPlay: String?
        if let lastPlayDict = (json["drives"] as? [String: Any])?["current"] as? [String: Any],
           let plays = lastPlayDict["plays"] as? [[String: Any]],
           let latestPlay = plays.last {
            lastPlay = latestPlay["text"] as? String ?? latestPlay["description"] as? String
        } else if let situationDict = json["situation"] as? [String: Any] {
            lastPlay = (situationDict["lastPlay"] as? [String: Any])?["text"] as? String
        }

        // Parse timeouts
        let homeTimeouts = (json["situation"] as? [String: Any])?["homeTimeouts"] as? Int ?? 3
        let awayTimeouts = (json["situation"] as? [String: Any])?["awayTimeouts"] as? Int ?? 3

        return NFLGame(
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
            quarterScores: quarterScores,
            currentQuarter: period,
            gameClock: clock,
            situation: situation,
            lastPlay: lastPlay,
            homeTimeouts: homeTimeouts,
            awayTimeouts: awayTimeouts
        )
    }

    // MARK: - Helper Parsers

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
        let score = dict["score"] as? String ?? "0"
        let logoURL = teamDict?["logo"] as? String
            ?? (teamDict?["logos"] as? [[String: Any]])?.first?["href"] as? String

        return TeamInfo(name: name, abbreviation: abbreviation, score: score, logoURL: logoURL)
    }

    private func parseQuarterScores(homeScores: [[String: Any]], awayScores: [[String: Any]]) -> [QuarterScore] {
        var quarters: [QuarterScore] = []
        let count = max(homeScores.count, awayScores.count)

        for i in 0..<count {
            let homeQScore: Int
            let awayQScore: Int

            if i < homeScores.count {
                if let valInt = homeScores[i]["value"] as? Int {
                    homeQScore = valInt
                } else if let valDouble = homeScores[i]["value"] as? Double {
                    homeQScore = Int(valDouble)
                } else if let valStr = homeScores[i]["displayValue"] as? String, let valParsed = Int(valStr) {
                    homeQScore = valParsed
                } else {
                    homeQScore = 0
                }
            } else {
                homeQScore = 0
            }

            if i < awayScores.count {
                if let valInt = awayScores[i]["value"] as? Int {
                    awayQScore = valInt
                } else if let valDouble = awayScores[i]["value"] as? Double {
                    awayQScore = Int(valDouble)
                } else if let valStr = awayScores[i]["displayValue"] as? String, let valParsed = Int(valStr) {
                    awayQScore = valParsed
                } else {
                    awayQScore = 0
                }
            } else {
                awayQScore = 0
            }

            quarters.append(QuarterScore(
                quarter: i + 1,
                homeScore: homeQScore,
                awayScore: awayQScore
            ))
        }

        return quarters
    }

    private func parseSituation(from dict: [String: Any]) -> GameSituation? {
        let down = dict["down"] as? Int ?? 0
        let distance = dict["distance"] as? Int ?? 0
        let yardLine = dict["yardLine"] as? Int ?? 0

        let possessionId = dict["possession"] as? String ?? ""
        let possessionTeam = (dict["possessionText"] as? String)
            ?? (dict["team"] as? [String: Any])?["abbreviation"] as? String
            ?? possessionId

        let isRedZone = dict["isRedZone"] as? Bool ?? false
        let yardsToEndzone = dict["yardsToEndzone"] as? Int
            ?? dict["distance"] as? Int ?? 0

        guard down > 0 else { return nil }

        return GameSituation(
            down: down,
            distance: distance,
            yardLine: yardLine,
            possession: possessionTeam,
            isRedZone: isRedZone,
            yardsToEndzone: yardsToEndzone
        )
    }


}
