import Foundation
import os

// MARK: - Cricket Service

final class CricketService {

    private let apiClient = APIClient.shared
    private let logger = Logger(subsystem: "com.notchisland.sports", category: "CricketService")

    private static let leagueEndpoints: [(slug: String, name: String)] = [
        ("all", "International Cricket"),
        ("8048", "IPL")
    ]

    private let summaryBaseURL = "https://site.api.espn.com/apis/site/v2/sports/cricket"

    // MARK: - Fetch All Matches

    func fetchMatches() async throws -> [CricketMatch] {
        var allMatches: [CricketMatch] = []
        var seenIds = Set<String>()

        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        let dates = [formatter.string(from: yesterday), formatter.string(from: today), formatter.string(from: tomorrow)]

        // Fetch from all dynamic and specific league endpoints in parallel
        await withTaskGroup(of: [CricketMatch].self) { group in
            // 1. Fetch from personalized dynamic header scoreboards for all 3 days
            for dateStr in dates {
                group.addTask { [self] in
                    do {
                        let urlString = "https://site.api.espn.com/apis/personalized/v2/scoreboard/header?sport=cricket&dates=\(dateStr)"
                        guard let url = URL(string: urlString) else { return [] }
                        let json = try await apiClient.fetchRawJSON(from: url)
                        return parseHeaderScoreboard(json: json)
                    } catch {
                        logger.warning("Cricket personalized discovery failed for date \(dateStr): \(error.localizedDescription)")
                        return []
                    }
                }
            }

            // 2. Fetch explicitly from IPL (8048) scoreboard for all 3 days to guarantee coverage
            for dateStr in dates {
                group.addTask { [self] in
                    do {
                        let urlString = "https://site.api.espn.com/apis/site/v2/sports/cricket/8048/scoreboard?dates=\(dateStr)"
                        guard let url = URL(string: urlString) else { return [] }
                        let json = try await apiClient.fetchRawJSON(from: url)
                        return parseScoreboard(json: json, leagueName: "IPL", leagueSlug: "8048")
                    } catch {
                        logger.warning("IPL scoreboard fetch failed for date \(dateStr): \(error.localizedDescription)")
                        return []
                    }
                }
            }

            for await matches in group {
                for match in matches {
                    if !seenIds.contains(match.id) {
                        seenIds.insert(match.id)
                        allMatches.append(match)
                    }
                }
            }
        }

        // Sort: live first, then upcoming by date soonest first, then completed most recent first
        allMatches.sort { lhs, rhs in
            let lhsPriority = statusPriority(lhs.status)
            let rhsPriority = statusPriority(rhs.status)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            
            // Within same status, sort by date
            guard let d1 = lhs.eventDate, let d2 = rhs.eventDate else { return false }
            if lhs.status == .completed {
                return d1 > d2  // Most recent completed first
            } else {
                return d1 < d2  // Soonest upcoming first
            }
        }

        logger.info("Parsed \(allMatches.count) total cricket matches across Yesterday/Today/Tomorrow")
        return allMatches
    }

    // MARK: - Fetch Match Detail

