import Foundation
import os

// MARK: - Volleyball Service

final class VolleyballService {

    private let apiClient = APIClient.shared
    private let logger = Logger(subsystem: "com.notchisland.sports", category: "VolleyballService")

    /// Multiple volleyball league endpoints.
    static let leagueEndpoints: [(slug: String, name: String)] = [
        ("mens-college-volleyball", "NCAA Men's Volleyball"),
        ("womens-college-volleyball", "NCAA Women's Volleyball"),
    ]

    // MARK: - Fetch Games

    func fetchGames() async throws -> [VolleyballGame] {
        var allGames: [VolleyballGame] = []
        var seenIds = Set<String>()

        await withTaskGroup(of: [VolleyballGame].self) { group in
            for league in Self.leagueEndpoints {
                group.addTask { [self] in
                    do {
                        let urlString = "https://site.api.espn.com/apis/site/v2/sports/volleyball/\(league.slug)/scoreboard"
                        guard let url = URL(string: urlString) else { return [] }
                        let json = try await apiClient.fetchRawJSON(from: url)
                        return parseScoreboard(json: json, leagueName: league.name, leagueSlug: league.slug)
                    } catch {
                        logger.warning("Volleyball \(league.name) fetch failed: \(error.localizedDescription)")
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

        logger.info("Parsed \(allGames.count) volleyball games")
        return allGames
    }

    // MARK: - Fetch Game Detail

    func fetchGameDetail(eventId: String, league: String) async throws -> VolleyballGame {
        let urlString = "https://site.api.espn.com/apis/site/v2/sports/volleyball/\(league)/summary?event=\(eventId)"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: url)
        return parseGameSummary(json: json, eventId: eventId, leagueSlug: league)
    }

    // MARK: - Parse Scoreboard

    private func parseScoreboard(json: [String: Any], leagueName: String, leagueSlug: String) -> [VolleyballGame] {
        guard let events = json["events"] as? [[String: Any]] else {
            return []
        }

        var games: [VolleyballGame] = []

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
            let period = statusDict?["period"] as? Int ?? 0

            let matchStatus = ESPNStatusParser.parseState(statusState)
            let eventDate = ESPNStatusParser.parseDate(event["date"] as? String)

            let home = competitors.first(where: { ($0["homeAway"] as? String) == "home" }) ?? competitors[0]
            let away = competitors.first(where: { ($0["homeAway"] as? String) == "away" }) ?? competitors[1]

            let homeInfo = parseTeamInfo(from: home)
            let awayInfo = parseTeamInfo(from: away)

            // Parse set scores from linescores
            let homeLinescores = home["linescores"] as? [[String: Any]] ?? []
            let awayLinescores = away["linescores"] as? [[String: Any]] ?? []
            var setScores: [VolleyballSetScore] = []
            for i in 0..<max(homeLinescores.count, awayLinescores.count) {
                let hs = i < homeLinescores.count ? (homeLinescores[i]["value"] as? Int ?? Int(homeLinescores[i]["value"] as? Double ?? 0)) : 0
                let as_ = i < awayLinescores.count ? (awayLinescores[i]["value"] as? Int ?? Int(awayLinescores[i]["value"] as? Double ?? 0)) : 0
                setScores.append(VolleyballSetScore(setNumber: i + 1, homeScore: hs, awayScore: as_))
            }

            let game = VolleyballGame(
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
                setScores: setScores,
                currentSet: period,
                leagueName: leagueName,
                leagueSlug: leagueSlug
            )
            games.append(game)
        }

        return games
    }

    // MARK: - Parse Game Summary

    private func parseGameSummary(json: [String: Any], eventId: String, leagueSlug: String) -> VolleyballGame {
        let event = json["event"] as? [String: Any] ?? [:]
        let competitions = event["competitions"] as? [[String: Any]] ?? []
        let competition = competitions.first ?? [:]
        let competitors = competition["competitors"] as? [[String: Any]] ?? []

        let statusDict = event["status"] as? [String: Any] ?? [:]
        let statusType = statusDict["type"] as? [String: Any] ?? [:]
        let statusState = statusType["state"] as? String ?? ""
        let statusDescription = statusType["description"] as? String ?? ""
        let period = statusDict["period"] as? Int ?? 0

        let matchStatus = ESPNStatusParser.parseState(statusState)
        let eventDate = ESPNStatusParser.parseDate(event["date"] as? String)

        var homeTeam = "Home"
        var awayTeam = "Away"
        var homeAbbrev = "HOME"
        var awayAbbrev = "AWAY"
        var homeScore = "0"
        var awayScore = "0"
        var homeLogo: String?
        var awayLogo: String?
        var setScores: [VolleyballSetScore] = []

        if competitors.count >= 2 {
            let home = competitors.first(where: { ($0["homeAway"] as? String) == "home" }) ?? competitors[0]
            let away = competitors.first(where: { ($0["homeAway"] as? String) == "away" }) ?? competitors[1]

            let h = parseTeamInfo(from: home)
            let a = parseTeamInfo(from: away)
            homeTeam = h.name; awayTeam = a.name
            homeAbbrev = h.abbreviation; awayAbbrev = a.abbreviation
            homeScore = h.score; awayScore = a.score
            homeLogo = h.logoURL; awayLogo = a.logoURL

            // Parse set scores
            let homeLinescores = home["linescores"] as? [[String: Any]] ?? []
            let awayLinescores = away["linescores"] as? [[String: Any]] ?? []
            for i in 0..<max(homeLinescores.count, awayLinescores.count) {
                let hs = i < homeLinescores.count ? (homeLinescores[i]["value"] as? Int ?? Int(homeLinescores[i]["value"] as? Double ?? 0)) : 0
                let as_ = i < awayLinescores.count ? (awayLinescores[i]["value"] as? Int ?? Int(awayLinescores[i]["value"] as? Double ?? 0)) : 0
                setScores.append(VolleyballSetScore(setNumber: i + 1, homeScore: hs, awayScore: as_))
            }
        }

        return VolleyballGame(
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
            setScores: setScores,
            currentSet: period,
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
