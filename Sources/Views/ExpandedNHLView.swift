// ExpandedNHLView.swift
// NotchIslandSports
//
// NHL and College Ice Hockey expanded card with period-by-period score table, SOG comparison bar,
// power play indicators, and last play ticker.

import SwiftUI

struct ExpandedNHLView: View {
    let game: NHLGame
    
    private let accentColor = Color(hex: "444444") // NHL Gray
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with scores
            headerSection
            
            nhlAccentDivider
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    // Period scores table
                    periodScoreTable
                    
                    // SOG Comparison Bar
                    sogSection
                    
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
            // Home team
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(game.homeTeam)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundColor(DesignSystem.primaryText)
                        .lineLimit(1)
                    
                    if game.powerPlay == "home" || game.powerPlay == game.homeTeamAbbrev {
                        powerPlayBadge
                    }
                }
                
                Text(game.homeScore)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundColor(DesignSystem.primaryText)
            }
            
            Spacer()
            
            // Game clock & period
            VStack(spacing: 2) {
                gameClockBadge
                
                Text(periodLabel(game.currentPeriod))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(DesignSystem.secondaryText)
            }
            
            Spacer()
            
            // Away team
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    if game.powerPlay == "away" || game.powerPlay == game.awayTeamAbbrev {
                        powerPlayBadge
                    }
                    
                    Text(game.awayTeam)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundColor(DesignSystem.primaryText)
                        .lineLimit(1)
                }
                
                Text(game.awayScore)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundColor(DesignSystem.primaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Game Clock Badge
    
    @ViewBuilder
    private var gameClockBadge: some View {
        if game.status == .live && !game.gameClock.isEmpty {
            HStack(spacing: 4) {
                PulsingDot(color: DesignSystem.liveRed, size: 4)
                Text(game.gameClock)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
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
    
    // MARK: - Power Play Badge
    
    private var powerPlayBadge: some View {
        Text("PP")
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundColor(.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.yellow)
            )
    }
    
    // MARK: - NHL Divider
    
    private var nhlAccentDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        accentColor.opacity(0.6),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.horizontal, 10)
    }
    
    // MARK: - Period Score Table
    
    private var periodScoreTable: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("TEAM")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(game.periodScores) { ps in
                    Text(ps.periodLabel)
                        .frame(width: 30)
                }
                
                Text("T")
                    .frame(width: 32)
                    .foregroundColor(Color.red)
            }
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundColor(DesignSystem.secondaryText.opacity(0.6))
            .padding(.bottom, 4)
            
            // Home team row
            HStack(spacing: 0) {
                Text(game.homeTeamAbbrev)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(game.periodScores) { ps in
                    Text("\(ps.homeScore)")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 30)
                }
                
                Text(game.homeScore)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .frame(width: 32)
            }
            .foregroundColor(DesignSystem.primaryText)
            
            Rectangle()
                .fill(DesignSystem.capsuleBorder.opacity(0.3))
                .frame(height: 0.5)
                .padding(.vertical, 3)
            
            // Away team row
            HStack(spacing: 0) {
                Text(game.awayTeamAbbrev)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(game.periodScores) { ps in
                    Text("\(ps.awayScore)")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 30)
                }
                
                Text(game.awayScore)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .frame(width: 32)
            }
            .foregroundColor(DesignSystem.primaryText)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
    
    // MARK: - Shots on Goal Section
    
    private var sogSection: some View {
        VStack(spacing: 4) {
            HStack {
                Text("SOG: \(game.homeShotsOnGoal)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.primaryText)
                
                Spacer()
                
                Text("SHOTS ON GOAL")
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.secondaryText.opacity(0.5))
                
                Spacer()
                
                Text("\(game.awayShotsOnGoal) :SOG")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.primaryText)
            }
            
            // Visual SOG bar
            let total = Double(game.homeShotsOnGoal + game.awayShotsOnGoal)
            let ratio = total > 0 ? Double(game.homeShotsOnGoal) / total : 0.5
            
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(ratio))
                    
                    Rectangle()
                        .fill(Color.red.opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(1.0 - ratio))
                }
            }
            .frame(height: 4)
            .cornerRadius(2)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Last Play Banner
    
    private func lastPlayBanner(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "play.fill")
                .font(.system(size: 8))
                .foregroundColor(Color.red)
            
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
                .fill(Color.red.opacity(0.08))
        )
    }
    
    // MARK: - Helpers
    
    private func periodLabel(_ period: Int) -> String {
        switch period {
        case 1: return "1st Period"
        case 2: return "2nd Period"
        case 3: return "3rd Period"
        default: return "Overtime \(period - 3)"
        }
    }
}
