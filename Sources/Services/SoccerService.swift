import Foundation
import os

// MARK: - Soccer Service

final class SoccerService {

    private let apiClient = APIClient.shared
    private let logger = Logger(subsystem: "com.notchisland.sports", category: "SoccerService")

    private let scoreboardBaseURL = "https://site.api.espn.com/apis/site/v2/sports/soccer"
    private let summaryBaseURL = "https://site.web.api.espn.com/apis/site/v2/sports/soccer"

    static let leagues: [(slug: String, name: String)] = [
        ("eng.1", "Premier League"),
        ("esp.1", "La Liga"),
        ("ger.1", "Bundesliga"),
        ("ita.1", "Serie A"),
        ("fra.1", "Ligue 1"),
        ("usa.1", "MLS"),
        ("usa.nwsl", "NWSL"),
        ("uefa.champions", "UEFA Champions League"),
        ("fifa.world", "FIFA World Cup"),
    ]

    // MARK: - Fetch All Matches

    func fetchMatches() async throws -> [SoccerMatch] {
        var allMatches: [SoccerMatch] = []

        await withTaskGroup(of: [SoccerMatch].self) { group in
            for league in SoccerService.leagues {
                group.addTask { [self] in
                    do {
                        return try await fetchLeagueMatches(slug: league.slug, leagueName: league.name)
                    } catch {
                        self.logger.warning("Failed to fetch \(league.name): \(error.localizedDescription)")
                        return []
                    }
                }
            }

            for await matches in group {
                allMatches.append(contentsOf: matches)
            }
        }

        logger.info("Fetched \(allMatches.count) total soccer matches across \(SoccerService.leagues.count) leagues")
        return allMatches
    }

    // MARK: - Fetch Match Detail

