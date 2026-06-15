use std::sync::{Arc, Mutex};

use crate::hands::{HandData, HandsState};
use crate::music::midi_note_name;
use crate::pinch::{PinchDetector, PinchPhase};

// ---------------------------------------------------------------------------
// Layout / Side / geometry constants
// ---------------------------------------------------------------------------

/// Three rendering / mapping layouts for the chord-melody mode. The musical
/// state machine in [`ChordMelodyModeManager`] is the same across all three;
/// only the position → degree / lane math differs.
#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum Layout {
    /// Chord hand: X-axis picks a zone, Y-axis picks an octave shift.
    /// Melody hand: Y-axis picks a lane.
    Grid,
    /// Both hands share one wheel centered on the screen; the chord hand's
    /// angle picks a chord on the outer ring, the melody hand's angle picks a
    /// note on the inner ring.
    Radial,
    /// Each hand owns one semicircle of a single wheel. Chord wedges fan along
    /// the chord half; melody wedges fan along the other. Reach outward inside
    /// a chord wedge to shift octaves.
    Split,
}

/// Which half of the screen / wheel a hand owns in Split + Radial layouts.
#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum Side {
    Left,
    Right,
}

pub const RADIAL_DEADZONE: f64 = 0.24;
pub const RADIAL_RADIUS_FRACTION: f64 = 0.92;
pub const SPLIT_DEADZONE: f64 = 0.36;
pub const SPLIT_RADIUS_FRACTION: f64 = 1.0;
pub const SPLIT_OCTAVE_BAND_THRESHOLD: f64 = 0.80;

#[uniffi::export]
pub fn radial_deadzone() -> f64 { RADIAL_DEADZONE }

#[uniffi::export]
pub fn radial_radius_fraction() -> f64 { RADIAL_RADIUS_FRACTION }

#[uniffi::export]
pub fn split_deadzone() -> f64 { SPLIT_DEADZONE }

#[uniffi::export]
pub fn split_radius_fraction() -> f64 { SPLIT_RADIUS_FRACTION }

#[uniffi::export]
pub fn split_octave_band_threshold() -> f64 { SPLIT_OCTAVE_BAND_THRESHOLD }

// ---------------------------------------------------------------------------
// Geometry helpers — freestanding so the Compose / SwiftUI touch overlays
// can drive their own pointer math through the same primitives.
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct PolarVector {
    /// Degrees clockwise from 12 o'clock (0 at top, 90 at right, 180 at bottom).
    pub angle: f64,
    /// 0 at the wheel center, 1 at the rim.
    pub radius: f64,
}

/// Convert a normalized hand X/Y (in raw camera coords) into polar coordinates
/// around the screen center. Distances are in units of screen height so X and
/// Y share one pixel scale — the wheel stays a true circle even when the
/// preview is letter/pillar-boxed. Mirrors Swift `radialVector(x:y:)`.
#[uniffi::export]
pub fn radial_vector(
    x: f64,
    y: f64,
    video_aspect: f64,
    screen_aspect: f64,
    radius_fraction: f64,
) -> PolarVector {
    if screen_aspect <= 0.0 {
        return PolarVector { angle: 0.0, radius: 0.0 };
    }
    let visible = visible_x(x, video_aspect, screen_aspect);
    let sx = visible * screen_aspect;
    let center_sx = 0.5 * screen_aspect;
    let dx = sx - center_sx;
    let dy_up = 0.5 - y;
    let wheel_radius = (0.5 * screen_aspect).min(0.5) * radius_fraction;
    if wheel_radius <= 0.0 {
        return PolarVector { angle: 0.0, radius: 0.0 };
    }
    let radius = ((dx * dx + dy_up * dy_up).sqrt() / wheel_radius).min(1.0);
    let mut deg = 90.0 - dy_up.atan2(dx) * 180.0 / std::f64::consts::PI;
    deg = deg.rem_euclid(360.0);
    PolarVector { angle: deg, radius }
}

/// Map an angle (clockwise from 12 o'clock) to a wedge index 0..<count, with
/// wedge 0 centered on the top of the wheel. Radial layout — wedges fan around
/// the full 360°. Mirrors Swift `radialWedgeIndex(angle:count:)`.
#[uniffi::export]
pub fn radial_wedge_index(angle: f64, count: i32) -> i32 {
    if count <= 0 { return 0; }
    let wedge = 360.0 / count as f64;
    let shifted = (angle + wedge / 2.0).rem_euclid(360.0);
    ((shifted / wedge) as i32).clamp(0, count - 1)
}

