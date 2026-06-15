use std::sync::{Arc, Mutex};

use crate::hands::{HandData, HandsState};
use crate::music::midi_note_name;
use crate::pinch::{PinchDetector, PinchPhase};

#[derive(Clone, Debug, uniffi::Enum)]
pub enum NoteAction {
    NoteOn { hand: String, midi: i32, note_name: String, velocity: f64 },
    NoteOff { hand: String },
    Slide { hand: String, midi: i32, note_name: String },
}

#[derive(Debug)]
struct GridState {
    left_pinch: PinchDetector,
    right_pinch: PinchDetector,
    left_held_midi: Option<i32>,
    right_held_midi: Option<i32>,
    video_aspect: f64,
    screen_aspect: f64,
}

impl Default for GridState {
    fn default() -> Self {
        Self {
            left_pinch: PinchDetector::default(),
            right_pinch: PinchDetector::default(),
            left_held_midi: None,
            right_held_midi: None,
            video_aspect: 0.75,
            screen_aspect: 0.46,
        }
    }
}

/// Grid mode: Y-position picks a lane in `scale_notes`; pinch crossings emit
/// note-on/off/slide events. Mirrors Swift `GridModeManager`.
#[derive(uniffi::Object)]
pub struct GridModeManager {
    inner: Mutex<GridState>,
}

#[uniffi::export]
impl GridModeManager {
    #[uniffi::constructor]
    pub fn new() -> Arc<Self> {
        Arc::new(Self { inner: Mutex::new(GridState::default()) })
    }

    pub fn set_aspects(&self, video_aspect: f64, screen_aspect: f64) {
        let mut s = self.inner.lock().unwrap();
        s.video_aspect = video_aspect;
        s.screen_aspect = screen_aspect;
    }

    /// Drive one frame. When `quantize` is true, audible onsets and slides are
    /// gated behind `grid_boundary_crossed`; releases always fire immediately.
    pub fn check_notes(
        &self,
        hands: HandsState,
        scale_notes: Vec<i32>,
        quantize: bool,
        grid_boundary_crossed: bool,
    ) -> Vec<NoteAction> {
        if scale_notes.is_empty() {
            return Vec::new();
        }
        let mut actions = Vec::new();
        let mut s = self.inner.lock().unwrap();
        let GridState {
            left_pinch,
            right_pinch,
            left_held_midi,
            right_held_midi,
            ..
        } = &mut *s;

        process_hand(
            hands.left.as_ref(),
            "left",
            &scale_notes,
            quantize,
            grid_boundary_crossed,
            left_pinch,
            left_held_midi,
            &mut actions,
        );
        process_hand(
            hands.right.as_ref(),
            "right",
            &scale_notes,
            quantize,
            grid_boundary_crossed,
            right_pinch,
            right_held_midi,
            &mut actions,
        );
        actions
    }

    /// Current lane index per hand (for UI highlights). `None` when that hand
    /// is out of frame.
    pub fn current_lanes(
        &self,
        hands: HandsState,
        scale_notes: Vec<i32>,
    ) -> CurrentLanes {
        if scale_notes.is_empty() {
            return CurrentLanes { left: None, right: None };
        }
        CurrentLanes {
            left: hands.left.as_ref().map(|h| y_to_note_index(h.pinch_y, scale_notes.len() as i32)),
            right: hands.right.as_ref().map(|h| y_to_note_index(h.pinch_y, scale_notes.len() as i32)),
        }
    }

    pub fn is_left_pinching(&self) -> bool {
        self.inner.lock().unwrap().left_pinch.is_pinching
    }

