import SwiftUI
import Cocoa
import IslandCore

/// Reuses the decoded source artwork. No timeline, repeated decoding or network fetches.
struct MediaArtworkThumbnail: View {
    let image: NSImage?
    var tint: Color = .purple

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint.opacity(0.25))
                    .overlay(Image(systemName: "music.note")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(tint))
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityHidden(true) // The parent button announces the current track.
    }
}

// MARK: - Decorative playback bars (not an audio-level meter)

struct DynamicIslandWaveform: View {
    let isPlaying: Bool
    let color: Color
    var barCount: Int = 3
    var animationAllowed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        let moving = isPlaying && animationAllowed && !reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !moving)) { timeline in
            Canvas { context, size in
                for index in 0..<barCount {
                    let height = MediaMotion.barHeight(elapsed: timeline.date.timeIntervalSinceReferenceDate,
                        index: index, moving: moving, playing: isPlaying)
                    let rect = CGRect(x: Double(index) * 5.5, y: (size.height - height) / 2, width: 3, height: height)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(color))
                }
            }
        }.frame(width: CGFloat(barCount) * 5.5 - 2.5, height: 20).accessibilityHidden(true)
    }
}

// MARK: - Collapsed: Album Art Ear (left side, outer edge aligned)

struct NowPlayingLeftEar: View {
    let track: NowPlayingTrack
    var artworkImage: NSImage? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Circular/Rounded album art, left-aligned to sit on the outer edge (like Sports icon)
            if let img = artworkImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: track.dominantColor.opacity(0.5), radius: 4, x: 0, y: 1)
                    .padding(.leading, 8)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [track.dominantColor.opacity(0.8), track.dominantColor.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 22, height: 22)
                    Image(systemName: "music.note")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.leading, 8)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Collapsed: Waveform Ear (right side, outer edge aligned)

struct NowPlayingRightEar: View {
    let track: NowPlayingTrack

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            // Waveform bars, right-aligned to sit on the outer edge (like FINAL/LIVE label)
            DynamicIslandWaveform(isPlaying: track.isPlaying, color: track.dominantColor)
                .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
    }
}

// MARK: - NowPlayingCollapsedView (Dynamic Island style: ears only, no text)

struct NowPlayingCollapsedView: View {
    @ObservedObject var manager: NowPlayingManager