/// Split layout: map an angle to a wedge index on the assigned semicircle, or
/// `None` if the hand is on the other half. Wedges fan counter-clockwise from
/// the top of the arc: index 0 sits at the top, index `count - 1` at the
/// bottom. Mirrors Swift `splitWedgeIndex(side:angle:count:)`.
#[uniffi::export]
pub fn split_wedge_index(side: Side, angle: f64, count: i32) -> Option<i32> {
    if count <= 0 { return None; }
    let a = angle.rem_euclid(360.0);
    let t = match side {
        Side::Left => {
            if !(180.0..360.0).contains(&a) { return None; }
            (360.0 - a) / 180.0
        }
        Side::Right => {
            if !(0.0..180.0).contains(&a) { return None; }
            a / 180.0
        }
    };
    Some(((t * count as f64) as i32).clamp(0, count - 1))
}

/// Split layout: octave shift driven by the chord-hand's position within its
/// wedge. Inside the inner band (radius < `SPLIT_OCTAVE_BAND_THRESHOLD`) the
/// chord plays at the base octave. In the outer band, the half closer to the
/// top of the arc lifts an octave; the half closer to the bottom drops one.
/// Mirrors Swift `splitOctaveShift(side:angle:radius:wedgeIndex:)`.
#[uniffi::export]
pub fn split_octave_shift(
    side: Side,
    angle: f64,
    radius: f64,
    wedge_index: i32,
    zone_count: i32,
) -> i32 {
    if radius < SPLIT_OCTAVE_BAND_THRESHOLD { return 0; }
    if zone_count <= 0 { return 0; }
    let a = angle.rem_euclid(360.0);
    let offset_from_top = match side {
        Side::Left => {
            if !(180.0..360.0).contains(&a) { return 0; }
            360.0 - a
        }
        Side::Right => {
            if !(0.0..180.0).contains(&a) { return 0; }
            a
        }
    };
    let wedge_len = 180.0 / zone_count as f64;
    let within_wedge = offset_from_top - wedge_index as f64 * wedge_len;
    if within_wedge < wedge_len / 2.0 { 1 } else { -1 }
}

// ---------------------------------------------------------------------------
// Action enum + manager state
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, uniffi::Enum)]
pub enum ChordMelodyAction {
    PadOn { midi_notes: Vec<i32>, degree: i32 },
    PadSlide { midi_notes: Vec<i32>, degree: i32 },
    PadOff,
    ChordAccent { midi_notes: Vec<i32>, degree: i32, velocity: f64 },
    MelodyOn { hand: String, midi: i32, name: String, velocity: f64 },
    MelodyOff { hand: String },
    MelodySlide { hand: String, midi: i32, name: String },
}

#[derive(Debug)]
struct ChordMelodyState {
    layout: Layout,
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
    chord_resting: bool,
    melody_resting: bool,
    last_chord_zone_index: Option<i32>,
    last_melody_lane: Option<i32>,
    touch_chord_degree: Option<i32>,
    touch_chord_octave: i32,
    touch_chord_midi: Vec<i32>,
    video_aspect: f64,
    screen_aspect: f64,
}

impl Default for ChordMelodyState {
    fn default() -> Self {
        Self {
            layout: Layout::Grid,
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
            chord_resting: false,
            melody_resting: false,
            last_chord_zone_index: None,
            last_melody_lane: None,
            touch_chord_degree: None,
            touch_chord_octave: 0,
            touch_chord_midi: Vec::new(),
            video_aspect: 0.75,
            screen_aspect: 0.46,
        }
    }
}

