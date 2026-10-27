import SwiftUI

/// Media keeps a broad metadata area and a curved lower edge around its controls/handle.
struct IslandSurfaceShape: Shape {
    var media: Bool
    var expanded: Bool
    func path(in rect: CGRect) -> Path {
        guard media, rect.height > 120 else {
            return RoundedRectangle(cornerRadius: expanded ? 20 : 18, style: .continuous).path(in: rect)
        }
        let w = rect.width, h = rect.height
        let shoulder = h - 88
        // Trim the empty outer corners below the time labels. Keep the curve
        // outside the previous/next buttons' full 36pt hit areas.
        let controlInset = min(66, w * 0.11)
        var path = Path()
        path.move(to: CGPoint(x: 20, y: 0))
        path.addLine(to: CGPoint(x: w - 20, y: 0))
        path.addQuadCurve(to: CGPoint(x: w, y: 20), control: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: shoulder))
        path.addCurve(to: CGPoint(x: w - controlInset, y: h - 30), control1: CGPoint(x: w, y: h - 52), control2: CGPoint(x: w - controlInset + 12, y: h - 30))
        path.addLine(to: CGPoint(x: w * 0.67, y: h - 30))
        path.addCurve(to: CGPoint(x: w * 0.57, y: h), control1: CGPoint(x: w * 0.62, y: h - 30), control2: CGPoint(x: w * 0.63, y: h))
        path.addLine(to: CGPoint(x: w * 0.43, y: h))
        path.addCurve(to: CGPoint(x: w * 0.33, y: h - 30), control1: CGPoint(x: w * 0.37, y: h), control2: CGPoint(x: w * 0.38, y: h - 30))
        path.addLine(to: CGPoint(x: controlInset, y: h - 30))
        path.addCurve(to: CGPoint(x: 0, y: shoulder), control1: CGPoint(x: controlInset - 12, y: h - 30), control2: CGPoint(x: 0, y: h - 52))
        path.addLine(to: CGPoint(x: 0, y: 20))
        path.addQuadCurve(to: CGPoint(x: 20, y: 0), control: .zero)
        path.closeSubpath()
        return path
    }
}
