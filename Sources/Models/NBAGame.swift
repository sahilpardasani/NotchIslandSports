import Foundation

// MARK: - NBA Game

struct NBAGame: SportEvent, Codable {
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

    // NBA-specific fields
    var quarterScores: [QuarterScore]
    var currentQuarter: Int
    var gameClock: String
    var homeLeader: String?
    var awayLeader: String?
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
        quarterScores: [QuarterScore] = [],
        currentQuarter: Int = 1,
        gameClock: String = "",
        homeLeader: String? = nil,
        awayLeader: String? = nil,
        lastPlay: String? = nil
    ) {
        self.id = id
        self.sportType = .nba
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
        self.homeLeader = homeLeader
        self.awayLeader = awayLeader
        self.lastPlay = lastPlay
    }
}
