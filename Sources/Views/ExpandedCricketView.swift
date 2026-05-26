// ExpandedCricketView.swift
// NotchIslandSports
//
// Rich cricket scorecard showing batting, bowling, partnership,
// run rates, and match description in a compact, information-dense layout.

import SwiftUI

struct ExpandedCricketView: View {
    let match: CricketMatch
    @ObservedObject var dataManager: SportsDataManager
    
    @State private var isBlinking = false
    
    private var isHindi: Bool {
        dataManager.isHindi
    }
    
    // MARK: - Cricket Break Types
    enum CricketBreakType: String {
        case strategicTimeout = "Strategic Timeout"
        case inningsBreak = "Innings Break"
        case lunch = "Lunch Break"
        case tea = "Tea Break"
        case drinks = "Drinks Break"
        case rainDelay = "Rain Delay"
        
        var title: String {
            switch self {
            case .strategicTimeout: return "STRATEGIC TIMEOUT"
            case .inningsBreak: return "INNINGS BREAK"
            case .lunch: return "LUNCH BREAK"
            case .tea: return "TEA BREAK"
            case .drinks: return "DRINKS BREAK"
            case .rainDelay: return "RAIN DELAY"
            }
        }
        
        var icon: String {
            switch self {
            case .strategicTimeout: return "timer"
            case .inningsBreak: return "hourglass"
            case .lunch: return "fork.knife"
            case .tea: return "cup.and.saucer.fill"
            case .drinks: return "drop.fill"
            case .rainDelay: return "cloud.rain.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .strategicTimeout: return Color.red // strategic timeout in red
            case .inningsBreak: return DesignSystem.cricketGreen
            case .lunch: return DesignSystem.nflOrange
            case .tea: return Color(red: 0.9, green: 0.6, blue: 0.1) // warm amber/tea brown
            case .drinks: return Color(red: 0.1, green: 0.6, blue: 1.0) // drinks blue
            case .rainDelay: return Color(red: 0.2, green: 0.8, blue: 0.9) // rain delay cyan
            }
        }
    }
    
