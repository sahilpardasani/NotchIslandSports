// ExpandedNBAView.swift
// NotchIslandSports
//
// NBA expanded card with quarter score breakdown, game clock badge,
// player leader stats, and last play ticker.

import SwiftUI

struct ExpandedNBAView: View {
    let game: NBAGame
    
    private let accentColor = Color(hex: "0C2340") // NBA Navy Blue
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with scores
            headerSection
            
            nbaAccentDivider
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    // Quarter scores table
                    quarterScoreTable
                    
                    // Leaders comparison
                    leadersSection
                    
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
                Text(game.homeTeam)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundColor(DesignSystem.primaryText)
                    .lineLimit(1)
                
                Text(game.homeScore)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundColor(DesignSystem.primaryText)
            }
            
            Spacer()
            
            // Game clock & quarter
            VStack(spacing: 2) {
                gameClockBadge
                
                Text(quarterLabel(game.currentQuarter))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(DesignSystem.secondaryText)
            }
            
            Spacer()
            
            // Away team
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
    
    // MARK: - NBA Divider
    
    private var nbaAccentDivider: some View {
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
    
    // MARK: - Quarter Score Table
    
    private var quarterScoreTable: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("TEAM")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(game.quarterScores, id: \.quarter) { qs in
                    Text("Q\(qs.quarter)")
                        .frame(width: 30)
                }
                
                Text("T")
                    .frame(width: 32)
                    .foregroundColor(Color.orange)
            }
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundColor(DesignSystem.secondaryText.opacity(0.6))
            .padding(.bottom, 4)
            
            // Home team row
            HStack(spacing: 0) {
                Text(game.homeTeamAbbrev)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(game.quarterScores, id: \.quarter) { qs in
                    Text("\(qs.homeScore)")
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
                
                ForEach(game.quarterScores, id: \.quarter) { qs in
                    Text("\(qs.awayScore)")
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
    
    // MARK: - Leaders Section
    
    private var leadersSection: some View {
        HStack {
            if let homeLeader = game.homeLeader {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LEADER (\(game.homeTeamAbbrev))")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                    Text(homeLeader)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(DesignSystem.primaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let awayLeader = game.awayLeader {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("LEADER (\(game.awayTeamAbbrev))")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                    Text(awayLeader)
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
                .foregroundColor(Color.orange)
            
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
                .fill(Color.orange.opacity(0.08))
        )
    }
    
    // MARK: - Helpers
    
    private func quarterLabel(_ quarter: Int) -> String {
        switch quarter {
        case 1: return "1st Quarter"
        case 2: return "2nd Quarter"
        case 3: return "3rd Quarter"
        case 4: return "4th Quarter"
        default: return "Overtime \(quarter - 4)"
        }
    }
}
