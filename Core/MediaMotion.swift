import Foundation

/// Decorative playback motion, independent of audio capture or provider polling.
public enum MediaMotion {
    public static func allowed(playing: Bool, active: Bool, visible: Bool, reduceMotion: Bool, lowPower: Bool) -> Bool {
        playing && active && visible && !reduceMotion && !lowPower
    }

    /// Travel to the end and back with a reading pause at both ends; never jumps on a loop.
    public static func titleOffset(elapsed: Double, overflow: Double) -> Double {
        guard overflow.isFinite, overflow > 1, elapsed.isFinite else { return 0 }
        let hold = 1.6
        let travel = max(2, overflow / 22)
        let half = hold + travel
        let phase = max(0, elapsed).truncatingRemainder(dividingBy: half * 2)
        let returning = phase >= half
        let local = returning ? phase - half : phase
        let t = min(1, max(0, (local - hold) / travel))
        // Cosine easing removes velocity changes at both reading pauses.
        let progress = (1 - cos(t * .pi)) / 2
        return -overflow * (returning ? 1 - progress : progress)
    }

    public static func barHeight(elapsed: Double, index: Int, moving: Bool, playing: Bool) -> Double {
        guard playing else { return 4 }
        let band = abs(index % 5)
        guard moving, elapsed.isFinite else { return [6.0, 11, 17, 12, 7][band] }
        // A tapered, center-aligned waveform instead of five equal-height pistons.
        // Continuous overlapping waves avoid random jumps and a mechanical loop.
        // This is a playback indicator, not captured audio or Apple's waveform algorithm.
        let phase = Double(band) * 0.9
        let energy = 0.5 + 0.28 * sin(elapsed * 3.2 + phase)
            + 0.15 * sin(elapsed * 5.1 - phase * 1.3)
            + 0.07 * sin(elapsed * 1.7 + phase * 2.1)
        let envelope = [0.45, 0.8, 1.0, 0.85, 0.5][band]
        return 5 + 13 * envelope * min(1, max(0, energy))
    }
}