    private var activeBreakType: CricketBreakType? {
        let text = (match.statusText + " " + match.matchDescription).lowercased()
        
        if text.contains("strategic timeout") || text.contains("strategic time-out") || text.contains("strategic break") {
            return .strategicTimeout
        } else if text.contains("innings break") || text.contains("innings interval") || text.contains("break between innings") || text.contains("mid innings") || text.contains("mid-innings") {
            return .inningsBreak
        } else if text.contains("lunch") {
            return .lunch
        } else if text.contains("tea") && !text.contains("team") && !text.contains("teas") {
            if text.contains("tea break") || text.contains("tea interval") || text.contains("take tea") || text.contains("at tea") {
                return .tea
            }
            let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            if words.contains("tea") {
                return .tea
            }
        }
        
        if text.contains("drinks") || text.contains("drink break") || text.contains("drinks break") {
            return .drinks
        } else if text.contains("rain") || text.contains("bad light") || text.contains("wet outfield") || text.contains("wet pitch") || text.contains("delayed by rain") {
            return .rainDelay
        }
        
        return nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            divider
            
            if match.status == .completed {
                concludedScorecardView
            } else {
                liveOrUpcomingScrollView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var breakBannerView: some View {
        if let breakType = activeBreakType {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(breakType.color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: breakType.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(breakType.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(HindiTranslator.translate(breakType.title, isHindi: isHindi))
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundColor(breakType.color)
                        
                        Circle()
                            .fill(breakType.color)
                            .frame(width: 6, height: 6)
                            .opacity(isBlinking ? 0.35 : 1.0)
                            .scaleEffect(isBlinking ? 1.3 : 1.0)
                    }
                    
                    Text(HindiTranslator.translate(match.statusText, isHindi: isHindi))
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .foregroundColor(DesignSystem.primaryText)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(breakType.color.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        breakType.color.opacity(0.4),
                                        breakType.color.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
                ) {
                    isBlinking = true
                }
            }
        }
    }
    
    private var liveOrUpcomingScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                // Active cricket breaks (strategic timeout, innings break, test match breaks)
                breakBannerView
                
                // Batting
                if !match.batsmen.isEmpty {
                    battingSection
                }
                
                // Bowling
                if let bowler = match.bowler {
                    bowlingSection(bowler: bowler)
                }
                
                // Partnership & Run Rates + Language Toggle
                HStack(spacing: 16) {
                    if let partnership = match.partnership {
                        partnershipBadge(partnership: partnership)
                    }
                    runRatesSection
                    
                    Spacer()
                    
                    languageToggleButton
                }
                
                // Match Description
                if !match.matchDescription.isEmpty {
                    matchDescriptionBanner(match.matchDescription)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 4) {
            HStack {
                // Home team
                VStack(alignment: .leading, spacing: 2) {
                    Text(HindiTranslator.translate(match.homeTeam, isHindi: isHindi))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundColor(DesignSystem.primaryText)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(HindiTranslator.translate(match.homeScore, isHindi: isHindi))
                            .font(.system(.title3, design: .monospaced).weight(.bold))
                            .foregroundColor(DesignSystem.primaryText)
                        
                        if let innings = match.currentInnings {
                            Text("(\(innings.formattedOvers) \(isHindi ? "ओवर" : "ov"))")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(DesignSystem.secondaryText)
                        }
                    }
                }
                
                Spacer()
                
                // Status / VS
                VStack(spacing: 2) {
                    liveBadge
                    Text(isHindi ? "बनाम" : "vs")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(DesignSystem.secondaryText)
                }
                
                Spacer()
                
                // Away team
                VStack(alignment: .trailing, spacing: 2) {
                    Text(HindiTranslator.translate(match.awayTeam, isHindi: isHindi))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundColor(DesignSystem.primaryText)
                        .lineLimit(1)
                    
                    Text(HindiTranslator.translate(match.awayScore, isHindi: isHindi))
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .foregroundColor(DesignSystem.primaryText)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Live Badge
    
    @ViewBuilder
    private var liveBadge: some View {
        if match.statusText.lowercased().contains("live") {
            HStack(spacing: 4) {
                PulsingDot(color: DesignSystem.liveRed, size: 5)
                Text(isHindi ? "लाइव" : "LIVE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.liveRed)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(DesignSystem.liveRed.opacity(0.15))
            )
        } else {
            Text(HindiTranslator.translate(match.statusText, isHindi: isHindi))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(DesignSystem.secondaryText)
                .lineLimit(1)
        }
    }
    
    // MARK: - Divider
    
    private var divider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        DesignSystem.cricketGreen.opacity(0.4),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.horizontal, 10)
    }
    
    // MARK: - Batting Section
    
    private var battingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(isHindi ? "बल्लेबाजी" : "BATTING", icon: "figure.cricket")
            
            // Column headers
            HStack(spacing: 0) {
                Text(isHindi ? "बल्लेबाज" : "Batter")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(isHindi ? "रन" : "R")
                    .frame(width: 32, alignment: .trailing)
                Text(isHindi ? "गेंद" : "B")
                    .frame(width: 32, alignment: .trailing)
                Text(isHindi ? "स्ट्राइक रेट" : "SR")
                    .frame(width: 44, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundColor(DesignSystem.secondaryText.opacity(0.7))
            
            ForEach(match.batsmen, id: \.name) { batsman in
                HStack(spacing: 0) {
                    HStack(spacing: 4) {
                        if batsman.isOnStrike {
                            Circle()
                                .fill(DesignSystem.cricketGreen)
                                .frame(width: 4, height: 4)
                        }
                        Text(HindiTranslator.translate(batsman.name, isHindi: isHindi))
                            .fontWeight(batsman.isOnStrike ? .bold : .regular)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("\(batsman.runs)")
                        .fontWeight(.semibold)
                        .frame(width: 32, alignment: .trailing)
                    
                    Text("\(batsman.balls)")
                        .frame(width: 32, alignment: .trailing)
                    
                    Text(String(format: "%.1f", batsman.strikeRate))
                        .frame(width: 44, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(DesignSystem.primaryText)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
    
    // MARK: - Bowling Section
    
    private func bowlingSection(bowler: Bowler) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(isHindi ? "गेंदबाजी" : "BOWLING", icon: "circle.dotted")
            
            HStack(spacing: 0) {
                Text(isHindi ? "गेंदबाज" : "Bowler")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(isHindi ? "ओवर" : "O")
                    .frame(width: 28, alignment: .trailing)
                Text(isHindi ? "मैडन" : "M")
                    .frame(width: 22, alignment: .trailing)
                Text(isHindi ? "रन" : "R")
                    .frame(width: 28, alignment: .trailing)
                Text(isHindi ? "विकेट" : "W")
                    .frame(width: 22, alignment: .trailing)
                Text(isHindi ? "इकोनॉमी" : "ECO")
                    .frame(width: 38, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundColor(DesignSystem.secondaryText.opacity(0.7))
            
            HStack(spacing: 0) {
                Text(HindiTranslator.translate(bowler.name, isHindi: isHindi))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(bowler.overs)
                    .frame(width: 28, alignment: .trailing)
                
                Text("\(bowler.maidens)")
                    .frame(width: 22, alignment: .trailing)
                
                Text("\(bowler.runs)")
                    .frame(width: 28, alignment: .trailing)
                
                Text("\(bowler.wickets)")
                    .fontWeight(.bold)
                    .foregroundColor(bowler.wickets > 0 ? DesignSystem.cricketGreen : DesignSystem.primaryText)
                    .frame(width: 22, alignment: .trailing)
                
                Text(String(format: "%.1f", bowler.economy))
                    .frame(width: 38, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .foregroundColor(DesignSystem.primaryText)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
    
    // MARK: - Partnership Badge
    
    private func partnershipBadge(partnership: Partnership) -> some View {
        VStack(spacing: 2) {
            Text(isHindi ? "साझेदारी" : "PARTNERSHIP")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.secondaryText.opacity(0.7))
            
            HStack(spacing: 2) {
                Text("\(partnership.runs)")
                    .font(.system(.body, design: .monospaced).weight(.bold))
                    .foregroundColor(DesignSystem.cricketGreen)
                
                Text("(\(partnership.balls)\(isHindi ? "गेंद" : "b"))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(DesignSystem.secondaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DesignSystem.cricketGreen.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(DesignSystem.cricketGreen.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Run Rates
    
    private var runRatesSection: some View {
        HStack(spacing: 10) {
            if let crr = match.currentRunRate {
                runRateIndicator(label: isHindi ? "सीआरआर" : "CRR", value: crr, max: 15)
            }
            if let rrr = match.requiredRunRate {
                runRateIndicator(label: isHindi ? "आरआरआर" : "RRR", value: rrr, max: 15)
            }
        }
    }
    
    private func runRateIndicator(label: String, value: Double, max: Double) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(DesignSystem.capsuleBorder, lineWidth: 2)
                
                Circle()
                    .trim(from: 0, to: CGFloat(min(value / max, 1.0)))
                    .stroke(
                        DesignSystem.cricketGreen,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                Text(String(format: "%.1f", value))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.primaryText)
            }
            .frame(width: 36, height: 36)
            
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.secondaryText.opacity(0.7))
        }
    }
    
    // MARK: - Language Toggle Button
    
    private var languageToggleButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0)) {
                dataManager.isHindi.toggle()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 9))
                Text(isHindi ? "English" : "हिंदी")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundColor(DesignSystem.cricketGreen)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DesignSystem.cricketGreen.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(DesignSystem.cricketGreen.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Match Description
    
    private func matchDescriptionBanner(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(DesignSystem.cricketGreen)
            
            Text(HindiTranslator.translate(text, isHindi: isHindi))
                .font(.system(.caption2, design: .rounded).weight(.medium))
                .foregroundColor(DesignSystem.primaryText)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DesignSystem.cricketGreen.opacity(0.08))
        )
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(DesignSystem.cricketGreen)
            
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
        }
    }
    
    private var concludedScorecardView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Venue Details
                if let venue = match.venue {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.cricketGreen)
                        Text(HindiTranslator.translate(venue, isHindi: isHindi))
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundColor(DesignSystem.secondaryText)
                    }
                    .padding(.top, 4)
                }

                // Dual Column Table
                HStack(alignment: .top, spacing: 10) {
                    // Left Column: Home Batting & Away Bowling
                    VStack(spacing: 10) {
                        // Home Batting Card
                        VStack(alignment: .leading, spacing: 4) {
                            concludedHeader(isHindi ? "\(HindiTranslator.translate(match.homeTeamAbbrev, isHindi: isHindi)) बल्लेबाजी" : "\(match.homeTeamAbbrev) BATTING", icon: "figure.cricket")
                            
                            HStack {
                                Text(isHindi ? "बल्लेबाज" : "Batter").font(.system(size: 8, weight: .medium, design: .rounded)).foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                                Spacer()
                                Text(isHindi ? "रन (गेंद)" : "R (B)").font(.system(size: 8, weight: .medium, design: .rounded)).foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                            }
                            .padding(.bottom, 2)
                            
                            if let batters = match.homeTopBatters, !batters.isEmpty {
                                ForEach(batters) { batter in
                                    HStack {
                                        Text(HindiTranslator.translate(batter.name, isHindi: isHindi))
                                            .font(.system(size: 10, weight: .regular, design: .rounded))
                                            .foregroundColor(DesignSystem.primaryText)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(batter.runs) (\(batter.balls))")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundColor(DesignSystem.primaryText)
                                    }
                                }
                            } else {
                                Text(isHindi ? "कोई बल्लेबाजी डेटा नहीं" : "No batting data")
                                    .font(.system(size: 9, weight: .regular, design: .rounded))
                                    .foregroundColor(DesignSystem.secondaryText)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                        )
                        
                        // Away Bowling Card
                        VStack(alignment: .leading, spacing: 4) {
                            concludedHeader(isHindi ? "\(HindiTranslator.translate(match.awayTeamAbbrev, isHindi: isHindi)) गेंदबाजी" : "\(match.awayTeamAbbrev) BOWLING", icon: "circle.dotted")
                            
                            HStack {
                                Text(isHindi ? "गेंदबाज" : "Bowler").font(.system(size: 8, weight: .medium, design: .rounded)).foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                                Spacer()
                                Text(isHindi ? "विकेट/रन (ओवर)" : "W/R (O)").font(.system(size: 8, weight: .medium, design: .rounded)).foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                            }
                            .padding(.bottom, 2)
                            
                            if let bowlers = match.awayTopBowlers, !bowlers.isEmpty {
                                ForEach(bowlers, id: \.name) { bowler in
                                    HStack {
                                        Text(HindiTranslator.translate(bowler.name, isHindi: isHindi))
                                            .font(.system(size: 10, weight: .regular, design: .rounded))
                                            .foregroundColor(DesignSystem.primaryText)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(bowler.wickets)/\(bowler.runs) (\(bowler.overs))")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundColor(DesignSystem.primaryText)
                                    }
                                }
                            } else {
                                Text(isHindi ? "कोई गेंदबाजी डेटा नहीं" : "No bowling data")
                                    .font(.system(size: 9, weight: .regular, design: .rounded))
                                    .foregroundColor(DesignSystem.secondaryText)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                        )
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Right Column: Away Batting & Home Bowling
                    VStack(spacing: 10) {
                        // Away Batting Card
                        VStack(alignment: .leading, spacing: 4) {
                            concludedHeader(isHindi ? "\(HindiTranslator.translate(match.awayTeamAbbrev, isHindi: isHindi)) बल्लेबाजी" : "\(match.awayTeamAbbrev) BATTING", icon: "figure.cricket")
                            
                            HStack {
                                Text(isHindi ? "बल्लेबाज" : "Batter").font(.system(size: 8, weight: .medium, design: .rounded)).foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                                Spacer()
                                Text(isHindi ? "रन (गेंद)" : "R (B)").font(.system(size: 8, weight: .medium, design: .rounded)).foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                            }
                            .padding(.bottom, 2)
                            
                            if let batters = match.awayTopBatters, !batters.isEmpty {
                                ForEach(batters) { batter in
                                    HStack {
                                        Text(HindiTranslator.translate(batter.name, isHindi: isHindi))
                                            .font(.system(size: 10, weight: .regular, design: .rounded))
                                            .foregroundColor(DesignSystem.primaryText)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(batter.runs) (\(batter.balls))")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundColor(DesignSystem.primaryText)
                                    }
                                }
                            } else {
                                Text(isHindi ? "कोई बल्लेबाजी डेटा नहीं" : "No batting data")
                                    .font(.system(size: 9, weight: .regular, design: .rounded))
                                    .foregroundColor(DesignSystem.secondaryText)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                        )
                        
                        // Home Bowling Card
                        VStack(alignment: .leading, spacing: 4) {
                            concludedHeader(isHindi ? "\(HindiTranslator.translate(match.homeTeamAbbrev, isHindi: isHindi)) गेंदबाजी" : "\(match.homeTeamAbbrev) BOWLING", icon: "circle.dotted")
                            
                            HStack {
                                Text(isHindi ? "गेंदबाज" : "Bowler").font(.system(size: 8, weight: .medium, design: .rounded)).foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                                Spacer()
                                Text(isHindi ? "विकेट/रन (ओवर)" : "W/R (O)").font(.system(size: 8, weight: .medium, design: .rounded)).foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                            }
                            .padding(.bottom, 2)
                            
                            if let bowlers = match.homeTopBowlers, !bowlers.isEmpty {
                                ForEach(bowlers, id: \.name) { bowler in
                                    HStack {
                                        Text(HindiTranslator.translate(bowler.name, isHindi: isHindi))
                                            .font(.system(size: 10, weight: .regular, design: .rounded))
                                            .foregroundColor(DesignSystem.primaryText)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(bowler.wickets)/\(bowler.runs) (\(bowler.overs))")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundColor(DesignSystem.primaryText)
                                    }
                                }
                            } else {
                                Text(isHindi ? "कोई गेंदबाजी डेटा नहीं" : "No bowling data")
                                    .font(.system(size: 9, weight: .regular, design: .rounded))
                                    .foregroundColor(DesignSystem.secondaryText)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                        )
                    }
                    .frame(maxWidth: .infinity)
                }

                // Player of the Match Banner
                if let potm = match.playerOfTheMatch {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.tennisGold)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(isHindi ? "प्लेयर ऑफ द मैच" : "PLAYER OF THE MATCH")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.tennisGold.opacity(0.8))
                            Text(HindiTranslator.translate(potm, isHindi: isHindi))
                                .font(.system(.caption2, design: .rounded).weight(.bold))
                                .foregroundColor(DesignSystem.primaryText)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DesignSystem.tennisGold.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(DesignSystem.tennisGold.opacity(0.25), lineWidth: 0.5)
                            )
                    )
                    .padding(.top, 4)
                }
                
                // Match description/result banner if any + Language Toggle
                HStack(spacing: 12) {
                    if !match.matchDescription.isEmpty {
                        matchDescriptionBanner(match.matchDescription)
                    } else {
                        Spacer()
                    }
                    
                    languageToggleButton
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private func concludedHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(DesignSystem.cricketGreen)
            
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.cricketGreen)
            
            Spacer()
        }
        .padding(.bottom, 4)
    }
}

// MARK: - PulsingDot (Shared)

/// A reusable pulsing dot indicator for live matches.
struct PulsingDot: View {
    let color: Color
    var size: CGFloat = 6
    
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.5), radius: 3)
            .scaleEffect(isPulsing ? 1.4 : 0.85)
            .opacity(isPulsing ? 0.6 : 1.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}
