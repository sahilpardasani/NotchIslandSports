import Foundation
import os

// MARK: - Tennis Service

final class TennisService {

    private let apiClient = APIClient.shared
    private let logger = Logger(subsystem: "com.notchisland.sports", category: "TennisService")

    private let atpScoreboardURL = "https://site.api.espn.com/apis/site/v2/sports/tennis/atp/scoreboard"
    private let wtaScoreboardURL = "https://site.api.espn.com/apis/site/v2/sports/tennis/wta/scoreboard"
    private let atpSummaryBaseURL = "https://site.api.espn.com/apis/site/v2/sports/tennis/atp/summary"
    private let wtaSummaryBaseURL = "https://site.api.espn.com/apis/site/v2/sports/tennis/wta/summary"

    // MARK: - Fetch All Matches

    func fetchMatches() async throws -> [TennisMatch] {
        var allMatches: [TennisMatch] = []
        var seenIds = Set<String>()

        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        let dates = [formatter.string(from: yesterday), formatter.string(from: today), formatter.string(from: tomorrow)]

        // Fetch Yesterday, Today, and Tomorrow's scoreboards for both ATP and WTA
        await withTaskGroup(of: [TennisMatch].self) { group in
            for dateStr in dates {
                // ATP
                group.addTask { [self] in
                    do {
                        return try await fetchTourMatches(url: "\(atpScoreboardURL)?dates=\(dateStr)", isWTA: false)
                    } catch {
                        logger.warning("Tennis ATP fetch failed for date \(dateStr): \(error.localizedDescription)")
                        return []
                    }
                }
                // WTA
                group.addTask { [self] in
                    do {
                        return try await fetchTourMatches(url: "\(wtaScoreboardURL)?dates=\(dateStr)", isWTA: true)
                    } catch {
                        logger.warning("Tennis WTA fetch failed for date \(dateStr): \(error.localizedDescription)")
                        return []
                    }
                }
            }

            for await matches in group {
                for match in matches {
                    if !seenIds.contains(match.id) {
                        seenIds.insert(match.id)
                        allMatches.append(match)
                    }
                }
            }
        }

        // Sort: live first, then upcoming by date soonest first, then completed most recent first
        allMatches.sort { lhs, rhs in
            let lhsPriority = statusPriority(lhs.status)
            let rhsPriority = statusPriority(rhs.status)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            
            // Within same status, sort by date
            guard let d1 = lhs.eventDate, let d2 = rhs.eventDate else { return false }
            if lhs.status == .completed {
                return d1 > d2  // Most recent completed first
            } else {
                return d1 < d2  // Soonest upcoming first
            }
        }

        logger.info("TennisService parsed \(allMatches.count) total tennis matches across Yesterday/Today/Tomorrow")
        return allMatches
    }

    private func statusPriority(_ status: MatchStatus) -> Int {
        switch status {
        case .live: return 0
        case .upcoming: return 1
        case .completed: return 2
        case .unknown: return 3
        }
    }

    // MARK: - Fetch Match Detail