    func fetchMatchDetail(eventId: String, leagueId: String?) async throws -> CricketMatch {
        // 1. Try dynamic series/league summary first if provided
        if let leagueId = leagueId, !leagueId.isEmpty {
            let urlString = "\(summaryBaseURL)/\(leagueId)/summary?event=\(eventId)"
            if let url = URL(string: urlString) {
                do {
                    let json = try await apiClient.fetchRawJSON(from: url)
                    if json["header"] != nil || json["scorecards"] != nil || json["matchcards"] != nil || json["rosters"] != nil {
                        var match = parseMatchSummary(json: json, eventId: eventId)
                        match.leagueId = leagueId
                        return match
                    }
                } catch {
                    logger.warning("Dynamic summary fetch failed for league \(leagueId), event \(eventId): \(error.localizedDescription)")
                }
            }
        }

        // 2. Try direct IPL summary as fallback
        let fallbackIPL = "https://site.api.espn.com/apis/site/v2/sports/cricket/8048/summary?event=\(eventId)"
        if let url = URL(string: fallbackIPL) {
            do {
                let json = try await apiClient.fetchRawJSON(from: url)
                if json["header"] != nil || json["matchcards"] != nil || json["rosters"] != nil {
                    var match = parseMatchSummary(json: json, eventId: eventId)
                    match.leagueId = "8048"
                    return match
                }
            } catch {}
        }

        // 3. Try standard series summaries
        for league in Self.leagueEndpoints {
            let urlString = "\(summaryBaseURL)/\(league.slug)/summary?event=\(eventId)"
            guard let url = URL(string: urlString) else { continue }
            do {
                let json = try await apiClient.fetchRawJSON(from: url)
                if json["header"] != nil || json["scorecards"] != nil || json["matchcards"] != nil {
                    var match = parseMatchSummary(json: json, eventId: eventId)
                    match.leagueId = league.slug
                    return match
                }
            } catch {
                continue
            }
        }

        throw NetworkError.noData
    }

    // MARK: - Parse Scoreboard

    private func parseScoreboard(json: [String: Any], leagueName: String, leagueSlug: String) -> [CricketMatch] {
        guard let events = json["events"] as? [[String: Any]] else {
            return []
        }

        var matches: [CricketMatch] = []

        for event in events {
            guard let eventId = event["id"] as? String,
                  let competitions = event["competitions"] as? [[String: Any]],
                  let competition = competitions.first,
                  let competitors = competition["competitors"] as? [[String: Any]],
                  competitors.count >= 2 else {
                continue
            }

            let statusDict = event["status"] as? [String: Any]
            let statusType = statusDict?["type"] as? [String: Any]
            let statusState = statusType?["state"] as? String ?? ""
            let statusDescription = statusType?["description"] as? String ?? ""

            let matchStatus = ESPNStatusParser.parseState(statusState)
            let eventDate = ESPNStatusParser.parseDate(event["date"] as? String)

            let team1 = competitors[0]
            let team2 = competitors[1]

            let team1Info = parseTeamInfo(from: team1)
            let team2Info = parseTeamInfo(from: team2)

            let summaryText = statusDict?["summary"] as? String ?? statusDescription

            let match = CricketMatch(
                id: eventId,
                status: matchStatus,
                homeTeam: team1Info.name,
                awayTeam: team2Info.name,
                homeTeamAbbrev: team1Info.abbreviation,
                awayTeamAbbrev: team2Info.abbreviation,
                homeScore: team1Info.score,
                awayScore: team2Info.score,
                statusText: summaryText,
                homeLogoURL: team1Info.logoURL,
                awayLogoURL: team2Info.logoURL,
                leagueId: leagueSlug,
                matchDescription: event["name"] as? String ?? "",
                eventDate: eventDate
            )

            matches.append(match)
        }

        return matches
    }

    // MARK: - Parse Header Scoreboard (Personalized API)

