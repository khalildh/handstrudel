import Foundation

/// Hysteresis-based pinch detector for a single hand.
///
/// Every mode that reacts to pinches (grid, drum, chord+melody) needs the same
/// state machine: a rising edge once the pinch amount crosses `onThreshold`, a
/// "held" signal while it stays pinched, and a falling edge once it drops back
/// below `offThreshold`. The gap between the two thresholds is what stops a
/// hand hovering near the boundary from rapidly re-triggering.
///
/// This used to be hand-copied into `DrumModeManager`, `GridModeManager` and
/// `ChordMelodyModeManager`, where the thresholds had already silently drifted
/// (0.7/0.4 vs 0.8/0.5). Centralising the logic here keeps the three modes in
/// lockstep; the thresholds themselves stay configurable per mode because the
/// percussive feel of drums intentionally wants a lighter touch than melodic
/// pinch-to-play.
struct PinchDetector {
    /// The transition reported by `update(pinch:)` / `release()` for one frame.
    enum Phase {
        /// Pinch just crossed `onThreshold` this frame (rising edge).
        case began
        /// Pinch is sustained above `onThreshold`.
        case held
        /// Pinch just dropped below `offThreshold` this frame (falling edge).
        case ended
        /// No state change this frame (released, or inside the dead band).
        case idle
    }

    let onThreshold: Double
    let offThreshold: Double
    private(set) var isPinching = false

    init(on onThreshold: Double = 0.8, off offThreshold: Double = 0.5) {
        self.onThreshold = onThreshold
        self.offThreshold = offThreshold
    }

    /// Feed the current pinch amount for a hand that is present in frame.
    ///
    /// Mirrors the original per-manager logic exactly: above `onThreshold`
    /// begins/holds, below `offThreshold` ends, and the band in between leaves
    /// the latched state untouched (so a wobbling hand neither re-triggers nor
    /// drops the held note).
    mutating func update(pinch: Double) -> Phase {
        if pinch > onThreshold {
            if !isPinching {
                isPinching = true
                return .began
            }
            return .held
        }
        if pinch < offThreshold {
            if isPinching {
                isPinching = false
                return .ended
            }
            return .idle
        }
        return .idle
    }

    /// The hand left the frame. Reports `.ended` if it was mid-pinch so callers
    /// can fire their note-off, otherwise `.idle`.
    @discardableResult
    mutating func release() -> Phase {
        if isPinching {
            isPinching = false
            return .ended
        }
        return .idle
    }

    mutating func reset() {
        isPinching = false
    }
}