    func fetchMatchDetail(eventId: String, isWTA: Bool) async throws -> TennisMatch {
        let baseURL = isWTA ? wtaSummaryBaseURL : atpSummaryBaseURL
        guard let url = URL(string: "\(baseURL)?event=\(eventId)") else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: url)
        return parseMatchSummary(json: json, eventId: eventId, isWTA: isWTA)
    }

    // MARK: - Fetch Tour Matches

    private func fetchTourMatches(url: String, isWTA: Bool) async throws -> [TennisMatch] {
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: requestURL)
        return parseScoreboard(json: json, isWTA: isWTA)
    }

    private func parseScoreboard(json: [String: Any], isWTA: Bool) -> [TennisMatch] {
        guard let events = json["events"] as? [[String: Any]] else {
            logger.warning("No events found in tennis scoreboard")
            return []
        }

        var matches: [TennisMatch] = []

        for event in events {
            let tournamentName = event["name"] as? String
                ?? (event["season"] as? [String: Any])?["name"] as? String
                ?? (json["leagues"] as? [[String: Any]])?.first?["name"] as? String
            
            // Check if groupings exists (tournament format)
            if let groupings = event["groupings"] as? [[String: Any]] {
                for grouping in groupings {
                    let groupingDict = grouping["grouping"] as? [String: Any]
                    let roundName = groupingDict?["displayName"] as? String
                    
                    if let competitions = grouping["competitions"] as? [[String: Any]] {
                        for competition in competitions {
                            if let match = parseCompetition(competition, tournamentName: tournamentName, round: roundName, isWTA: isWTA) {
                                matches.append(match)
                            }
                        }
                    }
                }
            } else if let competitions = event["competitions"] as? [[String: Any]] {
                // Fallback if competitions exist at the event level directly
                for competition in competitions {
                    let statusDict = event["status"] as? [String: Any]
                    let statusType = statusDict?["type"] as? [String: Any]
                    let shortDetail = statusType?["shortDetail"] as? String
                    if let match = parseCompetition(competition, tournamentName: tournamentName, round: shortDetail, isWTA: isWTA) {
                        matches.append(match)
                    }
                }
            }
        }

        // Sort & Truncate completed to avoid UI flood
        let liveMatches = matches.filter { $0.status == .live }
        let upcomingMatches = matches.filter { $0.status == .upcoming }
        let completedMatches = matches.filter { $0.status == .completed }
        
        let truncatedCompleted = Array(completedMatches.prefix(20))
        let finalMatches = liveMatches + upcomingMatches + truncatedCompleted

        logger.info("TennisService parsed \(liveMatches.count) live, \(upcomingMatches.count) upcoming, \(completedMatches.count) completed matches.")
        return finalMatches
    }

    private func parseCompetition(_ competition: [String: Any], tournamentName: String?, round: String?, isWTA: Bool) -> TennisMatch? {
        guard let eventId = competition["id"] as? String,
              let competitors = competition["competitors"] as? [[String: Any]],
              competitors.count >= 2 else {
            return nil
        }

        let statusDict = competition["status"] as? [String: Any]
        let statusType = statusDict?["type"] as? [String: Any]
        let statusState = statusType?["state"] as? String ?? ""
        let statusDescription = statusType?["description"] as? String ?? ""
        let matchStatus = ESPNStatusParser.parseState(statusState)
        let eventDate = ESPNStatusParser.parseDate(competition["date"] as? String)

        let player1 = competitors[0]
        let player2 = competitors[1]

        let player1Info = parsePlayerInfo(from: player1)
        let player2Info = parsePlayerInfo(from: player2)

        // Parse set scores from linescores
        let sets1 = player1["linescores"] as? [[String: Any]] ?? []
        let sets2 = player2["linescores"] as? [[String: Any]] ?? []
        let setScores = parseSets(player1Sets: sets1, player2Sets: sets2)

        var servingPlayer: Int?
        if competitors.count >= 2 {
            if competitors[0]["possession"] as? Bool == true {
                servingPlayer = 1
            } else if competitors[1]["possession"] as? Bool == true {
                servingPlayer = 2
            }
        }

        return TennisMatch(
            id: eventId,
            status: matchStatus,
            player1Name: player1Info.name,
            player2Name: player2Info.name,
            player1Country: player1Info.country,
            player2Country: player2Info.country,
            homeScore: player1Info.score,
            awayScore: player2Info.score,
            statusText: statusDescription,
            homeLogoURL: player1Info.flagURL,
            awayLogoURL: player2Info.flagURL,
            sets: setScores,
            servingPlayer: servingPlayer,
            currentSet: max(setScores.count, 1),
            tournamentName: tournamentName,
            round: round,
            isWTA: isWTA,
            eventDate: eventDate
        )
    }


    // MARK: - Parse Match Summary

    private func parseMatchSummary(json: [String: Any], eventId: String, isWTA: Bool) -> TennisMatch {
        let header = json["header"] as? [String: Any]
        let competitions = header?["competitions"] as? [[String: Any]]
        let competition = competitions?.first
        let competitors = competition?["competitors"] as? [[String: Any]] ?? []

        let statusDict = header?["status"] as? [String: Any] ?? (json["status"] as? [String: Any] ?? [:])
        let statusType = statusDict["type"] as? [String: Any]
        let statusState = statusType?["state"] as? String ?? ""
        let statusDescription = statusType?["description"] as? String ?? ""
        let matchStatus = ESPNStatusParser.parseState(statusState)

        var player1Info = PlayerInfo(name: "TBD", country: "", score: "", flagURL: nil)
        var player2Info = PlayerInfo(name: "TBD", country: "", score: "", flagURL: nil)
        var setScores: [SetScore] = []

        if competitors.count >= 2 {
            player1Info = parsePlayerInfo(from: competitors[0])
            player2Info = parsePlayerInfo(from: competitors[1])

            let sets1 = competitors[0]["linescores"] as? [[String: Any]] ?? []
            let sets2 = competitors[1]["linescores"] as? [[String: Any]] ?? []
            setScores = parseSets(player1Sets: sets1, player2Sets: sets2)
        }

        // Parse current game score from the summary
        var currentGameScore: GameScore?
        var servingPlayer: Int?

        if let situation = json["situation"] as? [String: Any] {
            if let p1Points = situation["player1Points"] as? String,
               let p2Points = situation["player2Points"] as? String {
                currentGameScore = GameScore(player1Points: p1Points, player2Points: p2Points)
            } else if let p1Points = situation["competitor1Points"] as? String,
                      let p2Points = situation["competitor2Points"] as? String {
                currentGameScore = GameScore(player1Points: p1Points, player2Points: p2Points)
            }

            if let serving = situation["servingCompetitor"] as? Int {
                servingPlayer = serving
            } else if let server = situation["server"] as? [String: Any],
                      let serverId = server["competitorId"] as? String {
                // Match competitor IDs to determine serving player
                let comp1Id = competitors.first?["id"] as? String
                servingPlayer = (serverId == comp1Id) ? 1 : 2
            }
        }

        let season = (json["header"] as? [String: Any])?["season"] as? [String: Any]
        let tournamentName = season?["name"] as? String
        let round = statusType?["shortDetail"] as? String

        return TennisMatch(
            id: eventId,
            status: matchStatus,
            player1Name: player1Info.name,
            player2Name: player2Info.name,
            player1Country: player1Info.country,
            player2Country: player2Info.country,
            homeScore: player1Info.score,
            awayScore: player2Info.score,
            statusText: statusDescription,
            homeLogoURL: player1Info.flagURL,
            awayLogoURL: player2Info.flagURL,
            sets: setScores,
            currentGameScore: currentGameScore,
            servingPlayer: servingPlayer,
            currentSet: max(setScores.count, 1),
            tournamentName: tournamentName,
            round: round,
            isWTA: isWTA
        )
    }

    // MARK: - Helper Parsers

    private struct PlayerInfo {
        let name: String
        let country: String
        let score: String
        let flagURL: String?
    }

    private func parsePlayerInfo(from dict: [String: Any]) -> PlayerInfo {
        let athlete = dict["athlete"] as? [String: Any]
        let name = athlete?["displayName"] as? String
            ?? athlete?["shortName"] as? String
            ?? (dict["team"] as? [String: Any])?["name"] as? String
            ?? "Unknown"

        let country = athlete?["flag"] as? [String: Any]
        let countryCode = country?["alt"] as? String
            ?? athlete?["nationality"] as? String
            ?? ""

        let score = dict["score"] as? String ?? ""
        let flagURL = country?["href"] as? String

        return PlayerInfo(name: name, country: countryCode, score: score, flagURL: flagURL)
    }

    private func parseSets(player1Sets: [[String: Any]], player2Sets: [[String: Any]]) -> [SetScore] {
        var setScores: [SetScore] = []

        let count = max(player1Sets.count, player2Sets.count)
        for i in 0..<count {
            let p1Games: Int
            let p2Games: Int

            if i < player1Sets.count {
                p1Games = player1Sets[i]["value"] as? Int
                    ?? Int(player1Sets[i]["value"] as? String ?? "") ?? 0
            } else {
                p1Games = 0
            }

            if i < player2Sets.count {
                p2Games = player2Sets[i]["value"] as? Int
                    ?? Int(player2Sets[i]["value"] as? String ?? "") ?? 0
            } else {
                p2Games = 0
            }

            let tiebreak = player1Sets.count > i ? player1Sets[i]["tiebreak"] as? Int : nil

            setScores.append(SetScore(
                setNumber: i + 1,
                player1Games: p1Games,
                player2Games: p2Games,
                tiebreak: tiebreak
            ))
        }

        return setScores
    }


}
