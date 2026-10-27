import SwiftUI
import IslandCore

struct CollapsedScoreView: View {
    @ObservedObject var dataManager: SportsDataManager
    @State private var isPulsing = false
    
    var body: some View {
        NotchEars(gap: dataManager.hasNotch ? dataManager.notchWidth + 12 : 20) {
            if let match = dataManager.activeMatch { leftSideView(for: match) }
            else { Text("No active match").font(.system(size: 11)).foregroundColor(.gray) }
        } right: {
            if let match = dataManager.activeMatch { rightSideView(for: match) }
            else { Text("NotchIsland").font(.system(size: 11)).foregroundColor(.gray) }
        }
    }

    // MARK: - Side View Routers
    
    @ViewBuilder
    private func leftSideView(for match: AnyMatch) -> some View {
        switch match {
        case .tennis(let tennisMatch):
            tennisLeftSide(tennisMatch)
        case .f1(let race):
            f1LeftSide(race)
        case .cricket(let cricketMatch):
            cricketLeftSide(cricketMatch)
        default:
            defaultLeftSide(match)
        }
    }
    
    @ViewBuilder
    private func rightSideView(for match: AnyMatch) -> some View {
        switch match {
        case .tennis(let tennisMatch):
            tennisRightSide(tennisMatch)
        case .f1(let race):
            f1RightSide(race)
        case .cricket(let cricketMatch):
            cricketRightSide(cricketMatch)
        default:
            defaultRightSide(match)
        }
    }
    
    // MARK: - Tennis Split Views
    
