import Foundation

// MARK: - Cricket Match

struct CricketMatch: SportEvent, Codable {
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

    // Cricket-specific fields
    var leagueId: String?
    var currentInnings: InningsDetail?
    var batsmen: [Batsman]
    var bowler: Bowler?
    var partnership: Partnership?
    var currentRunRate: Double?
    var requiredRunRate: Double?
    var target: Int?
    var recentOvers: String?
    var matchDescription: String
    var eventDate: Date?

    // Concluded match scorecard fields
    var venue: String?
    var playerOfTheMatch: String?
    var homeTopBatters: [Batsman]?
    var homeTopBowlers: [Bowler]?
    var awayTopBatters: [Batsman]?
    var awayTopBowlers: [Bowler]?

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
        leagueId: String? = nil,
        currentInnings: InningsDetail? = nil,
        batsmen: [Batsman] = [],
        bowler: Bowler? = nil,
        partnership: Partnership? = nil,
        currentRunRate: Double? = nil,
        requiredRunRate: Double? = nil,
        target: Int? = nil,
        recentOvers: String? = nil,
        matchDescription: String = "",
        eventDate: Date? = nil,
        venue: String? = nil,
        playerOfTheMatch: String? = nil,
        homeTopBatters: [Batsman]? = nil,
        homeTopBowlers: [Bowler]? = nil,
        awayTopBatters: [Batsman]? = nil,
        awayTopBowlers: [Bowler]? = nil
    ) {
        self.id = id
        self.sportType = .cricket
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
        self.leagueId = leagueId
        self.currentInnings = currentInnings
        self.batsmen = batsmen
        self.bowler = bowler
        self.partnership = partnership
        self.currentRunRate = currentRunRate
        self.requiredRunRate = requiredRunRate
        self.target = target
        self.recentOvers = recentOvers
        self.matchDescription = matchDescription
        self.eventDate = eventDate
        self.venue = venue
        self.playerOfTheMatch = playerOfTheMatch
        self.homeTopBatters = homeTopBatters
        self.homeTopBowlers = homeTopBowlers
        self.awayTopBatters = awayTopBatters
        self.awayTopBowlers = awayTopBowlers
    }
}

// MARK: - Innings Detail

struct InningsDetail: Codable {
    let teamName: String
    let runs: Int
    let wickets: Int
    let overs: Double
    let inningsNumber: Int

    var displayScore: String {
        "\(runs)/\(wickets) (\(formattedOvers))"
    }

    var formattedOvers: String {
        let wholeOvers = Int(overs)
        let balls = Int((overs - Double(wholeOvers)) * 10)
        return "\(wholeOvers).\(balls)"
    }
}

// MARK: - Batsman

struct Batsman: Codable, Identifiable {
    var id: String { name }
    let name: String
    let runs: Int
    let balls: Int
    let fours: Int
    let sixes: Int
    let strikeRate: Double
    let isOnStrike: Bool

    var displayScore: String {
        "\(runs)(\(balls))"
    }
}

// MARK: - Bowler

struct Bowler: Codable {
    let name: String
    let overs: String
    let maidens: Int
    let runs: Int
    let wickets: Int
    let economy: Double

    var displayFigures: String {
        "\(wickets)/\(runs) (\(overs))"
    }
}

// MARK: - Partnership

struct Partnership: Codable {
    let runs: Int
    let balls: Int
    let batsman1: String
    let batsman2: String

    var displayPartnership: String {
        "\(runs) runs (\(balls) balls)"
    }
}
