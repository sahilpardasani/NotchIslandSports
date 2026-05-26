import SwiftUI

struct ExpandedF1View: View {
    let race: F1Race
    
    @State private var selectedSessionType: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // F1 Grand Prix Header
            raceHeader
            
            // F1 Accent Divider
            f1AccentDivider
            
            // Session Selector Tabs
            if !race.sessions.isEmpty {
                sessionTabBar
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            
            // Standings Grid
            if let activeSession = race.sessions.first(where: { $0.sessionType == selectedSessionType }) {
                if activeSession.competitors.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "clock.fill")
                            .font(.system(size: 28))
                            .foregroundColor(DesignSystem.secondaryText.opacity(0.4))
                        Text("No Standings Available")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.secondaryText.opacity(0.8))
                        Text("This session is \(activeSession.status.lowercased()).")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(activeSession.competitors) { driver in
                                driverRow(driver: driver)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                    }
                }
            } else {
                Spacer()
                Text("No active session found")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(DesignSystem.secondaryText)
                Spacer()
            }
            
            Spacer(minLength: 0)
            
            // Status Footer
            statusFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if selectedSessionType.isEmpty {
                selectedSessionType = race.activeSessionType
            }
            // Fallback if the active session type is not present
            if !race.sessions.contains(where: { $0.sessionType == selectedSessionType }), let first = race.sessions.first {
                selectedSessionType = first.sessionType
            }
        }
    }
    
    // MARK: - Header
    
    private var raceHeader: some View {
        VStack(spacing: 4) {
            Text(race.raceName.uppercased())
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .tracking(1.2)
                .lineLimit(1)
            
            HStack(spacing: 6) {
                Text("🏁 \(race.circuitName)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.secondaryText)
                
                Text("•")
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.secondaryText.opacity(0.5))
                
                Text(race.location)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(DesignSystem.secondaryText.opacity(0.8))
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
    
    // MARK: - Divider
    
    private var f1AccentDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(hex: "E10600").opacity(0.6),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1.5)
            .padding(.horizontal, 12)
    }
    
    // MARK: - Tab Bar
    
    private var sessionTabBar: some View {
        HStack(spacing: 4) {
            ForEach(race.sessions) { session in
                let isSelected = session.sessionType == selectedSessionType
                
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        selectedSessionType = session.sessionType
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(session.sessionType)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(isSelected ? .white : DesignSystem.secondaryText.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isSelected ? Color(hex: "E10600").opacity(0.15) : Color.clear)
                            )
                        
                        // F1 Red sliding indicator line
                        Rectangle()
                            .fill(isSelected ? Color(hex: "E10600") : Color.clear)
                            .frame(height: 2)
                            .cornerRadius(1)
                            .padding(.horizontal, 4)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DesignSystem.capsuleBorder.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Driver Row
    
    private func driverRow(driver: F1Driver) -> some View {
        HStack(spacing: 12) {
            // Position Badge
            ZStack {
                let podiumColor = podiumBadgeColor(for: driver.position)
                Circle()
                    .fill(podiumColor.opacity(0.15))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(podiumColor.opacity(0.4), lineWidth: 0.5)
                    )
                
                Text("P\(driver.position)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(podiumColor)
            }
            
            // Driver Flag
            if let flagURL = driver.flagURL, let url = URL(string: flagURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 12)
                        .cornerRadius(2)
                        .shadow(radius: 1)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 20, height: 12)
                }
            } else {
                Text(driver.country.prefix(3).uppercased())
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.secondaryText.opacity(0.6))
                    .frame(width: 20)
            }
            
            // Driver Names
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(driver.fullName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(driver.abbrev)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.secondaryText.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Winner badge
            if driver.winner {
                Text("WINNER")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "E6FF00")) // Eye-catching neon yellow winner badge!
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(hex: "E6FF00").opacity(0.15))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color(hex: "E6FF00").opacity(0.4), lineWidth: 0.5)
                            )
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(driver.winner ? Color(hex: "E10600").opacity(0.04) : Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(driver.winner ? Color(hex: "E10600").opacity(0.3) : DesignSystem.capsuleBorder.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Helpers
    
    private func podiumBadgeColor(for position: Int) -> Color {
        switch position {
        case 1:  return Color(hex: "FFD700") // Gold
        case 2:  return Color(hex: "C0C0C0") // Silver
        case 3:  return Color(hex: "CD7F32") // Bronze
        default: return DesignSystem.secondaryText
        }
    }
    
    // MARK: - Footer
    
    private var statusFooter: some View {
        Text(race.statusText)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(Color(hex: "E10600").opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(hex: "E10600").opacity(0.1))
            )
            .padding(.bottom, 8)
    }
}
