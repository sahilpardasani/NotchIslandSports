import SwiftUI

struct NativeClockView: View {
    @ObservedObject var manager: NativeClockManager
    var body: some View {
        VStack(spacing: 12) {
            Label("Apple Clock", systemImage: "timer").font(.headline)
            Text("Experimental · read-only native timers").font(.caption).foregroundColor(.secondary)
            Text(manager.status).font(.caption).multilineTextAlignment(.center)
            if !manager.timers.isEmpty {
                ScrollView {
                    ForEach(Array(manager.timers.enumerated()), id: \.element.id) { index, timer in
                        HStack {
                            Text("Clock timer \(index + 1)")
                            Spacer()
                            Text(clockDuration(timer.remaining)).monospacedDigit()
                            Text(timer.paused ? "Paused" : "Running").foregroundColor(.secondary)
                        }.padding(.horizontal, 12).padding(.vertical, 4)
                    }
                }
            }
            if let observedAt = manager.observedAt {
                Text("Last observed: \(observedAt, style: .time)").font(.caption2).foregroundColor(.secondary)
            }
            HStack {
                Button("Open Clock") { manager.openClock() }
                if !manager.enabled {
                    Button("Enable Clock Observation…") { manager.requestPermission() }
                } else {
                    Button("Refresh Clock") { manager.refresh() }
                    Button("Disable") { manager.enabled = false }
                }
            }
            Text("Timers stay in Apple Clock. If its window cannot be read, the island stops showing a countdown. Manage timers in Clock.")
                .font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
        }.padding(14)
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