    pub fn is_right_pinching(&self) -> bool {
        self.inner.lock().unwrap().right_pinch.is_pinching
    }
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct CurrentLanes {
    pub left: Option<i32>,
    pub right: Option<i32>,
}

#[uniffi::export]
pub fn y_to_note_index(y: f64, note_count: i32) -> i32 {
    if note_count <= 0 { return 0; }
    let top_pad = 0.15;
    let bottom_pad = 0.20;
    let usable = 1.0 - top_pad - bottom_pad;
    let clamped = ((y - top_pad) / usable).clamp(0.0, 1.0);
    let normalized = 1.0 - clamped;
    let idx = (normalized * note_count as f64) as i32;
    idx.clamp(0, note_count - 1)
}

#[allow(clippy::too_many_arguments)]
fn process_hand(
    hand: Option<&HandData>,
    hand_name: &str,
    scale_notes: &[i32],
    quantize: bool,
    boundary: bool,
    pinch: &mut PinchDetector,
    audible_midi: &mut Option<i32>,
    actions: &mut Vec<NoteAction>,
) {
    let Some(h) = hand else {
        // Hand left the frame — release immediately, even in quantize mode.
        if pinch.release() == PinchPhase::Ended && audible_midi.is_some() {
            actions.push(NoteAction::NoteOff { hand: hand_name.to_string() });
            *audible_midi = None;
        }
        return;
    };

    let phase = pinch.update(h.pinch);
    let note_idx = y_to_note_index(h.pinch_y, scale_notes.len() as i32) as usize;
    let midi = scale_notes[note_idx];
    let allow_change = !quantize || boundary;

    match phase {
        PinchPhase::Began => {
            if allow_change {
                *audible_midi = Some(midi);
                actions.push(NoteAction::NoteOn {
                    hand: hand_name.to_string(),
                    midi,
                    note_name: midi_note_name(midi),
                    velocity: h.pinch.min(1.0),
                });
            }
        }
        PinchPhase::Held => {
            if !allow_change { return; }
            match *audible_midi {
                None => {
                    *audible_midi = Some(midi);
                    actions.push(NoteAction::NoteOn {
                        hand: hand_name.to_string(),
                        midi,
                        note_name: midi_note_name(midi),
                        velocity: h.pinch.min(1.0),
                    });
                }
                Some(prev) if prev != midi => {
                    *audible_midi = Some(midi);
                    actions.push(NoteAction::Slide {
                        hand: hand_name.to_string(),
                        midi,
                        note_name: midi_note_name(midi),
                    });
                }
                _ => {}
            }
        }
        PinchPhase::Ended => {
            if audible_midi.is_some() {
                *audible_midi = None;
                actions.push(NoteAction::NoteOff { hand: hand_name.to_string() });
            }
        }
        PinchPhase::Idle => {}
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn h(x: f64, y: f64, pinch: f64) -> HandData {
        HandData { pinch_x: x, pinch_y: y, pinch }
    }

    fn cmaj() -> Vec<i32> {
        crate::music::scale_notes(crate::music::MusicKey::C, crate::music::Scale::Major)
    }

    #[test]
    fn pinch_at_middle_y_emits_noteon() {
        let m = GridModeManager::new();
        let hands = HandsState { left: None, right: Some(h(0.5, 0.5, 0.0)) };
        // First tick — pinch is not engaged, no action.
        assert!(m.check_notes(hands.clone(), cmaj(), false, false).is_empty());

        // Engage pinch.
        let hands = HandsState { left: None, right: Some(h(0.5, 0.5, 0.95)) };
        let acts = m.check_notes(hands, cmaj(), false, false);
        assert_eq!(acts.len(), 1);
        assert!(matches!(acts[0], NoteAction::NoteOn { ref hand, .. } if hand == "right"));
    }

    #[test]
    fn release_when_hand_leaves_frame() {
        let m = GridModeManager::new();
        m.check_notes(
            HandsState { left: None, right: Some(h(0.5, 0.5, 0.95)) },
            cmaj(),
            false,
            false,
        );
        // Hand leaves
        let acts = m.check_notes(
            HandsState { left: None, right: None },
            cmaj(),
            false,
            false,
        );
        assert_eq!(acts.len(), 1);
        assert!(matches!(acts[0], NoteAction::NoteOff { ref hand } if hand == "right"));
    }

    #[test]
    fn quantize_defers_onset_until_boundary() {
        let m = GridModeManager::new();
        // Pinch engages but no boundary — no audible note yet.
        let acts = m.check_notes(
            HandsState { left: None, right: Some(h(0.5, 0.5, 0.95)) },
            cmaj(),
            true,
            false,
        );
        assert!(acts.is_empty());
        // Next tick, boundary crossed — note fires.
        let acts = m.check_notes(
            HandsState { left: None, right: Some(h(0.5, 0.5, 0.95)) },
            cmaj(),
            true,
            true,
        );
        assert_eq!(acts.len(), 1);
        assert!(matches!(acts[0], NoteAction::NoteOn { .. }));
    }
}
