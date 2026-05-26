import Foundation
import os

// MARK: - F1 Service

final class F1Service {

    private let apiClient = APIClient.shared
    private let logger = Logger(subsystem: "com.notchisland.sports", category: "F1Service")

    private let scoreboardURL = "https://site.api.espn.com/apis/site/v2/sports/racing/f1/scoreboard"

    // MARK: - Fetch Races

    func fetchRaces() async throws -> [F1Race] {
        guard let url = URL(string: scoreboardURL) else {
            throw NetworkError.invalidURL
        }

        let json = try await apiClient.fetchRawJSON(from: url)
        return parseScoreboard(json: json)
    }

    // MARK: - Parse Scoreboard

    private func parseScoreboard(json: [String: Any]) -> [F1Race] {
        guard let events = json["events"] as? [[String: Any]] else {
            logger.warning("No events found in F1 scoreboard")
            return []
        }

        var races: [F1Race] = []

        for event in events {
            guard let id = event["id"] as? String,
                  let name = event["name"] as? String,
                  let competitions = event["competitions"] as? [[String: Any]] else {
                continue
            }

            let shortName = event["shortName"] as? String ?? name
            
            // Circuit & location
            let circuit = event["circuit"] as? [String: Any]
            let circuitName = circuit?["fullName"] as? String ?? ""
            let address = circuit?["address"] as? [String: Any]
            let city = address?["city"] as? String ?? ""
            let country = address?["country"] as? String ?? ""
            let location = city.isEmpty ? country : (country.isEmpty ? city : "\(city), \(country)")

            // Status
            let statusDict = event["status"] as? [String: Any]
            let statusType = statusDict?["type"] as? [String: Any]
            let statusState = statusType?["state"] as? String ?? ""
            let statusDescription = statusType?["shortDetail"] as? String
                ?? statusType?["description"] as? String ?? ""
            let matchStatus = ESPNStatusParser.parseState(statusState)
            let eventDate = ESPNStatusParser.parseDate(event["date"] as? String)

            var sessions: [F1Session] = []

            for comp in competitions {
                let typeDict = comp["type"] as? [String: Any]
                let sessionType = typeDict?["abbreviation"] as? String ?? "Race"

                let compStatusDict = comp["status"] as? [String: Any]
                let compStatusType = compStatusDict?["type"] as? [String: Any]
                let compStatusState = compStatusType?["description"] as? String ?? "Scheduled"

                let compCompetitors = comp["competitors"] as? [[String: Any]] ?? []
                var drivers: [F1Driver] = []

                for competitor in compCompetitors {
                    guard let driverId = competitor["id"] as? String else { continue }
                    let position = competitor["order"] as? Int ?? 0
                    let winner = competitor["winner"] as? Bool ?? false

                    let athlete = competitor["athlete"] as? [String: Any]
                    let fullName = athlete?["fullName"] as? String ?? "Unknown"
                    let shortName = athlete?["shortName"] as? String ?? fullName

                    let flag = athlete?["flag"] as? [String: Any]
                    let flagURL = flag?["href"] as? String
                    let flagAlt = flag?["alt"] as? String ?? ""

                    drivers.append(F1Driver(
                        driverId: driverId,
                        position: position,
                        fullName: fullName,
                        shortName: shortName,
                        country: flagAlt,
                        flagURL: flagURL,
                        winner: winner
                    ))
                }

                // Sort drivers by position
                drivers.sort { $0.position < $1.position }

                sessions.append(F1Session(
                    sessionType: sessionType,
                    status: compStatusState,
                    competitors: drivers
                ))
            }

            // Determine active/main session
            let activeSession = sessions.first { $0.sessionType == "Race" } ?? sessions.last
            let activeDrivers = activeSession?.competitors ?? []

            let leader = activeDrivers.first
            let runnerUp = activeDrivers.count > 1 ? activeDrivers[1] : nil

            let homeTeam = leader?.fullName ?? "TBD"
            let homeTeamAbbrev = leader?.abbrev ?? "TBD"
            let awayTeam = runnerUp?.fullName ?? "TBD"
            let awayTeamAbbrev = runnerUp?.abbrev ?? "TBD"

            let homeScore = leader != nil ? "P1" : ""
            let awayScore = runnerUp != nil ? "P2" : ""

            races.append(F1Race(
                id: id,
                status: matchStatus,
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                homeTeamAbbrev: homeTeamAbbrev,
                awayTeamAbbrev: awayTeamAbbrev,
                homeScore: homeScore,
                awayScore: awayScore,
                statusText: statusDescription,
                homeLogoURL: leader?.flagURL,
                awayLogoURL: runnerUp?.flagURL,
                eventDate: eventDate,
                raceName: name,
                shortRaceName: shortName,
                circuitName: circuitName,
                location: location,
                sessions: sessions,
                activeSessionType: activeSession?.sessionType ?? "Race"
            ))
        }

        logger.info("F1Service parsed \(races.count) grand prix events")
        return races
    }
}
