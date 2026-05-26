import Foundation

// MARK: - Sport Type

enum SportType: String, CaseIterable, Codable {
    case cricket = "Cricket"
    case tennis = "Tennis"
    case nfl = "NFL"
    case collegeFootball = "College Football"
    case collegeBasketball = "College Basketball"
    case soccer = "Soccer"
    case lacrosse = "Lacrosse"
    case volleyball = "Volleyball"
    case mlb = "MLB"
    case nba = "NBA"
    case nhl = "NHL"
    case collegeHockey = "College Ice Hockey"
    case f1 = "F1"

    var icon: String {
        switch self {
        case .cricket: return "🏏"
        case .tennis: return "🎾"
        case .nfl: return "🏈"
        case .collegeFootball: return "🏈"
        case .collegeBasketball: return "🏀"
        case .soccer: return "⚽"
        case .lacrosse: return "🥍"
        case .volleyball: return "🏐"
        case .mlb: return "⚾"
        case .nba: return "🏀"
        case .nhl: return "🏒"
        case .collegeHockey: return "🏒"
        case .f1: return "🏎️"
        }
    }

    var accentColorHex: String {
        switch self {
        case .cricket: return "#4CAF50"
        case .tennis: return "#FFD700"
        case .nfl: return "#FF6B35"
        case .collegeFootball: return "#8B0000"
        case .collegeBasketball: return "#FF8C00"
        case .soccer: return "#00BCD4"
        case .lacrosse: return "#7B68EE"
        case .volleyball: return "#E91E63"
        case .mlb: return "#09632A"
        case .nba: return "#0C2340"
        case .nhl: return "#444444"
        case .collegeHockey: return "#CC0000"
        case .f1: return "#E10600"
        }
    }
}

// MARK: - Match Status

enum MatchStatus: String, Codable {
    case live = "LIVE"
    case upcoming = "UPCOMING"
    case completed = "FINAL"
    case unknown = "UNKNOWN"
}

// MARK: - Sport Event Protocol

protocol SportEvent: Identifiable {
    var id: String { get }
    var sportType: SportType { get }
    var status: MatchStatus { get }
    var homeTeam: String { get }
    var awayTeam: String { get }
    var homeTeamAbbrev: String { get }
    var awayTeamAbbrev: String { get }
    var homeScore: String { get }
    var awayScore: String { get }
    var statusText: String { get }
    var homeLogoURL: String? { get }
    var awayLogoURL: String? { get }
    var eventDate: Date? { get }
}

// MARK: - ESPN Status Parser (shared utility)

enum ESPNStatusParser {
    /// Parses ESPN's state string (\"pre\", \"in\", \"post\") into our MatchStatus.
    /// Accepts ALL states — never filters out any match.
    static func parseState(_ state: String) -> MatchStatus {
        switch state.lowercased() {
        case "in", "live":
            return .live
        case "pre":
            return .upcoming
        case "post":
            return .completed
        default:
            return .unknown
        }
    }

    /// Parses ESPN's ISO8601 date string into a Date.
    static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString, !dateString.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        // Retry without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
}
