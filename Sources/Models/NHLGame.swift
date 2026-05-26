import Foundation

// MARK: - Period Score

struct PeriodScore: Codable, Identifiable {
    var id: Int { period }
    let period: Int
    let homeScore: Int
    let awayScore: Int

    var periodLabel: String {
        switch period {
        case 1: return "P1"
        case 2: return "P2"
        case 3: return "P3"
        default: return "OT\(period - 3)"
        }
    }
}

// MARK: - NHL Game

struct NHLGame: SportEvent, Codable {
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

    // NHL-specific fields
    var periodScores: [PeriodScore]
    var currentPeriod: Int
    var gameClock: String
    var homeShotsOnGoal: Int
    var awayShotsOnGoal: Int
    var powerPlay: String? // e.g. "PP"
    var lastPlay: String?

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
        periodScores: [PeriodScore] = [],
        currentPeriod: Int = 1,
        gameClock: String = "",
        homeShotsOnGoal: Int = 0,
        awayShotsOnGoal: Int = 0,
        powerPlay: String? = nil,
        lastPlay: String? = nil
    ) {
        self.id = id
        self.sportType = .nhl
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
        self.periodScores = periodScores
        self.currentPeriod = currentPeriod
        self.gameClock = gameClock
        self.homeShotsOnGoal = homeShotsOnGoal
        self.awayShotsOnGoal = awayShotsOnGoal
        self.powerPlay = powerPlay
        self.lastPlay = lastPlay
    }
}
