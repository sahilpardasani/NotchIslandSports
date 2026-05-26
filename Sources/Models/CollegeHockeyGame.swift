import Foundation

// MARK: - College Hockey Game

struct CollegeHockeyGame: SportEvent, Codable {
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

    // College Hockey-specific fields
    var periodScores: [PeriodScore]
    var currentPeriod: Int
    var gameClock: String
    var homeShotsOnGoal: Int
    var awayShotsOnGoal: Int
    var conference: String?
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
        conference: String? = nil,
        lastPlay: String? = nil
    ) {
        self.id = id
        self.sportType = .collegeHockey
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
        self.conference = conference
        self.lastPlay = lastPlay
    }
}
