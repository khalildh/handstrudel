use std::sync::{Arc, Mutex};

use crate::hands::{HandData, HandsState};
use crate::music::midi_note_name;
use crate::pinch::{PinchDetector, PinchPhase};

/// Actions emitted by [`ChordMelodyModeManager::tick`].
#[derive(Clone, Debug, uniffi::Enum)]
pub enum ChordMelodyAction {
    /// Chord-hand pad turns on (hand entered frame).
    PadOn { midi_notes: Vec<i32>, degree: i32 },
    /// Chord-hand pad slides to a new chord/octave.
    PadSlide { midi_notes: Vec<i32>, degree: i32 },
    /// Chord-hand pad turns off (hand left frame).
    PadOff,
    /// Pinch-triggered strum on top of the pad.
    ChordAccent { midi_notes: Vec<i32>, degree: i32, velocity: f64 },
    /// Melody-hand note onset.
    MelodyOn { hand: String, midi: i32, name: String, velocity: f64 },
    /// Melody-hand note release.
    MelodyOff { hand: String },
    /// Melody-hand note slides while pinch is held.
    MelodySlide { hand: String, midi: i32, name: String },
}

#[derive(Debug)]
struct ChordMelodyState {
    swap_hands: bool,
    zone_degrees: Vec<i32>,
    chord_pinch: PinchDetector,
    melody_pinch: PinchDetector,
    held_melody_midi: Option<i32>,
    pending_chord_accent: bool,
    pending_chord_accent_vel: f64,
    pad_on: bool,
    pad_degree: Option<i32>,
    pad_octave_shift: i32,
    current_chord_degree: Option<i32>,
    current_chord_midi: Vec<i32>,
    current_octave_shift: i32,
    last_chord_zone_index: Option<i32>,
    last_melody_lane: Option<i32>,
    video_aspect: f64,
    screen_aspect: f64,
}

impl Default for ChordMelodyState {
    fn default() -> Self {
        Self {
            swap_hands: false,
            zone_degrees: vec![0, 1, 2, 3, 4, 5, 6],
            chord_pinch: PinchDetector::default(),
            melody_pinch: PinchDetector::default(),
            held_melody_midi: None,
            pending_chord_accent: false,
            pending_chord_accent_vel: 0.0,
            pad_on: false,
            pad_degree: None,
            pad_octave_shift: 0,
            current_chord_degree: None,
            current_chord_midi: Vec::new(),
            current_octave_shift: 0,
            last_chord_zone_index: None,
            last_melody_lane: None,
            video_aspect: 0.75,
            screen_aspect: 0.46,
        }
    }
}

