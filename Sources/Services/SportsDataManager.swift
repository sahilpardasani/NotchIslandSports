import Foundation
import Combine
import SwiftUI
import os
import IslandCore

// MARK: - AnyMatch (Type-Erased Sport Event Wrapper)

enum AnyMatch: Identifiable {
    case cricket(CricketMatch)
    case tennis(TennisMatch)
    case nfl(NFLGame)
    case collegeFootball(CollegeFootballGame)
    case collegeBasketball(CollegeBasketballGame)
    case soccer(SoccerMatch)
    case lacrosse(LacrosseGame)
    case volleyball(VolleyballGame)
    case mlb(MLBGame)
    case nba(NBAGame)
    case nhl(NHLGame)
    case collegeHockey(CollegeHockeyGame)
    case f1(F1Race)

    var identity: String {
        let scope: String
        switch self {
        case .soccer(let m): scope = m.leagueSlug ?? ""
        case .cricket(let m): scope = m.leagueId ?? ""
        case .tennis(let m): scope = m.isWTA ? "wta" : "atp"
        case .lacrosse(let m): scope = m.leagueSlug ?? ""
        case .volleyball(let m): scope = m.leagueSlug ?? ""
        default: scope = ""
        }
        return "\(sportType.rawValue):\(scope):\(id)"
    }

    var id: String {
        switch self {
        case .cricket(let m): return m.id
        case .tennis(let m): return m.id
        case .nfl(let m): return m.id
        case .collegeFootball(let m): return m.id
        case .collegeBasketball(let m): return m.id
        case .soccer(let m): return m.id
        case .lacrosse(let m): return m.id
        case .volleyball(let m): return m.id
        case .mlb(let m): return m.id
        case .nba(let m): return m.id
        case .nhl(let m): return m.id
        case .collegeHockey(let m): return m.id
        case .f1(let m): return m.id
        }
    }

    var sportType: SportType {
        switch self {
        case .cricket: return .cricket
        case .tennis: return .tennis
        case .nfl: return .nfl
        case .collegeFootball: return .collegeFootball
        case .collegeBasketball: return .collegeBasketball
        case .soccer: return .soccer
        case .lacrosse: return .lacrosse
        case .volleyball: return .volleyball
        case .mlb: return .mlb
        case .nba: return .nba
        case .nhl: return .nhl
        case .collegeHockey: return .collegeHockey
        case .f1: return .f1
        }
    }

    var status: MatchStatus {
        switch self {
        case .cricket(let m): return m.status
        case .tennis(let m): return m.status
        case .nfl(let m): return m.status
        case .collegeFootball(let m): return m.status
        case .collegeBasketball(let m): return m.status
        case .soccer(let m): return m.status
        case .lacrosse(let m): return m.status
        case .volleyball(let m): return m.status
        case .mlb(let m): return m.status
        case .nba(let m): return m.status
        case .nhl(let m): return m.status
        case .collegeHockey(let m): return m.status
        case .f1(let m): return m.status
        }
    }

    var homeTeam: String {
        switch self {
        case .cricket(let m): return m.homeTeam
        case .tennis(let m): return m.homeTeam
        case .nfl(let m): return m.homeTeam
        case .collegeFootball(let m): return m.homeTeam
        case .collegeBasketball(let m): return m.homeTeam
        case .soccer(let m): return m.homeTeam
        case .lacrosse(let m): return m.homeTeam
        case .volleyball(let m): return m.homeTeam
        case .mlb(let m): return m.homeTeam
        case .nba(let m): return m.homeTeam
        case .nhl(let m): return m.homeTeam
        case .collegeHockey(let m): return m.homeTeam
        case .f1(let m): return m.homeTeam
        }
    }

    var awayTeam: String {
        switch self {
        case .cricket(let m): return m.awayTeam
        case .tennis(let m): return m.awayTeam
        case .nfl(let m): return m.awayTeam
        case .collegeFootball(let m): return m.awayTeam
        case .collegeBasketball(let m): return m.awayTeam
        case .soccer(let m): return m.awayTeam
        case .lacrosse(let m): return m.awayTeam
        case .volleyball(let m): return m.awayTeam
        case .mlb(let m): return m.awayTeam
        case .nba(let m): return m.awayTeam
        case .nhl(let m): return m.awayTeam
        case .collegeHockey(let m): return m.awayTeam
        case .f1(let m): return m.awayTeam
        }
    }

    var homeTeamAbbrev: String {
        switch self {
        case .cricket(let m): return m.homeTeamAbbrev
        case .tennis(let m): return m.homeTeamAbbrev
        case .nfl(let m): return m.homeTeamAbbrev
        case .collegeFootball(let m): return m.homeTeamAbbrev
        case .collegeBasketball(let m): return m.homeTeamAbbrev
        case .soccer(let m): return m.homeTeamAbbrev
        case .lacrosse(let m): return m.homeTeamAbbrev
        case .volleyball(let m): return m.homeTeamAbbrev
        case .mlb(let m): return m.homeTeamAbbrev
        case .nba(let m): return m.homeTeamAbbrev
        case .nhl(let m): return m.homeTeamAbbrev
        case .collegeHockey(let m): return m.homeTeamAbbrev
        case .f1(let m): return m.homeTeamAbbrev
        }
    }

    var awayTeamAbbrev: String {
        switch self {
        case .cricket(let m): return m.awayTeamAbbrev
        case .tennis(let m): return m.awayTeamAbbrev
        case .nfl(let m): return m.awayTeamAbbrev
        case .collegeFootball(let m): return m.awayTeamAbbrev
        case .collegeBasketball(let m): return m.awayTeamAbbrev
        case .soccer(let m): return m.awayTeamAbbrev
        case .lacrosse(let m): return m.awayTeamAbbrev
        case .volleyball(let m): return m.awayTeamAbbrev
        case .mlb(let m): return m.awayTeamAbbrev
        case .nba(let m): return m.awayTeamAbbrev
        case .nhl(let m): return m.awayTeamAbbrev
        case .collegeHockey(let m): return m.awayTeamAbbrev
        case .f1(let m): return m.awayTeamAbbrev
        }
    }

