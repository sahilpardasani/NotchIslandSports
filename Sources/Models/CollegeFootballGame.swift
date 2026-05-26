import Foundation

// MARK: - College Football Game

struct CollegeFootballGame: SportEvent, Codable {
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

    // College Football-specific fields (reuses QuarterScore and GameSituation from NFLGame)
    var quarterScores: [QuarterScore]
    var currentQuarter: Int
    var gameClock: String
    var situation: GameSituation?
    var lastPlay: String?
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
        quarterScores: [QuarterScore] = [],
        currentQuarter: Int = 0,
        gameClock: String = "",
        situation: GameSituation? = nil,
        lastPlay: String? = nil,
        conference: String? = nil
    ) {
        self.id = id
        self.sportType = .collegeFootball
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
        self.quarterScores = quarterScores
        self.currentQuarter = currentQuarter
        self.gameClock = gameClock
        self.situation = situation
        self.lastPlay = lastPlay
        self.conference = conference
    }
}
