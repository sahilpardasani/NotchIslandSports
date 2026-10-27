import Foundation
import CoreGraphics

/// Geometry only: no menu labels, application content or screen pixels are needed.
public struct MenuBarPlacement {
    public let primary: CGRect
    public let secondary: CGRect?
    public let tertiary: CGRect?

    public static func appKitRect(_ rect: CGRect, mainDisplayTop: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: mainDisplayTop - rect.maxY, width: rect.width, height: rect.height)
    }

    public static func layout(base: NotchGeometry, screen: CGRect, occupied: [CGRect],
                              expanded: Bool, satelliteCount: Int) -> Self {
        let band = CGRect(x: screen.minX, y: base.primary.maxY - base.secondary.height,
                          width: screen.width, height: base.secondary.height)
        let blocks = occupied.filter { !$0.isNull && $0.width > 0 && $0.intersects(band) }
            .map { $0.insetBy(dx: -6, dy: 0) }
        // The primary always straddles the physical camera. Menu measurements (including
        // the conservative permission-free fallback) must never join both scores on one
        // side or shrink the primary to an empty camera-sized capsule.
        let primary = base.primary
        // Allocate nearest free intervals; both satellites may occupy the same side.
        var intervals = [(screen.minX + 8, screen.maxX - 8)]
        for block in blocks + [primary.insetBy(dx: -8, dy: 0)] {
            intervals = intervals.flatMap { lo, hi -> [(CGFloat, CGFloat)] in
                guard block.maxX > lo && block.minX < hi else { return [(lo, hi)] }
                var parts: [(CGFloat, CGFloat)] = []
                if block.minX > lo { parts.append((lo, min(hi, block.minX))) }
                if block.maxX < hi { parts.append((max(lo, block.maxX), hi)) }
                return parts
            }
        }
        func take(preferLeft: Bool) -> CGRect? {
            let width = base.secondary.width
            let candidates = intervals.enumerated().compactMap { index, interval -> (Int, CGFloat, CGFloat)? in
                let (lo, hi) = interval
                guard hi - lo >= width else { return nil }
                let left = hi <= primary.minX
                let x = left ? hi - width : lo
                let distance = left ? primary.minX - hi : lo - primary.maxX
                return (index, x, distance + (left == preferLeft ? 0 : screen.width))
            }
            guard let best = candidates.min(by: { $0.2 < $1.2 }) else { return nil }
            let old = intervals.remove(at: best.0)
            if best.1 - 8 > old.0 { intervals.append((old.0, best.1 - 8)) }
            if best.1 + width + 8 < old.1 { intervals.append((best.1 + width + 8, old.1)) }
            return CGRect(x: best.1, y: band.minY, width: width, height: band.height)
        }
        let secondary = satelliteCount > 0 ? take(preferLeft: true) : nil
        let tertiary = satelliteCount > 1 ? take(preferLeft: false) : nil
        return .init(primary: primary, secondary: secondary, tertiary: tertiary)
    }
}
