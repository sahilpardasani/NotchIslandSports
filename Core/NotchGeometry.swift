import Foundation
import CoreGraphics

public struct NotchGeometry: Equatable, Sendable {
    public let centerX: CGFloat
    public let cameraWidth: CGFloat
    public let cameraHeight: CGFloat
    public let primary: CGRect
    public let secondary: CGRect
    public let tertiary: CGRect

    public static func layout(screen: CGRect, safeTop: CGFloat, leftArea: CGRect?, rightArea: CGRect?,
                              simulated: Bool = false, expanded: Bool, contentHeight: CGFloat) -> Self {
        let notched = safeTop > 0 || simulated
        let reportedWidth = (rightArea?.minX ?? 0) - (leftArea?.maxX ?? 0)
        let reportedCenter = ((leftArea?.maxX ?? 0) + (rightArea?.minX ?? 0)) / 2
        // Reject malformed/off-screen auxiliary rectangles rather than stretching across the display.
        let valid = reportedWidth >= 80 && reportedWidth <= 300 &&
            abs(reportedCenter - screen.midX) < screen.width * 0.1
        let cameraWidth: CGFloat = notched ? (valid ? reportedWidth : 180) : 0
        let cameraHeight: CGFloat = notched ? min(safeTop > 0 ? safeTop : 32, 60) : 0
        let center = notched && valid ? reportedCenter : screen.midX
        let top = notched ? screen.maxY : screen.maxY - 4
        // Match the actual menu-bar/camera band, removing the old 4pt spill below it.
        // Plain displays get the same small (3pt) trim without inventing a physical mm size.
        let compactHeight = notched ? cameraHeight : 33
        let satelliteWidth: CGFloat = min(96, max(64, screen.width * 0.065))
        let gap: CGFloat = 8
        // Symmetric allowance keeps the primary centered on the camera as activities appear/disappear.
        let room = max(200, 2 * min(center - screen.minX, screen.maxX - center) - 2 * (satelliteWidth + gap + 12))
        // Expand vertically only: the compact footprint and companion anchors
        // must not move when any detail page opens. Plain displays need a usable
        // content width too, without inventing a physical camera.
        let width = min(notched ? cameraWidth + 224 : 352, room)
        let height = expanded ? min(contentHeight + cameraHeight + 18, screen.height - 24) : compactHeight
        let primary = CGRect(x:center - width / 2,y:top - height,width:width,height:height)
        let secondary = CGRect(x:primary.minX - gap - satelliteWidth,y:top - compactHeight,width:satelliteWidth,height:compactHeight)
        let tertiary = CGRect(x:primary.maxX + gap,y:top - compactHeight,width:satelliteWidth,height:compactHeight)
        return .init(centerX:center,cameraWidth:cameraWidth,cameraHeight:cameraHeight,
                     primary:primary,secondary:secondary,tertiary:tertiary)
    }
    /// A short emergence from the main island, with a stable top edge.
    public static func tuckedSatellite(_ frame: CGRect, toward centerX: CGFloat) -> CGRect {
        let width = frame.width * 0.78, height = frame.height * 0.90
        let shift = min(24, frame.width * 0.3) * (frame.midX < centerX ? 1.0 : -1.0)
        return CGRect(x: frame.midX + shift - width / 2, y: frame.maxY - height,
                      width: width, height: height)
    }
}