    private func parseHeaderScoreboard(json: [String: Any]) -> [CricketMatch] {
        guard let sports = json["sports"] as? [[String: Any]],
              let cricket = sports.first,
              let leagues = cricket["leagues"] as? [[String: Any]] else {
            return []
        }

        var matches: [CricketMatch] = []

        for league in leagues {
            let leagueId = league["id"] as? String ?? league["slug"] as? String
            guard let events = league["events"] as? [[String: Any]] else { continue }

            for event in events {
                guard let eventId = event["id"] as? String,
                      let competitors = event["competitors"] as? [[String: Any]],
                      competitors.count >= 2 else {
                    continue
                }

                var statusState = ""
                var statusDescription = ""

                if let statusStr = event["status"] as? String {
                    statusState = statusStr
                    if let fullStatus = event["fullStatus"] as? [String: Any],
                       let statusType = fullStatus["type"] as? [String: Any] {
                        statusDescription = statusType["description"] as? String ?? ""
                    }
                    if statusDescription.isEmpty {
                        statusDescription = statusStr.uppercased()
                    }
                } else if let statusDict = event["status"] as? [String: Any] {
                    let statusType = statusDict["type"] as? [String: Any]
                    statusState = statusType?["state"] as? String ?? ""
                    statusDescription = statusType?["description"] as? String ?? ""
                }

                let matchStatus = ESPNStatusParser.parseState(statusState)
                let eventDate = ESPNStatusParser.parseDate(event["date"] as? String)

                let team1 = competitors[0]
                let team2 = competitors[1]

                let homeTeam = team1["displayName"] as? String ?? team1["name"] as? String ?? "Unknown"
                let awayTeam = team2["displayName"] as? String ?? team2["name"] as? String ?? "Unknown"
                let homeAbbrev = team1["abbreviation"] as? String ?? team1["name"] as? String ?? "HOM"
                let awayAbbrev = team2["abbreviation"] as? String ?? team2["name"] as? String ?? "AWY"
                let homeScore = team1["score"] as? String ?? "–"
                let awayScore = team2["score"] as? String ?? "–"
                let homeLogo = team1["logo"] as? String ?? (team1["logos"] as? [[String: Any]])?.first?["href"] as? String
                let awayLogo = team2["logo"] as? String ?? (team2["logos"] as? [[String: Any]])?.first?["href"] as? String

                let summaryText = event["summary"] as? String
                    ?? (event["fullStatus"] as? [String: Any])?["summary"] as? String
                    ?? statusDescription

                let match = CricketMatch(
                    id: eventId,
                    status: matchStatus,
                    homeTeam: homeTeam,
                    awayTeam: awayTeam,
                    homeTeamAbbrev: homeAbbrev,
                    awayTeamAbbrev: awayAbbrev,
                    homeScore: homeScore,
                    awayScore: awayScore,
                    statusText: summaryText,
                    homeLogoURL: homeLogo,
                    awayLogoURL: awayLogo,
                    leagueId: leagueId,
                    matchDescription: event["description"] as? String ?? event["name"] as? String ?? "",
                    eventDate: eventDate
                )
                matches.append(match)
            }
        }
        return matches
    }

    // MARK: - Parse Match Summary

