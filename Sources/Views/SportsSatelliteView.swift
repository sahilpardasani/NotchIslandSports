import AppKit
import SwiftUI
import IslandCore

/// Keep each competitor beside its own score. Scale the pair together only when
/// necessary; never truncate digits or let separate rows imply the wrong team.
struct SportsSatelliteView: View {
    let match: AnyMatch
    private let fontSize: CGFloat = 9.5

    private var homeScore: String { Self.score(match.homeScore, sport: match.sportType) }
    private var awayScore: String { Self.score(match.awayScore, sport: match.sportType) }
    private func width(_ text: String, score: Bool = false) -> CGFloat {
        let font = score ? NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold)
                         : NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    var body: some View {
        GeometryReader { proxy in
            let teamWidth = max(width(match.homeTeamAbbrev), width(match.awayTeamAbbrev))
            let scoreWidth = max(width(homeScore, score: true), width(awayScore, score: true))
            let naturalWidth = teamWidth + scoreWidth + 6
            let scale = min(1, proxy.size.width / max(1, naturalWidth))
            VStack(spacing: 0) {
                row(team: match.homeTeamAbbrev, score: homeScore, scoreWidth: scoreWidth)
                row(team: match.awayTeamAbbrev, score: awayScore, scoreWidth: scoreWidth)
            }
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: max(naturalWidth, proxy.size.width))
            .fixedSize(horizontal: false, vertical: true)
            .scaleEffect(scale)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilitySummary(match))
    }

    private func row(team: String, score: String, scoreWidth: CGFloat) -> some View {
        HStack(spacing: 6) {
            Text(team).fixedSize()
            Spacer(minLength: 0)
            Text(score).monospacedDigit().fixedSize()
                .frame(width: scoreWidth, alignment: .trailing)
        }
    }

    private static func score(_ value: String, sport: SportType) -> String {
        CompactActivityText.satelliteScore(value, cricket: sport == .cricket)
    }

    static func accessibilitySummary(_ match: AnyMatch) -> String {
        "\(match.sportType.rawValue): \(match.homeTeam), \(score(match.homeScore, sport: match.sportType)); \(match.awayTeam), \(score(match.awayScore, sport: match.sportType))"
    }
}
