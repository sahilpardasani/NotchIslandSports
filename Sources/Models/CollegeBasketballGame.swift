import Foundation

// MARK: - Half Score

struct HalfScore: Codable, Identifiable {
    var id: Int { half }
    let half: Int
    let homeScore: Int
    let awayScore: Int

    var halfLabel: String {
        switch half {
        case 1: return "1H"
        case 2: return "2H"
        default: return "OT\(half - 2)"
        }
    }
}

// MARK: - College Basketball Game

struct CollegeBasketballGame: SportEvent, Codable {
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
    var eventDate: Date?

    // Basketball-specific fields
    var halfScores: [HalfScore]
    var currentPeriod: Int
    var gameClock: String
    var conference: String?

    init(
        id: String,
        status: MatchStatus,
        homeTeam: String,
        awayTeam: String,
        homeTeamAbbrev: String,
        awayTeamAbbrev: String,
        homeScore: String,
        awayScore: String,
        statusText: String,
        homeLogoURL: String? = nil,
        awayLogoURL: String? = nil,
        eventDate: Date? = nil,
        halfScores: [HalfScore] = [],
        currentPeriod: Int = 0,
        gameClock: String = "",
        conference: String? = nil
    ) {
        self.id = id
        self.sportType = .collegeBasketball
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
        self.halfScores = halfScores
        self.currentPeriod = currentPeriod
        self.gameClock = gameClock
        self.conference = conference
    }
}
