import SwiftUI
import IslandCore

/// Content only: permission/setup and observation diagnostics belong in About → Configure.
struct NativeClockView: View {
    @ObservedObject var manager: NativeClockManager
    @State private var cancelling: ObservedClockTimer?

    static func contentHeight(timerCount: Int) -> CGFloat {
        CGFloat(max(1, min(timerCount, 2))) * 88 + 32
    }

    var body: some View {
        VStack(spacing: 0) {
            if manager.timers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "timer").font(.system(size: 24, weight: .medium)).foregroundColor(.orange)
                    Text(manager.hasAccessibilityAccess && manager.enabled ? "Waiting for Apple Clock" : "Clock isn’t connected").font(.system(size: 15, weight: .medium))
                    Text(manager.hasAccessibilityAccess && manager.enabled ? "Open Clock’s Timers view to reconnect." : "Check Clock access in About → Configure.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: manager.timers.count > 2) {
                    VStack(spacing: 0) {
                        ForEach(Array(manager.timers.enumerated()), id: \.element.id) { index, timer in
                            NativeTimerRow(timer: timer, title: manager.timers.count == 1 ? "Timer" : "Timer \(index + 1)",
                                           busy: manager.controlBusy,
                                           onToggle: { manager.control(timer.paused ? .resume : .pause, timer: timer) },
                                           onCancel: { cancelling = timer })
                                .frame(height: 88)
                        }
                    }
                }
                .frame(height: CGFloat(min(manager.timers.count, 2)) * 88)
                if manager.controlMessage != nil {
                    Text("Couldn’t update timer · Details in About → Configure")
                        .font(.system(size: 10)).foregroundColor(.orange)
                } else if manager.timers.contains(where: { !$0.canControl }) {
                    Text("Native controls unavailable")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 8)
        .onAppear { manager.refresh() }
        .alert(item: $cancelling) { timer in
            Alert(title: Text("Cancel this timer in Apple Clock?"),
                  primaryButton: .destructive(Text("Cancel Timer")) { manager.control(.cancel, timer: timer) },
                  secondaryButton: .cancel(Text("Keep Timer")))
        }
    }
}

/// Real buttons dispatch native commands; the value is Clock's last observed remaining duration.
struct NativeTimerRow: View {
    let timer: ObservedClockTimer
    let title: String
    let busy: Bool
    let onToggle: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            HStack(spacing: 10) {
                Button(action: onToggle) {
                    Image(systemName: timer.paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 46, height: 46).contentShape(Circle())
                }
                .buttonStyle(TimerCircleButtonStyle(tint: .orange, background: Color.orange.opacity(0.18)))
                .accessibilityLabel(timer.paused ? "Resume \(title)" : "Pause \(title)")
                Button(action: onCancel) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 46, height: 46).contentShape(Circle())
                }
                .buttonStyle(TimerCircleButtonStyle(tint: .white, background: Color.white.opacity(0.14)))
                .accessibilityLabel("Cancel \(title)")
            }.disabled(busy || !timer.canControl)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                Text(timer.paused ? "Paused" : title)
                    .font(.system(size: 12, weight: .medium)).foregroundColor(.orange.opacity(0.85))
                Text(clockDuration(timer.remaining))
                    .font(.system(size: 46, weight: .light, design: .rounded)).monospacedDigit()
                    .foregroundColor(.orange).lineLimit(1).minimumScaleFactor(0.65)
                    .accessibilityLabel("Time remaining")
                    .accessibilityValue(clockDuration(timer.remaining))
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct TimerCircleButtonStyle: ButtonStyle {
    let tint: Color
    let background: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(tint)
            .background(Circle().fill(background))
            .overlay(Circle().fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0)))
            .opacity(isEnabled ? 1 : 0.35)
    }
}

struct NativeClockCompactView: View {
    @ObservedObject var manager: NativeClockManager
    var minimal: Bool
    var body: some View {
        VStack(spacing: 1) {
            if let timer = manager.timers.first {
                if !minimal { Text("Apple Clock").font(.caption2).foregroundColor(.secondary) }
                HStack(spacing: 4) {
                    Image(systemName: timer.paused ? "pause.fill" : "timer")
                    Text(clockDuration(timer.remaining)).monospacedDigit()
                }.font(.system(size: minimal ? 10 : 13, weight: .semibold))
            } else { Image(systemName: "timer").accessibilityLabel("Clock observation unavailable") }
        }.foregroundColor(.orange)
    }
}

func clockDuration(_ seconds: TimeInterval) -> String {
    let value = Int(max(0, seconds))
    if value >= 3600 { return String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60) }
    return String(format: "%d:%02d", value / 60, value % 60)
}
