import Foundation

public enum IslandDragIntent: Equatable {
    case next, previous, toggleMerge, open, close
    public static func isInward(horizontal: Double, vertical: Double, satelliteOnLeft: Bool) -> Bool {
        horizontal * (satelliteOnLeft ? 1 : -1) >= 22 && abs(horizontal) > abs(vertical) * 1.2
    }
    public static func resolve(horizontal: Double, vertical: Double, heldFor: Double) -> Self? {
        if abs(horizontal) >= 22, abs(horizontal) > abs(vertical) * 1.2 {
            return heldFor >= 0.28 ? .toggleMerge : (horizontal < 0 ? .next : .previous)
        }
        if abs(vertical) >= 18, abs(vertical) > abs(horizontal) * 1.2 {
            return vertical > 0 ? .open : .close
        }
        return nil
    }
}
