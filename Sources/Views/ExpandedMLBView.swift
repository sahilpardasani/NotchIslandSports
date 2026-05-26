// ExpandedMLBView.swift
// NotchIslandSports
//
// Custom expanded view for MLB games featuring a live baseball diamond representation,
// runs-hits-errors table, balls/strikes/outs indicators, and current pitcher.

import SwiftUI

struct ExpandedMLBView: View {
    let game: MLBGame
    
    private let accentColor = Color(hex: "09632A") // MLB Green
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with scores
            headerSection
            
            mlbAccentDivider
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    // Line Score Table (Runs, Hits, Errors)
                    rheTable
                    
                    HStack(spacing: 16) {
                        // Diamond View
                        BaseballDiamondView(onBase: game.onBase, accentColor: accentColor)
                            .padding(.leading, 8)
                        
                        // Count & Outs Indicators
                        VStack(alignment: .leading, spacing: 8) {
                            // Inning
                            HStack(spacing: 4) {
                                Image(systemName: game.inningHalf == "Top" ? "triangle.fill" : "triangle.inverse.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(accentColor)
                                Text("\(ordinalInning(game.inning))")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(DesignSystem.primaryText)
                            }
                            
                            // Balls & Strikes Count
                            HStack(spacing: 6) {
                                Text("COUNT:")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundColor(DesignSystem.secondaryText.opacity(0.8))
                                
                                Text("\(game.balls)-\(game.strikes)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(DesignSystem.primaryText)
                            }
                            
                            // Outs Indicators
                            HStack(spacing: 6) {
                                Text("OUTS:")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundColor(DesignSystem.secondaryText.opacity(0.8))
                                
                                HStack(spacing: 4) {
                                    ForEach(0..<3, id: \.self) { i in
                                        Circle()
                                            .fill(i < game.outs ? Color.yellow : Color.white.opacity(0.15))
                                            .frame(width: 7, height: 7)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                    )
                    
                    // Pitchers
                    pitcherInfo
                    
                    // Last Play
                    if let lastPlay = game.lastPlay, !lastPlay.isEmpty {
                        lastPlayBanner(lastPlay)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            // Home
            VStack(alignment: .leading, spacing: 2) {
                Text(game.homeTeam)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundColor(DesignSystem.primaryText)
                    .lineLimit(1)
                
                Text(game.homeScore)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundColor(DesignSystem.primaryText)
            }
            
            Spacer()
            
            // Inning / Game status
            VStack(spacing: 2) {
                gameStatusBadge
            }
            
            Spacer()
            
            // Away
            VStack(alignment: .trailing, spacing: 2) {
                Text(game.awayTeam)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundColor(DesignSystem.primaryText)
                    .lineLimit(1)
                
                Text(game.awayScore)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundColor(DesignSystem.primaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Status Badge
    
    @ViewBuilder
    private var gameStatusBadge: some View {
        if game.status == .live {
            HStack(spacing: 4) {
                PulsingDot(color: DesignSystem.liveRed, size: 4)
                Text("\(game.inningHalf == "Top" ? "▲" : "▼") \(game.inning)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.primaryText)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(DesignSystem.liveRed.opacity(0.12))
            )
        } else {
            Text(game.statusText)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(DesignSystem.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
        }
    }
    
    // MARK: - Divider
    
    private var mlbAccentDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        accentColor.opacity(0.4),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.horizontal, 10)
    }
    
    // MARK: - Runs Hits Errors Table
    
    private var rheTable: some View {
        VStack(spacing: 0) {
            // Header Row
            HStack(spacing: 0) {
                Text("TEAM")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("R")
                    .frame(width: 25)
                    .foregroundColor(accentColor)
                Text("H")
                    .frame(width: 25)
                Text("E")
                    .frame(width: 25)
            }
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundColor(DesignSystem.secondaryText.opacity(0.6))
            .padding(.bottom, 4)
            
            // Home Row
            HStack(spacing: 0) {
                Text(game.homeTeamAbbrev)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(game.homeScore)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .frame(width: 25)
                Text("\(game.homeHits)")
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 25)
                Text("\(game.homeErrors)")
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 25)
            }
            .foregroundColor(DesignSystem.primaryText)
            
            Rectangle()
                .fill(DesignSystem.capsuleBorder.opacity(0.3))
                .frame(height: 0.5)
                .padding(.vertical, 3)
            
            // Away Row
            HStack(spacing: 0) {
                Text(game.awayTeamAbbrev)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(game.awayScore)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .frame(width: 25)
                Text("\(game.awayHits)")
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 25)
                Text("\(game.awayErrors)")
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 25)
            }
            .foregroundColor(DesignSystem.primaryText)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
    
    // MARK: - Pitchers Info
    
    private var pitcherInfo: some View {
        HStack {
            if let homePitcher = game.homePitcher {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PITCHING (\(game.homeTeamAbbrev))")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                    Text(homePitcher)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(DesignSystem.primaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let awayPitcher = game.awayPitcher {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("PITCHING (\(game.awayTeamAbbrev))")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                    Text(awayPitcher)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(DesignSystem.primaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Last Play Banner
    
    private func lastPlayBanner(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "play.fill")
                .font(.system(size: 8))
                .foregroundColor(accentColor)
            
            Text(text)
                .font(.system(.caption2, design: .rounded).weight(.medium))
                .foregroundColor(DesignSystem.primaryText.opacity(0.85))
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accentColor.opacity(0.08))
        )
    }
    
    // MARK: - Helpers
    
    private func ordinalInning(_ num: Int) -> String {
        switch num {
        case 1: return "1st Inning"
        case 2: return "2nd Inning"
        case 3: return "3rd Inning"
        default: return "\(num)th Inning"
        }
    }
}

// MARK: - Baseball Diamond View

struct BaseballDiamondView: View {
    let onBase: [Bool]
    let accentColor: Color
    
    var body: some View {
        ZStack {
            // Path connecting bases
            Path { path in
                path.move(to: CGPoint(x: 35, y: 60))   // Home
                path.addLine(to: CGPoint(x: 65, y: 30)) // First
                path.addLine(to: CGPoint(x: 35, y: 0))  // Second
                path.addLine(to: CGPoint(x: 5, y: 30))  // Third
                path.closeSubpath()
            }
            .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
            
            // Second Base
            BaseMarker(isOccupied: onBase.count > 1 ? onBase[1] : false, accentColor: accentColor)
                .offset(y: -30)
            
            // Third Base
            BaseMarker(isOccupied: onBase.count > 2 ? onBase[2] : false, accentColor: accentColor)
                .offset(x: -30)
            
            // First Base
            BaseMarker(isOccupied: onBase.count > 0 ? onBase[0] : false, accentColor: accentColor)
                .offset(x: 30)
        }
        .frame(width: 70, height: 60)
    }
}

struct BaseMarker: View {
    let isOccupied: Bool
    let accentColor: Color
    
    var body: some View {
        Rectangle()
            .fill(isOccupied ? accentColor : Color.clear)
            .border(Color.white.opacity(0.4), width: 1.2)
            .frame(width: 8, height: 8)
            .rotationEffect(.degrees(45))
    }
}
