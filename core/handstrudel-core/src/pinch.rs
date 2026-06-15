/// Edge reported by [`PinchDetector::update`] / [`PinchDetector::release`].
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PinchPhase {
    /// Pinch crossed `on_threshold` this frame (rising edge).
    Began,
    /// Pinch is sustained above `on_threshold`.
    Held,
    /// Pinch dropped below `off_threshold` this frame (falling edge).
    Ended,
    /// No state change.
    Idle,
}

/// Hysteresis-based pinch detector for a single hand. Mirrors the Swift
/// [`PinchDetector`]: thresholds default to 0.8 (on) / 0.5 (off); the dead band
/// between them prevents jitter near the boundary from re-triggering.
///
/// Internal type — the mode managers compose it. Not exposed to FFI.
#[derive(Debug)]
pub(crate) struct PinchDetector {
    on_threshold: f64,
    off_threshold: f64,
    pub(crate) is_pinching: bool,
}

impl PinchDetector {
    pub fn new(on_threshold: f64, off_threshold: f64) -> Self {
        Self { on_threshold, off_threshold, is_pinching: false }
    }

    pub fn update(&mut self, pinch: f64) -> PinchPhase {
        if pinch > self.on_threshold {
            if !self.is_pinching {
                self.is_pinching = true;
                return PinchPhase::Began;
            }
            return PinchPhase::Held;
        }
        if pinch < self.off_threshold {
            if self.is_pinching {
                self.is_pinching = false;
                return PinchPhase::Ended;
            }
            return PinchPhase::Idle;
        }
        PinchPhase::Idle
    }

    pub fn release(&mut self) -> PinchPhase {
        if self.is_pinching {
            self.is_pinching = false;
            return PinchPhase::Ended;
        }
        PinchPhase::Idle
    }

    pub fn reset(&mut self) {
        self.is_pinching = false;
    }
}

impl Default for PinchDetector {
    fn default() -> Self {
        Self::new(0.8, 0.5)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hysteresis_prevents_chatter() {
        let mut p = PinchDetector::default();
        assert_eq!(p.update(0.0), PinchPhase::Idle);
        assert_eq!(p.update(0.9), PinchPhase::Began);
        assert_eq!(p.update(0.9), PinchPhase::Held);
        // Inside the dead band — latched state stays true but phase is Idle
        // (matches Swift: no edge this frame, but is_pinching == true).
        assert_eq!(p.update(0.7), PinchPhase::Idle);
        assert!(p.is_pinching);
        assert_eq!(p.update(0.6), PinchPhase::Idle);
        assert!(p.is_pinching);
        // Drops below off_threshold
        assert_eq!(p.update(0.4), PinchPhase::Ended);
        assert!(!p.is_pinching);
        assert_eq!(p.update(0.4), PinchPhase::Idle);
    }

    #[test]
    fn release_while_pinched_emits_ended() {
        let mut p = PinchDetector::default();
        p.update(0.9);
        assert_eq!(p.release(), PinchPhase::Ended);
        assert_eq!(p.release(), PinchPhase::Idle);
    }
}