/// Two-hand chord+melody mode. One hand drives a chord pad with pinch strums;
/// the other plays melody notes snapped to the sounding chord's tones. The
/// `Layout` setting controls how positions map to zones — Grid, Radial, or
/// Split. The musical state machine is identical in all three.
#[derive(uniffi::Object)]
pub struct ChordMelodyModeManager {
    inner: Mutex<ChordMelodyState>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct ChordToneTables {
    /// `chord_tones[degree]` → root/third/fifth MIDI notes for that scale degree.
    pub chord_tones: Vec<Vec<i32>>,
    /// `melody_tones[degree]` → snap targets across multiple octaves.
    pub melody_tones: Vec<Vec<i32>>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct ChordMelodyZones {
    pub chord_zone_index: Option<i32>,
    pub melody_lane: Option<i32>,
    pub chord_resting: bool,
    pub melody_resting: bool,
}

#[uniffi::export]
impl ChordMelodyModeManager {
    #[uniffi::constructor]
    pub fn new() -> Arc<Self> {
        Arc::new(Self { inner: Mutex::new(ChordMelodyState::default()) })
    }

    pub fn set_layout(&self, layout: Layout) {
        self.inner.lock().unwrap().layout = layout;
    }

    pub fn layout(&self) -> Layout {
        self.inner.lock().unwrap().layout
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

    pub fn chord_resting(&self) -> bool {
        self.inner.lock().unwrap().chord_resting
    }

    pub fn melody_resting(&self) -> bool {
        self.inner.lock().unwrap().melody_resting
    }

    /// Side the chord hand owns under the current `swap_hands` setting.
    pub fn chord_side(&self) -> Side {
        if self.inner.lock().unwrap().swap_hands { Side::Right } else { Side::Left }
    }

    /// Side the melody hand owns under the current `swap_hands` setting.
    pub fn melody_side(&self) -> Side {
        if self.inner.lock().unwrap().swap_hands { Side::Left } else { Side::Right }
    }

    /// Touch override for Split mode: set when a finger is held on a chord
    /// wedge. Forces the published chord state to match the touched chord so
    /// the melody-snap math sees that chord instead of stale hand state.
    /// `degree == None` clears the override.
    pub fn set_touch_chord(&self, degree: Option<i32>, octave: i32, midi_notes: Vec<i32>) {
        let mut s = self.inner.lock().unwrap();
        s.touch_chord_degree = degree;
        s.touch_chord_octave = octave;
        s.touch_chord_midi = midi_notes;
    }

    pub fn degree_for_zone(&self, zone_index: i32) -> i32 {
        let s = self.inner.lock().unwrap();
        if s.zone_degrees.is_empty() { return 0; }
        let safe = zone_index.clamp(0, s.zone_degrees.len() as i32 - 1) as usize;
        s.zone_degrees[safe]
    }

    /// Drive one frame. `tones` is a pre-resolved table keyed by scale degree —
    /// callers compute it from the current key/scale before each call.
    pub fn tick(
        &self,
        hands: HandsState,
        tones: ChordToneTables,
        quantize: bool,
        grid_boundary_crossed: bool,
    ) -> Vec<ChordMelodyAction> {
        let mut actions = Vec::new();
        let mut s = self.inner.lock().unwrap();

        let chord_side = if s.swap_hands { Side::Right } else { Side::Left };
        let melody_side = if s.swap_hands { Side::Left } else { Side::Right };
        let chord_hand_owned = if s.swap_hands { hands.right.clone() } else { hands.left.clone() };
        let melody_hand_owned = if s.swap_hands { hands.left.clone() } else { hands.right.clone() };
        let melody_hand_name = (if s.swap_hands { "left" } else { "right" }).to_string();

        // -------------------- Chord hand --------------------
        if let Some(h) = chord_hand_owned {
            let reading = read_chord_hand(&s, &h, chord_side);
            let degree = reading.degree;
            let octave = reading.octave;
            s.current_octave_shift = octave;
            s.current_chord_degree = Some(degree);
            s.chord_resting = reading.resting;

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
                if changed && !reading.resting && (!quantize || grid_boundary_crossed) {
                    s.pad_degree = Some(degree);
                    s.pad_octave_shift = octave;
                    actions.push(ChordMelodyAction::PadSlide {
                        midi_notes: s.current_chord_midi.clone(),
                        degree,
                    });
                }
            }

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

        // Touch override (Split mode): a held finger on a chord wedge forces
        // the published chord state to match, so the melody-snap math sees the
        // touched chord. Hand input still wins on the frame it fires.
        if let Some(td) = s.touch_chord_degree {
            s.pad_on = true;
            s.pad_degree = Some(td);
            s.pad_octave_shift = s.touch_chord_octave;
            s.current_chord_degree = Some(td);
            if !s.touch_chord_midi.is_empty() {
                s.current_chord_midi = s.touch_chord_midi.clone();
            }
            s.chord_resting = false;
        }

        // -------------------- Melody hand --------------------
        let snap_degree = s.pad_degree.or(s.current_chord_degree).unwrap_or(0);
        let melody_snap_targets: Vec<i32> = tones
            .melody_tones
            .get(snap_degree as usize)
            .cloned()
            .unwrap_or_default();

        if let (Some(h), false) = (melody_hand_owned, melody_snap_targets.is_empty()) {
            let reading = read_melody_hand(&s, &h, melody_snap_targets.len() as i32, melody_side);
            s.melody_resting = reading.resting;
            let lane = reading.lane.clamp(0, melody_snap_targets.len() as i32 - 1) as usize;
            let midi = melody_snap_targets[lane];
            let allow_change = !quantize || grid_boundary_crossed;

            match s.melody_pinch.update(h.pinch) {
                PinchPhase::Began => {
                    if allow_change {
                        s.held_melody_midi = Some(midi);
                        actions.push(ChordMelodyAction::MelodyOn {
                            hand: melody_hand_name.clone(),
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
                            hand: melody_hand_name.clone(),
                            midi,
                            name: midi_note_name(midi),
                            velocity: h.pinch.min(1.0),
                        });
                    } else if s.held_melody_midi != Some(midi) && !reading.resting {
                        s.held_melody_midi = Some(midi);
                        actions.push(ChordMelodyAction::MelodySlide {
                            hand: melody_hand_name.clone(),
                            midi,
                            name: midi_note_name(midi),
                        });
                    }
                }
                PinchPhase::Ended => {
                    s.held_melody_midi = None;
                    actions.push(ChordMelodyAction::MelodyOff { hand: melody_hand_name.clone() });
                }
                PinchPhase::Idle => {}
            }
        } else if s.melody_pinch.release() == PinchPhase::Ended {
            s.held_melody_midi = None;
            actions.push(ChordMelodyAction::MelodyOff { hand: melody_hand_name });
        }

        actions
    }

    /// For UI: chord zone index + melody lane in the active layout, plus the
    /// resting flags. When a hand briefly leaves the frame the last known
    /// value is held so highlights feel sticky.
    pub fn current_zones(&self, hands: HandsState) -> ChordMelodyZones {
        let mut s = self.inner.lock().unwrap();
        let layout = s.layout;
        let swap = s.swap_hands;
        let zone_count = s.zone_degrees.len().max(1) as i32;
        let chord_side = if swap { Side::Right } else { Side::Left };
        let melody_side = if swap { Side::Left } else { Side::Right };

        if let Some(h) = chord_hand_owned_ref(&hands, swap) {
            match layout {
                Layout::Grid => {
                    s.last_chord_zone_index = Some(x_to_zone_index(h.pinch_x, zone_count, swap, s.video_aspect, s.screen_aspect));
                    s.chord_resting = false;
                }
                Layout::Radial => {
                    let radius_fraction = RADIAL_RADIUS_FRACTION;
                    let v = radial_vector(h.pinch_x, h.pinch_y, s.video_aspect, s.screen_aspect, radius_fraction);
                    s.chord_resting = v.radius < RADIAL_DEADZONE;
                    if !s.chord_resting {
                        s.last_chord_zone_index = Some(radial_wedge_index(v.angle, zone_count));
                    }
                }
                Layout::Split => {
                    let v = radial_vector(h.pinch_x, h.pinch_y, s.video_aspect, s.screen_aspect, SPLIT_RADIUS_FRACTION);
                    if v.radius < SPLIT_DEADZONE {
                        s.chord_resting = true;
                    } else if let Some(zone) = split_wedge_index(chord_side, v.angle, zone_count) {
                        s.last_chord_zone_index = Some(zone);
                        s.chord_resting = false;
                    } else {
                        s.chord_resting = true;
                    }
                }
            }
        }
        if let Some(h) = melody_hand_owned_ref(&hands, swap) {
            match layout {
                Layout::Grid => {
                    let count = s.current_chord_midi.len().max(9) as i32;
                    s.last_melody_lane = Some(y_to_melody_lane(h.pinch_y, count));
                    s.melody_resting = false;
                }
                Layout::Radial => {
                    let v = radial_vector(h.pinch_x, h.pinch_y, s.video_aspect, s.screen_aspect, RADIAL_RADIUS_FRACTION);
                    s.melody_resting = v.radius < RADIAL_DEADZONE;
                    if !s.melody_resting {
                        s.last_melody_lane = Some(radial_wedge_index(v.angle, 9));
                    }
                }
                Layout::Split => {
                    let v = radial_vector(h.pinch_x, h.pinch_y, s.video_aspect, s.screen_aspect, SPLIT_RADIUS_FRACTION);
                    if v.radius < SPLIT_DEADZONE {
                        s.melody_resting = true;
                    } else if let Some(wedge) = split_wedge_index(melody_side, v.angle, 9) {
                        // Wedge 0 = top of arc; invert so top = highest pitch.
                        s.last_melody_lane = Some(9 - 1 - wedge);
                        s.melody_resting = false;
                    } else {
                        s.melody_resting = true;
                    }
                }
            }
        }
        ChordMelodyZones {
            chord_zone_index: s.last_chord_zone_index,
            melody_lane: s.last_melody_lane,
            chord_resting: s.chord_resting,
            melody_resting: s.melody_resting,
        }
    }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn chord_hand_owned_ref(hands: &HandsState, swap: bool) -> Option<&HandData> {
    if swap { hands.right.as_ref() } else { hands.left.as_ref() }
}

fn melody_hand_owned_ref(hands: &HandsState, swap: bool) -> Option<&HandData> {
    if swap { hands.left.as_ref() } else { hands.right.as_ref() }
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

fn x_to_zone_index(x: f64, zone_count: i32, swap: bool, video_aspect: f64, screen_aspect: f64) -> i32 {
    let visible = visible_x(x, video_aspect, screen_aspect);
    let half_range = if swap { (visible - 0.5) * 2.0 } else { visible * 2.0 };
    let clamped = half_range.clamp(0.0, 0.9999);
    ((clamped * zone_count as f64) as i32).min(zone_count - 1).max(0)
}

#[uniffi::export]
pub fn y_to_melody_lane(y: f64, note_count: i32) -> i32 {
    if note_count <= 0 { return 0; }
    let top_pad = 0.15;
    let bottom_pad = 0.20;
    let usable = 1.0 - top_pad - bottom_pad;
    let clamped = ((y - top_pad) / usable).clamp(0.0, 1.0);
    let normalized = 1.0 - clamped;
    ((normalized * note_count as f64) as i32).clamp(0, note_count - 1)
}

#[uniffi::export]
pub fn y_to_octave_shift(y: f64) -> i32 {
    let clamped = y.clamp(0.0, 0.9999);
    if clamped < 0.33 { return 1; }
    if clamped < 0.66 { return 0; }
    -1
}

struct ChordReading { degree: i32, octave: i32, resting: bool }
struct MelodyReading { lane: i32, resting: bool }

fn read_chord_hand(s: &ChordMelodyState, h: &HandData, chord_side: Side) -> ChordReading {
    let zone_count = s.zone_degrees.len().max(1) as i32;
    let degree_for_zone = |zone: i32| -> i32 {
        if s.zone_degrees.is_empty() { return 0; }
        let safe = zone.clamp(0, s.zone_degrees.len() as i32 - 1) as usize;
        s.zone_degrees[safe]
    };
    match s.layout {
        Layout::Grid => {
            let zone = x_to_zone_index(h.pinch_x, zone_count, s.swap_hands, s.video_aspect, s.screen_aspect);
            ChordReading { degree: degree_for_zone(zone), octave: y_to_octave_shift(h.pinch_y), resting: false }
        }
        Layout::Radial => {
            let v = radial_vector(h.pinch_x, h.pinch_y, s.video_aspect, s.screen_aspect, RADIAL_RADIUS_FRACTION);
            if v.radius < RADIAL_DEADZONE {
                let hold_degree = s.pad_degree.or(s.current_chord_degree).unwrap_or(0);
                ChordReading { degree: hold_degree, octave: 0, resting: true }
            } else {
                let zone = radial_wedge_index(v.angle, zone_count);
                ChordReading { degree: degree_for_zone(zone), octave: 0, resting: false }
            }
        }
        Layout::Split => {
            let v = radial_vector(h.pinch_x, h.pinch_y, s.video_aspect, s.screen_aspect, SPLIT_RADIUS_FRACTION);
            let hold_degree = s.pad_degree.or(s.current_chord_degree).unwrap_or(0);
            if v.radius < SPLIT_DEADZONE {
                return ChordReading { degree: hold_degree, octave: s.pad_octave_shift, resting: true };
            }
            match split_wedge_index(chord_side, v.angle, zone_count) {
                Some(zone) => {
                    let octave = split_octave_shift(chord_side, v.angle, v.radius, zone, zone_count);
                    ChordReading { degree: degree_for_zone(zone), octave, resting: false }
                }
                None => ChordReading { degree: hold_degree, octave: s.pad_octave_shift, resting: true },
            }
        }
    }
}

fn read_melody_hand(s: &ChordMelodyState, h: &HandData, note_count: i32, melody_side: Side) -> MelodyReading {
    if note_count <= 0 { return MelodyReading { lane: 0, resting: false }; }
    let rest = || -> MelodyReading {
        let fallback = s.last_melody_lane.unwrap_or(note_count / 2);
        MelodyReading { lane: fallback.clamp(0, note_count - 1), resting: true }
    };
    match s.layout {
        Layout::Grid => MelodyReading { lane: y_to_melody_lane(h.pinch_y, note_count), resting: false },
        Layout::Radial => {
            let v = radial_vector(h.pinch_x, h.pinch_y, s.video_aspect, s.screen_aspect, RADIAL_RADIUS_FRACTION);
            if v.radius < RADIAL_DEADZONE { rest() }
            else { MelodyReading { lane: radial_wedge_index(v.angle, note_count), resting: false } }
        }
        Layout::Split => {
            let v = radial_vector(h.pinch_x, h.pinch_y, s.video_aspect, s.screen_aspect, SPLIT_RADIUS_FRACTION);
            if v.radius < SPLIT_DEADZONE { return rest(); }
            match split_wedge_index(melody_side, v.angle, note_count) {
                Some(wedge) => MelodyReading { lane: note_count - 1 - wedge, resting: false },
                None => rest(),
            }
        }
    }
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
    fn split_left_wedge_top_is_index_0() {
        // Left side, angle just below 360 (i.e. just left of 12 o'clock) → wedge 0.
        let idx = split_wedge_index(Side::Left, 359.0, 7);
        assert_eq!(idx, Some(0));
    }

    #[test]
    fn split_left_wedge_bottom_is_last_index() {
        // Left side, angle ≈ 180 (6 o'clock) → wedge 6 (last).
        let idx = split_wedge_index(Side::Left, 180.0, 7);
        assert_eq!(idx, Some(6));
    }

    #[test]
    fn split_right_wedge_rejects_left_side() {
        // Right side, angle 270 → Some? No, 270 is on the left half → None.
        assert_eq!(split_wedge_index(Side::Right, 270.0, 7), None);
    }

    #[test]
    fn split_octave_shift_zero_in_inner_band() {
        // Radius below threshold → base octave.
        assert_eq!(split_octave_shift(Side::Left, 270.0, 0.5, 3, 7), 0);
    }

    #[test]
    fn split_octave_shift_plus_one_top_half_of_wedge() {
        // Outer band, top half of a wedge (closer to top of arc) → +1.
        // Left side, top of arc is at 360 (i.e. 0). With 7 wedges (each 180/7 ≈ 25.7°),
        // wedge 0 spans offset_from_top 0..25.7. Top half is 0..12.85.
        // angle 350 → offset_from_top = 360 - 350 = 10 (top half).
        assert_eq!(split_octave_shift(Side::Left, 350.0, 0.95, 0, 7), 1);
    }

    #[test]
    fn pad_on_in_split_layout() {
        let m = ChordMelodyModeManager::new();
        m.set_layout(Layout::Split);
        // Hand near the rim on the left half — should pick a chord, not rest.
        // Reach for the top of the left arc (angle ≈ 350°, radius ≈ 0.85).
        // In raw camera coords with default aspects (0.75 video, 0.46 screen),
        // the left half is x < 0.5. Place x around 0.2, y around 0.1.
        let hands = HandsState {
            left: Some(HandData { pinch_x: 0.2, pinch_y: 0.1, pinch: 0.0 }),
            right: None,
        };
        let acts = m.tick(hands, tones_for(MusicKey::C, Scale::Major), false, false);
        // Pad should come up.
        assert!(acts.iter().any(|a| matches!(a, ChordMelodyAction::PadOn { .. })));
    }

    #[test]
    fn touch_override_overrides_published_chord() {
        let m = ChordMelodyModeManager::new();
        m.set_layout(Layout::Split);
        // No camera input — set a touch chord.
        m.set_touch_chord(Some(4), 1, vec![71, 76, 79]); // V chord, +1 octave
        let _ = m.tick(HandsState::default(), tones_for(MusicKey::C, Scale::Major), false, false);
        assert_eq!(m.current_chord_degree(), Some(4));
        assert_eq!(m.current_chord_midi(), vec![71, 76, 79]);
    }
}