    private func parseMatchSummary(json: [String: Any], eventId: String) -> CricketMatch {
        let header = json["header"] as? [String: Any]
        let competitions = header?["competitions"] as? [[String: Any]]
        let competition = competitions?.first
        let competitors = competition?["competitors"] as? [[String: Any]] ?? []

        let statusDict = header?["status"] as? [String: Any] ?? (json["status"] as? [String: Any] ?? [:])
        let statusType = statusDict["type"] as? [String: Any]
        let statusState = statusType?["state"] as? String ?? ""
        let statusDescription = statusType?["description"] as? String ?? ""
        let matchStatus = ESPNStatusParser.parseState(statusState)

        var homeTeam = "", awayTeam = ""
        var homeAbbrev = "", awayAbbrev = ""
        var homeScore = "", awayScore = ""
        var homeLogo: String?, awayLogo: String?

        if competitors.count >= 2 {
            let team1 = parseTeamInfo(from: competitors[0])
            let team2 = parseTeamInfo(from: competitors[1])
            homeTeam = team1.name
            awayTeam = team2.name
            homeAbbrev = team1.abbreviation
            awayAbbrev = team2.abbreviation
            homeScore = team1.score
            awayScore = team2.score
            homeLogo = team1.logoURL
            awayLogo = team2.logoURL
        }

        var batsmen: [Batsman] = []
        var bowler: Bowler?
        var partnership: Partnership?
        var currentRunRate: Double?
        var requiredRunRate: Double?
        var target: Int?
        var recentOvers: String?
        var currentInnings: InningsDetail?
        var matchDescription = ""

        let toDouble: (Any?) -> Double = { val in
            if let d = val as? Double { return d }
            if let i = val as? Int { return Double(i) }
            if let s = val as? String { return Double(s) ?? 0.0 }
            return 0.0
        }
        let toInt: (Any?) -> Int = { val in
            if let i = val as? Int { return i }
            if let d = val as? Double { return Int(d) }
            if let s = val as? String { return Int(s) ?? 0 }
            return 0
        }

        if let scorecard = json["scorecards"] as? [[String: Any]], let latestInnings = scorecard.last {
            currentInnings = parseInningsDetail(from: latestInnings)
        }

        if let batsmenArray = json["batsmen"] as? [[String: Any]] {
            batsmen = batsmenArray.compactMap { parseBatsman(from: $0) }
        }

        if let bowlersArray = json["bowlers"] as? [[String: Any]], let firstBowler = bowlersArray.first {
            bowler = parseBowler(from: firstBowler)
        }

        if let situationDict = json["situation"] as? [String: Any] {
            currentRunRate = situationDict["currentRunRate"] as? Double
            requiredRunRate = situationDict["requiredRunRate"] as? Double
            target = situationDict["target"] as? Int

            if let partnershipDict = situationDict["partnership"] as? [String: Any] {
                partnership = parsePartnership(from: partnershipDict)
            }

            if let lastOvers = situationDict["recentOvers"] as? String {
                recentOvers = lastOvers
            }
        }

        // Fallback for live matches where standard details are missing/nested
        if batsmen.isEmpty || bowler == nil {
            if let comp = competition, let commentaries = comp["commentaries"] as? [String: Any] {
                let commentaryArray = commentaries.values.compactMap { $0 as? [String: Any] }
                let sortedCommentaries = commentaryArray.sorted { (c1, c2) -> Bool in
                    let p1 = c1["period"] as? Int ?? 1
                    let p2 = c2["period"] as? Int ?? 1
                    if p1 != p2 {
                        return p1 > p2
                    }
                    let id1 = Int(c1["id"] as? String ?? "") ?? Int(c1["sequence"] as? String ?? "") ?? 0
                    let id2 = Int(c2["id"] as? String ?? "") ?? Int(c2["sequence"] as? String ?? "") ?? 0
                    return id1 > id2
                }
                
                if let latest = sortedCommentaries.first {
                    // 1. Parse Batsmen (striker & non-striker)
                    var parsedBatsmen: [Batsman] = []
                    if let strikerDict = latest["batsman"] as? [String: Any],
                       let athlete = strikerDict["athlete"] as? [String: Any] {
                        let name = athlete["displayName"] as? String ?? athlete["name"] as? String ?? "Striker"
                        let runs = toInt(strikerDict["totalRuns"] ?? strikerDict["runs"])
                        let balls = toInt(strikerDict["faced"])
                        let sr = balls > 0 ? (Double(runs) / Double(balls)) * 100.0 : 0.0
                        parsedBatsmen.append(Batsman(
                            name: name,
                            runs: runs,
                            balls: balls,
                            fours: toInt(strikerDict["fours"]),
                            sixes: toInt(strikerDict["sixes"]),
                            strikeRate: sr,
                            isOnStrike: true
                        ))
                    }
                    
                    if let nonStrikerDict = latest["otherBatsman"] as? [String: Any],
                       let athlete = nonStrikerDict["athlete"] as? [String: Any] {
                        let name = athlete["displayName"] as? String ?? athlete["name"] as? String ?? "Non-Striker"
                        let runs = toInt(nonStrikerDict["totalRuns"] ?? nonStrikerDict["runs"])
                        let balls = toInt(nonStrikerDict["faced"])
                        let sr = balls > 0 ? (Double(runs) / Double(balls)) * 100.0 : 0.0
                        parsedBatsmen.append(Batsman(
                            name: name,
                            runs: runs,
                            balls: balls,
                            fours: toInt(nonStrikerDict["fours"]),
                            sixes: toInt(nonStrikerDict["sixes"]),
                            strikeRate: sr,
                            isOnStrike: false
                        ))
                    }
                    
                    if !parsedBatsmen.isEmpty {
                        batsmen = parsedBatsmen
                    }
                    
                    // 2. Parse Bowler
                    if let bowlerDict = latest["bowler"] as? [String: Any],
                       let athlete = bowlerDict["athlete"] as? [String: Any] {
                        let name = athlete["displayName"] as? String ?? athlete["name"] as? String ?? "Bowler"
                        let balls = toInt(bowlerDict["balls"])
                        let runs = toInt(bowlerDict["conceded"])
                        let wickets = toInt(bowlerDict["wickets"])
                        
                        let oversStr = "\(balls / 6).\(balls % 6)"
                        let econ = balls > 0 ? Double(runs) / (Double(balls) / 6.0) : 0.0
                        
                        bowler = Bowler(
                            name: name,
                            overs: oversStr,
                            maidens: toInt(bowlerDict["maidens"]),
                            runs: runs,
                            wickets: wickets,
                            economy: econ
                        )
                    }
                    
                    // 3. Parse CRR, RRR, Target
                    if let inningsDict = latest["innings"] as? [String: Any] {
                        if currentRunRate == nil {
                            currentRunRate = toDouble(inningsDict["runRate"])
                        }
                        if requiredRunRate == nil {
                            requiredRunRate = toDouble(inningsDict["requiredRunRate"])
                        }
                        if target == nil {
                            target = toInt(inningsDict["target"])
                        }
                    }
                }
            }
            
            // 4. Parse currentInnings & active Partnership from current linescore
            if let comp = competition, let competitorsArr = comp["competitors"] as? [[String: Any]] {
                for competitor in competitorsArr {
                    if let linescores = competitor["linescores"] as? [[String: Any]] {
                        for ls in linescores {
                            if toInt(ls["isCurrent"]) == 1 && toInt(ls["isBatting"]) == 1 {
                                let teamName = (competitor["team"] as? [String: Any])?["displayName"] as? String ?? "Unknown"
                                
                                if currentInnings == nil {
                                    currentInnings = InningsDetail(
                                        teamName: teamName,
                                        runs: toInt(ls["runs"]),
                                        wickets: toInt(ls["wickets"]),
                                        overs: toDouble(ls["overs"]),
                                        inningsNumber: toInt(ls["period"])
                                    )
                                }
                                
                                if partnership == nil,
                                   let partnerships = ls["partnerships"] as? [[String: Any]],
                                   let lastPartnership = partnerships.last {
                                    let pRuns = toInt(lastPartnership["runs"])
                                    let ovVal = toDouble(lastPartnership["overs"])
                                    let pBalls = Int(ovVal) * 6 + Int(round((ovVal - Double(Int(ovVal))) * 10))
                                    
                                    // Use batsmen names if parsed
                                    let batsman1 = batsmen.first?.name ?? "Striker"
                                    let batsman2 = batsmen.count > 1 ? batsmen[1].name : "Non-Striker"
                                    
                                    partnership = Partnership(
                                        runs: pRuns,
                                        balls: pBalls,
                                        batsman1: batsman1,
                                        batsman2: batsman2
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        if let notes = json["notes"] as? [[String: Any]], let firstNote = notes.first {
            matchDescription = firstNote["text"] as? String ?? ""
        } else if let gameInfo = json["gameInfo"] as? [String: Any] {
            matchDescription = gameInfo["note"] as? String ?? ""
        }

        if matchDescription.isEmpty {
            matchDescription = header?["gameNote"] as? String ?? statusDescription
        }

        // Concluded match scorecard extraction
        var venue: String? = nil
        if let gameInfo = json["gameInfo"] as? [String: Any] {
            if let venueDict = gameInfo["venue"] as? [String: Any] {
                venue = venueDict["fullName"] as? String ?? venueDict["name"] as? String
            }
        }

        var playerOfTheMatch: String? = nil
        if let featuredAthletes = statusDict["featuredAthletes"] as? [[String: Any]] {
            for fa in featuredAthletes {
                if fa["abbreviation"] as? String == "POTM" {
                    if let athlete = fa["athlete"] as? [String: Any] {
                        playerOfTheMatch = athlete["displayName"] as? String
                    }
                }
            }
        }

        var homeTopBatters: [Batsman] = []
        var homeTopBowlers: [Bowler] = []
        var awayTopBatters: [Batsman] = []
        var awayTopBowlers: [Bowler] = []

        if let rosters = json["rosters"] as? [[String: Any]] {
            let toDouble: (Any?) -> Double = { val in
                if let d = val as? Double { return d }
                if let i = val as? Int { return Double(i) }
                if let s = val as? String { return Double(s) ?? 0.0 }
                return 0.0
            }
            let toInt: (Any?) -> Int = { val in
                if let i = val as? Int { return i }
                if let d = val as? Double { return Int(d) }
                if let s = val as? String { return Int(s) ?? 0 }
                return 0
            }

            for teamRoster in rosters {
                let isHome = teamRoster["homeAway"] as? String == "home"
                let players = teamRoster["roster"] as? [[String: Any]] ?? []

                var teamBatters: [(name: String, runs: Int, balls: Int, sr: Double, period: Int)] = []
                var teamBowlers: [(name: String, wickets: Int, conceded: Int, overs: String, econ: Double, period: Int)] = []

                for p in players {
                    guard let athlete = p["athlete"] as? [String: Any] else { continue }
                    let name = athlete["displayName"] as? String ?? athlete["shortName"] as? String ?? "Unknown"
                    let shortName = athlete["shortName"] as? String ?? name
                    let linescores = p["linescores"] as? [[String: Any]] ?? []

                    for ls in linescores {
                        guard let statistics = ls["statistics"] as? [String: Any],
                              let categories = statistics["categories"] as? [[String: Any]],
                              let firstCategory = categories.first,
                              let stats = firstCategory["stats"] as? [[String: Any]] else { continue }

                        var statsDict: [String: [String: Any]] = [:]
                        for stat in stats {
                            if let name = stat["name"] as? String {
                                statsDict[name] = stat
                            }
                        }

                        let period = ls["period"] as? Int ?? 1

                        if let batted = statsDict["batted"]?["value"], toInt(batted) == 1 {
                            let runs = toInt(statsDict["runs"]?["value"])
                            let balls = toInt(statsDict["ballsFaced"]?["value"])
                            let srVal = toDouble(statsDict["strikeRate"]?["value"])
                            teamBatters.append((name: shortName, runs: runs, balls: balls, sr: srVal, period: period))
                        }

                        if let oversVal = statsDict["overs"]?["value"], toDouble(oversVal) > 0.0 {
                            let wickets = toInt(statsDict["wickets"]?["value"])
                            let conceded = toInt(statsDict["conceded"]?["value"] ?? statsDict["runs"]?["value"])
                            let econVal = toDouble(statsDict["economyRate"]?["value"])
                            let oversStr = statsDict["overs"]?["displayValue"] as? String ?? "\(toDouble(oversVal))"
                            teamBowlers.append((name: shortName, wickets: wickets, conceded: conceded, overs: oversStr, econ: econVal, period: period))
                        }
                    }
                }

                teamBatters.sort { (lhs, rhs) -> Bool in
                    if lhs.runs != rhs.runs { return lhs.runs > rhs.runs }
                    return lhs.balls < rhs.balls
                }

                teamBowlers.sort { (lhs, rhs) -> Bool in
                    if lhs.wickets != rhs.wickets { return lhs.wickets > rhs.wickets }
                    return lhs.conceded < rhs.conceded
                }

                let mappedBatters = teamBatters.prefix(4).map { b in
                    Batsman(name: b.name, runs: b.runs, balls: b.balls, fours: 0, sixes: 0, strikeRate: b.sr, isOnStrike: false)
                }
                let mappedBowlers = teamBowlers.prefix(4).map { b in
                    Bowler(name: b.name, overs: b.overs, maidens: 0, runs: b.conceded, wickets: b.wickets, economy: b.econ)
                }

                if isHome {
                    homeTopBatters = mappedBatters
                    homeTopBowlers = mappedBowlers
                } else {
                    awayTopBatters = mappedBatters
                    awayTopBowlers = mappedBowlers
                }
            }
        }
        // Robust fallback for Required Run Rate (RRR) in second innings
        var finalRequiredRunRate = requiredRunRate
        if let targetVal = target, targetVal > 0, let innings = currentInnings, innings.inningsNumber == 2 {
            let runsNeeded = max(targetVal - innings.runs, 0)
            if runsNeeded > 0 {
                var totalBalls = 120 // default to T20
                if let scorecards = json["scorecards"] as? [[String: Any]], let latestInnings = scorecards.last {
                    if let ballLimit = latestInnings["ballLimit"] as? Int, ballLimit > 0 {
                        totalBalls = ballLimit
                    }
                }
                
                if let comp = competition, let commentariesDict = comp["commentaries"] as? [String: Any] {
                    for (_, val) in commentariesDict {
                        if let comm = val as? [String: Any],
                           let inningsDict = comm["innings"] as? [String: Any],
                           let ballLimit = inningsDict["ballLimit"] as? Int, ballLimit > 0 {
                            totalBalls = ballLimit
                            break
                        }
                    }
                }
                
                let wholeOvers = Int(innings.overs)
                let ballsBowledInOver = Int(round((innings.overs - Double(wholeOvers)) * 10))
                let totalBallsBowled = wholeOvers * 6 + ballsBowledInOver
                let ballsRemaining = max(totalBalls - totalBallsBowled, 1)
                
                let calculatedRRR = (Double(runsNeeded) / Double(ballsRemaining)) * 6.0
                if finalRequiredRunRate == nil || finalRequiredRunRate == 0.0 {
                    finalRequiredRunRate = calculatedRRR
                }
            } else {
                finalRequiredRunRate = 0.0
            }
        }

        let eventDate = ESPNStatusParser.parseDate(header?["date"] as? String ?? json["date"] as? String)

        return CricketMatch(
            id: eventId,
            status: matchStatus,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            homeTeamAbbrev: homeAbbrev,
            awayTeamAbbrev: awayAbbrev,
            homeScore: homeScore,
            awayScore: awayScore,
            statusText: statusDescription,
            homeLogoURL: homeLogo,
            awayLogoURL: awayLogo,
            currentInnings: currentInnings,
            batsmen: batsmen,
            bowler: bowler,
            partnership: partnership,
            currentRunRate: currentRunRate,
            requiredRunRate: finalRequiredRunRate,
            target: target,
            recentOvers: recentOvers,
            matchDescription: matchDescription,
            eventDate: eventDate,
            venue: venue,
            playerOfTheMatch: playerOfTheMatch,
            homeTopBatters: homeTopBatters.isEmpty ? nil : homeTopBatters,
            homeTopBowlers: homeTopBowlers.isEmpty ? nil : homeTopBowlers,
            awayTopBatters: awayTopBatters.isEmpty ? nil : awayTopBatters,
            awayTopBowlers: awayTopBowlers.isEmpty ? nil : awayTopBowlers
        )
    }

    // MARK: - Helper Parsers

    private struct TeamInfo {
        let name: String
        let abbreviation: String
        let score: String
        let logoURL: String?
    }

    private func parseTeamInfo(from dict: [String: Any]) -> TeamInfo {
        let teamDict = dict["team"] as? [String: Any]
        let name = teamDict?["displayName"] as? String
            ?? teamDict?["name"] as? String
            ?? "Unknown"
        let abbreviation = teamDict?["abbreviation"] as? String ?? String(name.prefix(3)).uppercased()
        let score = dict["score"] as? String ?? "–"
        let logoURL = (teamDict?["logos"] as? [[String: Any]])?.first?["href"] as? String
            ?? teamDict?["logo"] as? String

        return TeamInfo(name: name, abbreviation: abbreviation, score: score, logoURL: logoURL)
    }

    private func statusPriority(_ status: MatchStatus) -> Int {
        switch status {
        case .live: return 0
        case .upcoming: return 1
        case .completed: return 2
        case .unknown: return 3
        }
    }

    private func parseInningsDetail(from dict: [String: Any]) -> InningsDetail? {
        let teamName = (dict["team"] as? [String: Any])?["displayName"] as? String ?? "Unknown"
        let runs = dict["totalRuns"] as? Int ?? dict["runs"] as? Int ?? 0
        let wickets = dict["totalWickets"] as? Int ?? dict["wickets"] as? Int ?? 0
        let overs = dict["totalOvers"] as? Double ?? dict["overs"] as? Double ?? 0.0
        let inningsNumber = dict["inning"] as? Int ?? 1

        return InningsDetail(
            teamName: teamName,
            runs: runs,
            wickets: wickets,
            overs: overs,
            inningsNumber: inningsNumber
        )
    }

    private func parseBatsman(from dict: [String: Any]) -> Batsman? {
        let athlete = dict["athlete"] as? [String: Any]
        let name = athlete?["displayName"] as? String
            ?? athlete?["shortName"] as? String
            ?? dict["name"] as? String
            ?? "Unknown"

        let runs = dict["totalRuns"] as? Int ?? dict["runs"] as? Int ?? 0
        let balls = dict["totalBalls"] as? Int ?? dict["balls"] as? Int ?? 0
        let fours = dict["fours"] as? Int ?? 0
        let sixes = dict["sixes"] as? Int ?? 0
        let strikeRate = dict["strikeRate"] as? Double ?? (balls > 0 ? Double(runs) / Double(balls) * 100.0 : 0.0)
        let isOnStrike = dict["isOnStrike"] as? Bool ?? false

        return Batsman(
            name: name,
            runs: runs,
            balls: balls,
            fours: fours,
            sixes: sixes,
            strikeRate: strikeRate,
            isOnStrike: isOnStrike
        )
    }

    private func parseBowler(from dict: [String: Any]) -> Bowler? {
        let athlete = dict["athlete"] as? [String: Any]
        let name = athlete?["displayName"] as? String
            ?? athlete?["shortName"] as? String
            ?? dict["name"] as? String
            ?? "Unknown"

        let overs = dict["overs"] as? String ?? "\(dict["overs"] as? Double ?? 0.0)"
        let maidens = dict["maidens"] as? Int ?? 0
        let runs = dict["totalRuns"] as? Int ?? dict["runs"] as? Int ?? dict["conceded"] as? Int ?? 0
        let wickets = dict["wickets"] as? Int ?? 0
        let economy = dict["economy"] as? Double ?? 0.0

        return Bowler(
            name: name,
            overs: overs,
            maidens: maidens,
            runs: runs,
            wickets: wickets,
            economy: economy
        )
    }

    private func parsePartnership(from dict: [String: Any]) -> Partnership? {
        let runs = dict["totalRuns"] as? Int ?? dict["runs"] as? Int ?? 0
        let balls = dict["totalBalls"] as? Int ?? dict["balls"] as? Int ?? 0

        let players = dict["athletes"] as? [[String: Any]] ?? []
        let batsman1 = players.first?["displayName"] as? String
            ?? (players.first?["athlete"] as? [String: Any])?["displayName"] as? String
            ?? "Unknown"
        let batsman2 = (players.count > 1 ? players[1]["displayName"] as? String : nil)
            ?? (players.count > 1 ? (players[1]["athlete"] as? [String: Any])?["displayName"] as? String : nil)
            ?? "Unknown"

        return Partnership(runs: runs, balls: balls, batsman1: batsman1, batsman2: batsman2)
    }
}
