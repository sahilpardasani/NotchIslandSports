import Foundation

// MARK: - F1 Race Model

struct F1Race: SportEvent, Codable {
    let id: String
    let sportType: SportType
    let status: MatchStatus
    let homeTeam: String
    let awayTeam: String
    let homeTeamAbbrev: String
    let awayTeamAbbrev: String
    let homeScore: String
    let awayScore: String
    let statusText: String
    let homeLogoURL: String?
    let awayLogoURL: String?
    let eventDate: Date?

    // F1-specific fields
    let raceName: String
    let shortRaceName: String
    let circuitName: String
    let location: String
    var sessions: [F1Session]
    var activeSessionType: String // e.g. "FP1", "SS", "SR", "Qual", "Race"
    
    init(
        id: String,
        sportType: SportType = .f1,
        status: MatchStatus,
        homeTeam: String,
        awayTeam: String,
        homeTeamAbbrev: String,
        awayTeamAbbrev: String,
        homeScore: String,
        awayScore: String,
        statusText: String,
        homeLogoURL: String?,
        awayLogoURL: String?,
        eventDate: Date?,
        raceName: String,
        shortRaceName: String,
        circuitName: String,
        location: String,
        sessions: [F1Session],
        activeSessionType: String = "Race"
    ) {
        self.id = id
        self.sportType = sportType
        self.status = status
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeTeamAbbrev = homeTeamAbbrev
        self.awayTeamAbbrev = awayTeamAbbrev
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.statusText = statusText
        self.homeLogoURL = homeLogoURL
        self.awayLogoURL = awayLogoURL
        self.eventDate = eventDate
        self.raceName = raceName
        self.shortRaceName = shortRaceName
        self.circuitName = circuitName
        self.location = location
        self.sessions = sessions
        self.activeSessionType = activeSessionType
    }
}

// MARK: - F1 Session

struct F1Session: Codable, Identifiable {
    var id: String { sessionType }
    let sessionType: String // e.g. "FP1", "SS", "SR", "Qual", "Race"
    let status: String // e.g. "Final", "Scheduled", "Live"
    let competitors: [F1Driver]
}

// MARK: - F1 Driver

struct F1Driver: Codable, Identifiable {
    var id: String { driverId }
    let driverId: String
    let position: Int
    let fullName: String
    let shortName: String
    let country: String
    let flagURL: String?
    let winner: Bool
    
    var abbrev: String {
        let parts = fullName.split(separator: " ")
        if let last = parts.last {
            return String(last).prefix(3).uppercased()
        }
        let cleanShort = shortName.replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)
        return String(cleanShort.prefix(3)).uppercased()
    }
}
