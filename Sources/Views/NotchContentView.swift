// NotchContentView.swift
// NotchIslandSports
//
// Main SwiftUI container that morphs between collapsed capsule
// and expanded sport-specific detail card.

import SwiftUI
import IslandCore

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
    @ObservedObject var dataManager: SportsDataManager
    @ObservedObject var nowPlayingManager: NowPlayingManager
    @ObservedObject var clockManager: NativeClockManager
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var approvals: ApprovalManager
    @ObservedObject var presentation: IslandPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { geometry in
            islandSurface(size: geometry.size)
        }
        // Window-frame motion is the sole animator; avoid a second SwiftUI layout spring.
        .transaction { $0.animation = nil }
        .transaction { if reduceMotion || presentation.reduceMotion || presentation.lowPower || presentation.suspended { $0.disablesAnimations = true } }
        .modifier(IslandSwipeGesture(presentation: presentation, headerOnly: true))
        .onExitCommand { presentation.collapse() }
    }

    private var compactHeight: CGFloat {
        max(1, presentation.cameraHeight > 0 ? presentation.cameraHeight : 33)
    }

    private func islandSurface(size: CGSize) -> some View {
        let travel = max(1, presentation.expandedPanelHeight - compactHeight)
        let progress: CGFloat = min(1, max(0, (size.height - compactHeight) / travel))
        let shape = IslandSurfaceShape(media: presentation.contentActivity == .music &&
            (presentation.expanded || presentation.expandedContentMounted), expanded: presentation.expanded)
        return ZStack(alignment: .top) {
            if presentation.expanded || presentation.expandedContentMounted {
                expandedSurface(progress: progress)
            }
            if !presentation.expanded || progress < 1 {
                compactSurface(progress: progress)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(shape.fill(Color.black))
        .overlay(shape.stroke(Color.white.opacity(contrast == .increased ? 0.55 : 0.20), lineWidth: 1)
            .allowsHitTesting(false))
        .clipShape(shape)
        .foregroundColor(.white)
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
    }

    private func expandedSurface(progress: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: presentation.cameraHeight)
            expandedPage(moving: mediaMotionAllowed && presentation.expanded && progress >= 0.99)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if presentation.contentActivity == .sports, let error = dataManager.detailError ?? dataManager.lastError {
                Text(error).font(.caption).foregroundColor(.orange).padding(.bottom, 4)
            }
            Button { presentation.collapse() } label: {
                Capsule().fill(Color.white.opacity(0.32)).frame(width: 34, height: 4)
                    .frame(maxWidth: .infinity).frame(height: 18).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Collapse island")
            .keyboardShortcut(.cancelAction)
        }
        .frame(width: presentation.expandedPanelWidth, height: presentation.expandedPanelHeight, alignment: .top)
        .opacity(Double(min(1, max(0, (progress - 0.10) / 0.55))))
        .allowsHitTesting(presentation.expanded && progress > 0.75)
        .accessibilityHidden(!presentation.expanded)
    }

    @ViewBuilder private func expandedPage(moving: Bool) -> some View {
        switch presentation.contentActivity {
        case .sports:
            if dataManager.showMatchSelector { MatchSelectorView(dataManager: dataManager) }
            else if let match = dataManager.activeMatch { expandedView(for: match) }
            else { emptyState }
        case .music:
            VStack(spacing: 4) {
                NowPlayingExpandedView(manager: nowPlayingManager, animationAllowed: moving,
                    progressVisible: presentation.expanded && !presentation.suspended, lowPower: presentation.lowPower)
                if let error = nowPlayingManager.controlError {
                    Text(error).font(.caption).foregroundColor(.orange)
                } else if nowPlayingManager.currentTrack != nil && !nowPlayingManager.canControl {
                    Text("This player is not exposing playback controls.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        case .calendar: NativeCalendarView(manager: calendarManager)
        case .clock: NativeClockView(manager: clockManager)
        case .approval: ApprovalExpandedView(manager: approvals)
        }
    }

    private var compactAccessibilityLabel: String {
        if presentation.collapsedActivity == .music { return "Expand music: \(nowPlayingManager.currentTrack?.title ?? "Music")" }
        return "Expand \(presentation.collapsedActivity.rawValue) activity"
    }

    private func compactSurface(progress: CGFloat) -> some View {
        Button { presentation.open(presentation.collapsedActivity) } label: {
            compactPage.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .frame(height: compactHeight)
        .opacity(Double(max(0, 1 - progress / 0.25)))
        .allowsHitTesting(!presentation.expanded && progress < 0.25)
        .accessibilityHidden(presentation.expanded)
        .accessibilityLabel(compactAccessibilityLabel)
    }

    @ViewBuilder private var compactPage: some View {
        switch presentation.collapsedActivity {
        case .sports: CollapsedScoreView(dataManager: dataManager)
        case .music: cameraSafeCompact(.music)
        case .calendar: cameraSafeCompact(.calendar)
        case .approval:
            NotchEars(gap: dataManager.notchWidth) { ApprovalCompactView(manager: approvals) } right: {
                Text(approvals.requests.first?.provider.label ?? "Approvals").font(.system(size: 10)).foregroundColor(.orange)
            }
        case .clock: cameraSafeCompact(.clock)
        }
    }

    private var mediaMotionAllowed: Bool {
        MediaMotion.allowed(playing: nowPlayingManager.currentTrack?.isPlaying == true,
            active: nowPlayingManager.isActive, visible: !presentation.suspended,
            reduceMotion: reduceMotion || presentation.reduceMotion, lowPower: presentation.lowPower)
    }

    private func cameraSafeCompact(_ activity: IslandActivity) -> some View {
        NotchEars(gap: dataManager.hasNotch ? dataManager.notchWidth + 12 : 20) {
            HStack(spacing: 6) {
                Image(systemName: activity == .music ? "music.note" : activity == .clock ? "timer" : "calendar")
                    .foregroundColor(activity == .clock ? .orange : .cyan)
                if activity == .music {
                    ScrollingMediaTitle(title: nowPlayingManager.currentTrack?.title ?? "Music",
                        moving: mediaMotionAllowed && !presentation.expanded)
                } else {
                    Text(activity == .clock ? "Apple Clock" : (calendarManager.currentEvent?.title ?? "Calendar"))
                        .font(.system(size: 11, weight: .semibold))
                }
            }
        } right: {
            Group {
                if activity == .clock { NativeClockCompactView(manager: clockManager, minimal: true) }
                else if activity == .calendar {
                    if let event = calendarManager.currentEvent {
                        Text(event.allDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 11, weight: .semibold)).foregroundColor(.cyan)
                    } else {
                        Text("No more today").font(.system(size: 10)).foregroundColor(.secondary)
                    }
                } else {
                    DynamicIslandWaveform(isPlaying: nowPlayingManager.currentTrack?.isPlaying == true,
                        color: nowPlayingManager.currentTrack?.dominantColor ?? .cyan,
                        barCount: 5, animationAllowed: mediaMotionAllowed && !presentation.expanded)
                }
            }
        }
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
            
            Text("Choose Select Match from the menu-bar menu")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(DesignSystem.secondaryText)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

