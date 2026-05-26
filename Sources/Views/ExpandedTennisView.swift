// ExpandedTennisView.swift
// NotchIslandSports
//
// Tennis scorecard with player names, serving indicator,
// set score grid, tiebreak superscripts, and current game score.

import SwiftUI

struct ExpandedTennisView: View {
    let match: TennisMatch
    
    var body: some View {
        VStack(spacing: 0) {
            // Tournament & Round
            tournamentHeader
            
            // Divider
            tennisAccentDivider
            
            // Scoreboard
            VStack(spacing: 8) {
                scoreGrid
                
                // Current game score
                if let gameScore = match.activeGameScore {
                    currentGameSection(gameScore: gameScore)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            Spacer(minLength: 0)
            
            // Status
            statusFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Tournament Header
    
    private var tournamentHeader: some View {
        VStack(spacing: 2) {
            if let tournament = match.tournamentName {
                Text(tournament.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.tennisGold)
                    .tracking(1.2)
            }
            if let round = match.round {
                Text(round)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(DesignSystem.secondaryText)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
    
    // MARK: - Tennis Divider
    
    private var tennisAccentDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        DesignSystem.tennisGold.opacity(0.4),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.horizontal, 10)
    }
    
    // MARK: - Score Grid
    
    private var scoreGrid: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(0..<max(match.sets.count, 1), id: \.self) { index in
                    Text("S\(index + 1)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(
                            match.currentSet - 1 == index
                                ? DesignSystem.tennisGold
                                : DesignSystem.secondaryText.opacity(0.5)
                        )
                        .frame(width: 28)
                }
                
                if match.activeGameScore != nil {
                    Text("GM")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.tennisGold)
                        .frame(width: 32)
                }
            }
            .padding(.bottom, 4)
            
            // Player 1 row
            playerRow(
                name: match.player1Name,
                country: match.player1Country,
                isServing: match.servingPlayer == 1,
                playerIndex: 1
            )
            
            Rectangle()
                .fill(DesignSystem.capsuleBorder.opacity(0.4))
                .frame(height: 0.5)
                .padding(.vertical, 3)
            
            // Player 2 row
            playerRow(
                name: match.player2Name,
                country: match.player2Country,
                isServing: match.servingPlayer == 2,
                playerIndex: 2
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DesignSystem.capsuleBorder.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Player Row
    
    private func playerRow(name: String, country: String?, isServing: Bool, playerIndex: Int) -> some View {
        HStack(spacing: 0) {
            // Player name + serving indicator
            HStack(spacing: 5) {
                if isServing {
                    Circle()
                        .fill(DesignSystem.cricketGreen)
                        .frame(width: 5, height: 5)
                        .shadow(color: DesignSystem.cricketGreen.opacity(0.5), radius: 2)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 12, weight: isServing ? .bold : .semibold, design: .rounded))
                        .foregroundColor(DesignSystem.primaryText)
                        .lineLimit(1)
                    
                    if let country = country {
                        Text(country)
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Set scores
            ForEach(0..<match.sets.count, id: \.self) { setIndex in
                let setScore = match.sets[setIndex]
                let games = playerIndex == 1 ? setScore.player1Games : setScore.player2Games
                let isCurrentSet = match.currentSet - 1 == setIndex
                
                ZStack(alignment: .topTrailing) {
                    Text("\(games)")
                        .font(.system(size: 14, weight: isCurrentSet ? .bold : .medium, design: .monospaced))
                        .foregroundColor(
                            isCurrentSet
                                ? DesignSystem.primaryText
                                : DesignSystem.secondaryText
                        )
                    
                    // Tiebreak superscript
                    if let tiebreak = setScore.tiebreak {
                        Text("\(tiebreak)")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.tennisGold.opacity(0.8))
                            .offset(x: 8, y: -2)
                    }
                }
                .frame(width: 28)
            }
            
            // Current game score
            if let gameScore = match.activeGameScore {
                let points = playerIndex == 1 ? gameScore.player1Points : gameScore.player2Points
                Text(points)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.tennisGold)
                    .frame(width: 32)
            }
        }
    }
    
    // MARK: - Current Game Section
    
    private func currentGameSection(gameScore: GameScore) -> some View {
        HStack(spacing: 16) {
            Text("Current Game")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(DesignSystem.secondaryText)
            
            HStack(spacing: 8) {
                Text(gameScore.player1Points)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundColor(DesignSystem.primaryText)
                
                Text("–")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(DesignSystem.secondaryText)
                
                Text(gameScore.player2Points)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundColor(DesignSystem.primaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DesignSystem.tennisGold.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(DesignSystem.tennisGold.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Status Footer
    
    private var statusFooter: some View {
        Text(match.statusText)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundColor(DesignSystem.secondaryText.opacity(0.7))
            .padding(.bottom, 8)
    }
}
