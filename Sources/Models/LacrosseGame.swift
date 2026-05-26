import Foundation

// MARK: - Lacrosse Quarter Score

struct LacrosseQuarterScore: Codable, Identifiable {
    var id: Int { quarter }
    let quarter: Int
    let homeScore: Int
    let awayScore: Int

    var quarterLabel: String {
        switch quarter {
        case 1: return "Q1"
        case 2: return "Q2"
        case 3: return "Q3"
        case 4: return "Q4"
        default: return "OT\(quarter - 4)"
        }
    }
}

// MARK: - Lacrosse Game

struct LacrosseGame: SportEvent, Codable {
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

    // Lacrosse-specific fields
    var quarterScores: [LacrosseQuarterScore]
    var currentQuarter: Int
    var gameClock: String
    var leagueName: String?
    var leagueSlug: String?

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
        quarterScores: [LacrosseQuarterScore] = [],
        currentQuarter: Int = 0,
        gameClock: String = "",
        leagueName: String? = nil,
        leagueSlug: String? = nil
    ) {
        self.id = id
        self.sportType = .lacrosse
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
        self.leagueName = leagueName
        self.leagueSlug = leagueSlug
    }
}
