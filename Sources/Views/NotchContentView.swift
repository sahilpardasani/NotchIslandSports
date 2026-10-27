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
    @ObservedObject var hoverState: HoverState
    @ObservedObject var dataManager: SportsDataManager
    @ObservedObject var nowPlayingManager: NowPlayingManager
    @ObservedObject var clockManager: NativeClockManager
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var presentation: IslandPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if presentation.expanded {
                VStack(spacing: 6) {
                    Color.clear.frame(height: presentation.cameraHeight)
                    Capsule().fill(Color.white.opacity(0.35)).frame(width: 34, height: 4)
                        .frame(maxWidth: .infinity).frame(height: 12).contentShape(Rectangle())
                        .accessibilityLabel("Drag up to collapse island")
                    HStack(spacing: 6) {
                        tab("Sports", icon: "sportscourt", activity: .sports)
                        tab("Music", icon: "music.note", activity: .music)
                        tab("Calendar", icon: "calendar", activity: .calendar)
                        tab("Clock", icon: "timer", activity: .clock)
                        Button { presentation.collapse() } label: { Image(systemName: "xmark") }
                            .buttonStyle(.plain).accessibilityLabel("Collapse island")
                            .keyboardShortcut(.cancelAction)
                    }
                    .padding(.horizontal, 10).padding(.top, 8)
                    Group {
                        switch presentation.selectedTab {
                        case .sports:
                            if dataManager.showMatchSelector { MatchSelectorView(dataManager: dataManager) }
                            else if let match = dataManager.activeMatch { expandedView(for: match) }
                            else { emptyState }
                        case .music:
                            VStack(spacing: 4) {
                                NowPlayingExpandedView(manager: nowPlayingManager)
                                if let error = nowPlayingManager.controlError {
                                    Text(error).font(.caption).foregroundColor(.orange)
                                } else if nowPlayingManager.currentTrack != nil && !nowPlayingManager.canControl {
                                    Text("Playback controls are available for identified Music and Spotify sources.")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                        case .calendar: NativeCalendarView(manager: calendarManager, presentation: presentation)
                        case .clock: NativeClockView(manager: clockManager)
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    if presentation.selectedTab == .sports, let error = dataManager.detailError ?? dataManager.lastError {
                        Text(error).font(.caption).foregroundColor(.orange).padding(.bottom, 4)
                    }
                }
            } else {
                Button {
                    presentation.open(presentation.selection.primary ?? .sports)
                } label: {
                    Group {
                        switch presentation.selection.primary ?? .sports {
                        case .sports: CollapsedScoreView(dataManager: dataManager)
                        case .music: cameraSafeCompact(.music)
                        case .calendar: cameraSafeCompact(.calendar)
                        case .clock: cameraSafeCompact(.clock)
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Expand \(presentation.selection.primary?.rawValue ?? "sports") activity")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: presentation.expanded ? 20 : 18).fill(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: presentation.expanded ? 20 : 18))
        .foregroundColor(.white)
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .transaction { if reduceMotion || presentation.lowPower || presentation.suspended { $0.disablesAnimations = true } }
        .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { value in
            // Expanded content keeps vertical drag/scroll interaction; its handle owns collapse.
            if !presentation.expanded || value.startLocation.y < presentation.cameraHeight + 36 || abs(value.translation.width) > abs(value.translation.height) {
                presentation.handleDrag(horizontal: value.translation.width, vertical: value.translation.height)
            }
        })
        .onExitCommand { presentation.collapse() }
    }

    private func cameraSafeCompact(_ activity: IslandActivity) -> some View {
        NotchEars(gap: dataManager.hasNotch ? dataManager.notchWidth + 12 : 20) {
            HStack(spacing: 6) {
                Image(systemName: activity == .music ? "music.note" : activity == .clock ? "timer" : "calendar")
                    .foregroundColor(activity == .clock ? .orange : .cyan)
                Text(activity == .music ? (nowPlayingManager.currentTrack?.title ?? "Music") :
                     activity == .clock ? "Apple Clock" : (calendarManager.currentEvent?.title ?? "Calendar"))
                    .font(.system(size: 11, weight: .semibold))
            }
        } right: {
            Group {
                if activity == .clock { NativeClockCompactView(manager: clockManager, minimal: true) }
                else if activity == .calendar, let event = calendarManager.currentEvent {
                    Text(event.allDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.cyan)
                } else {
                    Text(nowPlayingManager.currentTrack?.artist ?? "")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
        }
    }

    private func tab(_ title: String, icon: String, activity: IslandActivity) -> some View {
        Button { presentation.open(activity) } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(presentation.selectedTab == activity ? Color.white.opacity(0.16) : .clear))
        }.buttonStyle(.plain)
        .accessibilityAddTraits(presentation.selectedTab == activity ? .isSelected : [])
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
                withAnimation(.easeInOut(duration: 0.2)) {
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