    var homeScore: String {
        switch self {
        case .cricket(let m): return m.homeScore
        case .tennis(let m): return m.homeScore
        case .nfl(let m): return m.homeScore
        case .collegeFootball(let m): return m.homeScore
        case .collegeBasketball(let m): return m.homeScore
        case .soccer(let m): return m.homeScore
        case .lacrosse(let m): return m.homeScore
        case .volleyball(let m): return m.homeScore
        case .mlb(let m): return m.homeScore
        case .nba(let m): return m.homeScore
        case .nhl(let m): return m.homeScore
        case .collegeHockey(let m): return m.homeScore
        case .f1(let m): return m.homeScore
        }
    }

    var awayScore: String {
        switch self {
        case .cricket(let m): return m.awayScore
        case .tennis(let m): return m.awayScore
        case .nfl(let m): return m.awayScore
        case .collegeFootball(let m): return m.awayScore
        case .collegeBasketball(let m): return m.awayScore
        case .soccer(let m): return m.awayScore
        case .lacrosse(let m): return m.awayScore
        case .volleyball(let m): return m.awayScore
        case .mlb(let m): return m.awayScore
        case .nba(let m): return m.awayScore
        case .nhl(let m): return m.awayScore
        case .collegeHockey(let m): return m.awayScore
        case .f1(let m): return m.awayScore
        }
    }

    var statusText: String {
        switch self {
        case .cricket(let m): return m.statusText
        case .tennis(let m): return m.statusText
        case .nfl(let m): return m.statusText
        case .collegeFootball(let m): return m.statusText
        case .collegeBasketball(let m): return m.statusText
        case .soccer(let m): return m.statusText
        case .lacrosse(let m): return m.statusText
        case .volleyball(let m): return m.statusText
        case .mlb(let m): return m.statusText
        case .nba(let m): return m.statusText
        case .nhl(let m): return m.statusText
        case .collegeHockey(let m): return m.statusText
        case .f1(let m): return m.statusText
        }
    }

    var homeLogoURL: String? {
        switch self {
        case .cricket(let m): return m.homeLogoURL
        case .tennis(let m): return m.homeLogoURL
        case .nfl(let m): return m.homeLogoURL
        case .collegeFootball(let m): return m.homeLogoURL
        case .collegeBasketball(let m): return m.homeLogoURL
        case .soccer(let m): return m.homeLogoURL
        case .lacrosse(let m): return m.homeLogoURL
        case .volleyball(let m): return m.homeLogoURL
        case .mlb(let m): return m.homeLogoURL
        case .nba(let m): return m.homeLogoURL
        case .nhl(let m): return m.homeLogoURL
        case .collegeHockey(let m): return m.homeLogoURL
        case .f1(let m): return m.homeLogoURL
        }
    }

    var awayLogoURL: String? {
        switch self {
        case .cricket(let m): return m.awayLogoURL
        case .tennis(let m): return m.awayLogoURL
        case .nfl(let m): return m.awayLogoURL
        case .collegeFootball(let m): return m.awayLogoURL
        case .collegeBasketball(let m): return m.awayLogoURL
        case .soccer(let m): return m.awayLogoURL
        case .lacrosse(let m): return m.awayLogoURL
        case .volleyball(let m): return m.awayLogoURL
        case .mlb(let m): return m.awayLogoURL
        case .nba(let m): return m.awayLogoURL
        case .nhl(let m): return m.awayLogoURL
        case .collegeHockey(let m): return m.awayLogoURL
        case .f1(let m): return m.awayLogoURL
        }
    }

    var eventDate: Date? {
        switch self {
        case .cricket(let m): return m.eventDate
        case .tennis(let m): return m.eventDate
        case .nfl(let m): return m.eventDate
        case .collegeFootball(let m): return m.eventDate
        case .collegeBasketball(let m): return m.eventDate
        case .soccer(let m): return m.eventDate
        case .lacrosse(let m): return m.eventDate
        case .volleyball(let m): return m.eventDate
        case .mlb(let m): return m.eventDate
        case .nba(let m): return m.eventDate
        case .nhl(let m): return m.eventDate
        case .collegeHockey(let m): return m.eventDate
        case .f1(let m): return m.eventDate
        }
    }

    /// Whether this match is currently live.
    var isLive: Bool {
        status == .live
    }

    /// Whether this match is a completed/historical result.
    var isCompleted: Bool {
        status == .completed
    }

    /// Whether this is a fallback (most recent completed) when no live/upcoming exist for the sport.
    var isFallbackResult: Bool {
        // This is a display hint — checked externally by the data manager
        false
    }
}

// MARK: - Persistence Keys

private enum StorageKeys {
    static let activeMatchId = "NotchIsland_ActiveMatchId"
    static let activeMatchSport = "NotchIsland_ActiveMatchSport"
    static let activeMatchLeague = "NotchIsland_ActiveMatchLeague"
    static let activeMatchIsWTA = "NotchIsland_ActiveMatchIsWTA"
    static let isHindiSelected = "NotchIsland_IsHindiSelected"
}

// MARK: - Sports Data Manager

@MainActor
class SportsDataManager: ObservableObject {

    // MARK: - Published State

    @Published var allMatches: [AnyMatch] = []
    @Published var activeMatch: AnyMatch? {
        didSet {
            if oldValue?.identity != activeMatch?.identity {
                selectionGeneration.invalidate()
                detailTask?.cancel()
                detailTask = nil
                detailRequestID = nil
                lastDetailUpdate = nil
                detailError = nil
                detailFailures = 0
                scheduleDetail(after: 0.2)
            } else if oldValue?.status != activeMatch?.status && detailTask == nil {
                // A catalog update can move a selected match from upcoming to live.
                scheduleDetail(after: 0.2)
            }
        }
    }
    @Published private(set) var lastDetailUpdate: Date?
    @Published private(set) var detailError: String?
    var isExpanded = false
    var lowPowerMode = false
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var selectedSportFilter: SportType? = nil {
        didSet {
            guard selectedSportFilter != oldValue else { return }
            autoSelectActiveMatch()
        }
    }
    @Published var showMatchSelector = false {
        didSet { if oldValue != showMatchSelector { scheduleDiscovery() } }
    }
    @Published var isUsingMockData = false
    @Published var forceNotchLayout = false
    @Published var hasNotch = false
    @Published var notchWidth: CGFloat = 150
    @Published var isHindi = UserDefaults.standard.bool(forKey: StorageKeys.isHindiSelected) {
        didSet {
            UserDefaults.standard.set(isHindi, forKey: StorageKeys.isHindiSelected)
        }
    }

    /// Tracks which sports have ONLY completed (fallback) matches and no live/upcoming.
    @Published var fallbackSports: Set<SportType> = []