    func fetchMatchDetail(eventId: String, league: String) async throws -> SoccerMatch {
        guard let url = URL(string: "\(summaryBaseURL)/\(league)/summary?event=\(eventId)") else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: url)
        let leagueName = SoccerService.leagues.first { $0.slug == league }?.name
        return parseMatchSummary(json: json, eventId: eventId, leagueSlug: league, leagueName: leagueName)
    }

    // MARK: - Fetch League Matches

    private func fetchLeagueMatches(slug: String, leagueName: String) async throws -> [SoccerMatch] {
        guard let url = URL(string: "\(scoreboardBaseURL)/\(slug)/scoreboard") else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: url)
        return parseScoreboard(json: json, leagueSlug: slug, leagueName: leagueName)
    }

    // MARK: - Parse Scoreboard

    private func parseScoreboard(json: [String: Any], leagueSlug: String, leagueName: String) -> [SoccerMatch] {
        guard let events = json["events"] as? [[String: Any]] else {
            return []
        }

        var matches: [SoccerMatch] = []

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

            // Find home and away
            let homeCompetitor = competitors.first { ($0["homeAway"] as? String) == "home" } ?? competitors[0]
            let awayCompetitor = competitors.first { ($0["homeAway"] as? String) == "away" } ?? competitors[1]

            let homeInfo = parseTeamInfo(from: homeCompetitor)
            let awayInfo = parseTeamInfo(from: awayCompetitor)

            // Match clock
            let clock = statusDict?["displayClock"] as? String ?? ""
            let period = statusDict?["period"] as? Int ?? 0
            let periodText = parsePeriodText(period: period, state: statusState)

            let match = SoccerMatch(
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
                matchMinute: clock,
                period: periodText,
                leagueName: leagueName,
                leagueSlug: leagueSlug,
                eventDate: eventDate
            )

            matches.append(match)
        }

        return matches
    }

    // MARK: - Parse Match Summary

    private func parseMatchSummary(json: [String: Any], eventId: String, leagueSlug: String, leagueName: String?) -> SoccerMatch {
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

        let homeCompetitor = competitors.first { ($0["homeAway"] as? String) == "home" } ?? competitors.first ?? [:]
        let awayCompetitor = competitors.first { ($0["homeAway"] as? String) == "away" } ?? (competitors.count > 1 ? competitors[1] : [:])

        let homeInfo = parseTeamInfo(from: homeCompetitor)
        let awayInfo = parseTeamInfo(from: awayCompetitor)

        let clock = statusDict["displayClock"] as? String ?? ""
        let period = statusDict["period"] as? Int ?? 0
        let periodText = parsePeriodText(period: period, state: statusState)

        // Parse scoring plays (goal scorers)
        var goalScorers: [GoalEvent] = []
        if let scoringPlays = json["scoringPlays"] as? [[String: Any]] {
            goalScorers = scoringPlays.compactMap { parseGoalEvent(from: $0) }
        }

        // Parse cards from keyEvents or other sections
        var cards: [CardEvent] = []
        if let keyEvents = json["keyEvents"] as? [[String: Any]] {
            for keyEvent in keyEvents {
                if let card = parseCardEvent(from: keyEvent) {
                    cards.append(card)
                }
            }
        }

        // Parse possession from boxscore stats
        var possessionHome: Int?
        var possessionAway: Int?
        if let boxscore = json["boxscore"] as? [String: Any],
           let teams = boxscore["teams"] as? [[String: Any]] {
            for team in teams {
                let stats = team["statistics"] as? [[String: Any]] ?? []
                for stat in stats {
                    if let name = stat["name"] as? String, name == "possessionPct",
                       let displayValue = stat["displayValue"] as? String,
                       let pct = Int(displayValue.replacingOccurrences(of: "%", with: "")) {
                        let homeAway = team["homeAway"] as? String ?? ""
                        if homeAway == "home" {
                            possessionHome = pct
                        } else {
                            possessionAway = pct
                        }
                    }
                }
            }
        }

        return SoccerMatch(
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
            matchMinute: clock,
            period: periodText,
            goalScorers: goalScorers,
            cards: cards,
            possessionHome: possessionHome,
            possessionAway: possessionAway,
            leagueName: leagueName,
            leagueSlug: leagueSlug
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

    private func parseGoalEvent(from dict: [String: Any]) -> GoalEvent? {
        let athleteDict = dict["athlete"] as? [String: Any]
            ?? (dict["athletes"] as? [[String: Any]])?.first
        let playerName = athleteDict?["displayName"] as? String
            ?? athleteDict?["shortName"] as? String
            ?? "Unknown"

        let clock = dict["clock"] as? [String: Any]
        let minute = clock?["displayValue"] as? String
            ?? dict["displayClock"] as? String
            ?? ""

        let teamDict = dict["team"] as? [String: Any]
        let team = teamDict?["abbreviation"] as? String
            ?? teamDict?["displayName"] as? String
            ?? ""

        let typeDict = dict["type"] as? [String: Any]
        let typeText = typeDict?["text"] as? String ?? ""
        let isPenalty = typeText.lowercased().contains("penalty")
        let isOwnGoal = typeText.lowercased().contains("own goal")

        return GoalEvent(
            playerName: playerName,
            minute: minute,
            team: team,
            isPenalty: isPenalty,
            isOwnGoal: isOwnGoal
        )
    }

    private func parseCardEvent(from dict: [String: Any]) -> CardEvent? {
        let typeDict = dict["type"] as? [String: Any]
        let typeText = typeDict?["text"] as? String ?? ""

        // Only process card events
        guard typeText.lowercased().contains("card") else { return nil }

        // Try multiple paths to find the player name:
        // 1. Direct "athlete" dict
        // 2. "athletes" array
        // 3. "participants" array (ESPN soccer keyEvents use this)
        // 4. "text" field on the event itself
        var playerName = "Unknown"
        
        if let athleteDict = dict["athlete"] as? [String: Any] {
            playerName = athleteDict["displayName"] as? String
                ?? athleteDict["shortName"] as? String
                ?? playerName
        } else if let athletes = dict["athletes"] as? [[String: Any]], let first = athletes.first {
            playerName = first["displayName"] as? String
                ?? first["shortName"] as? String
                ?? playerName
        } else if let participants = dict["participants"] as? [[String: Any]] {
            // ESPN soccer often nests the athlete inside participants[].athlete
            for participant in participants {
                if let athleteDict = participant["athlete"] as? [String: Any] {
                    playerName = athleteDict["displayName"] as? String
                        ?? athleteDict["shortName"] as? String
                        ?? playerName
                    break
                }
                // Some formats put displayName directly on the participant
                if let name = participant["displayName"] as? String {
                    playerName = name
                    break
                }
            }
        }
        
        // Fallback: try to extract from the event's "text" field (e.g. "Yellow Card - Kim Little")
        if playerName == "Unknown", let eventText = dict["text"] as? String {
            let cardPrefixes = ["Yellow Card - ", "Red Card - ", "Second Yellow Card - "]
            for prefix in cardPrefixes {
                if eventText.hasPrefix(prefix) {
                    playerName = String(eventText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
            // Also try splitting on " - " generically
            if playerName == "Unknown", eventText.contains(" - ") {
                let parts = eventText.components(separatedBy: " - ")
                if parts.count >= 2 {
                    playerName = parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }

        let clock = dict["clock"] as? [String: Any]
        let minute = clock?["displayValue"] as? String
            ?? dict["displayClock"] as? String
            ?? ""

        let teamDict = dict["team"] as? [String: Any]
        let team = teamDict?["abbreviation"] as? String ?? ""

        let cardType: CardType = typeText.lowercased().contains("red") ? .red : .yellow

        return CardEvent(
            playerName: playerName,
            minute: minute,
            team: team,
            cardType: cardType
        )
    }

    private func parsePeriodText(period: Int, state: String) -> String {
        if state.lowercased() == "post" { return "FT" }
        if state.lowercased() == "pre" { return "" }

        switch period {
        case 1: return "1H"
        case 2: return "2H"
        case 3: return "ET"
        case 4: return "PEN"
        default:
            // Check for halftime: period 2 with state "in" and clock at "45:00+" often means HT
            return "HT"
        }
    }


}
