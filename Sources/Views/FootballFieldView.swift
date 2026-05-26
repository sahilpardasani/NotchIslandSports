// FootballFieldView.swift
// NotchIslandSports
//
// Vector-drawn SwiftUI football field blueprint with yard lines,
// end zones, hash marks, animated position marker, and first-down line.

import SwiftUI

struct FootballFieldView: View {
    let situation: GameSituation?
    let homeTeamAbbrev: String
    let awayTeamAbbrev: String
    
    /// Animated marker position (0–100, left end zone to right end zone)
    @State private var animatedYardLine: CGFloat = 50
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let endZoneWidth = width * 0.1
            let fieldWidth = width - (endZoneWidth * 2)
            
            ZStack {
                // Main field background
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DesignSystem.fieldGreen)
                
                // End zones
                endZones(width: width, height: height, endZoneWidth: endZoneWidth)
                
                // Yard lines & numbers
                yardLines(fieldWidth: fieldWidth, height: height, startX: endZoneWidth)
                
                // Hash marks
                hashMarks(fieldWidth: fieldWidth, height: height, startX: endZoneWidth)
                
                // First down line
                if let situation = situation {
                    firstDownLine(
                        situation: situation,
                        fieldWidth: fieldWidth,
                        height: height,
                        startX: endZoneWidth
                    )
                }
                
                // Position marker
                if let situation = situation {
                    positionMarker(
                        yardLine: CGFloat(situation.yardLine),
                        fieldWidth: fieldWidth,
                        height: height,
                        startX: endZoneWidth
                    )
                }
                
                // Down & distance overlay
                if let situation = situation {
                    downAndDistanceLabel(situation: situation)
                }
                
