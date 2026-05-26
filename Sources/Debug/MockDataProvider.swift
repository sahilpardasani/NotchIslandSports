import Foundation

/// A provider of high-fidelity mock sports data for testing and previewing in Xcode.
/// To clean this up before production, simply delete this entire `Sources/Debug` directory.
struct MockDataProvider {
    
    static func getMockMatches() -> [AnyMatch] {
        var matches: [AnyMatch] = []
        
        // 1. Cricket Mock Matches
        let indScore = "240"
        let ausScore = "241/4"
        let cricketLive = CricketMatch(
            id: "cricket_live_1",
            status: .live,
            homeTeam: "India",
            awayTeam: "Australia",
            homeTeamAbbrev: "IND",
            awayTeamAbbrev: "AUS",
            homeScore: indScore,
            awayScore: ausScore,
            statusText: "Australia need 80 runs from 42 balls",
            currentInnings: InningsDetail(teamName: "Australia", runs: 241, wickets: 4, overs: 43.0, inningsNumber: 2),
            batsmen: [
                Batsman(name: "Glenn Maxwell", runs: 76, balls: 41, fours: 6, sixes: 4, strikeRate: 185.36, isOnStrike: true),
                Batsman(name: "Marcus Stoinis", runs: 18, balls: 12, fours: 1, sixes: 1, strikeRate: 150.0, isOnStrike: false)
            ],
            bowler: Bowler(name: "Jasprit Bumrah", overs: "8.2", maidens: 1, runs: 42, wickets: 2, economy: 5.04),
            partnership: Partnership(runs: 54, balls: 28, batsman1: "Glenn Maxwell", batsman2: "Marcus Stoinis"),
            currentRunRate: 5.6,
            requiredRunRate: 11.42,
            target: 321,
            recentOvers: "6 4 1 • 2 1W",
            matchDescription: "ICC Men's T20 World Cup - Final",
            eventDate: Date()
        )
        matches.append(.cricket(cricketLive))
        
        // Additional Cricket mock matches showcasing breaks
        let cricketStrategicTimeout = CricketMatch(
            id: "cricket_strategic_timeout",
            status: .live,
            homeTeam: "Mumbai Indians",
            awayTeam: "Chennai Super Kings",
            homeTeamAbbrev: "MI",
            awayTeamAbbrev: "CSK",
            homeScore: "172/3",
            awayScore: "120/4",
            statusText: "Strategic Timeout - MI leading by run rate",
            currentInnings: InningsDetail(teamName: "Chennai Super Kings", runs: 120, wickets: 4, overs: 14.0, inningsNumber: 2),
            batsmen: [
                Batsman(name: "MS Dhoni", runs: 12, balls: 6, fours: 1, sixes: 1, strikeRate: 200.0, isOnStrike: true),
                Batsman(name: "Ravindra Jadeja", runs: 8, balls: 8, fours: 0, sixes: 0, strikeRate: 100.0, isOnStrike: false)
            ],
            bowler: Bowler(name: "Jasprit Bumrah", overs: "3.0", maidens: 0, runs: 18, wickets: 2, economy: 6.0),
            partnership: Partnership(runs: 20, balls: 14, batsman1: "MS Dhoni", batsman2: "Ravindra Jadeja"),
            currentRunRate: 8.57,
            requiredRunRate: 8.83,
            target: 173,
            recentOvers: "1 6 • 1 4 Wd",
            matchDescription: "IPL - Strategic Timeout Active",
            eventDate: Date()
        )
        matches.append(.cricket(cricketStrategicTimeout))
        
        let cricketInningsBreak = CricketMatch(
            id: "cricket_innings_break",
            status: .live,
            homeTeam: "Pakistan",
            awayTeam: "India",
            homeTeamAbbrev: "PAK",
            awayTeamAbbrev: "IND",
            homeScore: "152/10",
            awayScore: "0/0",
            statusText: "Innings Break - India innings starting shortly",
            currentInnings: nil,
            batsmen: [],
            bowler: nil,
            partnership: nil,
            currentRunRate: nil,
            requiredRunRate: nil,
            target: 153,
            recentOvers: nil,
            matchDescription: "T20 International - Innings Break",
            eventDate: Date()
        )
        matches.append(.cricket(cricketInningsBreak))
        
        let cricketLunch = CricketMatch(
            id: "cricket_lunch",
            status: .live,
            homeTeam: "England",
            awayTeam: "Australia",
            homeTeamAbbrev: "ENG",
            awayTeamAbbrev: "AUS",
            homeScore: "312/4",
            awayScore: "–",
            statusText: "Lunch Break - Day 1 Session 1 concluded",
            currentInnings: InningsDetail(teamName: "England", runs: 312, wickets: 4, overs: 26.0, inningsNumber: 1),
            batsmen: [
                Batsman(name: "Joe Root", runs: 112, balls: 140, fours: 12, sixes: 0, strikeRate: 80.0, isOnStrike: true),
                Batsman(name: "Harry Brook", runs: 45, balls: 32, fours: 5, sixes: 2, strikeRate: 140.6, isOnStrike: false)
            ],
            bowler: Bowler(name: "Pat Cummins", overs: "12.0", maidens: 2, runs: 54, wickets: 2, economy: 4.5),
            partnership: Partnership(runs: 78, balls: 68, batsman1: "Joe Root", batsman2: "Harry Brook"),
            currentRunRate: 4.8,
            requiredRunRate: nil,
            target: nil,
            recentOvers: "4 1 • 6 1 4",
            matchDescription: "The Ashes - Lunch Break Active",
            eventDate: Date()
        )
        matches.append(.cricket(cricketLunch))
        
        let cricketTea = CricketMatch(
            id: "cricket_tea",
            status: .live,
            homeTeam: "India",
            awayTeam: "South Africa",
            homeTeamAbbrev: "IND",
            awayTeamAbbrev: "SA",
            homeScore: "180/6",
            awayScore: "–",
            statusText: "Tea Break - Day 2 Session 2 concluded",
            currentInnings: InningsDetail(teamName: "India", runs: 180, wickets: 6, overs: 54.0, inningsNumber: 1),
            batsmen: [
                Batsman(name: "Virat Kohli", runs: 82, balls: 165, fours: 8, sixes: 0, strikeRate: 49.7, isOnStrike: true),
                Batsman(name: "Ravichandran Ashwin", runs: 14, balls: 28, fours: 1, sixes: 0, strikeRate: 50.0, isOnStrike: false)
            ],
            bowler: Bowler(name: "Kagiso Rabada", overs: "16.0", maidens: 4, runs: 38, wickets: 3, economy: 2.38),
            partnership: Partnership(runs: 35, balls: 62, batsman1: "Virat Kohli", batsman2: "Ravichandran Ashwin"),
            currentRunRate: 3.33,
            requiredRunRate: nil,
            target: nil,
            recentOvers: "• • 1 • • 2",
            matchDescription: "Test Series - Tea Break Active",
            eventDate: Date()
        )
        matches.append(.cricket(cricketTea))
        
        let cricketDrinks = CricketMatch(
            id: "cricket_drinks",
            status: .live,
            homeTeam: "New Zealand",
            awayTeam: "Bangladesh",
            homeTeamAbbrev: "NZ",
            awayTeamAbbrev: "BAN",
            homeScore: "215/2",
            awayScore: "–",
            statusText: "Drinks Break - 1st Innings 30 Overs completed",
            currentInnings: InningsDetail(teamName: "New Zealand", runs: 215, wickets: 2, overs: 30.0, inningsNumber: 1),
            batsmen: [
                Batsman(name: "Kane Williamson", runs: 94, balls: 88, fours: 9, sixes: 1, strikeRate: 106.8, isOnStrike: true),
                Batsman(name: "Daryl Mitchell", runs: 22, balls: 18, fours: 2, sixes: 0, strikeRate: 122.2, isOnStrike: false)
            ],
            bowler: Bowler(name: "Mustafizur Rahman", overs: "6.0", maidens: 0, runs: 42, wickets: 1, economy: 7.0),
            partnership: Partnership(runs: 48, balls: 36, batsman1: "Kane Williamson", batsman2: "Daryl Mitchell"),
            currentRunRate: 7.17,
            requiredRunRate: nil,
            target: nil,
            recentOvers: "1 4 • 1 2 1",
            matchDescription: "ODI Series - Drinks Break Active",
            eventDate: Date()
        )
        matches.append(.cricket(cricketDrinks))
        
        let cricketCompleted = CricketMatch(
            id: "cricket_completed_1",
            status: .completed,
            homeTeam: "Peshawar Zalmi",
            awayTeam: "Lahore Qalandars",
            homeTeamAbbrev: "PES",
            awayTeamAbbrev: "LAH",
            homeScore: "185/7",
            awayScore: "186/3",
            statusText: "Lahore Qalandars won by 7 wickets",
            currentInnings: InningsDetail(teamName: "Lahore Qalandars", runs: 186, wickets: 3, overs: 18.4, inningsNumber: 2),
            batsmen: [],
            bowler: nil,
            partnership: nil,
            currentRunRate: nil,
            requiredRunRate: nil,
            target: 186,
            recentOvers: nil,
            matchDescription: "Pakistan Super League",
            eventDate: Date(timeIntervalSinceNow: -86400)
        )
        matches.append(.cricket(cricketCompleted))
        
        let cricketUpcoming = CricketMatch(
            id: "cricket_upcoming_1",
            status: .upcoming,
            homeTeam: "England",
            awayTeam: "Australia",
            homeTeamAbbrev: "ENG",
            awayTeamAbbrev: "AUS",
            homeScore: "–",
            awayScore: "–",
            statusText: "Starts tomorrow at 10:30 AM",
            matchDescription: "The Ashes - 1st Test",
            eventDate: Date(timeIntervalSinceNow: 86400)
        )
        matches.append(.cricket(cricketUpcoming))

        // 2. Tennis Mock Matches
        let tennisLive1 = TennisMatch(
            id: "tennis_live_1",
            status: .live,
            player1Name: "Carlos Alcaraz",
            player2Name: "Jannik Sinner",
            player1Country: "ESP",
            player2Country: "ITA",
            homeScore: "2",
            awayScore: "1",
            statusText: "Set 4 - Sinner Serving",
            sets: [
                SetScore(setNumber: 1, player1Games: 6, player2Games: 4, tiebreak: nil),
                SetScore(setNumber: 2, player1Games: 3, player2Games: 6, tiebreak: nil),
                SetScore(setNumber: 3, player1Games: 7, player2Games: 6, tiebreak: 5),
                SetScore(setNumber: 4, player1Games: 4, player2Games: 3, tiebreak: nil)
            ],
            currentGameScore: GameScore(player1Points: "30", player2Points: "40"),
            servingPlayer: 2,
            currentSet: 4,
            tournamentName: "Roland Garros",
            round: "Semifinal",
            isWTA: false,
            eventDate: Date()
        )
        matches.append(.tennis(tennisLive1))

        let tennisLive2 = TennisMatch(
            id: "tennis_live_2",
            status: .live,
            player1Name: "Iga Swiatek",
            player2Name: "Aryna Sabalenka",
            player1Country: "POL",
            player2Country: "BLR",
            homeScore: "1",
            awayScore: "0",
            statusText: "Set 2 - Swiatek Serving",
            sets: [
                SetScore(setNumber: 1, player1Games: 6, player2Games: 3, tiebreak: nil),
                SetScore(setNumber: 2, player1Games: 2, player2Games: 1, tiebreak: nil)
            ],
            currentGameScore: GameScore(player1Points: "AD", player2Points: "40"),
            servingPlayer: 1,
            currentSet: 2,
            tournamentName: "Roland Garros",
            round: "Final",
            isWTA: true,
            eventDate: Date()
        )
        matches.append(.tennis(tennisLive2))

        // 3. NFL Mock Matches
        let nflLive = NFLGame(
            id: "nfl_live_1",
            status: .live,
            homeTeam: "Kansas City Chiefs",
            awayTeam: "San Francisco 49ers",
            homeTeamAbbrev: "KC",
            awayTeamAbbrev: "SF",
            homeScore: "24",
            awayScore: "20",
            statusText: "4th Quarter - 2:15",
            quarterScores: [
                QuarterScore(quarter: 1, homeScore: 7, awayScore: 3),
                QuarterScore(quarter: 2, homeScore: 3, awayScore: 10),
                QuarterScore(quarter: 3, homeScore: 7, awayScore: 7),
                QuarterScore(quarter: 4, homeScore: 7, awayScore: 0)
            ],
            currentQuarter: 4,
            gameClock: "2:15",
            situation: GameSituation(down: 3, distance: 7, yardLine: 34, possession: "SF", isRedZone: false, yardsToEndzone: 66),
            lastPlay: "P.Mahomes pass deep middle to T.Kelce for 22 yards to the SF 34.",
            homeTimeouts: 2,
            awayTimeouts: 1,
            eventDate: Date()
        )
        matches.append(.nfl(nflLive))

        // 4. College Football Mock Matches
        let cfbUpcoming = CollegeFootballGame(
            id: "cfb_upcoming_1",
            status: .upcoming,
            homeTeam: "Georgia Bulldogs",
            awayTeam: "Alabama Crimson Tide",
            homeTeamAbbrev: "UGA",
            awayTeamAbbrev: "ALA",
            homeScore: "–",
            awayScore: "–",
            statusText: "Starts Saturday at 7:30 PM",
            eventDate: Date(timeIntervalSinceNow: 172800),
            conference: "SEC"
        )
        matches.append(.collegeFootball(cfbUpcoming))

        // 5. College Basketball Mock Matches
        let cbbLiveMen = CollegeBasketballGame(
            id: "cbb_live_1",
            status: .live,
            homeTeam: "Duke Blue Devils",
            awayTeam: "North Carolina Tar Heels",
            homeTeamAbbrev: "DUKE",
            awayTeamAbbrev: "UNC",
            homeScore: "82",
            awayScore: "79",
            statusText: "2nd Half - 0:45",
            eventDate: Date(),
            halfScores: [
                HalfScore(half: 1, homeScore: 38, awayScore: 41),
                HalfScore(half: 2, homeScore: 44, awayScore: 38)
            ],
            currentPeriod: 2,
            gameClock: "0:45",
            conference: "ACC (Men)"
        )
        matches.append(.collegeBasketball(cbbLiveMen))

        let cbbCompletedWomen = CollegeBasketballGame(
            id: "cbb_completed_1",
            status: .completed,
            homeTeam: "South Carolina Gamecocks",
            awayTeam: "Iowa Hawkeyes",
            homeTeamAbbrev: "SC",
            awayTeamAbbrev: "IOWA",
            homeScore: "87",
            awayScore: "75",
            statusText: "FINAL",
            eventDate: Date(timeIntervalSinceNow: -86400 * 2),
            halfScores: [
                HalfScore(half: 1, homeScore: 49, awayScore: 46),
                HalfScore(half: 2, homeScore: 38, awayScore: 29)
            ],
            currentPeriod: 2,
            gameClock: "0:00",
            conference: "NCAA Women's Final"
        )
        matches.append(.collegeBasketball(cbbCompletedWomen))

        // 6. Soccer Mock Matches
        let soccerLive = SoccerMatch(
            id: "soccer_live_1",
            status: .live,
            homeTeam: "Chelsea FC Women",
            awayTeam: "Arsenal WFC",
            homeTeamAbbrev: "CHE",
            awayTeamAbbrev: "ARS",
            homeScore: "2",
            awayScore: "1",
            statusText: "82nd Minute",
            matchMinute: "82'",
            period: "2nd Half",
            goalScorers: [
                GoalEvent(playerName: "Sam Kerr", minute: "14'", team: "CHE", isPenalty: false, isOwnGoal: false),
                GoalEvent(playerName: "Lauren James", minute: "42'", team: "CHE", isPenalty: false, isOwnGoal: false),
                GoalEvent(playerName: "Alessia Russo", minute: "61'", team: "ARS", isPenalty: true, isOwnGoal: false)
            ],
            cards: [
                CardEvent(playerName: "Kim Little", minute: "35'", team: "ARS", cardType: .yellow)
            ],
            halfTimeScore: "2-0",
            possessionHome: 52,
            possessionAway: 48,
            leagueName: "Barclays Women's Super League",
            leagueSlug: "eng.w.1",
            eventDate: Date()
        )
        matches.append(.soccer(soccerLive))

        // 7. Lacrosse Mock Matches
        let lacrosseLive = LacrosseGame(
            id: "lacrosse_live_1",
            status: .live,
            homeTeam: "Maryland Terrapins",
            awayTeam: "Johns Hopkins Blue Jays",
            homeTeamAbbrev: "UMD",
            awayTeamAbbrev: "JHU",
            homeScore: "12",
            awayScore: "11",
            statusText: "4th Quarter - 1:12",
            eventDate: Date(),
            quarterScores: [
                LacrosseQuarterScore(quarter: 1, homeScore: 3, awayScore: 4),
                LacrosseQuarterScore(quarter: 2, homeScore: 4, awayScore: 2),
                LacrosseQuarterScore(quarter: 3, homeScore: 2, awayScore: 3),
                LacrosseQuarterScore(quarter: 4, homeScore: 3, awayScore: 2)
            ],
            currentQuarter: 4,
            gameClock: "1:12",
            leagueName: "NCAA Men's Lacrosse"
        )
        matches.append(.lacrosse(lacrosseLive))

        // 8. Volleyball Mock Matches
        let volleyballLive = VolleyballGame(
            id: "volleyball_live_1",
            status: .live,
            homeTeam: "Nebraska Cornhuskers",
            awayTeam: "Wisconsin Badgers",
            homeTeamAbbrev: "NEB",
            awayTeamAbbrev: "WIS",
            homeScore: "2",
            awayScore: "1",
            statusText: "Set 4 - 18-15",
            eventDate: Date(),
            setScores: [
                VolleyballSetScore(setNumber: 1, homeScore: 25, awayScore: 22),
                VolleyballSetScore(setNumber: 2, homeScore: 21, awayScore: 25),
                VolleyballSetScore(setNumber: 3, homeScore: 25, awayScore: 19),
                VolleyballSetScore(setNumber: 4, homeScore: 18, awayScore: 15)
            ],
            currentSet: 4,
            leagueName: "NCAA Women's Volleyball"
        )
        matches.append(.volleyball(volleyballLive))
        
        // 9. MLB Mock Matches
        let mlbLive = MLBGame(
            id: "mlb_live_1",
            status: .live,
            homeTeam: "Boston Red Sox",
            awayTeam: "New York Yankees",
            homeTeamAbbrev: "BOS",
            awayTeamAbbrev: "NYY",
            homeScore: "4",
            awayScore: "3",
            statusText: "Bot 8th - 1 Out",
            eventDate: Date(),
            inning: 8,
            inningHalf: "Bot",
            outs: 1,
            balls: 2,
            strikes: 1,
            onBase: [true, false, true],
            homePitcher: "Kenley Jansen",
            awayPitcher: "Clay Holmes",
            homeHits: 8,
            awayHits: 6,
            homeErrors: 0,
            awayErrors: 1,
            lastPlay: "Rafael Devers singles to right. Alex Verdugo to third. 1 Out."
        )
        matches.append(.mlb(mlbLive))

        // 10. NBA Mock Matches
        let nbaLive = NBAGame(
            id: "nba_live_1",
            status: .live,
            homeTeam: "Los Angeles Lakers",
            awayTeam: "Boston Celtics",
            homeTeamAbbrev: "LAL",
            awayTeamAbbrev: "BOS",
            homeScore: "102",
            awayScore: "99",
            statusText: "4th Qtr - 1:04",
            eventDate: Date(),
            quarterScores: [
                QuarterScore(quarter: 1, homeScore: 28, awayScore: 30),
                QuarterScore(quarter: 2, homeScore: 24, awayScore: 25),
                QuarterScore(quarter: 3, homeScore: 26, awayScore: 22),
                QuarterScore(quarter: 4, homeScore: 24, awayScore: 22)
            ],
            currentQuarter: 4,
            gameClock: "1:04",
            homeLeader: "LeBron James (28 PTS)",
            awayLeader: "Jayson Tatum (31 PTS)",
            lastPlay: "LeBron James step back 3-pt jump shot made (28 PTS)."
        )
        matches.append(.nba(nbaLive))

        // 11. NHL Mock Matches
        let nhlLive = NHLGame(
            id: "nhl_live_1",
            status: .live,
            homeTeam: "Chicago Blackhawks",
            awayTeam: "Detroit Red Wings",
            homeTeamAbbrev: "CHI",
            awayTeamAbbrev: "DET",
            homeScore: "3",
            awayScore: "2",
            statusText: "3rd Per - 4:12",
            eventDate: Date(),
            periodScores: [
                PeriodScore(period: 1, homeScore: 1, awayScore: 1),
                PeriodScore(period: 2, homeScore: 1, awayScore: 1),
                PeriodScore(period: 3, homeScore: 1, awayScore: 0)
            ],
            currentPeriod: 3,
            gameClock: "4:12",
            homeShotsOnGoal: 28,
            awayShotsOnGoal: 31,
            powerPlay: "PP",
            lastPlay: "Connor Bedard shot saved by Alex Lyon. CHI power play continues."
        )
        matches.append(.nhl(nhlLive))

        // 12. College Hockey Mock Matches
        let collegeHockeyLive = CollegeHockeyGame(
            id: "college_hockey_live_1",
            status: .live,
            homeTeam: "Boston University Terriers",
            awayTeam: "Boston College Eagles",
            homeTeamAbbrev: "BU",
            awayTeamAbbrev: "BC",
            homeScore: "4",
            awayScore: "4",
            statusText: "OT1 - 2:30",
            eventDate: Date(),
            periodScores: [
                PeriodScore(period: 1, homeScore: 1, awayScore: 2),
                PeriodScore(period: 2, homeScore: 2, awayScore: 1),
                PeriodScore(period: 3, homeScore: 1, awayScore: 1),
                PeriodScore(period: 4, homeScore: 0, awayScore: 0)
            ],
            currentPeriod: 4,
            gameClock: "2:30",
            homeShotsOnGoal: 34,
            awayShotsOnGoal: 36,
            conference: "Hockey East",
            lastPlay: "Lane Hutson slap shot blocked. Faceoff in BC zone."
        )
        matches.append(.collegeHockey(collegeHockeyLive))
        
        // 13. F1 Mock Matches
        let f1Live = F1Race(
            id: "f1_live_1",
            status: .live,
            homeTeam: "Lando Norris",
            awayTeam: "Max Verstappen",
            homeTeamAbbrev: "NOR",
            awayTeamAbbrev: "VER",
            homeScore: "P1",
            awayScore: "P2",
            statusText: "Lap 56/70 - Live",
            homeLogoURL: "https://a.espncdn.com/i/teamlogos/countries/500/gbr.png",
            awayLogoURL: "https://a.espncdn.com/i/teamlogos/countries/500/ned.png",
            eventDate: Date(),
            raceName: "Canadian Grand Prix",
            shortRaceName: "CAN GP",
            circuitName: "Circuit Gilles Villeneuve",
            location: "Montreal, Canada",
            sessions: [
                F1Session(
                    sessionType: "Race",
                    status: "Live",
                    competitors: [
                        F1Driver(driverId: "norris", position: 1, fullName: "Lando Norris", shortName: "Norris", country: "GBR", flagURL: "https://a.espncdn.com/i/teamlogos/countries/500/gbr.png", winner: false),
                        F1Driver(driverId: "verstappen", position: 2, fullName: "Max Verstappen", shortName: "Verstappen", country: "NED", flagURL: "https://a.espncdn.com/i/teamlogos/countries/500/ned.png", winner: false),
                        F1Driver(driverId: "russell", position: 3, fullName: "George Russell", shortName: "Russell", country: "GBR", flagURL: "https://a.espncdn.com/i/teamlogos/countries/500/gbr.png", winner: false),
                        F1Driver(driverId: "piastri", position: 4, fullName: "Oscar Piastri", shortName: "Piastri", country: "AUS", flagURL: "https://a.espncdn.com/i/teamlogos/countries/500/aus.png", winner: false),
                        F1Driver(driverId: "leclerc", position: 5, fullName: "Charles Leclerc", shortName: "Leclerc", country: "MON", flagURL: "https://a.espncdn.com/i/teamlogos/countries/500/mon.png", winner: false),
                        F1Driver(driverId: "hamilton", position: 6, fullName: "Lewis Hamilton", shortName: "Hamilton", country: "GBR", flagURL: "https://a.espncdn.com/i/teamlogos/countries/500/gbr.png", winner: false)
                    ]
                ),
                F1Session(
                    sessionType: "Qual",
                    status: "Final",
                    competitors: [
                        F1Driver(driverId: "russell", position: 1, fullName: "George Russell", shortName: "Russell", country: "GBR", flagURL: "https://a.espncdn.com/i/teamlogos/countries/500/gbr.png", winner: true),
                        F1Driver(driverId: "verstappen", position: 2, fullName: "Max Verstappen", shortName: "Verstappen", country: "NED", flagURL: "https://a.espncdn.com/i/teamlogos/countries/500/ned.png", winner: false),
                        F1Driver(driverId: "norris", position: 3, fullName: "Lando Norris", shortName: "Norris", country: "GBR", flagURL: "https://a.espncdn.com/i/teamlogos/countries/500/gbr.png", winner: false)
                    ]
                )
            ],
            activeSessionType: "Race"
        )
        matches.append(.f1(f1Live))
        
        return matches
    }
    
    @MainActor
    static func setupMockData(for dataManager: SportsDataManager) {
        let mockMatches = getMockMatches()
        dataManager.allMatches = mockMatches
        
        // Find the live cricket match as active match by default
        if let liveCricket = mockMatches.first(where: { $0.id == "cricket_live_1" }) {
            dataManager.activeMatch = liveCricket
        } else {
            dataManager.activeMatch = mockMatches.first
        }
        
        dataManager.fallbackSports = []
        dataManager.showMatchSelector = false
    }
}
