import SwiftUI
import ApplicationServices
import IslandCore

/// Shown once; always reachable again through About → Configure.
struct IslandSetupView: View {
    @ObservedObject var clock: NativeClockManager
    @ObservedObject var calendar: CalendarManager
    @ObservedObject var media: NowPlayingManager
    @ObservedObject var presentation: IslandPresentation
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
          ScrollView {
           VStack(alignment: .leading, spacing: 16) {
            Text("Make the island yours").font(.title2.bold())
            Text("Pull down to open. Swipe up to close. Swipe sideways to change activities. Moving the pointer does nothing.")
                .foregroundColor(.secondary)
            Divider()
            Toggle("Music & video", isOn: $media.enabled)
            Text("Shows the system’s current player, including supported browser videos. Uses an experimental macOS media integration.")
                .font(.caption).foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                if !clock.setupChoiceMade {
                    Text("Apple Clock timers")
                    HStack {
                        Button("Connect Apple Clock…") { clock.requestPermission() }
                        Button("Skip Clock") { clock.enabled = false }
                    }
                } else {
                    Toggle("Apple Clock timers", isOn: Binding(get: { clock.enabled }, set: { enabled in
                        if enabled { clock.requestPermission() } else { clock.enabled = false }
                    }))
                }
                Text(clock.setupState.label).font(.caption).foregroundColor(clock.configurationReady ? .secondary : .orange)
                if let failure = clock.setupFailure { Text(failure).font(.caption).foregroundColor(.secondary) }
                Text("Keep Clock open on Timers. Native timer controls depend on Clock’s accessible interface; no timers are created here.")
                    .font(.caption).foregroundColor(.secondary)
                if clock.enabled {
                    HStack {
                        if !clock.hasAccessibilityAccess { Button("Allow Accessibility…") { clock.requestPermission() } }
                        else if !clock.configurationReady && !clock.setupInProgress { Button("Retry connection") { clock.requestPermission() } }
                        Button("Open Clock") { clock.openClock() }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Apple Calendar agenda", isOn: Binding(get: { calendar.enabled }, set: { enabled in
                    if enabled { calendar.connect() } else { calendar.enabled = false }
                }))
                Text(calendar.enabled ? calendar.status : "Read-only agenda, available by swiping. Never uses a live activity slot.")
                    .font(.caption).foregroundColor(.secondary)
                if calendar.enabled && !calendar.hasAccess { Button("Allow Calendar…") { calendar.connect() } }
            }
            Toggle("Separate live activities (up to three)", isOn: Binding(get: { !presentation.merged },
                set: { presentation.setMerged(!$0) }))
            Text("Hold and swipe sideways to merge or separate them.").font(.caption).foregroundColor(.secondary)
           }.frame(maxWidth: .infinity, alignment: .leading)
          }
            HStack {
                Text("Change these later in About → Configure.").font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("Done", action: done).keyboardShortcut(.defaultAction).disabled(!clock.configurationReady)
            }
        }.padding(26).frame(width: 490, height: 600)
    }
}
