// ExpandedSoccerView.swift
// NotchIslandSports
//
// Soccer/Football expanded card with team scores, match minute,
// goal scorers, cards, half-time score, and league badge.

import SwiftUI

struct ExpandedSoccerView: View {
    let match: SoccerMatch
    
    var body: some View {
        VStack(spacing: 0) {
            // League badge
            leagueHeader
            
            // Header with scores
            headerSection
            
            soccerAccentDivider
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    // Goal scorers
                    if !match.goalScorers.isEmpty {
                        goalScorersSection
                    }
                    
                    // Cards
                    if !match.cards.isEmpty {
                        cardsSection
                    }
                    
                    // Soccer pitch decoration
                    SoccerPitchView()
                        .opacity(0.6)
                    
                    // Half-time score
                    if let htScore = match.halfTimeScore {
                        halfTimeScoreBadge(htScore)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - League Header
    
    @ViewBuilder
    private var leagueHeader: some View {
        if let league = match.leagueName {
            Text(league.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.soccerCyan)
                .tracking(1.0)
                .padding(.top, 10)
                .padding(.bottom, 2)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            // Home team
            VStack(alignment: .leading, spacing: 2) {
                Text(match.homeTeam)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundColor(DesignSystem.primaryText)
                    .lineLimit(1)
                
                Text(match.homeScore)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundColor(DesignSystem.primaryText)
            }
            
            Spacer()
            
            // Match minute & period
            VStack(spacing: 3) {
                matchTimeBadge
                
                if !match.period.isEmpty {
                    Text(match.period)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(DesignSystem.secondaryText)
                }
            }
            
            Spacer()
            
            // Away team
            VStack(alignment: .trailing, spacing: 2) {
                Text(match.awayTeam)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundColor(DesignSystem.primaryText)
                    .lineLimit(1)
                
                Text(match.awayScore)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundColor(DesignSystem.primaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
    
    // MARK: - Match Time Badge
    
    @ViewBuilder
    private var matchTimeBadge: some View {
        if !match.matchMinute.isEmpty {
            HStack(spacing: 4) {
                PulsingDot(color: DesignSystem.liveRed, size: 4)
                Text("\(match.matchMinute)'")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.primaryText)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(DesignSystem.liveRed.opacity(0.12))
            )
        } else {
            Text(match.statusText)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(DesignSystem.secondaryText)
        }
    }
    
    // MARK: - Divider
    
    private var soccerAccentDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        DesignSystem.soccerCyan.opacity(0.4),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.horizontal, 10)
    }
    
    // MARK: - Goal Scorers
    
    private var goalScorersSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "soccerball")
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.soccerCyan)
                
                Text("GOALS")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.soccerCyan.opacity(0.8))
            }
            
            ForEach(Array(match.goalScorers.enumerated()), id: \.offset) { _, goal in
                HStack(spacing: 6) {
                    // Minute
                    Text("\(goal.minute)'")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.soccerCyan)
                        .frame(width: 28, alignment: .trailing)
                    
                    // Team indicator dot
                    Circle()
                        .fill(
                            goal.team == match.homeTeamAbbrev
                                ? DesignSystem.primaryText
                                : DesignSystem.secondaryText
                        )
                        .frame(width: 4, height: 4)
                    
                    // Player name
                    Text(goal.playerName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(DesignSystem.primaryText)
                        .lineLimit(1)
                    
                    // Annotations
                    if goal.isPenalty {
                        annotationBadge("PEN", color: DesignSystem.soccerCyan)
                    }
                    if goal.isOwnGoal {
                        annotationBadge("OG", color: DesignSystem.liveRed)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
    
    // MARK: - Cards Section
    
    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "rectangle.portrait.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.yellow)
                
                Text("CARDS")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.secondaryText.opacity(0.7))
            }
            
            ForEach(Array(match.cards.enumerated()), id: \.offset) { _, card in
                HStack(spacing: 6) {
                    // Minute
                    Text("\(card.minute)'")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.secondaryText)
                        .frame(width: 28, alignment: .trailing)
                    
                    // Card indicator
                    cardIcon(for: card.cardType)
                    
                    // Player name
                    Text(card.playerName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(DesignSystem.primaryText)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Team
                    Text(card.team)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(DesignSystem.secondaryText)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
    
    // MARK: - Half-Time Score
    
    private func halfTimeScoreBadge(_ score: String) -> some View {
        HStack(spacing: 6) {
            Text("HT")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.secondaryText.opacity(0.6))
            
            Text(score)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(DesignSystem.secondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
                .overlay(
                    Capsule()
                        .stroke(DesignSystem.capsuleBorder.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Helpers
    
    private func annotationBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 7, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }
    
    @ViewBuilder
    private func cardIcon(for type: CardType) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(type == .red ? Color.red : Color.yellow)
            .frame(width: 8, height: 11)
            .shadow(color: (type == .red ? Color.red : Color.yellow).opacity(0.4), radius: 2)
    }
}
