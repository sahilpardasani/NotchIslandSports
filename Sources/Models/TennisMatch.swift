import Foundation

// MARK: - Tennis Match

struct TennisMatch: SportEvent, Codable {
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

    // Tennis-specific fields
    let player1Name: String
    let player2Name: String
    let player1Country: String
    let player2Country: String
    var sets: [SetScore]
    var currentGameScore: GameScore?
    var activeGameScore: GameScore? {
        return currentGameScore
    }
    var servingPlayer: Int?
    var currentSet: Int
    var tournamentName: String?
    var round: String?
    var isWTA: Bool
    var eventDate: Date?

    init(
        id: String,
        status: MatchStatus,
        player1Name: String,
        player2Name: String,
        player1Country: String = "",
        player2Country: String = "",
        homeScore: String = "",
        awayScore: String = "",
        statusText: String = "",
        homeLogoURL: String? = nil,
        awayLogoURL: String? = nil,
        sets: [SetScore] = [],
        currentGameScore: GameScore? = nil,
        servingPlayer: Int? = nil,
        currentSet: Int = 1,
        tournamentName: String? = nil,
        round: String? = nil,
        isWTA: Bool = false,
        eventDate: Date? = nil
    ) {
        self.id = id
        self.sportType = .tennis
        self.status = status
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.player1Country = player1Country
        self.player2Country = player2Country
        self.homeTeam = player1Name
        self.awayTeam = player2Name
        self.homeTeamAbbrev = String(player1Name.split(separator: " ").last ?? Substring(player1Name)).prefix(3).uppercased()
        self.awayTeamAbbrev = String(player2Name.split(separator: " ").last ?? Substring(player2Name)).prefix(3).uppercased()
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.statusText = statusText
        self.homeLogoURL = homeLogoURL
        self.awayLogoURL = awayLogoURL
        self.sets = sets
        self.currentGameScore = currentGameScore
        self.servingPlayer = servingPlayer
        self.currentSet = currentSet
        self.tournamentName = tournamentName
        self.round = round
        self.isWTA = isWTA
        self.eventDate = eventDate
    }
}

// MARK: - Set Score

struct SetScore: Codable, Identifiable {
    var id: Int { setNumber }
    let setNumber: Int
    let player1Games: Int
    let player2Games: Int
    let tiebreak: Int?

    var displayScore: String {
        if let tb = tiebreak {
            let winner = player1Games > player2Games ? 2 : 1
            let tbDisplay = winner == 1 ? "\(player1Games)-\(player2Games)(\(tb))" : "\(player1Games)(\(tb))-\(player2Games)"
            return tbDisplay
        }
        return "\(player1Games)-\(player2Games)"
    }
}

// MARK: - Game Score

struct GameScore: Codable {
    let player1Points: String
    let player2Points: String

    var displayScore: String {
        "\(player1Points)-\(player2Points)"
    }
}
