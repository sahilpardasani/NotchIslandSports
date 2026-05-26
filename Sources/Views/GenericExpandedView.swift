// GenericExpandedView.swift
// NotchIslandSports
//
// A reusable expanded view for sports that don't have their own
// custom detailed view (e.g., College Basketball, Lacrosse).
// Shows scores, status, and a clean sport-branded card.

import SwiftUI

struct GenericExpandedView: View {
    let match: AnyMatch
    let accentColor: Color
    let sportIcon: String

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            accentDivider

            VStack(spacing: 14) {
                // Status badge
                statusBadge

                // Large Score
                HStack(spacing: 20) {
                    // Home
                    VStack(spacing: 4) {
                        Text(match.homeTeamAbbrev)
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundColor(DesignSystem.secondaryText)
                        Text(match.homeScore)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.primaryText)
                    }

                    Text("–")
                        .font(.system(size: 24, weight: .light, design: .rounded))
                        .foregroundColor(DesignSystem.secondaryText)

                    // Away
                    VStack(spacing: 4) {
                        Text(match.awayTeamAbbrev)
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundColor(DesignSystem.secondaryText)
                        Text(match.awayScore)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.primaryText)
                    }
                }
                .padding(.vertical, 8)

                // Sport icon decoration
                Image(systemName: sportIcon)
                    .font(.system(size: 40))
                    .foregroundColor(accentColor.opacity(0.15))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(match.homeTeam)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundColor(DesignSystem.primaryText)
                    .lineLimit(1)
            }

            Spacer()

            VStack(spacing: 2) {
                Image(systemName: sportIcon)
                    .font(.system(size: 10))
                    .foregroundColor(accentColor)

                Text("vs")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(DesignSystem.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(match.awayTeam)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundColor(DesignSystem.primaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        if match.status == .live {
            HStack(spacing: 4) {
                PulsingDot(color: DesignSystem.liveRed, size: 5)
                Text("LIVE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.liveRed)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(DesignSystem.liveRed.opacity(0.12))
            )
        } else if match.status == .completed {
            Text("FINAL")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
        } else {
            Text(match.statusText)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(DesignSystem.secondaryText)
        }
    }

    // MARK: - Divider

    private var accentDivider: some View {
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
}
