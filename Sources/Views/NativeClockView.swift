import SwiftUI
import IslandCore

struct NativeClockView: View {
    @ObservedObject var manager: NativeClockManager
    @State private var cancelling: ObservedClockTimer?
    var body: some View {
        VStack(spacing: 12) {
            Label("Apple Clock", systemImage: "timer").font(.headline)
            Text("Experimental · native Clock timers").font(.caption).foregroundColor(.secondary)
            Text(manager.status).font(.caption).multilineTextAlignment(.center)
            if !manager.timers.isEmpty {
                ScrollView {
                    ForEach(Array(manager.timers.enumerated()), id: \.element.id) { index, timer in
                        HStack {
                            Text("Clock timer \(index + 1)")
                            Spacer()
                            Text(clockDuration(timer.remaining)).monospacedDigit()
                            if timer.canControl {
                                Button(timer.paused ? "Resume" : "Pause") { manager.control(timer.paused ? .resume : .pause, timer: timer) }
                                    .disabled(manager.controlBusy)
                                Button("Cancel") { cancelling = timer }.disabled(manager.controlBusy)
                            } else { Text(timer.paused ? "Paused" : "Running").foregroundColor(.secondary) }
                        }.padding(.horizontal, 12).padding(.vertical, 4)
                    }
                }
            }
            if let message = manager.controlMessage { Text(message).font(.caption).foregroundColor(.orange) }
            if let observedAt = manager.observedAt {
                Text("Last observed: \(observedAt, style: .time)").font(.caption2).foregroundColor(.secondary)
            }
            Text("Timers stay in Apple Clock. Pause, resume and cancel appear only when native controls can be identified. Open Clock or enable observation from the menu-bar menu → Clock Settings.")
                .font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
        }.padding(14)
        .alert(item: $cancelling) { timer in
            Alert(title: Text("Cancel this timer in Apple Clock?"),
                  primaryButton: .destructive(Text("Cancel Timer")) { manager.control(.cancel, timer: timer) },
                  secondaryButton: .cancel(Text("Keep Timer")))
        }
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
