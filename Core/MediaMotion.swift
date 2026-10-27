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
        guard moving, elapsed.isFinite else { return [8.0, 17, 11, 15, 7][abs(index % 5)] }
        let phase = elapsed * (3.4 + Double(index) * 0.37) + Double(index) * 1.8
        return 5 + 13 * (0.5 + 0.5 * sin(phase))
    }
}