                // Field border
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            }
        }
        .frame(height: 100)
        .onChange(of: situation?.yardLine) { newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedYardLine = CGFloat(newValue ?? 50)
            }
        }
    }
    
    // MARK: - End Zones
    
    private func endZones(width: CGFloat, height: CGFloat, endZoneWidth: CGFloat) -> some View {
        ZStack {
            // Left end zone
            UnevenRoundedRectangle(
                topLeadingRadius: 6,
                bottomLeadingRadius: 6,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(Color(hex: "1B5E20"))
            .frame(width: endZoneWidth)
            .position(x: endZoneWidth / 2, y: height / 2)
            .overlay(
                Text(homeTeamAbbrev)
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .rotationEffect(.degrees(-90))
                    .position(x: endZoneWidth / 2, y: height / 2)
            )
            
            // Right end zone
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 6,
                topTrailingRadius: 6
            )
            .fill(Color(hex: "1B5E20"))
            .frame(width: endZoneWidth)
            .position(x: width - endZoneWidth / 2, y: height / 2)
            .overlay(
                Text(awayTeamAbbrev)
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .rotationEffect(.degrees(90))
                    .position(x: width - endZoneWidth / 2, y: height / 2)
            )
        }
    }
    
    // MARK: - Yard Lines
    
    private func yardLines(fieldWidth: CGFloat, height: CGFloat, startX: CGFloat) -> some View {
        ZStack {
            ForEach(0...10, id: \.self) { i in
                let x = startX + fieldWidth * CGFloat(i) / 10.0
                
                // Yard line
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                
                // Yard numbers
                if i > 0 && i < 10 {
                    let yardNumber = i <= 5 ? i * 10 : (10 - i) * 10
                    Text("\(yardNumber)")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .position(x: x, y: height * 0.15)
                }
            }
        }
    }
    
    // MARK: - Hash Marks
    
    private func hashMarks(fieldWidth: CGFloat, height: CGFloat, startX: CGFloat) -> some View {
        ZStack {
            // Draw hash marks between each 10-yard interval
            ForEach(0..<100, id: \.self) { i in
                if i % 10 != 0 { // Skip positions where yard lines already exist
                    let x = startX + fieldWidth * CGFloat(i) / 100.0
                    let markLength: CGFloat = i % 5 == 0 ? 6 : 3
                    
                    // Top hash
                    Path { path in
                        path.move(to: CGPoint(x: x, y: height * 0.33 - markLength / 2))
                        path.addLine(to: CGPoint(x: x, y: height * 0.33 + markLength / 2))
                    }
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    
                    // Bottom hash
                    Path { path in
                        path.move(to: CGPoint(x: x, y: height * 0.67 - markLength / 2))
                        path.addLine(to: CGPoint(x: x, y: height * 0.67 + markLength / 2))
                    }
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                }
            }
        }
    }
    
    // MARK: - First Down Line
    
    private func firstDownLine(
        situation: GameSituation,
        fieldWidth: CGFloat,
        height: CGFloat,
        startX: CGFloat
    ) -> some View {
        let firstDownYard = min(max(situation.yardLine + situation.distance, 0), 100)
        let x = startX + fieldWidth * CGFloat(firstDownYard) / 100.0
        
        return Path { path in
            path.move(to: CGPoint(x: x, y: 2))
            path.addLine(to: CGPoint(x: x, y: height - 2))
        }
        .stroke(Color.yellow.opacity(0.8), lineWidth: 1.5)
        .shadow(color: .yellow.opacity(0.3), radius: 2)
    }
    
    // MARK: - Position Marker
    
    private func positionMarker(
        yardLine: CGFloat,
        fieldWidth: CGFloat,
        height: CGFloat,
        startX: CGFloat
    ) -> some View {
        let x = startX + fieldWidth * animatedYardLine / 100.0
        
        return ZStack {
            // Glow ring
            Circle()
                .fill(DesignSystem.nflOrange.opacity(0.2))
                .frame(width: 16, height: 16)
            
            // Marker
            Circle()
                .fill(DesignSystem.nflOrange)
                .frame(width: 8, height: 8)
                .shadow(color: DesignSystem.nflOrange.opacity(0.5), radius: 4)
        }
        .position(x: x, y: height / 2)
    }
    
    // MARK: - Down & Distance Label
    
    private func downAndDistanceLabel(situation: GameSituation) -> some View {
        let downText: String = {
            let ordinal: String
            switch situation.down {
            case 1: ordinal = "1st"
            case 2: ordinal = "2nd"
            case 3: ordinal = "3rd"
            case 4: ordinal = "4th"
            default: ordinal = "\(situation.down)th"
            }
            return "\(ordinal) & \(situation.distance)"
        }()
        
        return VStack {
            Spacer()
            HStack {
                Spacer()
                
                HStack(spacing: 4) {
                    if situation.isRedZone {
                        Circle()
                            .fill(DesignSystem.liveRed)
                            .frame(width: 4, height: 4)
                    }
                    
                    Text(downText)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(
                            situation.isRedZone
                                ? DesignSystem.liveRed.opacity(0.7)
                                : Color.black.opacity(0.6)
                        )
                )
                .padding(.trailing, 6)
                .padding(.bottom, 4)
            }
        }
    }
}

// MARK: - UnevenRoundedRectangle (macOS 12 compatible)

/// A shape with individually specified corner radii, available on macOS 12+.
struct UnevenRoundedRectangle: Shape {
    var topLeadingRadius: CGFloat
    var bottomLeadingRadius: CGFloat
    var bottomTrailingRadius: CGFloat
    var topTrailingRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let tl = min(topLeadingRadius, min(rect.width, rect.height) / 2)
        let tr = min(topTrailingRadius, min(rect.width, rect.height) / 2)
        let bl = min(bottomLeadingRadius, min(rect.width, rect.height) / 2)
        let br = min(bottomTrailingRadius, min(rect.width, rect.height) / 2)
        
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
            radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(
            center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
            radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
            radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(
            center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
            radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        path.closeSubpath()
        
        return path
    }
}