    var body: some View {
        Group {
            if let track = manager.currentTrack {
                let earWidth: CGFloat = 110.0
                HStack(spacing: 0) {
                    // LEFT EAR: album art (aligned outer edge)
                    NowPlayingLeftEar(track: track, artworkImage: manager.artworkImage)
                        .frame(width: earWidth)

                    // CENTER: the physical notch (camera/sensor area)
                    Spacer()
                        .frame(width: 180)

                    // RIGHT EAR: waveform (aligned outer edge)
                    NowPlayingRightEar(track: track)
                        .frame(width: earWidth)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - NowPlayingExpandedView (full iPhone-style card)

struct NowPlayingExpandedView: View {
    @ObservedObject var manager: NowPlayingManager
    var animationAllowed = false
    var progressVisible = true
    var lowPower = false

    var body: some View {
        Group {
            if let track = manager.currentTrack {
                VStack(spacing: 0) {
                    // ── Top row: album art + metadata ───────────────────
                    HStack(alignment: .center, spacing: 14) {

                        // Album Art with dominant color glow
                        ZStack {
                            if let img = manager.artworkImage {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .shadow(color: track.dominantColor.opacity(0.4), radius: 10, x: 0, y: 4)
                            } else {
                                Circle().fill(track.dominantColor.opacity(0.18))
                                    .frame(width: 60, height: 60)
                                    .overlay(Image(systemName: "music.note")
                                        .font(.system(size: 25, weight: .semibold))
                                        .foregroundColor(track.dominantColor))
                                    .frame(width: 72, height: 72)
                            }
                        }

                        // Track info
                        VStack(alignment: .leading, spacing: 3) {
                            ScrollingMediaTitle(title: track.title, moving: animationAllowed && track.isPlaying, size: 14, weight: .bold)
                                .foregroundColor(.white)

                            Text(track.artist)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)

                            if !track.album.isEmpty {
                                Text(track.album)
                                    .font(.system(size: 10, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.4))
                                    .lineLimit(1)
                            }

                            // Waveform in track info (smaller, decorative)
                            DynamicIslandWaveform(isPlaying: track.isPlaying, color: track.dominantColor, barCount: 5, animationAllowed: animationAllowed)
                                .frame(height: 14)
                                .padding(.top, 2)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 6)

                    // ── Progress bar ─────────────────────────────────────
                    MediaProgressView(manager: manager, track: track,
                        visible: progressVisible, lowPower: lowPower)

                    // ── Playback controls ─────────────────────────────────
                    HStack(spacing: 0) {
                        Spacer()

                        // Previous
                        Button(action: { manager.previousTrack() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(MediaControlButtonStyle())
                        .disabled(!manager.canControl)

                        Spacer()

                        // Go Back 15s
                        Button(action: { manager.skipBackward15() }) {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(MediaControlButtonStyle())
                        .disabled(!manager.canControl)

                        Spacer()

                        // Play / Pause (large pill button)
                        Button(action: { manager.playPause() }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(track.dominantColor)
                                    .frame(width: 56, height: 40)
                                    .shadow(color: track.dominantColor.opacity(0.4), radius: 6, x: 0, y: 2)

                                Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .offset(x: track.isPlaying ? 0 : 1.5)
                            }
                        }
                        .buttonStyle(PlayPauseButtonStyle())
                        .disabled(!manager.canControl)

                        Spacer()

                        // Go Forward 15s
                        Button(action: { manager.skipForward15() }) {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(MediaControlButtonStyle())
                        .disabled(!manager.canControl)

                        Spacer()

                        // Next
                        Button(action: { manager.nextTrack() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(MediaControlButtonStyle())
                        .disabled(!manager.canControl)

                        Spacer()
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                // No active media state
                VStack(spacing: 10) {
                    Image(systemName: "music.note.tv")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.25))
                        .padding(.bottom, 4)

                    Text("Nothing Playing")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))

                    Text("Play music or video in any app")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// A one-second progress tick never rebuilds the artwork, title or controls.
private struct MediaProgressView: View {
    @ObservedObject var manager: NowPlayingManager
    let track: NowPlayingTrack
    let visible: Bool
    let lowPower: Bool
    @State private var scrub: MediaScrubSession?
    @GestureState private var dragging = false

    private var displayedPosition: Double { scrub?.target ?? manager.elapsedTime() }

    var body: some View {
        TimelineView(.animation(minimumInterval: lowPower ? 2 : 1,
            paused: !visible || !manager.isActive || !track.isPlaying || track.duration <= 0 || dragging)) { _ in
            VStack(spacing: 1) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12)).frame(height: 4)
                        Capsule().fill(track.dominantColor)
                            .frame(width: geo.size.width * ratio, height: 4)
                        if scrub?.target != nil {
                            Circle().fill(track.dominantColor).frame(width: 10, height: 10)
                                .offset(x: max(0, min(geo.size.width - 10, geo.size.width * ratio - 5)))
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .updating($dragging) { _, active, _ in active = true }
                        .onChanged { value in
                            guard manager.canSeek else { return }
                            if scrub == nil { scrub = MediaScrubSession(identity: track.playbackIdentity) }
                            scrub?.update(x: value.location.x, width: geo.size.width, current: track.playbackIdentity)
                        }
                        .onEnded { value in
                            guard var session = scrub else { return }
                            session.update(x: value.location.x, width: geo.size.width, current: track.playbackIdentity)
                            scrub = nil
                            if let target = session.destination(current: track.playbackIdentity) {
                                manager.seek(to: target, expected: session.identity)
                            }
                        })
                    .focusable(manager.canSeek)
                    .onMoveCommand { direction in
                        if direction == .left { adjust(-5) }
                        else if direction == .right { adjust(5) }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Playback position")
                    .accessibilityValue("\(formatTime(displayedPosition)) of \(formatTime(track.duration))")
                    .accessibilityHint(manager.canSeek ? "Adjust to seek forward or backward" : "Seeking unavailable for this player")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: adjust(5)
                        case .decrement: adjust(-5)
                        @unknown default: break
                        }
                    }
                }
                .frame(height: 20)
                HStack {
                    Text(formatTime(displayedPosition))
                    Spacer()
                    Text("-" + formatTime(max(0, track.duration - displayedPosition)))
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
        }
        .onChange(of: track.playbackIdentity) { _ in scrub?.cancel() }
        .onChange(of: dragging) { active in if !active { scrub = nil } }
        .onDisappear { scrub = nil }
    }

    private var ratio: Double {
        guard track.duration.isFinite, track.duration > 0 else { return 0 }
        return min(1, max(0, displayedPosition / track.duration))
    }
    private func adjust(_ seconds: Double) {
        manager.seek(to: manager.elapsedTime() + seconds, expected: track.playbackIdentity)
    }
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time > 0, time < Double(Int.max) else { return "0:00" }
        return String(format: "%d:%02d", Int(time) / 60, Int(time) % 60)
    }
}

// MARK: - Button Styles

struct MediaControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PlayPauseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

