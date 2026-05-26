// MatchSelectorView.swift
// NotchIslandSports
//
// Match selection overlay with sport filter tabs,
// scrollable match list, and dark glassmorphic styling.

import SwiftUI

struct MatchSelectorView: View {
    @ObservedObject var dataManager: SportsDataManager
    
    /// Currently selected sport filter tab
    @State private var selectedFilter: SportType? = nil
    @State private var isAppearing: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            headerBar
            
            // Sport filter tabs
            sportFilterTabs
            
            // Divider
            Rectangle()
                .fill(DesignSystem.capsuleBorder.opacity(0.4))
                .frame(height: 0.5)
                .padding(.horizontal, 8)
            
            // Match list
            matchListContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            selectedFilter = dataManager.selectedSportFilter
            withAnimation(.easeOut(duration: 0.3)) {
                isAppearing = true
            }
        }
        .opacity(isAppearing ? 1 : 0)
        .scaleEffect(isAppearing ? 1 : 0.95)
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack {
            Text("Matches")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundColor(DesignSystem.primaryText)
            
            Spacer()
            
            // Close button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    dataManager.showMatchSelector = false
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.secondaryText.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
    
    // MARK: - Sport Filter Tabs
    
    private var sportFilterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // "All" tab
                filterTab(label: "All", icon: "sportscourt", color: .white, isSelected: selectedFilter == nil) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedFilter = nil
                        dataManager.selectedSportFilter = nil
                    }
                }
                
                // Individual sport tabs
                ForEach(allSportTypes, id: \.self) { sport in
                    filterTab(
                        label: sportLabel(sport),
                        icon: sport.icon,
                        color: DesignSystem.accentColor(for: sport),
                        isSelected: selectedFilter == sport
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedFilter = sport
                            dataManager.selectedSportFilter = sport
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
    }
    
    private func filterTab(label: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(icon)
                    .font(.system(size: 9))
                
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : DesignSystem.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.3) : Color.white.opacity(0.05))
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected ? color.opacity(0.5) : Color.clear,
                                lineWidth: 0.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Match List Content
    
    @ViewBuilder
    private var matchListContent: some View {
        if dataManager.isLoading {
            loadingState
        } else if filteredMatches.isEmpty {
            emptyState
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(filteredMatches, id: \.id) { match in
                        matchRow(for: match)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
        }
    }
    
    // MARK: - Match Row
    
    private func matchRow(for match: AnyMatch) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                dataManager.selectMatch(match)
                dataManager.showMatchSelector = false
            }
        }) {
            HStack(spacing: 8) {
                // Sport icon (emoji)
                Text(match.sportType.icon)
                    .font(.system(size: 11))
                    .frame(width: 18, height: 18)
                
                // Team names
                VStack(alignment: .leading, spacing: 1) {
                    Text(match.homeTeam)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(DesignSystem.primaryText)
                        .lineLimit(1)
                    
                    Text(match.awayTeam)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(DesignSystem.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Score
                VStack(alignment: .trailing, spacing: 1) {
                    Text(match.homeScore)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.primaryText)
                    
                    Text(match.awayScore)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.primaryText)
                }
                .frame(width: 30)
                
                // Status badge
                statusBadge(for: match.status, text: match.statusText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isActiveMatch(match)
                            ? Color.white.opacity(0.08)
                            : Color.white.opacity(0.02)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isActiveMatch(match)
                            ? DesignSystem.accentColor(for: match.sportType).opacity(0.3)
                            : Color.clear,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Status Badge
    
    private func statusBadge(for status: MatchStatus, text: String) -> some View {
        let (color, label) = statusInfo(for: status, text: text)
        
        return Text(label)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }
    
    private func statusInfo(for status: MatchStatus, text: String) -> (Color, String) {
        switch status {
        case .live:
            return (DesignSystem.liveRed, "LIVE")
        case .upcoming:
            return (Color.blue, "UPCOMING")
        case .completed:
            return (DesignSystem.secondaryText, "FINAL")
        case .unknown:
            return (DesignSystem.secondaryText, text.prefix(8).uppercased().description)
        }
    }
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.8)
            
            Text("Loading matches...")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(DesignSystem.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sportscourt")
                .font(.system(size: 28))
                .foregroundColor(DesignSystem.secondaryText.opacity(0.5))
            
            Text("No matches available")
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundColor(DesignSystem.secondaryText)
            
            Button(action: {
                Task {
                    await dataManager.refresh()
                }
            }) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundColor(DesignSystem.soccerCyan)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(DesignSystem.soccerCyan.opacity(0.12))
                            .overlay(
                                Capsule()
                                    .stroke(DesignSystem.soccerCyan.opacity(0.3), lineWidth: 0.5)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helpers
    
    /// All sport types in display order
    private var allSportTypes: [SportType] {
        SportType.allCases
    }
    
    private var filteredMatches: [AnyMatch] {
        let matches = dataManager.filteredMatches
        if let filter = selectedFilter {
            return matches.filter { $0.sportType == filter }
        }
        return matches
    }
    
    private func isActiveMatch(_ match: AnyMatch) -> Bool {
        guard let active = dataManager.activeMatch else { return false }
        return active.id == match.id
    }
    
    private func sportLabel(_ sport: SportType) -> String {
        sport.rawValue
    }
}