    @ViewBuilder
    private func tennisLeftSide(_ match: TennisMatch) -> some View {
        HStack(spacing: 6) {
            // Server indicator for Player 2 OR fallback if serving player is unknown
            if (match.servingPlayer == 2 || match.servingPlayer == nil) && match.status == .live {
                Circle()
                    .fill(Color.red)
                    .frame(width: 5, height: 5)
            }
            
            Text(match.awayTeamAbbrev)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(isTennisWinner(match, isPlayer1: false) ? Color(hex: "E6FF00") : .white)
            
            if !match.sets.isEmpty {
                HStack(spacing: 3) {
                    ForEach(match.sets) { setScore in
                        let isActive = setScore.setNumber == match.currentSet && match.status == .live
                        Text("\(setScore.player2Games)")
                            .font(.system(size: 11, weight: isActive ? .bold : .medium, design: .rounded))
                            .foregroundColor(.white.opacity(isActive ? 1.0 : 0.5))
                    }
                    
                    // Current game points (Away) - plain number with space
                    if let game = match.activeGameScore, match.status == .live {
                        Text("\(game.player2Points)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "E6FF00"))
                            .padding(.leading, 3)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func tennisRightSide(_ match: TennisMatch) -> some View {
        HStack(spacing: 6) {
            if !match.sets.isEmpty {
                HStack(spacing: 3) {
                    // Current game points (Home) - plain number with space
                    if let game = match.activeGameScore, match.status == .live {
                        Text("\(game.player1Points)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "E6FF00"))
                            .padding(.trailing, 3)
                    }
                    
                    ForEach(match.sets) { setScore in
                        let isActive = setScore.setNumber == match.currentSet && match.status == .live
                        Text("\(setScore.player1Games)")
                            .font(.system(size: 11, weight: isActive ? .bold : .medium, design: .rounded))
                            .foregroundColor(.white.opacity(isActive ? 1.0 : 0.5))
                    }
                }
            }
            
            Text(match.homeTeamAbbrev)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(isTennisWinner(match, isPlayer1: true) ? Color(hex: "E6FF00") : .white)
            
            // Server indicator for Player 1
            if match.servingPlayer == 1 && match.status == .live {
                Circle()
                    .fill(Color.red)
                    .frame(width: 5, height: 5)
            }
        }
    }
    
    // MARK: - F1 Split Views
    
    @ViewBuilder
    private func f1LeftSide(_ race: F1Race) -> some View {
        HStack(spacing: 6) {
            // Pulsing live dot
            if race.status == .live {
                Circle()
                    .fill(Color.red)
                    .frame(width: 5, height: 5)
                    .scaleEffect(isPulsing ? 1.2 : 0.9)
                    .opacity(isPulsing ? 0.5 : 1.0)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 0.8).repeatCount(2, autoreverses: true)) {
                            isPulsing = true
                        }
                    }
            }
            
            Text("🏎️")
            Text(race.shortRaceName)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Compact status/session label (cleaned of long updates)
            let status = collapsedStatusText(race.statusText).isEmpty ? race.activeSessionType : collapsedStatusText(race.statusText)
            Text(status)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
        }
    }
    
    @ViewBuilder
    private func f1RightSide(_ race: F1Race) -> some View {
        if let session = race.sessions.first(where: { $0.sessionType == race.activeSessionType }) {
            let topDrivers = session.competitors.prefix(3)
            if !topDrivers.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(topDrivers.enumerated()), id: \.offset) { index, driver in
                        if index > 0 {
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        Text(driver.abbrev)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(index == 0 ? Color(hex: "E10600") : .white)
                    }
                }
            } else {
                Text("No Standings")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
        } else {
            Text("Upcoming")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    // MARK: - Cricket Split Views
    
    @ViewBuilder
    private func cricketLeftSide(_ match: CricketMatch) -> some View {
        HStack(spacing: 6) {
            // Live indicator dot
            if match.status == .live {
                Circle()
                    .fill(Color.red)
                    .frame(width: 5, height: 5)
                    .scaleEffect(isPulsing ? 1.2 : 0.9)
                    .opacity(isPulsing ? 0.5 : 1.0)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 0.8).repeatCount(2, autoreverses: true)) {
                            isPulsing = true
                        }
                    }
            }
            
            Text("🏏")
            
            Text(match.awayTeamAbbrev)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .layoutPriority(1)
            
            Text(CompactActivityText.score(match.awayScore))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(isWinner(match: .cricket(match), isHome: false) ? Color(hex: "E6FF00") : .white)
                .lineLimit(1)
                .layoutPriority(2)
        }
    }
    
    @ViewBuilder
    private func cricketRightSide(_ match: CricketMatch) -> some View {
        HStack(spacing: 6) {
            Text(CompactActivityText.score(match.homeScore))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(isWinner(match: .cricket(match), isHome: true) ? Color(hex: "E6FF00") : .white)
                .lineLimit(1)
                .layoutPriority(2)
            
            Text(match.homeTeamAbbrev)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .layoutPriority(1)
            
            if !match.statusText.isEmpty {
                let displayStatus = collapsedStatusText(match.statusText)
                if !displayStatus.isEmpty {
                    Text(displayStatus)
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
    }
    
    // MARK: - Default Split Views
    
    @ViewBuilder
    private func defaultLeftSide(_ match: AnyMatch) -> some View {
        HStack(spacing: 6) {
            // Live indicator dot
            if match.status == .live {
                Circle()
                    .fill(Color.red)
                    .frame(width: 5, height: 5)
                    .scaleEffect(isPulsing ? 1.2 : 0.9)
                    .opacity(isPulsing ? 0.5 : 1.0)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 0.8).repeatCount(2, autoreverses: true)) {
                            isPulsing = true
                        }
                    }
            }
            
            Text(match.sportType.icon)
            
            Text(match.awayTeamAbbrev)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(cleanScore(match.awayScore))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(isWinner(match: match, isHome: false) ? Color(hex: "E6FF00") : .white)
        }
    }
    
    @ViewBuilder
    private func defaultRightSide(_ match: AnyMatch) -> some View {
        HStack(spacing: 6) {
            Text(cleanScore(match.homeScore))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(isWinner(match: match, isHome: true) ? Color(hex: "E6FF00") : .white)
            
            Text(match.homeTeamAbbrev)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Display status text only if it's compact and not long status updates
            if !match.statusText.isEmpty {
                let displayStatus = collapsedStatusText(match.statusText)
                if !displayStatus.isEmpty {
                    Text(displayStatus)
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func cleanScore(_ score: String) -> String {
        if let range = score.range(of: "(") {
            return String(score[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return score
    }
    
    /// Filters out long status strings (won toss, delayed, postponed) to prevent notch collision
    private func collapsedStatusText(_ status: String) -> String {
        let lower = status.lowercased()
        if lower.contains("toss") || lower.contains("won") || lower.contains("elect") || lower.contains("bat") || lower.contains("field") || lower.contains("bowl") || lower.contains("live") || lower.contains("delay") || lower.contains("rain") || lower.contains("schedule") || lower.contains("preview") || lower.contains("postpone") || lower.contains("choose") || lower.contains("chose") {
            return ""
        }
        if status.count > 10 {
            return ""
        }
        return status
    }
    
    /// Evaluates if a competitor won the game at the end of the match
    private func isWinner(match: AnyMatch, isHome: Bool) -> Bool {
        guard match.status == .completed else { return false }
        
        let homeClean = match.homeScore.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let awayClean = match.awayScore.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        if let h = Int(homeClean), let a = Int(awayClean) {
            if h > a {
                return isHome
            } else if a > h {
                return !isHome
            }
        }
        return false
    }
    
    /// Determines tennis winner by counting sets won
    private func isTennisWinner(_ match: TennisMatch, isPlayer1: Bool) -> Bool {
        guard match.status == .completed else { return false }
        var p1Sets = 0
        var p2Sets = 0
        for s in match.sets {
            if s.player1Games > s.player2Games {
                p1Sets += 1
            } else if s.player2Games > s.player1Games {
                p2Sets += 1
            }
        }
        if p1Sets > p2Sets {
            return isPlayer1
        } else if p2Sets > p1Sets {
            return !isPlayer1
        }
        return false
    }
}

