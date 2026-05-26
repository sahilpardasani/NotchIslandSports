import Foundation

// MARK: - NFL Game

struct NFLGame: SportEvent, Codable {
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

    // NFL-specific fields
    var quarterScores: [QuarterScore]
    var currentQuarter: Int
    var gameClock: String
    var situation: GameSituation?
    var lastPlay: String?
    var homeTimeouts: Int
    var awayTimeouts: Int
    var eventDate: Date?

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
        quarterScores: [QuarterScore] = [],
        currentQuarter: Int = 0,
        gameClock: String = "",
        situation: GameSituation? = nil,
        lastPlay: String? = nil,
        homeTimeouts: Int = 3,
        awayTimeouts: Int = 3,
        eventDate: Date? = nil
    ) {
        self.id = id
        self.sportType = .nfl
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
        self.quarterScores = quarterScores
        self.currentQuarter = currentQuarter
        self.gameClock = gameClock
        self.situation = situation
        self.lastPlay = lastPlay
        self.homeTimeouts = homeTimeouts
        self.awayTimeouts = awayTimeouts
        self.eventDate = eventDate
    }
}

// MARK: - Quarter Score

struct QuarterScore: Codable, Identifiable {
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

// MARK: - Game Situation

struct GameSituation: Codable {
    let down: Int
    let distance: Int
    let yardLine: Int
    let possession: String
    let isRedZone: Bool
    let yardsToEndzone: Int

    var downAndDistanceText: String {
        let ordinal: String
        switch down {
        case 1: ordinal = "1st"
        case 2: ordinal = "2nd"
        case 3: ordinal = "3rd"
        case 4: ordinal = "4th"
        default: ordinal = "\(down)th"
        }
        return "\(ordinal) & \(distance)"
    }

    var fieldPositionText: String {
        if yardLine == 50 {
            return "50 yd line"
        }
        return "\(possession) \(yardLine)"
    }

    var displayText: String {
        "\(downAndDistanceText) at \(fieldPositionText)"
    }
}
