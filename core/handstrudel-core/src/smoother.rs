use std::collections::HashMap;
use std::sync::{Arc, Mutex};

/// Per-key exponential-moving-average smoother. Mirrors Swift `ParamSmoother`
/// with `alpha = 0.6` (snappier than the original 0.35 that felt sluggish).
#[derive(uniffi::Object)]
pub struct ParamSmoother {
    alpha: f64,
    state: Mutex<HashMap<String, f64>>,
}

#[uniffi::export]
impl ParamSmoother {
    #[uniffi::constructor]
    pub fn new(alpha: f64) -> Arc<Self> {
        Arc::new(Self {
            alpha,
            state: Mutex::new(HashMap::new()),
        })
    }

    #[uniffi::constructor]
    pub fn default_alpha() -> Arc<Self> {
        Self::new(0.6)
    }

    /// Apply EMA toward the target values, returning the new smoothed state.
    /// Keys not previously seen snap directly to the target (no warm-up).
    pub fn smooth(&self, target: HashMap<String, f64>) -> HashMap<String, f64> {
        let mut state = self.state.lock().unwrap();
        for (k, v) in target {
            match state.get(&k) {
                Some(current) => {
                    let next = current + (v - current) * self.alpha;
                    state.insert(k, next);
                }
                None => {
                    state.insert(k, v);
                }
            }
        }
        state.clone()
    }

    pub fn current(&self) -> HashMap<String, f64> {
        self.state.lock().unwrap().clone()
    }

    pub fn reset(&self) {
        self.state.lock().unwrap().clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn map_of(pairs: &[(&str, f64)]) -> HashMap<String, f64> {
        pairs.iter().map(|(k, v)| (k.to_string(), *v)).collect()
    }

    #[test]
    fn first_value_snaps_then_subsequent_eased() {
        let s = ParamSmoother::new(0.5);
        let out = s.smooth(map_of(&[("lpf", 1000.0)]));
        assert_eq!(out["lpf"], 1000.0);
        let out = s.smooth(map_of(&[("lpf", 2000.0)]));
        assert_eq!(out["lpf"], 1500.0);
    }
}
