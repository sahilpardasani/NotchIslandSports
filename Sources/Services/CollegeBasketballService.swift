import Foundation
import os

// MARK: - College Basketball Service

final class CollegeBasketballService {

    private let apiClient = APIClient.shared
    private let logger = Logger(subsystem: "com.notchisland.sports", category: "CollegeBasketballService")

    static let leagueEndpoints: [(slug: String, name: String)] = [
        ("mens-college-basketball", "NCAA Men's Basketball"),
        ("womens-college-basketball", "NCAA Women's Basketball")
    ]

    // MARK: - Fetch Games

    func fetchGames() async throws -> [CollegeBasketballGame] {
        var allGames: [CollegeBasketballGame] = []
        var seenIds = Set<String>()

        await withTaskGroup(of: [CollegeBasketballGame].self) { group in
            for league in Self.leagueEndpoints {
                group.addTask { [self] in
                    do {
                        let urlString = "https://site.api.espn.com/apis/site/v2/sports/basketball/\(league.slug)/scoreboard?limit=50"
                        guard let url = URL(string: urlString) else { return [] }
                        let json = try await apiClient.fetchRawJSON(from: url)
                        return parseScoreboard(json: json, leagueName: league.name)
                    } catch {
                        logger.warning("College Basketball \(league.name) fetch failed: \(error.localizedDescription)")
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

        logger.info("Parsed \(allGames.count) college basketball games")
        return allGames
    }

    // MARK: - Fetch Game Detail

    func fetchGameDetail(eventId: String) async throws -> CollegeBasketballGame {
        let mensURLString = "https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/summary?event=\(eventId)"
        let womensURLString = "https://site.api.espn.com/apis/site/v2/sports/basketball/womens-college-basketball/summary?event=\(eventId)"

        do {
            guard let url = URL(string: mensURLString) else { throw NetworkError.invalidURL }
            let json = try await apiClient.fetchRawJSON(from: url)
            return parseGameSummary(json: json, eventId: eventId)
        } catch {
            guard let url = URL(string: womensURLString) else { throw NetworkError.invalidURL }
            let json = try await apiClient.fetchRawJSON(from: url)
            return parseGameSummary(json: json, eventId: eventId)
        }
    }

    // MARK: - Parse Scoreboard

    private func parseScoreboard(json: [String: Any], leagueName: String) -> [CollegeBasketballGame] {
        guard let events = json["events"] as? [[String: Any]] else {
            return []
        }

        var games: [CollegeBasketballGame] = []

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

            // Parse half scores from linescores
            let homeLinescores = home["linescores"] as? [[String: Any]] ?? []
            let awayLinescores = away["linescores"] as? [[String: Any]] ?? []
            var halfScores: [HalfScore] = []
            for i in 0..<max(homeLinescores.count, awayLinescores.count) {
                let hs = i < homeLinescores.count ? (homeLinescores[i]["value"] as? Int ?? Int(homeLinescores[i]["value"] as? Double ?? 0)) : 0
                let as_ = i < awayLinescores.count ? (awayLinescores[i]["value"] as? Int ?? Int(awayLinescores[i]["value"] as? Double ?? 0)) : 0
                halfScores.append(HalfScore(half: i + 1, homeScore: hs, awayScore: as_))
            }

            // Append gender to conference name or just use leagueName
            let confName = leagueName

            let game = CollegeBasketballGame(
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
                halfScores: halfScores,
                currentPeriod: period,
                gameClock: clock,
                conference: confName
            )

            games.append(game)
        }

        return games
    }

    // MARK: - Parse Summary

    private func parseGameSummary(json: [String: Any], eventId: String) -> CollegeBasketballGame {
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

        return CollegeBasketballGame(
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
            halfScores: [],
            currentPeriod: period,
            gameClock: clock
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
