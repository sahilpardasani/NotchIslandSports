import SwiftUI
import AppKit
import IslandCore

/// Only the clipped text region redraws. Fitting and inactive titles have no animation schedule.
struct ScrollingMediaTitle: View {
    let title: String
    let moving: Bool
    var size: CGFloat = 11
    var weight: NSFont.Weight = .semibold
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()

    private var font: NSFont { .systemFont(ofSize: size, weight: weight) }
    private var textWidth: CGFloat { ceil((title as NSString).size(withAttributes: [.font: font]).width) }

    var body: some View {
        GeometryReader { geometry in
            let overflow = max(0, textWidth - geometry.size.width)
            let animate = moving && !reduceMotion && overflow > 1
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animate)) { context in
                Text(title)
                    .font(Font(font))
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: animate ? MediaMotion.titleOffset(elapsed: context.date.timeIntervalSince(started), overflow: overflow) : 0)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
                    .clipped()
            }
            .onChange(of: geometry.size.width) { _ in started = Date() }
        }
        .frame(height: ceil(font.ascender - font.descender + 2))
        .onChange(of: title) { _ in started = Date() }
        .onChange(of: moving) { _ in started = Date() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}