/// Two-hand chord+melody mode. One hand drives a 7-zone chord pad with pinch
/// strums; the other plays melody notes snapped to the sounding chord's tones.
///
/// Mirrors Swift `ChordMelodyModeManager`. The chord-tone and melody-tone
/// closures used in Swift are replaced here by a [`ChordToneProvider`]
/// callback object passed at tick time — see [`ChordMelodyModeManager::tick`].
#[derive(uniffi::Object)]
pub struct ChordMelodyModeManager {
    inner: Mutex<ChordMelodyState>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct ChordToneTables {
    /// chord_tones[zoneDegree] → root/third/fifth MIDI notes for that degree.
    pub chord_tones: Vec<Vec<i32>>,
    /// melody_tones[zoneDegree] → snap targets across multiple octaves.
    pub melody_tones: Vec<Vec<i32>>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct ChordMelodyZones {
    pub chord_zone_index: Option<i32>,
    pub melody_lane: Option<i32>,
}

#[uniffi::export]
impl ChordMelodyModeManager {
    #[uniffi::constructor]
    pub fn new() -> Arc<Self> {
        Arc::new(Self { inner: Mutex::new(ChordMelodyState::default()) })
    }

    pub fn set_swap_hands(&self, swap: bool) {
        self.inner.lock().unwrap().swap_hands = swap;
    }

    pub fn set_zone_degrees(&self, degrees: Vec<i32>) {
        let mut s = self.inner.lock().unwrap();
        s.zone_degrees = if degrees.is_empty() { vec![0] } else { degrees };
    }

    pub fn zone_count(&self) -> i32 {
        self.inner.lock().unwrap().zone_degrees.len().max(1) as i32
    }

    pub fn set_aspects(&self, video_aspect: f64, screen_aspect: f64) {
        let mut s = self.inner.lock().unwrap();
        s.video_aspect = video_aspect;
        s.screen_aspect = screen_aspect;
    }

    pub fn current_chord_degree(&self) -> Option<i32> {
        self.inner.lock().unwrap().current_chord_degree
    }

    pub fn current_chord_midi(&self) -> Vec<i32> {
        self.inner.lock().unwrap().current_chord_midi.clone()
    }

    pub fn current_octave_shift(&self) -> i32 {
        self.inner.lock().unwrap().current_octave_shift
    }

    pub fn is_chord_hand_pinching(&self) -> bool {
        self.inner.lock().unwrap().chord_pinch.is_pinching
    }

    pub fn is_melody_hand_pinching(&self) -> bool {
        self.inner.lock().unwrap().melody_pinch.is_pinching
    }

    /// Map a zone index → scale degree via the current progression.
    pub fn degree_for_zone(&self, zone_index: i32) -> i32 {
        let s = self.inner.lock().unwrap();
        if s.zone_degrees.is_empty() { return 0; }
        let safe = zone_index.clamp(0, s.zone_degrees.len() as i32 - 1) as usize;
        s.zone_degrees[safe]
    }

    /// Map normalized X → zone index, accounting for camera aspect-fill crop
    /// and the chord hand owning half of the screen.
    pub fn x_to_zone_index(&self, x: f64) -> i32 {
        let s = self.inner.lock().unwrap();
        let visible = visible_x(x, s.video_aspect, s.screen_aspect);
        let half_range = if s.swap_hands {
            (visible - 0.5) * 2.0
        } else {
            visible * 2.0
        };
        let zone_count = s.zone_degrees.len().max(1) as i32;
        let clamped = half_range.clamp(0.0, 0.9999);
        ((clamped * zone_count as f64) as i32).min(zone_count - 1)
    }

    pub fn y_to_octave_shift(&self, y: f64) -> i32 {
        let clamped = y.clamp(0.0, 0.9999);
        if clamped < 0.33 { return 1; }
        if clamped < 0.66 { return 0; }
        -1
    }

    /// Drive one frame. Pass pre-resolved chord and melody tone tables indexed
    /// by scale degree (computed by the caller from current key/scale).
    pub fn tick(
        &self,
        hands: HandsState,
        tones: ChordToneTables,
        quantize: bool,
        grid_boundary_crossed: bool,
    ) -> Vec<ChordMelodyAction> {
        let mut actions = Vec::new();
        let mut s = self.inner.lock().unwrap();

        let chord_hand_owned = chord_hand(&hands, s.swap_hands).cloned();
        let melody_hand_name_str = melody_hand_name(s.swap_hands).to_string();

        // -------------------- Chord hand --------------------
        if let Some(h) = chord_hand_owned {
            let visible = visible_x(h.pinch_x, s.video_aspect, s.screen_aspect);
            let half_range = if s.swap_hands { (visible - 0.5) * 2.0 } else { visible * 2.0 };
            let zone_count = s.zone_degrees.len().max(1) as i32;
            let clamped = half_range.clamp(0.0, 0.9999);
            let zone_idx = ((clamped * zone_count as f64) as i32).min(zone_count - 1);
            let safe = zone_idx.clamp(0, s.zone_degrees.len() as i32 - 1) as usize;
            let degree = s.zone_degrees[safe];

            let octave = if h.pinch_y < 0.33 { 1 } else if h.pinch_y < 0.66 { 0 } else { -1 };
            s.current_octave_shift = octave;
            s.current_chord_degree = Some(degree);

            let base_tones = tones
                .chord_tones
                .get(degree as usize)
                .cloned()
                .unwrap_or_default();
            s.current_chord_midi = base_tones.iter().map(|m| m + octave * 12).collect();

            if !s.pad_on {
                s.pad_on = true;
                s.pad_degree = Some(degree);
                s.pad_octave_shift = octave;
                actions.push(ChordMelodyAction::PadOn {
                    midi_notes: s.current_chord_midi.clone(),
                    degree,
                });
            } else {
                let changed = s.pad_degree != Some(degree) || s.pad_octave_shift != octave;
                if changed && (!quantize || grid_boundary_crossed) {
                    s.pad_degree = Some(degree);
                    s.pad_octave_shift = octave;
                    actions.push(ChordMelodyAction::PadSlide {
                        midi_notes: s.current_chord_midi.clone(),
                        degree,
                    });
                }
            }

            // Pinch crossings → strum.
            if s.chord_pinch.update(h.pinch) == PinchPhase::Began {
                if quantize {
                    s.pending_chord_accent = true;
                    s.pending_chord_accent_vel = h.pinch.min(1.0);
                } else {
                    actions.push(ChordMelodyAction::ChordAccent {
                        midi_notes: s.current_chord_midi.clone(),
                        degree,
                        velocity: h.pinch.min(1.0),
                    });
                }
            }

            if quantize && s.pending_chord_accent && grid_boundary_crossed {
                s.pending_chord_accent = false;
                let strike_degree = s.pad_degree.unwrap_or(degree);
                let strike_base = tones
                    .chord_tones
                    .get(strike_degree as usize)
                    .cloned()
                    .unwrap_or_default();
                let strike_midi: Vec<i32> = strike_base
                    .iter()
                    .map(|m| m + s.pad_octave_shift * 12)
                    .collect();
                actions.push(ChordMelodyAction::ChordAccent {
                    midi_notes: strike_midi,
                    degree: strike_degree,
                    velocity: s.pending_chord_accent_vel,
                });
            }
        } else {
            if s.pad_on {
                s.pad_on = false;
                s.pad_degree = None;
                actions.push(ChordMelodyAction::PadOff);
            }
            s.chord_pinch.reset();
            s.pending_chord_accent = false;
        }

        // -------------------- Melody hand --------------------
        let snap_degree = s.pad_degree.or(s.current_chord_degree).unwrap_or(0);
        let melody_snap_targets: Vec<i32> = tones
            .melody_tones
            .get(snap_degree as usize)
            .cloned()
            .unwrap_or_default();

        let melody_hand_owned = melody_hand(&hands, s.swap_hands).cloned();
        if let (Some(h), false) = (melody_hand_owned, melody_snap_targets.is_empty()) {
            let lane = y_to_melody_lane(h.pinch_y, melody_snap_targets.len() as i32) as usize;
            let midi = melody_snap_targets[lane];
            let allow_change = !quantize || grid_boundary_crossed;

            match s.melody_pinch.update(h.pinch) {
                PinchPhase::Began => {
                    if allow_change {
                        s.held_melody_midi = Some(midi);
                        actions.push(ChordMelodyAction::MelodyOn {
                            hand: melody_hand_name_str.clone(),
                            midi,
                            name: midi_note_name(midi),
                            velocity: h.pinch.min(1.0),
                        });
                    }
                }
                PinchPhase::Held => {
                    if !allow_change {
                        // skip
                    } else if s.held_melody_midi.is_none() {
                        s.held_melody_midi = Some(midi);
                        actions.push(ChordMelodyAction::MelodyOn {
                            hand: melody_hand_name_str.clone(),
                            midi,
                            name: midi_note_name(midi),
                            velocity: h.pinch.min(1.0),
                        });
                    } else if s.held_melody_midi != Some(midi) {
                        s.held_melody_midi = Some(midi);
                        actions.push(ChordMelodyAction::MelodySlide {
                            hand: melody_hand_name_str.clone(),
                            midi,
                            name: midi_note_name(midi),
                        });
                    }
                }
                PinchPhase::Ended => {
                    s.held_melody_midi = None;
                    actions.push(ChordMelodyAction::MelodyOff { hand: melody_hand_name_str.clone() });
                }
                PinchPhase::Idle => {}
            }
        } else if s.melody_pinch.release() == PinchPhase::Ended {
            s.held_melody_midi = None;
            actions.push(ChordMelodyAction::MelodyOff { hand: melody_hand_name_str });
        }

        actions
    }

    /// For UI: chord zone index + melody lane. Falls back to last known when
    /// a hand briefly leaves the frame.
    pub fn current_zones(&self, hands: HandsState) -> ChordMelodyZones {
        let mut s = self.inner.lock().unwrap();
        let swap = s.swap_hands;
        let zone_count = s.zone_degrees.len().max(1) as i32;
        let video_aspect = s.video_aspect;
        let screen_aspect = s.screen_aspect;

        if let Some(h) = chord_hand(&hands, swap) {
            let visible = visible_x(h.pinch_x, video_aspect, screen_aspect);
            let half_range = if swap { (visible - 0.5) * 2.0 } else { visible * 2.0 };
            let clamped = half_range.clamp(0.0, 0.9999);
            let idx = ((clamped * zone_count as f64) as i32).min(zone_count - 1);
            s.last_chord_zone_index = Some(idx);
        }

        if let Some(h) = melody_hand(&hands, swap) {
            let count = s.current_chord_midi.len().max(9) as i32;
            s.last_melody_lane = Some(y_to_melody_lane(h.pinch_y, count));
        }

        ChordMelodyZones {
            chord_zone_index: s.last_chord_zone_index,
            melody_lane: s.last_melody_lane,
        }
    }
}

fn chord_hand(hands: &HandsState, swap: bool) -> Option<&HandData> {
    if swap { hands.right.as_ref() } else { hands.left.as_ref() }
}

fn melody_hand(hands: &HandsState, swap: bool) -> Option<&HandData> {
    if swap { hands.left.as_ref() } else { hands.right.as_ref() }
}

fn melody_hand_name(swap: bool) -> &'static str {
    if swap { "left" } else { "right" }
}

fn visible_x(x: f64, video_aspect: f64, screen_aspect: f64) -> f64 {
    if video_aspect <= 0.0 || screen_aspect <= 0.0 { return x; }
    if video_aspect > screen_aspect {
        let visible_width = screen_aspect / video_aspect;
        let offset = (1.0 - visible_width) / 2.0;
        return (x - offset) / visible_width;
    }
    x
}

#[uniffi::export]
pub fn y_to_melody_lane(y: f64, note_count: i32) -> i32 {
    if note_count <= 0 { return 0; }
    let top_pad = 0.15;
    let bottom_pad = 0.20;
    let usable = 1.0 - top_pad - bottom_pad;
    let clamped = ((y - top_pad) / usable).clamp(0.0, 1.0);
    let normalized = 1.0 - clamped;
    let idx = (normalized * note_count as f64) as i32;
    idx.clamp(0, note_count - 1)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::music::{chord_notes, scale_notes, MusicKey, Scale};

    fn tones_for(key: MusicKey, scale: Scale) -> ChordToneTables {
        let degree_count = scale.intervals().len();
        let mut chord_tones = Vec::with_capacity(degree_count);
        let mut melody_tones = Vec::with_capacity(degree_count);
        let scale_full = scale_notes(key, scale);
        for d in 0..degree_count as i32 {
            chord_tones.push(chord_notes(key, scale, d));
            melody_tones.push(scale_full.clone());
        }
        ChordToneTables { chord_tones, melody_tones }
    }

    #[test]
    fn pad_on_when_chord_hand_appears() {
        let m = ChordMelodyModeManager::new();
        let hands = HandsState {
            left: Some(HandData { pinch_x: 0.1, pinch_y: 0.5, pinch: 0.0 }),
            right: None,
        };
        let acts = m.tick(hands, tones_for(MusicKey::C, Scale::Major), false, false);
        assert_eq!(acts.len(), 1);
        assert!(matches!(acts[0], ChordMelodyAction::PadOn { degree: 0, .. }));
    }

    #[test]
    fn moving_chord_hand_emits_pad_slide() {
        let m = ChordMelodyModeManager::new();
        // First, pad on at zone 0.
        m.tick(
            HandsState {
                left: Some(HandData { pinch_x: 0.0, pinch_y: 0.5, pinch: 0.0 }),
                right: None,
            },
            tones_for(MusicKey::C, Scale::Major),
            false,
            false,
        );
        // Move to a different zone.
        let acts = m.tick(
            HandsState {
                left: Some(HandData { pinch_x: 0.49, pinch_y: 0.5, pinch: 0.0 }),
                right: None,
            },
            tones_for(MusicKey::C, Scale::Major),
            false,
            false,
        );
        assert!(acts.iter().any(|a| matches!(a, ChordMelodyAction::PadSlide { .. })));
    }

    #[test]
    fn chord_hand_leaving_frame_emits_pad_off() {
        let m = ChordMelodyModeManager::new();
        m.tick(
            HandsState {
                left: Some(HandData { pinch_x: 0.1, pinch_y: 0.5, pinch: 0.0 }),
                right: None,
            },
            tones_for(MusicKey::C, Scale::Major),
            false,
            false,
        );
        let acts = m.tick(
            HandsState { left: None, right: None },
            tones_for(MusicKey::C, Scale::Major),
            false,
            false,
        );
        assert!(acts.iter().any(|a| matches!(a, ChordMelodyAction::PadOff)));
    }
}
