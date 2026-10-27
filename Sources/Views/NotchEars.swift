import SwiftUI
import IslandCore

private struct CompactNotchInsetsKey: EnvironmentKey {
    static let defaultValue: CompactNotchInsets? = nil
}
extension EnvironmentValues {
    var compactNotchInsets: CompactNotchInsets? {
        get { self[CompactNotchInsetsKey.self] }
        set { self[CompactNotchInsetsKey.self] = newValue }
    }
}

/// Equal-width content on both sides of the physical camera, for every primary activity.
struct NotchEars<Left: View, Right: View>: View {
    @Environment(\.compactNotchInsets) private var insets
    let gap: CGFloat
    @ViewBuilder var left: () -> Left
    @ViewBuilder var right: () -> Right
    var body: some View {
        GeometryReader { proxy in
            if let insets {
                adaptive(insets, height: proxy.size.height)
            } else {
            let ear = max(0, (proxy.size.width - 24 - gap) / 2)
            HStack(spacing: 0) {
                left().frame(width: ear, alignment: .leading)
                    .lineLimit(1).minimumScaleFactor(0.75).clipped()
                Color.clear.frame(width: gap)
                right().frame(width: ear, alignment: .trailing)
                    .lineLimit(1).minimumScaleFactor(0.75).clipped()
            }.padding(.horizontal, 12).frame(height: proxy.size.height)
            }
        }
    }

    private func adaptive(_ insets: CompactNotchInsets, height: CGFloat) -> some View {
        let leftWidth = max(0, insets.left - 18)
        let rightWidth = max(0, insets.right - 18)
        return ZStack(alignment: .leading) {
            if insets.left == 0 {
                joined(width: rightWidth).frame(width: rightWidth, height: height)
                    .offset(x: insets.camera + 6)
            } else if insets.right == 0 {
                joined(width: leftWidth).frame(width: leftWidth, height: height).offset(x: 12)
            } else {
                left().frame(width: leftWidth, height: height, alignment: .leading)
                    .lineLimit(1).minimumScaleFactor(0.75).clipped().offset(x: 12)
                right().frame(width: rightWidth, height: height, alignment: .trailing)
                    .lineLimit(1).minimumScaleFactor(0.75).clipped().offset(x: insets.left + insets.camera + 6)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
    @ViewBuilder private func joined(width: CGFloat) -> some View {
        if width >= 150 {
            HStack(spacing: 8) { left(); Spacer(minLength: 0); right() }
                .lineLimit(1).minimumScaleFactor(0.75).clipped()
        } else {
            left().frame(maxWidth: .infinity, alignment: .leading).lineLimit(1).clipped()
        }
    }
}
