import Foundation
import os

// MARK: - MLB Service

final class MLBService {

    private let apiClient = APIClient.shared
    private let logger = Logger(subsystem: "com.notchisland.sports", category: "MLBService")

    private let scoreboardURL = "https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard"
    private let summaryBaseURL = "https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/summary"

    // MARK: - Fetch All Games

    func fetchGames() async throws -> [MLBGame] {
        guard let url = URL(string: scoreboardURL) else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: url)
        return parseScoreboard(json: json)
    }

    // MARK: - Fetch Game Detail

    func fetchGameDetail(eventId: String) async throws -> MLBGame {
        guard let url = URL(string: "\(summaryBaseURL)?event=\(eventId)") else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: url)
        return parseGameSummary(json: json, eventId: eventId)
    }

    // MARK: - Parse Scoreboard

    private func parseScoreboard(json: [String: Any]) -> [MLBGame] {
        guard let events = json["events"] as? [[String: Any]] else {
            logger.warning("No events found in MLB scoreboard")
            return []
        }

        var games: [MLBGame] = []

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

            let inning = statusDict?["period"] as? Int ?? parseInningFromStatus(statusDescription)
            
            // Situation
            let situation = competition["situation"] as? [String: Any] ?? [:]
            let outs = situation["outs"] as? Int ?? 0
            let balls = situation["balls"] as? Int ?? 0
            let strikes = situation["strikes"] as? Int ?? 0
            
            let onFirst = situation["onFirst"] != nil
            let onSecond = situation["onSecond"] != nil
            let onThird = situation["onThird"] != nil
            let onBase = [onFirst, onSecond, onThird]

            // Parse inningHalf from situation first, then fallback to statusText parsing
            let situationHalf = situation["inningHalf"] as? String
            let formattedInningHalf: String
            if let half = situationHalf, !half.isEmpty {
                formattedInningHalf = half.lowercased().contains("bottom") || half.lowercased().contains("bot") ? "Bot" : "Top"
            } else {
                formattedInningHalf = parseInningHalfFromStatus(statusDescription)
            }

            let homeHits = homeCompetitor["hits"] as? Int ?? Int(homeCompetitor["hits"] as? String ?? "") ?? 0
            let awayHits = awayCompetitor["hits"] as? Int ?? Int(awayCompetitor["hits"] as? String ?? "") ?? 0
            let homeErrors = homeCompetitor["errors"] as? Int ?? Int(homeCompetitor["errors"] as? String ?? "") ?? 0
            let awayErrors = awayCompetitor["errors"] as? Int ?? Int(awayCompetitor["errors"] as? String ?? "") ?? 0

            let lastPlayText = (situation["lastPlay"] as? [String: Any])?["text"] as? String

            let game = MLBGame(
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
                inning: inning,
                inningHalf: formattedInningHalf,
                outs: outs,
                balls: balls,
                strikes: strikes,
                onBase: onBase,
                homePitcher: nil,
                awayPitcher: nil,
                homeHits: homeHits,
                awayHits: awayHits,
                homeErrors: homeErrors,
                awayErrors: awayErrors,
                lastPlay: lastPlayText
            )

            games.append(game)
        }

        return games
    }

    // MARK: - Parse Game Summary

    private func parseGameSummary(json: [String: Any], eventId: String) -> MLBGame {
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
        var homeHits = 0, awayHits = 0
        var homeErrors = 0, awayErrors = 0

        if competitors.count >= 2 {
            let home = competitors.first(where: { ($0["homeAway"] as? String) == "home" }) ?? competitors[0]
            let away = competitors.first(where: { ($0["homeAway"] as? String) == "away" }) ?? competitors[1]
            let h = parseTeamInfo(from: home)
            let a = parseTeamInfo(from: away)
            homeTeam = h.name; awayTeam = a.name
            homeAbbrev = h.abbreviation; awayAbbrev = a.abbreviation
            homeScore = h.score; awayScore = a.score
            homeLogo = h.logoURL; awayLogo = a.logoURL

            homeHits = home["hits"] as? Int ?? Int(home["hits"] as? String ?? "") ?? 0
            awayHits = away["hits"] as? Int ?? Int(away["hits"] as? String ?? "") ?? 0
            homeErrors = home["errors"] as? Int ?? Int(home["errors"] as? String ?? "") ?? 0
            awayErrors = away["errors"] as? Int ?? Int(away["errors"] as? String ?? "") ?? 0
        }

        let inning = statusDict["period"] as? Int ?? parseInningFromStatus(statusDescription)
        
        let situation = json["situation"] as? [String: Any] ?? (competition?["situation"] as? [String: Any] ?? [:])
        let outs = situation["outs"] as? Int ?? 0
        let balls = situation["balls"] as? Int ?? 0
        let strikes = situation["strikes"] as? Int ?? 0
        
        let onFirst = situation["onFirst"] != nil
        let onSecond = situation["onSecond"] != nil
        let onThird = situation["onThird"] != nil
        let onBase = [onFirst, onSecond, onThird]

        // Parse inningHalf from situation first, then fallback to statusText parsing
        let situationHalf = situation["inningHalf"] as? String
        let formattedInningHalf: String
        if let half = situationHalf, !half.isEmpty {
            formattedInningHalf = half.lowercased().contains("bottom") || half.lowercased().contains("bot") ? "Bot" : "Top"
        } else {
            formattedInningHalf = parseInningHalfFromStatus(statusDescription)
        }

        // Pitchers
        let homePitcher = (situation["homePitcher"] as? [String: Any])?["displayName"] as? String
        let awayPitcher = (situation["awayPitcher"] as? [String: Any])?["displayName"] as? String

        let lastPlayText = (situation["lastPlay"] as? [String: Any])?["text"] as? String

        return MLBGame(
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
            inning: inning,
            inningHalf: formattedInningHalf,
            outs: outs,
            balls: balls,
            strikes: strikes,
            onBase: onBase,
            homePitcher: homePitcher,
            awayPitcher: awayPitcher,
            homeHits: homeHits,
            awayHits: awayHits,
            homeErrors: homeErrors,
            awayErrors: awayErrors,
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
    
    /// Parse inning number from statusText like "Bot 8th - 1 Out", "Top 3rd", "End 7th"
    private func parseInningFromStatus(_ status: String) -> Int {
        let lower = status.lowercased()
        // Match patterns like "1st", "2nd", "3rd", "4th"..."9th" etc
        let ordinals: [(String, Int)] = [
            ("1st", 1), ("2nd", 2), ("3rd", 3), ("4th", 4), ("5th", 5),
            ("6th", 6), ("7th", 7), ("8th", 8), ("9th", 9),
            ("10th", 10), ("11th", 11), ("12th", 12), ("13th", 13), ("14th", 14)
        ]
        for (suffix, num) in ordinals {
            if lower.contains(suffix) {
                return num
            }
        }
        return 1
    }
    
    /// Parse inning half from statusText like "Bot 8th", "Top 3rd", "Mid 5th", "End 7th"
    private func parseInningHalfFromStatus(_ status: String) -> String {
        let lower = status.lowercased()
        if lower.contains("bot") || lower.contains("bottom") {
            return "Bot"
        } else if lower.contains("mid") || lower.contains("end") {
            // Mid/End inning = between half innings, show as Bot (just completed top)
            return "Bot"
        }
        return "Top"
    }
}
