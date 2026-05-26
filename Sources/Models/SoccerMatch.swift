import Foundation

// MARK: - Soccer Match

struct SoccerMatch: SportEvent, Codable {
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

    // Soccer-specific fields
    var matchMinute: String
    var period: String
    var goalScorers: [GoalEvent]
    var cards: [CardEvent]
    var halfTimeScore: String?
    var possessionHome: Int?
    var possessionAway: Int?
    var leagueName: String?
    var leagueSlug: String?
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
        matchMinute: String = "",
        period: String = "",
        goalScorers: [GoalEvent] = [],
        cards: [CardEvent] = [],
        halfTimeScore: String? = nil,
        possessionHome: Int? = nil,
        possessionAway: Int? = nil,
        leagueName: String? = nil,
        leagueSlug: String? = nil,
        eventDate: Date? = nil
    ) {
        self.id = id
        self.sportType = .soccer
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
        self.matchMinute = matchMinute
        self.period = period
        self.goalScorers = goalScorers
        self.cards = cards
        self.halfTimeScore = halfTimeScore
        self.possessionHome = possessionHome
        self.possessionAway = possessionAway
        self.leagueName = leagueName
        self.leagueSlug = leagueSlug
        self.eventDate = eventDate
    }
}

// MARK: - Goal Event

struct GoalEvent: Codable, Identifiable {
    var id: String { "\(playerName)-\(minute)-\(team)" }
    let playerName: String
    let minute: String
    let team: String
    let isPenalty: Bool
    let isOwnGoal: Bool

    var displayText: String {
        var text = "\(playerName) \(minute)"
        if isPenalty { text += " (P)" }
        if isOwnGoal { text += " (OG)" }
        return text
    }
}

// MARK: - Card Event

struct CardEvent: Codable, Identifiable {
    var id: String { "\(playerName)-\(minute)-\(cardType.rawValue)" }
    let playerName: String
    let minute: String
    let team: String
    let cardType: CardType

    var displayText: String {
        "\(cardType.icon) \(playerName) \(minute)"
    }
}

// MARK: - Card Type

enum CardType: String, Codable {
    case yellow = "YELLOW"
    case red = "RED"

    var icon: String {
        switch self {
        case .yellow: return "🟨"
        case .red: return "🟥"
        }
    }
}