    // MARK: - Local In-Memory Cache for Error/Empty Responses Fallback
    private var cachedCricketMatches: [CricketMatch] = []
    private var cachedTennisMatches: [TennisMatch] = []
    private var cachedNFLGames: [NFLGame] = []
    private var cachedCFBGames: [CollegeFootballGame] = []
    private var cachedCBBGames: [CollegeBasketballGame] = []
    private var cachedSoccerMatches: [SoccerMatch] = []
    private var cachedLacrosseGames: [LacrosseGame] = []
    private var cachedVolleyballGames: [VolleyballGame] = []
    private var cachedMLBGames: [MLBGame] = []
    private var cachedNBAGames: [NBAGame] = []
    private var cachedNHLGames: [NHLGame] = []
    private var cachedCollegeHockeyGames: [CollegeHockeyGame] = []
    private var cachedF1Races: [F1Race] = []

    // MARK: - Services

    private let detailLoader: ((AnyMatch) async throws -> AnyMatch)?
    private let cricketService = CricketService()
    private let tennisService = TennisService()
    private let nflService = NFLService()
    private let collegeFootballService = CollegeFootballService()
    private let collegeBasketballService = CollegeBasketballService()
    private let soccerService = SoccerService()
    private let lacrosseService = LacrosseService()
    private let volleyballService = VolleyballService()
    private let mlbService = MLBService()
    private let nbaService = NBAService()
    private let nhlService = NHLService()
    private let collegeHockeyService = CollegeHockeyService()
    private let f1Service = F1Service()

    // MARK: - Timers

    private var pollingTimer: Timer?
    private var detailTimer: Timer?
    private var discoveryTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?
    private var detailRequestID: UUID?
    private var discoveryRequestID: UUID?
    private var lifecycleGeneration = RequestGeneration()
    private var selectionGeneration = RequestGeneration()
    private var isPolling = false
    private var suspended = false
    private var discoveryFailures = 0
    private var lastDiscoveryAt: Date?
    private var cacheDates: [SportType: Date] = [:]
    private var detailFailures = 0

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.notchisland.sports", category: "SportsDataManager")

    // MARK: - Computed Properties

    /// Matches filtered by the currently selected sport type.
    var filteredMatches: [AnyMatch] {
        guard let filter = selectedSportFilter else {
            return allMatches
        }
        return allMatches.filter { $0.sportType == filter }
    }

    /// Only live matches, sorted by sport type.
    var liveMatches: [AnyMatch] {
        allMatches.filter { $0.isLive }
    }

    /// Check if a specific match is a fallback (from a sport with no active/upcoming games).
    func isFallbackMatch(_ match: AnyMatch) -> Bool {
        return match.isCompleted && fallbackSports.contains(match.sportType)
    }

    // MARK: - Lifecycle

    #if DEBUG
    private func shouldRunMockData() -> Bool {
        // --- XCODE PREVIEW & MOCK DATA TRIGGER ---
        // Change this return to `true` to pre-populate mock data for all sports.
        // Once done testing, set it to `false` or delete the "Sources/Debug" folder.
        return false
    }
    #endif

    private let selectionDefaults: UserDefaults
    init(selectionDefaults: UserDefaults = .standard, detailLoader: ((AnyMatch) async throws -> AnyMatch)? = nil) {
        self.selectionDefaults = selectionDefaults
        self.detailLoader = detailLoader
        #if DEBUG
        if shouldRunMockData() {
            self.isUsingMockData = true
            MockDataProvider.setupMockData(for: self)
            return
        }
        #endif

        restoreActiveMatch()
    }

    deinit {
        pollingTimer?.invalidate()
        detailTimer?.invalidate()
    }

    // MARK: - Polling Control

    func startPolling() {
        guard !isPolling else { return }
        isPolling = true
        suspended = false
        if EnergyPolicy.discoveryNeeded(age: lastDiscoveryAt.map { Date().timeIntervalSince($0) },
                                        browsing: showMatchSelector, lowPower: lowPowerMode) {
            requestDiscovery()
        } else { scheduleDiscovery() }
        scheduleDetail(after: 1)
    }

    func stopPolling() {
        isPolling = false
        suspended = true
        lifecycleGeneration.invalidate()
        pollingTimer?.invalidate(); pollingTimer = nil
        detailTimer?.invalidate(); detailTimer = nil
        discoveryTask?.cancel(); discoveryTask = nil
        detailTask?.cancel(); detailTask = nil
        discoveryRequestID = nil; detailRequestID = nil
        isLoading = false
    }

    func requestDiscovery() {
        guard !suspended else { return }
        Task { [weak self] in await self?.fetchAllMatches() }
    }

