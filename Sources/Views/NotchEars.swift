import SwiftUI

/// Equal-width content on both sides of the physical camera, for every primary activity.
struct NotchEars<Left: View, Right: View>: View {
    let gap: CGFloat
    @ViewBuilder var left: () -> Left
    @ViewBuilder var right: () -> Right
    var body: some View {
        GeometryReader { proxy in
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
