import Foundation

// MARK: - MLB Game

struct MLBGame: SportEvent, Codable {
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

    // MLB-specific fields
    var inning: Int
    var inningHalf: String // "Top" or "Bot"
    var outs: Int
    var balls: Int
    var strikes: Int
    var onBase: [Bool] // [first, second, third]
    var homePitcher: String?
    var awayPitcher: String?
    var homeHits: Int
    var awayHits: Int
    var homeErrors: Int
    var awayErrors: Int
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
        inning: Int = 1,
        inningHalf: String = "Top",
        outs: Int = 0,
        balls: Int = 0,
        strikes: Int = 0,
        onBase: [Bool] = [false, false, false],
        homePitcher: String? = nil,
        awayPitcher: String? = nil,
        homeHits: Int = 0,
        awayHits: Int = 0,
        homeErrors: Int = 0,
        awayErrors: Int = 0,
        lastPlay: String? = nil
    ) {
        self.id = id
        self.sportType = .mlb
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
        self.inning = inning
        self.inningHalf = inningHalf
        self.outs = outs
        self.balls = balls
        self.strikes = strikes
        self.onBase = onBase
        self.homePitcher = homePitcher
        self.awayPitcher = awayPitcher
        self.homeHits = homeHits
        self.awayHits = awayHits
        self.homeErrors = homeErrors
        self.awayErrors = awayErrors
        self.lastPlay = lastPlay
    }
}