    private func scheduleDiscovery() {
        guard isPolling else { return }
        pollingTimer?.invalidate()
        let interval = PollPolicy.discovery(browsing: showMatchSelector,
                                            lowPower: lowPowerMode, failures: discoveryFailures)
        pollingTimer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.requestDiscovery() }
        }
        pollingTimer?.tolerance = interval * 0.15
        if let pollingTimer { RunLoop.main.add(pollingTimer, forMode: .common) }
    }

    private func scheduleDetail(after delay: TimeInterval? = nil) {
        guard isPolling else { return }
        let existingDeadline = detailTimer?.isValid == true ? detailTimer?.fireDate : nil
        detailTimer?.invalidate()
        guard activeMatch != nil else { detailTimer = nil; return }
        let interval = delay ?? PollPolicy.detail(live: activeMatch?.isLive == true,
            completed: activeMatch?.isCompleted == true, expanded: isExpanded,
            lowPower: lowPowerMode, failures: detailFailures)
        let nextDelay = min(interval, existingDeadline.map { max(0.01, $0.timeIntervalSinceNow) } ?? interval)
        detailTimer = Timer(timeInterval: nextDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in await self?.fetchActiveMatchDetail() }
        }
        detailTimer?.tolerance = activeMatch?.isLive == true ? min(0.25, nextDelay * 0.1) : nextDelay * 0.1
        if let detailTimer { RunLoop.main.add(detailTimer, forMode: .common) }
    }

    func setPresentation(expanded: Bool, lowPower: Bool) {
        guard expanded != isExpanded || lowPower != lowPowerMode else { return }
        let becameExpanded = expanded && !isExpanded
        isExpanded = expanded
        lowPowerMode = lowPower
        if becameExpanded && isPolling { scheduleDetail(after: 0.2) }
        else { scheduleDetail() }
        scheduleDiscovery()
    }

    func refresh() async {
        guard !suspended else { return }
        async let catalog: Void = fetchAllMatches()
        await fetchActiveMatchDetail()
        await catalog
    }

    func fetchAllMatches() async {
        guard !suspended, !isUsingMockData else { return }
        if let discoveryTask { await discoveryTask.value; return }
        let requestID = UUID()
        discoveryRequestID = requestID
        let generation = lifecycleGeneration.value
        let task = Task { await performDiscovery(generation: generation) }
        discoveryTask = task
        await task.value
        guard discoveryRequestID == requestID else { return }
        discoveryTask = nil
        discoveryRequestID = nil
        scheduleDiscovery()
    }

    func fetchActiveMatchDetail() async {
        guard !suspended, !isUsingMockData else { return }
        if let detailTask { await detailTask.value; return }
        detailTimer?.invalidate(); detailTimer = nil
        let requestID = UUID()
        detailRequestID = requestID
        let generation = lifecycleGeneration.value
        let selection = selectionGeneration.value
        let task = Task { await performDetail(generation: generation, selection: selection) }
        detailTask = task
        await task.value
        guard detailRequestID == requestID else { return }
        detailTask = nil
        detailRequestID = nil
        scheduleDetail()
    }

    // MARK: - Fetch All Matches

    private func performDiscovery(generation: UInt64) async {
        if isUsingMockData { return }
        isLoading = true
        lastError = nil

        var cricketMatches: [CricketMatch] = []
        var tennisMatches: [TennisMatch] = []
        var nflGames: [NFLGame] = []
        var cfbGames: [CollegeFootballGame] = []
        var cbbGames: [CollegeBasketballGame] = []
        var soccerMatches: [SoccerMatch] = []
        var lacrosseGames: [LacrosseGame] = []
        var volleyballGames: [VolleyballGame] = []
        var mlbGames: [MLBGame] = []
        var nbaGames: [NBAGame] = []
        var nhlGames: [NHLGame] = []
        var collegeHockeyGames: [CollegeHockeyGame] = []
        var f1Races: [F1Race] = []
        var errors: [String] = []
        let startedAt = Date()
        var staleSports = Set<SportType>()

        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor [self] in
                do {
                    let fetched = try await self.cricketService.fetchMatches()
                    if !fetched.isEmpty {
                        cricketMatches = fetched
                        guard !Task.isCancelled, self.lifecycleGeneration.accepts(generation) else { return }
                        self.cachedCricketMatches = fetched
                        self.cacheDates[.cricket] = Date()
                    } else {
                        cricketMatches = self.cacheDates[.cricket].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedCricketMatches : []
                        if !cricketMatches.isEmpty { staleSports.insert(.cricket) }
                    }
                } catch {
                    errors.append("Cricket: \(error.localizedDescription)")
                    self.logger.error("Cricket fetch failed: \(error.localizedDescription)")
                    cricketMatches = self.cacheDates[.cricket].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedCricketMatches : []
                        if !cricketMatches.isEmpty { staleSports.insert(.cricket) }
                }
            }
            group.addTask { @MainActor [self] in
                do {
                    let fetched = try await self.tennisService.fetchMatches()
                    if !fetched.isEmpty {
                        tennisMatches = fetched
                        guard !Task.isCancelled, self.lifecycleGeneration.accepts(generation) else { return }
                        self.cachedTennisMatches = fetched
                        self.cacheDates[.tennis] = Date()
                    } else {
                        tennisMatches = self.cacheDates[.tennis].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedTennisMatches : []
                        if !tennisMatches.isEmpty { staleSports.insert(.tennis) }
                    }
                } catch {
                    errors.append("Tennis: \(error.localizedDescription)")
                    self.logger.error("Tennis fetch failed: \(error.localizedDescription)")
                    tennisMatches = self.cacheDates[.tennis].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedTennisMatches : []
                        if !tennisMatches.isEmpty { staleSports.insert(.tennis) }
                }
            }
            group.addTask { @MainActor [self] in
                do {
                    let fetched = try await self.nflService.fetchGames()
                    if !fetched.isEmpty {
                        nflGames = fetched
                        guard !Task.isCancelled, self.lifecycleGeneration.accepts(generation) else { return }
                        self.cachedNFLGames = fetched
                        self.cacheDates[.nfl] = Date()
                    } else {
                        nflGames = self.cacheDates[.nfl].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedNFLGames : []
                        if !nflGames.isEmpty { staleSports.insert(.nfl) }
                    }
                } catch {
                    errors.append("NFL: \(error.localizedDescription)")
                    self.logger.error("NFL fetch failed: \(error.localizedDescription)")
                    nflGames = self.cacheDates[.nfl].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedNFLGames : []
                        if !nflGames.isEmpty { staleSports.insert(.nfl) }
                }
            }
            group.addTask { @MainActor [self] in
                do {
                    let fetched = try await self.collegeFootballService.fetchGames()
                    if !fetched.isEmpty {
                        cfbGames = fetched
                        guard !Task.isCancelled, self.lifecycleGeneration.accepts(generation) else { return }
                        self.cachedCFBGames = fetched
                        self.cacheDates[.collegeFootball] = Date()
                    } else {
                        cfbGames = self.cacheDates[.collegeFootball].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedCFBGames : []
                        if !cfbGames.isEmpty { staleSports.insert(.collegeFootball) }
                    }
                } catch {
                    errors.append("CFB: \(error.localizedDescription)")
                    self.logger.error("CFB fetch failed: \(error.localizedDescription)")
                    cfbGames = self.cacheDates[.collegeFootball].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedCFBGames : []
                        if !cfbGames.isEmpty { staleSports.insert(.collegeFootball) }
                }
            }
            group.addTask { @MainActor [self] in
                do {
                    let fetched = try await self.collegeBasketballService.fetchGames()
                    if !fetched.isEmpty {
                        cbbGames = fetched
                        guard !Task.isCancelled, self.lifecycleGeneration.accepts(generation) else { return }
                        self.cachedCBBGames = fetched
                        self.cacheDates[.collegeBasketball] = Date()
                    } else {
                        cbbGames = self.cacheDates[.collegeBasketball].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedCBBGames : []
                        if !cbbGames.isEmpty { staleSports.insert(.collegeBasketball) }
                    }
                } catch {
                    errors.append("CBB: \(error.localizedDescription)")
                    self.logger.error("CBB fetch failed: \(error.localizedDescription)")
                    cbbGames = self.cacheDates[.collegeBasketball].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedCBBGames : []
                        if !cbbGames.isEmpty { staleSports.insert(.collegeBasketball) }
                }
            }
            group.addTask { @MainActor [self] in
                do {
                    let fetched = try await self.soccerService.fetchMatches()
                    if !fetched.isEmpty {
                        soccerMatches = fetched
                        guard !Task.isCancelled, self.lifecycleGeneration.accepts(generation) else { return }
                        self.cachedSoccerMatches = fetched
                        self.cacheDates[.soccer] = Date()
                    } else {
                        soccerMatches = self.cacheDates[.soccer].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedSoccerMatches : []
                        if !soccerMatches.isEmpty { staleSports.insert(.soccer) }
                    }
                } catch {
                    errors.append("Soccer: \(error.localizedDescription)")
                    self.logger.error("Soccer fetch failed: \(error.localizedDescription)")
                    soccerMatches = self.cacheDates[.soccer].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedSoccerMatches : []
                        if !soccerMatches.isEmpty { staleSports.insert(.soccer) }
                }
            }
            group.addTask { @MainActor [self] in
                do {
                    let fetched = try await self.lacrosseService.fetchGames()
                    if !fetched.isEmpty {
                        lacrosseGames = fetched
                        guard !Task.isCancelled, self.lifecycleGeneration.accepts(generation) else { return }
                        self.cachedLacrosseGames = fetched
                        self.cacheDates[.lacrosse] = Date()
                    } else {
                        lacrosseGames = self.cacheDates[.lacrosse].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedLacrosseGames : []
                        if !lacrosseGames.isEmpty { staleSports.insert(.lacrosse) }
                    }
                } catch {
                    errors.append("Lacrosse: \(error.localizedDescription)")
                    self.logger.error("Lacrosse fetch failed: \(error.localizedDescription)")
                    lacrosseGames = self.cacheDates[.lacrosse].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedLacrosseGames : []
                        if !lacrosseGames.isEmpty { staleSports.insert(.lacrosse) }
                }
            }
            group.addTask { @MainActor [self] in
                do {
                    let fetched = try await self.volleyballService.fetchGames()
                    if !fetched.isEmpty {
                        volleyballGames = fetched
                        guard !Task.isCancelled, self.lifecycleGeneration.accepts(generation) else { return }
                        self.cachedVolleyballGames = fetched
                        self.cacheDates[.volleyball] = Date()
                    } else {
                        volleyballGames = self.cacheDates[.volleyball].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedVolleyballGames : []
                        if !volleyballGames.isEmpty { staleSports.insert(.volleyball) }
                    }
                } catch {
                    errors.append("Volleyball: \(error.localizedDescription)")
                    self.logger.error("Volleyball fetch failed: \(error.localizedDescription)")
                    volleyballGames = self.cacheDates[.volleyball].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedVolleyballGames : []
                        if !volleyballGames.isEmpty { staleSports.insert(.volleyball) }
                }
            }
            group.addTask { @MainActor [self] in
                do {
                    let fetched = try await self.mlbService.fetchGames()
                    if !fetched.isEmpty {
                        mlbGames = fetched
                        guard !Task.isCancelled, self.lifecycleGeneration.accepts(generation) else { return }
                        self.cachedMLBGames = fetched
                        self.cacheDates[.mlb] = Date()
                    } else {
                        mlbGames = self.cacheDates[.mlb].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedMLBGames : []
                        if !mlbGames.isEmpty { staleSports.insert(.mlb) }
                    }
                } catch {
                    errors.append("MLB: \(error.localizedDescription)")
                    self.logger.error("MLB fetch failed: \(error.localizedDescription)")
                    mlbGames = self.cacheDates[.mlb].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedMLBGames : []
                        if !mlbGames.isEmpty { staleSports.insert(.mlb) }
                }
            }
            group.addTask { @MainActor [self] in
                do {
                    let fetched = try await self.nbaService.fetchGames()
                    if !fetched.isEmpty {
                        nbaGames = fetched
                        guard !Task.isCancelled, self.lifecycleGeneration.accepts(generation) else { return }
                        self.cachedNBAGames = fetched
                        self.cacheDates[.nba] = Date()
                    } else {
                        nbaGames = self.cacheDates[.nba].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedNBAGames : []
                        if !nbaGames.isEmpty { staleSports.insert(.nba) }
                    }
                } catch {
                    errors.append("NBA: \(error.localizedDescription)")
                    self.logger.error("NBA fetch failed: \(error.localizedDescription)")
                    nbaGames = self.cacheDates[.nba].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedNBAGames : []
                        if !nbaGames.isEmpty { staleSports.insert(.nba) }
                }
            }
            group.addTask { @MainActor [self] in
                do {
                    let fetched = try await self.nhlService.fetchGames()
                    if !fetched.isEmpty {
                        nhlGames = fetched
                        guard !Task.isCancelled, self.lifecycleGeneration.accepts(generation) else { return }
                        self.cachedNHLGames = fetched
                        self.cacheDates[.nhl] = Date()
                    } else {
                        nhlGames = self.cacheDates[.nhl].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedNHLGames : []
                        if !nhlGames.isEmpty { staleSports.insert(.nhl) }
                    }
                } catch {
                    errors.append("NHL: \(error.localizedDescription)")
                    self.logger.error("NHL fetch failed: \(error.localizedDescription)")
                    nhlGames = self.cacheDates[.nhl].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedNHLGames : []
                        if !nhlGames.isEmpty { staleSports.insert(.nhl) }
                }
            }
            group.addTask { @MainActor [self] in
                do {
                    let fetched = try await self.collegeHockeyService.fetchGames()
                    if !fetched.isEmpty {
                        collegeHockeyGames = fetched
                        guard !Task.isCancelled, self.lifecycleGeneration.accepts(generation) else { return }
                        self.cachedCollegeHockeyGames = fetched
                        self.cacheDates[.collegeHockey] = Date()
                    } else {
                        collegeHockeyGames = self.cacheDates[.collegeHockey].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedCollegeHockeyGames : []
                        if !collegeHockeyGames.isEmpty { staleSports.insert(.collegeHockey) }
                    }
                } catch {
                    errors.append("College Hockey: \(error.localizedDescription)")
                    self.logger.error("College Hockey fetch failed: \(error.localizedDescription)")
                    collegeHockeyGames = self.cacheDates[.collegeHockey].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedCollegeHockeyGames : []
                        if !collegeHockeyGames.isEmpty { staleSports.insert(.collegeHockey) }
                }
            }
            group.addTask { @MainActor [self] in
                do {
                    let fetched = try await self.f1Service.fetchRaces()
                    if !fetched.isEmpty {
                        f1Races = fetched
                        guard !Task.isCancelled, self.lifecycleGeneration.accepts(generation) else { return }
                        self.cachedF1Races = fetched
                        self.cacheDates[.f1] = Date()
                    } else {
                        f1Races = self.cacheDates[.f1].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedF1Races : []
                        if !f1Races.isEmpty { staleSports.insert(.f1) }
                    }
                } catch {
                    errors.append("F1: \(error.localizedDescription)")
                    self.logger.error("F1 fetch failed: \(error.localizedDescription)")
                    f1Races = self.cacheDates[.f1].map { Date().timeIntervalSince($0) < 900 } == true ? self.cachedF1Races : []
                        if !f1Races.isEmpty { staleSports.insert(.f1) }
                }
            }

            await group.waitForAll()
        }

        guard !Task.isCancelled, lifecycleGeneration.accepts(generation) else { return }
        lastDiscoveryAt = Date()
        discoveryFailures = errors.isEmpty ? 0 : discoveryFailures + 1

        // Build unified match list — include ALL statuses
        var combined: [AnyMatch] = []
        combined.append(contentsOf: cricketMatches.map { .cricket($0) })
        combined.append(contentsOf: tennisMatches.map { .tennis($0) })
        combined.append(contentsOf: nflGames.map { .nfl($0) })
        combined.append(contentsOf: cfbGames.map { .collegeFootball($0) })
        combined.append(contentsOf: cbbGames.map { .collegeBasketball($0) })
        combined.append(contentsOf: soccerMatches.map { .soccer($0) })
        combined.append(contentsOf: lacrosseGames.map { .lacrosse($0) })
        combined.append(contentsOf: volleyballGames.map { .volleyball($0) })
        combined.append(contentsOf: mlbGames.map { .mlb($0) })
        combined.append(contentsOf: nbaGames.map { .nba($0) })
        combined.append(contentsOf: nhlGames.map { .nhl($0) })
        combined.append(contentsOf: collegeHockeyGames.map { .collegeHockey($0) })
        combined.append(contentsOf: f1Races.map { .f1($0) })

        // Centrally filter out completed matches older than 48 hours (2 days)
        let now = Date()
        let maxAge: TimeInterval = 48 * 60 * 60
        combined = combined.filter { match in
            if match.status == .completed {
                if let eventDate = match.eventDate {
                    let age = now.timeIntervalSince(eventDate)
                    return age <= maxAge
                }
                return false // Exclude completed matches that have no date
            }
            return true
        }

        // Track which sports are fallback-only (no live or upcoming, only completed)
        var newFallbackSports = Set<SportType>()
        for sport in SportType.allCases {
            let sportMatches = combined.filter { $0.sportType == sport }
            let hasActiveOrUpcoming = sportMatches.contains { $0.status == .live || $0.status == .upcoming }
            if !hasActiveOrUpcoming && !sportMatches.isEmpty {
                newFallbackSports.insert(sport)
            }
        }
        fallbackSports = newFallbackSports

        // Sort: live first, then upcoming by date, then most-recent completed
        combined.sort { lhs, rhs in
            let lhsPriority = statusPriority(lhs.status)
            let rhsPriority = statusPriority(rhs.status)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }

            // Within same status, sort by eventDate
            if let d1 = lhs.eventDate, let d2 = rhs.eventDate {
                if lhs.status == .completed {
                    return d1 > d2  // Most recent completed first
                } else {
                    return d1 < d2  // Soonest upcoming first
                }
            }
            // Items with dates come before items without
            if lhs.eventDate != nil && rhs.eventDate == nil { return true }
            if lhs.eventDate == nil && rhs.eventDate != nil { return false }
            return false
        }

        // Merge detailed properties from current allMatches to preserve live scorecards/stats
        combined = combined.map { newMatch in
            if let existing = self.allMatches.first(where: { $0.identity == newMatch.identity }) {
                return self.mergeMatchDetails(from: existing, to: newMatch)
            }
            return newMatch
        }

        // A slower discovery snapshot must not roll back a newer selected-detail response.
        if let updatedAt = lastDetailUpdate, updatedAt > startedAt, let current = activeMatch,
           let index = combined.firstIndex(where: { $0.identity == current.identity }) {
            combined[index] = current
        }
        allMatches = combined

        if !staleSports.isEmpty {
            errors.append("Showing cached scores for " + staleSports.map(\.rawValue).sorted().joined(separator: ", "))
        }
        lastError = errors.isEmpty ? nil : errors.joined(separator: "; ")

        isLoading = false
        logger.info("Fetched \(combined.count) total matches across 13 sports (fallback sports: \(newFallbackSports.map { $0.rawValue }))")

        if activeMatch == nil {
            restoreActiveMatch()
        }
        autoSelectActiveMatch()
    }

    // MARK: - Select Match

    func selectMatch(_ match: AnyMatch) {
        activeMatch = match
        persistActiveMatch(match)

        Task {
            await fetchActiveMatchDetail()
        }

        logger.info("Selected match: \(match.homeTeamAbbrev) vs \(match.awayTeamAbbrev) (\(match.sportType.rawValue))")
    }

    func clearActiveMatch() {
        activeMatch = nil
        selectionDefaults.removeObject(forKey: StorageKeys.activeMatchId)
        selectionDefaults.removeObject(forKey: StorageKeys.activeMatchSport)
        selectionDefaults.removeObject(forKey: StorageKeys.activeMatchLeague)
        selectionDefaults.removeObject(forKey: StorageKeys.activeMatchIsWTA)
        logger.info("Cleared active match")
    }

    // MARK: - Fetch Active Match Detail

    private func performDetail(generation: UInt64, selection: UInt64) async {
        if isUsingMockData { return }
        guard let match = activeMatch else { return }

        do {
            let updatedMatch: AnyMatch

            if let detailLoader { updatedMatch = try await detailLoader(match) } else {
            switch match {
            case .cricket(let m):
                let detail = try await cricketService.fetchMatchDetail(eventId: m.id, leagueId: m.leagueId)
                updatedMatch = .cricket(detail)

            case .tennis(let m):
                let detail = try await tennisService.fetchMatchDetail(eventId: m.id, isWTA: m.isWTA, eventDate: m.eventDate)
                updatedMatch = .tennis(detail)

            case .nfl(let m):
                let detail = try await nflService.fetchGameDetail(eventId: m.id)
                updatedMatch = .nfl(detail)

            case .collegeFootball(let m):
                let detail = try await collegeFootballService.fetchGameDetail(eventId: m.id)
                updatedMatch = .collegeFootball(detail)

            case .collegeBasketball(let m):
                let detail = try await collegeBasketballService.fetchGameDetail(eventId: m.id)
                updatedMatch = .collegeBasketball(detail)

            case .soccer(let m):
                let league = m.leagueSlug ?? "eng.1"
                let detail = try await soccerService.fetchMatchDetail(eventId: m.id, league: league)
                updatedMatch = .soccer(detail)

            case .lacrosse(let m):
                let league = m.leagueSlug ?? "pll"
                let detail = try await lacrosseService.fetchGameDetail(eventId: m.id, league: league)
                updatedMatch = .lacrosse(detail)

            case .volleyball(let m):
                let league = m.leagueSlug ?? "mens-college-volleyball"
                let detail = try await volleyballService.fetchGameDetail(eventId: m.id, league: league)
                updatedMatch = .volleyball(detail)

            case .mlb(let m):
                let detail = try await mlbService.fetchGameDetail(eventId: m.id)
                updatedMatch = .mlb(detail)

            case .nba(let m):
                let detail = try await nbaService.fetchGameDetail(eventId: m.id)
                updatedMatch = .nba(detail)

            case .nhl(let m):
                let detail = try await nhlService.fetchGameDetail(eventId: m.id)
                updatedMatch = .nhl(detail)

            case .collegeHockey(let m):
                let detail = try await collegeHockeyService.fetchGameDetail(eventId: m.id)
                updatedMatch = .collegeHockey(detail)

            case .f1(let m):
                let races = try await f1Service.fetchRaces(fresh: true)
                if let updated = races.first(where: { $0.id == m.id }) {
                    updatedMatch = .f1(updated)
                } else {
                    throw NetworkError.noData
                }
            }

            }
            guard updatedMatch.sportType == match.sportType, updatedMatch.id == match.id else { throw NetworkError.noData }
            guard !Task.isCancelled, lifecycleGeneration.accepts(generation),
                  selectionGeneration.accepts(selection), activeMatch?.identity == match.identity else { return }
            activeMatch = updatedMatch
            lastDetailUpdate = Date()
            detailError = nil
            detailFailures = 0

            if let index = allMatches.firstIndex(where: { $0.identity == updatedMatch.identity }) {
                allMatches[index] = updatedMatch
            }

            logger.info("Updated active match detail: \(updatedMatch.homeTeamAbbrev) vs \(updatedMatch.awayTeamAbbrev)")
        } catch {
            guard !Task.isCancelled, lifecycleGeneration.accepts(generation),
                  selectionGeneration.accepts(selection) else { return }
            detailFailures += 1
            detailError = "Score update unavailable — showing last known data"
            logger.error("Failed to fetch active match detail: \(error.localizedDescription)")
        }
    }

    // MARK: - Persistence

    private func persistActiveMatch(_ match: AnyMatch) {
        selectionDefaults.set(match.id, forKey: StorageKeys.activeMatchId)
        selectionDefaults.set(match.sportType.rawValue, forKey: StorageKeys.activeMatchSport)

        selectionDefaults.removeObject(forKey: StorageKeys.activeMatchLeague)
        selectionDefaults.removeObject(forKey: StorageKeys.activeMatchIsWTA)
        switch match {
        case .soccer(let m):
            selectionDefaults.set(m.leagueSlug, forKey: StorageKeys.activeMatchLeague)
        case .tennis(let m):
            selectionDefaults.set(m.isWTA, forKey: StorageKeys.activeMatchIsWTA)
        case .lacrosse(let m):
            selectionDefaults.set(m.leagueSlug, forKey: StorageKeys.activeMatchLeague)
        case .volleyball(let m):
            selectionDefaults.set(m.leagueSlug, forKey: StorageKeys.activeMatchLeague)
        default:
            break
        }
    }

    private func restoreActiveMatch() {
        guard let matchId = selectionDefaults.string(forKey: StorageKeys.activeMatchId) else {
            return
        }

        let sport = selectionDefaults.string(forKey: StorageKeys.activeMatchSport)
        let league = selectionDefaults.string(forKey: StorageKeys.activeMatchLeague)
        if let found = allMatches.first(where: {
            guard $0.id == matchId, sport == nil || $0.sportType.rawValue == sport else { return false }
            if let league { return $0.identity.contains(":\(league):") }
            return true
        }) {
            activeMatch = found
            logger.info("Restored active match: \(matchId)")
        }
    }

    private func autoSelectActiveMatch() {
        // A sport choice is a display choice, not just a picker filter. Never keep
        // the previous sport's match while selecting from the new sport's feed.
        if let filter = selectedSportFilter, let current = activeMatch, current.sportType != filter {
            clearActiveMatch()
        }
        // If there's an active match, keep it unless it has expired (completed and older than 48 hours).
        if let current = activeMatch {
            if let found = allMatches.first(where: { $0.identity == current.identity }) {
                // Update activeMatch with the latest live data from the feed, preserving detailed stats
                activeMatch = mergeMatchDetails(from: current, to: found)
                return
            } else {
                // Active match not in discovery feed (could be completed, older, or cached).
                // Keep it active as long as it hasn't expired (completed and older than 48 hours).
                if current.status == .completed, let eventDate = current.eventDate {
                    let age = Date().timeIntervalSince(eventDate)
                    if age > 48 * 60 * 60 {
                        logger.info("Active match \(current.id) has expired (older than 48 hours). Clearing.")
                        clearActiveMatch()
                    } else {
                        // Keep it since it hasn't expired yet
                        return
                    }
                } else {
                    // Keep it (live, upcoming, or recently completed with no/recent date)
                    return
                }
            }
        }

        // If there's no active match, select the best candidate from the current filtered matches.
        let candidates = filteredMatches

        // 1. First choice: Any LIVE match
        if let liveMatch = candidates.first(where: { $0.status == .live }) {
            selectMatch(liveMatch)
            return
        }

        // 2. Second choice: Any UPCOMING match
        if let upcomingMatch = candidates.first(where: { $0.status == .upcoming }) {
            selectMatch(upcomingMatch)
            return
        }

        // 3. Third choice: Any COMPLETED match from the last 24 hours
        let recentCompleted = candidates.filter { match in
            guard match.status == .completed else { return false }
            guard let eventDate = match.eventDate else { return false }
            return Date().timeIntervalSince(eventDate) < 24 * 60 * 60
        }
        if let bestRecent = recentCompleted.first {
            selectMatch(bestRecent)
            return
        }

        // 4. Fallback: First available match in candidates
        if let firstMatch = candidates.first {
            selectMatch(firstMatch)
        } else {
            clearActiveMatch()
        }
    }

    // MARK: - Helpers

    private func statusPriority(_ status: MatchStatus) -> Int {
        switch status {
        case .live: return 0
        case .upcoming: return 1
        case .completed: return 2
        case .unknown: return 3
        }
    }

    private func mergeMatchDetails(from existing: AnyMatch, to newMatch: AnyMatch) -> AnyMatch {
        switch (existing, newMatch) {
        case (.cricket(let cur), .cricket(var new)):
            new.leagueId = new.leagueId ?? cur.leagueId
            new.currentInnings = new.currentInnings ?? cur.currentInnings
            if new.batsmen.isEmpty { new.batsmen = cur.batsmen }
            new.bowler = new.bowler ?? cur.bowler
            new.partnership = new.partnership ?? cur.partnership
            new.currentRunRate = new.currentRunRate ?? cur.currentRunRate
            new.requiredRunRate = new.requiredRunRate ?? cur.requiredRunRate
            new.target = new.target ?? cur.target
            new.recentOvers = new.recentOvers ?? cur.recentOvers
            new.venue = new.venue ?? cur.venue
            new.playerOfTheMatch = new.playerOfTheMatch ?? cur.playerOfTheMatch
            new.homeTopBatters = new.homeTopBatters ?? cur.homeTopBatters
            new.homeTopBowlers = new.homeTopBowlers ?? cur.homeTopBowlers
            new.awayTopBatters = new.awayTopBatters ?? cur.awayTopBatters
            new.awayTopBowlers = new.awayTopBowlers ?? cur.awayTopBowlers
            return .cricket(new)

        case (.tennis(let cur), .tennis(var new)):
            if new.sets.isEmpty { new.sets = cur.sets }
            new.currentGameScore = new.currentGameScore ?? cur.currentGameScore
            new.servingPlayer = new.servingPlayer ?? cur.servingPlayer
            new.tournamentName = new.tournamentName ?? cur.tournamentName
            new.round = new.round ?? cur.round
            return .tennis(new)

        case (.nfl(let cur), .nfl(var new)):
            if new.quarterScores.isEmpty { new.quarterScores = cur.quarterScores }
            new.situation = new.situation ?? cur.situation
            new.lastPlay = new.lastPlay ?? cur.lastPlay
            return .nfl(new)

        case (.collegeFootball(let cur), .collegeFootball(var new)):
            if new.quarterScores.isEmpty { new.quarterScores = cur.quarterScores }
            new.situation = new.situation ?? cur.situation
            new.lastPlay = new.lastPlay ?? cur.lastPlay
            new.conference = new.conference ?? cur.conference
            return .collegeFootball(new)

        case (.collegeBasketball(let cur), .collegeBasketball(var new)):
            if new.halfScores.isEmpty { new.halfScores = cur.halfScores }
            new.conference = new.conference ?? cur.conference
            return .collegeBasketball(new)

        case (.soccer(let cur), .soccer(var new)):
            if new.goalScorers.isEmpty { new.goalScorers = cur.goalScorers }
            if new.cards.isEmpty { new.cards = cur.cards }
            new.halfTimeScore = new.halfTimeScore ?? cur.halfTimeScore
            new.possessionHome = new.possessionHome ?? cur.possessionHome
            new.possessionAway = new.possessionAway ?? cur.possessionAway
            new.leagueName = new.leagueName ?? cur.leagueName
            new.leagueSlug = new.leagueSlug ?? cur.leagueSlug
            return .soccer(new)

        case (.lacrosse(let cur), .lacrosse(var new)):
            if new.quarterScores.isEmpty { new.quarterScores = cur.quarterScores }
            new.leagueName = new.leagueName ?? cur.leagueName
            new.leagueSlug = new.leagueSlug ?? cur.leagueSlug
            return .lacrosse(new)

        case (.volleyball(let cur), .volleyball(var new)):
            if new.setScores.isEmpty { new.setScores = cur.setScores }
            new.leagueName = new.leagueName ?? cur.leagueName
            new.leagueSlug = new.leagueSlug ?? cur.leagueSlug
            return .volleyball(new)

        case (.mlb(let cur), .mlb(var new)):
            new.homePitcher = new.homePitcher ?? cur.homePitcher
            new.awayPitcher = new.awayPitcher ?? cur.awayPitcher
            new.lastPlay = new.lastPlay ?? cur.lastPlay
            return .mlb(new)

        case (.nba(let cur), .nba(var new)):
            if new.quarterScores.isEmpty { new.quarterScores = cur.quarterScores }
            new.homeLeader = new.homeLeader ?? cur.homeLeader
            new.awayLeader = new.awayLeader ?? cur.awayLeader
            new.lastPlay = new.lastPlay ?? cur.lastPlay
            return .nba(new)

        case (.nhl(let cur), .nhl(var new)):
            if new.periodScores.isEmpty { new.periodScores = cur.periodScores }
            new.powerPlay = new.powerPlay ?? cur.powerPlay
            new.lastPlay = new.lastPlay ?? cur.lastPlay
            return .nhl(new)

        case (.collegeHockey(let cur), .collegeHockey(var new)):
            if new.periodScores.isEmpty { new.periodScores = cur.periodScores }
            new.conference = new.conference ?? cur.conference
            new.lastPlay = new.lastPlay ?? cur.lastPlay
            return .collegeHockey(new)

        case (.f1(let cur), .f1(var new)):
            if new.sessions.isEmpty { new.sessions = cur.sessions }
            return .f1(new)

        default:
            return newMatch
        }
    }
}


#if DEBUG
extension SportsDataManager {
    /// Start only the selected-detail scheduler; injected fixture loads never use the network.
    func beginDetailFixture(_ match: AnyMatch) {
        precondition(detailLoader != nil)
        isPolling = true; suspended = false; activeMatch = match
    }
    var detailFixtureDeadline: Date? { detailTimer?.isValid == true ? detailTimer?.fireDate : nil }
    func fireDetailFixture() { detailTimer?.fire() }
}
#endif
