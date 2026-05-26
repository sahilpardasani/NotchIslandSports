// SoccerPitchView.swift
// NotchIslandSports
//
// Minimal vector-drawn soccer pitch for visual decoration.
// Draws center circle, penalty areas, goal areas, and halfway line.

import SwiftUI

struct SoccerPitchView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Pitch background
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DesignSystem.fieldGreen.opacity(0.3))
                
                // Field markings
                Canvas { context, size in
                    let lineColor = Color.white.opacity(0.2)
                    
                    // Outer boundary
                    let boundaryRect = CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4)
                    let boundaryPath = Path(roundedRect: boundaryRect, cornerRadius: 2)
                    context.stroke(boundaryPath, with: .color(lineColor), lineWidth: 0.5)
                    
                    // Halfway line
                    var halfwayPath = Path()
                    halfwayPath.move(to: CGPoint(x: size.width / 2, y: 2))
                    halfwayPath.addLine(to: CGPoint(x: size.width / 2, y: size.height - 2))
                    context.stroke(halfwayPath, with: .color(lineColor), lineWidth: 0.5)
                    
                    // Center circle
                    let centerRadius = min(size.width, size.height) * 0.15
                    let centerCircleRect = CGRect(
                        x: size.width / 2 - centerRadius,
                        y: size.height / 2 - centerRadius,
                        width: centerRadius * 2,
                        height: centerRadius * 2
                    )
                    let centerCirclePath = Path(ellipseIn: centerCircleRect)
                    context.stroke(centerCirclePath, with: .color(lineColor), lineWidth: 0.5)
                    
                    // Center dot
                    let dotSize: CGFloat = 2
                    let dotRect = CGRect(
                        x: size.width / 2 - dotSize / 2,
                        y: size.height / 2 - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(Path(ellipseIn: dotRect), with: .color(lineColor))
                    
                    // Left penalty area
                    let penaltyWidth = size.width * 0.15
                    let penaltyHeight = size.height * 0.55
                    let penaltyY = (size.height - penaltyHeight) / 2
                    let leftPenaltyRect = CGRect(x: 2, y: penaltyY, width: penaltyWidth, height: penaltyHeight)
                    context.stroke(Path(leftPenaltyRect), with: .color(lineColor), lineWidth: 0.5)
                    
                    // Left goal area
                    let goalWidth = size.width * 0.06
                    let goalHeight = size.height * 0.3
                    let goalY = (size.height - goalHeight) / 2
                    let leftGoalRect = CGRect(x: 2, y: goalY, width: goalWidth, height: goalHeight)
                    context.stroke(Path(leftGoalRect), with: .color(lineColor), lineWidth: 0.5)
                    
                    // Right penalty area
                    let rightPenaltyRect = CGRect(
                        x: size.width - penaltyWidth - 2,
                        y: penaltyY,
                        width: penaltyWidth,
                        height: penaltyHeight
                    )
                    context.stroke(Path(rightPenaltyRect), with: .color(lineColor), lineWidth: 0.5)
                    
                    // Right goal area
                    let rightGoalRect = CGRect(
                        x: size.width - goalWidth - 2,
                        y: goalY,
                        width: goalWidth,
                        height: goalHeight
                    )
                    context.stroke(Path(rightGoalRect), with: .color(lineColor), lineWidth: 0.5)
                }
                
                // Pitch border
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            }
        }
        .frame(height: 120)
    }
}
