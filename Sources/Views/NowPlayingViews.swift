import SwiftUI
import Cocoa

// MARK: - Dynamic Island Waveform (iPhone-faithful: 3 bars)

struct DynamicIslandWaveform: View {
    let isPlaying: Bool
    let color: Color
    let barCount: Int

    @State private var barHeights: [CGFloat] = []
    private let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    init(isPlaying: Bool, color: Color, barCount: Int = 3) {
        self.isPlaying = isPlaying
        self.color = color
        self.barCount = barCount
        _barHeights = State(initialValue: Array(repeating: 4, count: barCount))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: 3, height: barHeights.indices.contains(i) ? barHeights[i] : 4)
                    .animation(.spring(response: 0.2, dampingFraction: 0.65), value: barHeights.indices.contains(i) ? barHeights[i] : 4)
            }
        }
        .frame(height: 20, alignment: .center)
        .onReceive(timer) { _ in
            guard isPlaying else {
                if barHeights.contains(where: { $0 != 4 }) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                        barHeights = Array(repeating: 4, count: barCount)
                    }
                }
                return
            }
            let heights: [CGFloat] = (0..<barCount).map { _ in CGFloat.random(in: 5...18) }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                barHeights = heights
            }
        }
        .onAppear {
            if isPlaying {
                barHeights = (0..<barCount).map { _ in CGFloat.random(in: 5...18) }
            } else {
                barHeights = Array(repeating: 4, count: barCount)
            }
        }
    }
}

// MARK: - Collapsed: Album Art Ear (left side, outer edge aligned)

struct NowPlayingLeftEar: View {
    let track: NowPlayingTrack

    var body: some View {
        HStack(spacing: 0) {
            // Circular/Rounded album art, left-aligned to sit on the outer edge (like Sports icon)
            if let data = track.artwork, let img = NSImage(data: data) {
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
                    NowPlayingLeftEar(track: track)
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
    
    // Sub-second local interpolation for butter-smooth progress updates
    @State private var interpolatedElapsedTime: TimeInterval = 0
    private let progressTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let track = manager.currentTrack {
                VStack(spacing: 0) {
                    // ── Top row: album art + metadata ───────────────────
                    HStack(alignment: .center, spacing: 14) {

                        // Album Art with dominant color glow
                        ZStack {
                            if let data = track.artwork, let img = NSImage(data: data) {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .shadow(color: track.dominantColor.opacity(0.4), radius: 10, x: 0, y: 4)
                            } else {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [track.dominantColor.opacity(0.7), Color.black.opacity(0.5)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 72, height: 72)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(.white.opacity(0.9))
                                    )
                            }
                        }

                        // Track info
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)

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
                            DynamicIslandWaveform(isPlaying: track.isPlaying, color: track.dominantColor, barCount: 5)
                                .frame(height: 14)
                                .padding(.top, 2)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 6)

                    // ── Progress bar ─────────────────────────────────────
                    VStack(spacing: 3) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 4)

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [track.dominantColor, track.dominantColor.opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: geo.size.width * CGFloat(progressRatio(track)),
                                        height: 4
                                    )
                            }
                        }
                        .frame(height: 4)

                        // Time labels
                        HStack {
                            Text(formatTime(interpolatedElapsedTime))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                            Spacer()
                            Text("-" + formatTime(max(0, track.duration - interpolatedElapsedTime)))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

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

                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onReceive(progressTimer) { _ in
                    guard track.isPlaying else { return }
                    interpolatedElapsedTime = min(track.duration, interpolatedElapsedTime + 0.1)
                }
                .onChange(of: track) { newTrack in
                    interpolatedElapsedTime = newTrack.elapsedTime
                }
                .onAppear {
                    interpolatedElapsedTime = track.elapsedTime
                }

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

    // MARK: - Helpers

    private func progressRatio(_ track: NowPlayingTrack) -> Double {
        guard track.duration > 0 else { return 0 }
        return min(1.0, max(0.0, interpolatedElapsedTime / track.duration))
    }

    private func formatTime(_ t: TimeInterval) -> String {
        guard t > 0, !t.isNaN else { return "0:00" }
        let m = Int(t) / 60; let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
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
