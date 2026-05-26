import Foundation

// MARK: - Volleyball Set Score

struct VolleyballSetScore: Codable, Identifiable {
    var id: Int { setNumber }
    let setNumber: Int
    let homeScore: Int
    let awayScore: Int

    var setLabel: String {
        return "Set \(setNumber)"
    }
}

// MARK: - Volleyball Game

struct VolleyballGame: SportEvent, Codable {
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

    // Volleyball-specific fields
    var setScores: [VolleyballSetScore]
    var currentSet: Int
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
        setScores: [VolleyballSetScore] = [],
        currentSet: Int = 0,
        leagueName: String? = nil,
        leagueSlug: String? = nil
    ) {
        self.id = id
        self.sportType = .volleyball
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
        self.setScores = setScores
        self.currentSet = currentSet
        self.leagueName = leagueName
        self.leagueSlug = leagueSlug
    }
}
