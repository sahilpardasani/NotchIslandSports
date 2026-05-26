// NotchContentView.swift
// NotchIslandSports
//
// Main SwiftUI container that morphs between collapsed capsule
// and expanded sport-specific detail card.

import SwiftUI

// MARK: - Color Extension

extension Color {
    /// Initialize a Color from a hex string (6 or 8 character, with or without '#').
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)
        
        let length = sanitized.count
        let r, g, b, a: Double
        
        switch length {
        case 6:
            r = Double((rgb >> 16) & 0xFF) / 255.0
            g = Double((rgb >> 8) & 0xFF) / 255.0
            b = Double(rgb & 0xFF) / 255.0
            a = 1.0
        case 8:
            r = Double((rgb >> 24) & 0xFF) / 255.0
            g = Double((rgb >> 16) & 0xFF) / 255.0
            b = Double((rgb >> 8) & 0xFF) / 255.0
            a = Double(rgb & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1.0
        }
        
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Design System Constants

enum DesignSystem {
    static let background       = Color.black
    static let primaryText      = Color.white
    static let secondaryText    = Color(hex: "ABABAB")
    static let liveRed          = Color(hex: "FF3B30")
    static let cricketGreen     = Color(hex: "4CAF50")
    static let tennisGold       = Color(hex: "FFD700")
    static let nflOrange        = Color(hex: "FF6B35")
    static let soccerCyan       = Color(hex: "00BCD4")
    static let fieldGreen       = Color(hex: "2E7D32")
    static let capsuleBorder    = Color(hex: "333333")
    static let cfbMaroon        = Color(hex: "8B0000")
    static let cbbOrange        = Color(hex: "FF8C00")
    static let lacrossePurple   = Color(hex: "7B68EE")
    static let volleyballPink   = Color(hex: "E91E63")
    static let neonYellow       = Color(hex: "E6FF00")
    static let mlbGreen         = Color(hex: "09632A")
    static let nbaNavy          = Color(hex: "0C2340")
    static let nhlGray          = Color(hex: "444444")
    static let collegeHockeyRed = Color(hex: "CC0000")
    static let f1Red            = Color(hex: "E10600")
    
    /// Returns the accent color for a given sport type.
    static func accentColor(for sport: SportType) -> Color {
        switch sport {
        case .cricket: return cricketGreen
        case .tennis:  return tennisGold
        case .nfl:     return nflOrange
        case .collegeFootball: return cfbMaroon
        case .collegeBasketball: return cbbOrange
        case .soccer:  return soccerCyan
        case .lacrosse: return lacrossePurple
        case .volleyball: return volleyballPink
        case .mlb: return mlbGreen
        case .nba: return nbaNavy
        case .nhl: return nhlGray
        case .collegeHockey: return collegeHockeyRed
        case .f1: return f1Red
        }
    }
}

// MARK: - NotchContentView

struct NotchContentView: View {
    @ObservedObject var hoverState: HoverState
    @ObservedObject var dataManager: SportsDataManager
    
    @StateObject private var nowPlayingManager = NowPlayingManager()
    @State private var isExpanded: Bool = false
    @State private var selectedTab: Tab = .sports
    
    enum Tab {
        case sports
        case nowPlaying
    }
    
    private let expandAnimation: Animation = .easeInOut(duration: 0.35)
    
    private var collapsedWidth: CGFloat {
        let baseSpacer: CGFloat = dataManager.hasNotch ? min(dataManager.notchWidth + 16, 170) : 60
        let padding: CGFloat = 80 // Increased horizontal padding on each side for spaciousness (added ~8px to both sides)
        
        guard let match = dataManager.activeMatch else {
            // "📺 No Active Matches" (~130px) + spacer + "NotchIsland" (~80px)
            return 130 + baseSpacer + 80 + padding
        }
        
        switch match {
        case .tennis(let tennisMatch):
            var leftSideWidth: CGFloat = 56 // Increased Team Name width
            if tennisMatch.status == .live {
                leftSideWidth += 10 // live dot
            }
            if tennisMatch.servingPlayer == 2 && tennisMatch.status == .live {
                leftSideWidth += 10 // serving dot
            }
            if !tennisMatch.sets.isEmpty {
                leftSideWidth += CGFloat(tennisMatch.sets.count) * 14 // More room for sets
                if tennisMatch.activeGameScore != nil && tennisMatch.status == .live {
                    leftSideWidth += 46 // "(30-40)" score text
                }
            }
            
            var rightSideWidth: CGFloat = 56 // Increased Team Name width
            if tennisMatch.servingPlayer == 1 && tennisMatch.status == .live {
                rightSideWidth += 10 // serving dot
            }
            if !tennisMatch.sets.isEmpty {
                rightSideWidth += CGFloat(tennisMatch.sets.count) * 14 // More room for sets
                if tennisMatch.activeGameScore != nil && tennisMatch.status == .live {
                    rightSideWidth += 46 // "(30-40)" score text
                }
            }
            
            return leftSideWidth + baseSpacer + rightSideWidth + padding
            
        case .cricket(let cricketMatch):
            var leftSideWidth: CGFloat = 104 // Increased for breathing room
            var rightSideWidth: CGFloat = 104 // Increased for breathing room
            
            // If limited overs, add some extra space to accommodate overs text
            let text = (cricketMatch.matchDescription + " " + cricketMatch.statusText).lowercased()
            let isLimitedOvers = text.contains("t20") || text.contains("ipl") || text.contains("t-20") || 
                                 text.contains("odi") || text.contains("one day") || text.contains("50 overs") || 
                                 text.contains("t10") || text.contains("hundred") ||
                                 (cricketMatch.leagueId?.lowercased().contains("ipl") == true) ||
                                 (cricketMatch.leagueId?.lowercased().contains("t20") == true) ||
                                 (cricketMatch.leagueId?.lowercased().contains("hundred") == true)
            
            if isLimitedOvers {
                leftSideWidth += 70 // " (43.0/20)"
                rightSideWidth += 60 // " (20/20)"
            }
            
            return leftSideWidth + baseSpacer + rightSideWidth + padding
            
        default:
            // Soccer / NFL / NBA / NHL typical scores: e.g. "ABR 24" (~70px) and "17 ABR" (~70px)
            return 96 + baseSpacer + 96 + padding
        }
    }
    
    private var expandedHeight: CGFloat {
        if dataManager.showMatchSelector {
            return 280
        }
        
        if selectedTab == .nowPlaying && nowPlayingManager.currentTrack != nil {
            return 160
        }
        
        guard let match = dataManager.activeMatch else {
            return 240
        }
        
        switch match {
        case .cricket:
            return 360
        case .tennis:
            return 210
        case .soccer:
            return 220
        case .lacrosse:
            return 180
        case .f1:
            return 320
        case .nfl, .collegeFootball:
            return 240
        default:
            return 200
        }
    }
    
    private var currentWidth: CGFloat {
        if isExpanded {
            return dataManager.hasNotch ? 600 : 500
        } else {
            return collapsedWidth
        }
    }
    
    var body: some View {
        ZStack {
            // Background shape that morphs between capsule and rounded rect
            backgroundShape
            
            // Content
            if isExpanded {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
            } else {
                Group {
                    if nowPlayingManager.showMediaMode, nowPlayingManager.currentTrack != nil {
                        NowPlayingCollapsedView(manager: nowPlayingManager)
                    } else {
                        CollapsedScoreView(dataManager: dataManager)
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 1.02)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            if abs(value.translation.width) > 20 {
                                // Swipe gesture detected: toggle media / sports view
                                if nowPlayingManager.currentTrack != nil {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        nowPlayingManager.showMediaMode.toggle()
                                    }
                                }
                            } else if abs(value.translation.height) < 10 && abs(value.translation.width) < 10 {
                                // Tap gesture detected
                                if nowPlayingManager.showMediaMode {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        nowPlayingManager.showMediaMode = false
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        dataManager.showMatchSelector.toggle()
                                    }
                                }
                            }
                        }
                )
            }
        }
        .frame(
            width: currentWidth,
            height: isExpanded ? expandedHeight : 36
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .onChange(of: hoverState.isHovered) { newValue in
            withAnimation(expandAnimation) {
                isExpanded = newValue
            }
        }
        .onChange(of: nowPlayingManager.showMediaMode) { newValue in
            if newValue {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTab = .nowPlaying
                }
            }
        }
    }
    
    @ViewBuilder
    private var backgroundShape: some View {
        RoundedRectangle(
            cornerRadius: isExpanded ? 20 : 18,
            style: .continuous
        )
        .fill(DesignSystem.background)
        .overlay(
            RoundedRectangle(
                cornerRadius: isExpanded ? 20 : 18,
                style: .continuous
            )
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
        )
        .shadow(
            color: .black.opacity(isExpanded ? 0.4 : 0.15),
            radius: isExpanded ? 20 : 4,
            x: 0,
            y: isExpanded ? 8 : 2
        )
    }
    
    // MARK: - Expanded Content
    
    private var segmentHeader: some View {
        HStack(spacing: 0) {
            // Sports Tab Button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    selectedTab = .sports
                }
            }) {
                HStack(spacing: 6) {
                    Text("🏀")
                        .font(.system(size: 11))
                    Text("Sports")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(selectedTab == .sports ? .white : .white.opacity(0.5))
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedTab == .sports ? Color.white.opacity(0.12) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            
            // Now Playing Tab Button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    selectedTab = .nowPlaying
                }
            }) {
                HStack(spacing: 6) {
                    Text("🎵")
                        .font(.system(size: 11))
                    Text("Now Playing")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(selectedTab == .nowPlaying ? .white : .white.opacity(0.5))
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedTab == .nowPlaying ? Color.white.opacity(0.12) : Color.clear)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(3)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 6) {
            // Segment Bar at the top (only if not showing match selector and there is active media)
            if !dataManager.showMatchSelector && nowPlayingManager.currentTrack != nil {
                segmentHeader
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
            }
            
            Group {
                if selectedTab == .sports || nowPlayingManager.currentTrack == nil {
                    VStack(spacing: 0) {
                        if dataManager.showMatchSelector {
                            MatchSelectorView(dataManager: dataManager)
                        } else if let match = dataManager.activeMatch {
                            expandedView(for: match)
                        } else {
                            emptyState
                        }
                    }
                } else {
                    NowPlayingExpandedView(manager: nowPlayingManager)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func expandedView(for match: AnyMatch) -> some View {
        switch match {
        case .cricket(let cricketMatch):
            ExpandedCricketView(match: cricketMatch, dataManager: dataManager)
        case .tennis(let tennisMatch):
            ExpandedTennisView(match: tennisMatch)
        case .nfl(let nflGame):
            ExpandedNFLView(game: nflGame)
        case .collegeFootball(let cfbGame):
            // Reuse NFL-style expanded view for College Football
            ExpandedNFLView(game: NFLGame(
                id: cfbGame.id, status: cfbGame.status,
                homeTeam: cfbGame.homeTeam, awayTeam: cfbGame.awayTeam,
                homeTeamAbbrev: cfbGame.homeTeamAbbrev, awayTeamAbbrev: cfbGame.awayTeamAbbrev,
                homeScore: cfbGame.homeScore, awayScore: cfbGame.awayScore,
                statusText: cfbGame.statusText, homeLogoURL: cfbGame.homeLogoURL, awayLogoURL: cfbGame.awayLogoURL,
                quarterScores: cfbGame.quarterScores, currentQuarter: cfbGame.currentQuarter,
                gameClock: cfbGame.gameClock, situation: cfbGame.situation,
                lastPlay: cfbGame.lastPlay
            ))
        case .collegeBasketball(let cbbGame):
            // Simple score display for basketball
            GenericExpandedView(match: .collegeBasketball(cbbGame), accentColor: DesignSystem.cbbOrange, sportIcon: "basketball.fill")
        case .soccer(let soccerMatch):
            ExpandedSoccerView(match: soccerMatch)
        case .lacrosse(let laxGame):
            GenericExpandedView(match: .lacrosse(laxGame), accentColor: DesignSystem.lacrossePurple, sportIcon: "figure.lacrosse")
        case .volleyball(let vballGame):
            GenericExpandedView(match: .volleyball(vballGame), accentColor: DesignSystem.volleyballPink, sportIcon: "volleyball.fill")
        case .mlb(let mlbGame):
            ExpandedMLBView(game: mlbGame)
        case .nba(let nbaGame):
            ExpandedNBAView(game: nbaGame)
        case .nhl(let nhlGame):
            ExpandedNHLView(game: nhlGame)
        case .collegeHockey(let chGame):
            ExpandedNHLView(game: NHLGame(
                id: chGame.id, status: chGame.status,
                homeTeam: chGame.homeTeam, awayTeam: chGame.awayTeam,
                homeTeamAbbrev: chGame.homeTeamAbbrev, awayTeamAbbrev: chGame.awayTeamAbbrev,
                homeScore: chGame.homeScore, awayScore: chGame.awayScore,
                statusText: chGame.statusText, homeLogoURL: chGame.homeLogoURL, awayLogoURL: chGame.awayLogoURL,
                eventDate: chGame.eventDate,
                periodScores: chGame.periodScores, currentPeriod: chGame.currentPeriod,
                gameClock: chGame.gameClock, homeShotsOnGoal: chGame.homeShotsOnGoal,
                awayShotsOnGoal: chGame.awayShotsOnGoal, powerPlay: nil,
                lastPlay: chGame.lastPlay
            ))
        case .f1(let race):
            ExpandedF1View(race: race)
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sportscourt")
                .font(.system(size: 32))
                .foregroundColor(DesignSystem.secondaryText)
            
            Text("No Match Selected")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(DesignSystem.primaryText)
            
            Text("Hover and click to select a match")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(DesignSystem.secondaryText)
            
            Button(action: {
                withAnimation(expandAnimation) {
                    dataManager.showMatchSelector = true
                }
            }) {
                Label("Browse Matches", systemImage: "list.bullet")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
