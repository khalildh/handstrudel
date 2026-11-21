use std::sync::{Arc, Mutex};
use std::time::Instant;

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
    /// Split's richer cousin (iOS `.scale`): same wheel and chord half, but
    /// the melody side fans the full scale (one octave) and its outer band
    /// shifts the melody ±1 octave. The engine voices chords as 7ths.
    Scale,
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
    let v = radial_vector_raw(x, y, video_aspect, screen_aspect, radius_fraction);
    PolarVector { angle: v.angle, radius: v.radius.min(1.0) }
}

/// Uncapped variant used by the manager (iOS `radialVector`): a radius above
/// 1 means the hand is past the rim.
fn radial_vector_raw(x: f64, y: f64, video_aspect: f64, screen_aspect: f64, radius_fraction: f64) -> PolarVector {
    if screen_aspect <= 0.0 {
        return PolarVector { angle: 0.0, radius: 0.0 };
    }
    let sx = visible_x(x, video_aspect, screen_aspect) * screen_aspect;
    let dx = sx - 0.5 * screen_aspect;
    let dy_up = 0.5 - y;
    let wheel_radius = (0.5 * screen_aspect).min(0.5) * radius_fraction;
    if wheel_radius <= 0.0 {
        return PolarVector { angle: 0.0, radius: 0.0 };
    }
    let radius = (dx * dx + dy_up * dy_up).sqrt() / wheel_radius;
    let deg = (90.0 - dy_up.atan2(dx) * 180.0 / std::f64::consts::PI).rem_euclid(360.0);
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
// Action enum + manager state. Mirrors iOS `ChordMelodyModeManager.swift`
// (1.0.1) field for field; comments there explain the musical reasoning.
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, PartialEq, uniffi::Enum)]
pub enum ChordMelodyAction {
    PadOn { midi_notes: Vec<i32>, degree: i32 },
    PadSlide { midi_notes: Vec<i32>, degree: i32 },
    PadOff,
    ChordAccent { midi_notes: Vec<i32>, degree: i32, velocity: f64 },
    MelodyOn { hand: String, midi: i32, name: String, velocity: f64 },
    MelodyOff { hand: String },
    MelodySlide { hand: String, midi: i32, name: String },
}

/// Frames the chord hand may vanish before the pad is released (~200 ms at 60 fps).
pub const CHORD_ABSENT_GRACE_FRAMES: i32 = 12;
/// Seconds a held melody note survives a tracking dropout.
pub const MELODY_MISSING_GRACE: f64 = 0.075;

#[derive(Debug)]
struct ChordMelodyState {
    layout: Layout,
    swap_hands: bool,
    zone_degrees: Vec<i32>,
    // Chord pinch is wider (0.7 / 0.25) than melody (0.8 / 0.5): a held chord
    // hand's fingers drift apart over time.
    chord_pinch: PinchDetector,
    chord_hand_absent_frames: i32,
    melody_pinch: PinchDetector,
    held_melody_midi: Option<i32>,
    melody_hand_missing_since: Option<f64>,
    pending_chord_accent: bool,
    pending_chord_accent_vel: f64,
    pad_on: bool,
    pad_degree: Option<i32>,
    pad_octave_shift: i32,
    current_octave_shift: i32,
    current_melody_octave_shift: i32,
    last_melody_target_count: i32,
    current_chord_degree: Option<i32>,
    current_chord_midi: Vec<i32>,
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
            chord_pinch: PinchDetector::new(0.7, 0.25),
            chord_hand_absent_frames: 0,
            melody_pinch: PinchDetector::new(0.8, 0.5),
            held_melody_midi: None,
            melody_hand_missing_since: None,
            pending_chord_accent: false,
            pending_chord_accent_vel: 0.0,
            pad_on: false,
            pad_degree: None,
            pad_octave_shift: 0,
            current_octave_shift: 0,
            current_melody_octave_shift: 0,
            last_melody_target_count: 9,
            current_chord_degree: None,
            current_chord_midi: Vec::new(),
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

/// Two-hand chord+melody mode. One hand drives a pinch-gated chord pad; the
/// other plays melody notes snapped to the sounding chord (or, in the Scale
/// layout, to one octave of the scale).
#[derive(uniffi::Object)]
pub struct ChordMelodyModeManager {
    inner: Mutex<ChordMelodyState>,
    epoch: Instant,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct ChordToneTables {
    /// `chord_tones[degree]` → chord MIDI notes for that scale degree (triad, or
    /// a 7th chord in the Scale layout).
    pub chord_tones: Vec<Vec<i32>>,
    /// `melody_tones[degree]` → melody snap targets while that degree sounds.
    pub melody_tones: Vec<Vec<i32>>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct ChordMelodyZones {
    /// Zone index (0..<zone_count, not the scale degree), sticky when the hand leaves.
    pub chord_zone_index: Option<i32>,
    pub melody_lane: Option<i32>,
    pub chord_resting: bool,
    pub melody_resting: bool,
}

#[uniffi::export]
impl ChordMelodyModeManager {
    #[uniffi::constructor]
    pub fn new() -> Arc<Self> {
        Arc::new(Self { inner: Mutex::new(ChordMelodyState::default()), epoch: Instant::now() })
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
        self.inner.lock().unwrap().zone_degrees = degrees;
    }

    pub fn zone_degrees(&self) -> Vec<i32> {
        self.inner.lock().unwrap().zone_degrees.clone()
    }

    pub fn zone_count(&self) -> i32 {
        self.inner.lock().unwrap().zone_count()
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

    /// Melody-hand octave shift from the outer band (Scale layout only).
    pub fn current_melody_octave_shift(&self) -> i32 {
        self.inner.lock().unwrap().current_melody_octave_shift
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

    pub fn chord_side(&self) -> Side {
        self.inner.lock().unwrap().chord_side()
    }

    pub fn melody_side(&self) -> Side {
        self.inner.lock().unwrap().melody_side()
    }

    /// Touch override: set while a finger holds a chord wedge so the melody
    /// snap (hand- and touch-driven) follows the touched chord. `None` clears.
    pub fn set_touch_chord(&self, degree: Option<i32>, octave: i32, midi_notes: Vec<i32>) {
        let mut s = self.inner.lock().unwrap();
        s.touch_chord_degree = degree;
        s.touch_chord_octave = octave;
        s.touch_chord_midi = midi_notes;
    }

    pub fn degree_for_zone(&self, zone_index: i32) -> i32 {
        self.inner.lock().unwrap().degree_for_zone(zone_index)
    }

    /// Drive one frame, timed by the manager's monotonic clock.
    pub fn tick(
        &self,
        hands: HandsState,
        tones: ChordToneTables,
        quantize: bool,
        grid_boundary_crossed: bool,
    ) -> Vec<ChordMelodyAction> {
        let now = self.epoch.elapsed().as_secs_f64();
        self.tick_at(hands, tones, quantize, grid_boundary_crossed, now)
    }

    /// Drive one frame at an explicit time in seconds (iOS `tick(…, now:)`).
    pub fn tick_at(
        &self,
        hands: HandsState,
        tones: ChordToneTables,
        quantize: bool,
        grid_boundary_crossed: bool,
        now: f64,
    ) -> Vec<ChordMelodyAction> {
        let mut s = self.inner.lock().unwrap();
        s.tick(&hands, &tones, quantize, grid_boundary_crossed, now)
    }

    /// UI state: chord zone index + melody lane, sticky when a hand leaves.
    pub fn current_zones(&self, hands: HandsState) -> ChordMelodyZones {
        let mut s = self.inner.lock().unwrap();
        s.current_zones(&hands)
    }
}

impl ChordMelodyState {
    fn zone_count(&self) -> i32 {
        self.zone_degrees.len().max(1) as i32
    }

    fn chord_side(&self) -> Side {
        if self.swap_hands { Side::Right } else { Side::Left }
    }

    fn melody_side(&self) -> Side {
        if self.swap_hands { Side::Left } else { Side::Right }
    }

    fn melody_hand_name(&self) -> String {
        (if self.swap_hands { "left" } else { "right" }).to_string()
    }

    fn degree_for_zone(&self, zone_index: i32) -> i32 {
        if self.zone_degrees.is_empty() {
            return 0;
        }
        let safe = zone_index.clamp(0, self.zone_degrees.len() as i32 - 1) as usize;
        self.zone_degrees[safe]
    }

    fn radial(&self, h: &HandData) -> PolarVector {
        // iOS uses the radial radius fraction for every wheel layout.
        radial_vector_raw(h.pinch_x, h.pinch_y, self.video_aspect, self.screen_aspect, RADIAL_RADIUS_FRACTION)
    }

    fn x_to_zone_index(&self, x: f64) -> i32 {
        x_to_zone_index(x, self.zone_count(), self.swap_hands, self.video_aspect, self.screen_aspect)
    }

    fn read_chord_hand(&self, h: &HandData) -> ChordReading {
        match self.layout {
            Layout::Grid => ChordReading {
                degree: self.degree_for_zone(self.x_to_zone_index(h.pinch_x)),
                octave: y_to_octave_shift(h.pinch_y),
                resting: false,
            },
            Layout::Radial => {
                let v = self.radial(h);
                if v.radius < RADIAL_DEADZONE {
                    let hold = self.pad_degree.or(self.current_chord_degree).unwrap_or(0);
                    return ChordReading { degree: hold, octave: 0, resting: true };
                }
                let zone = radial_wedge_index(v.angle, self.zone_count());
                ChordReading { degree: self.degree_for_zone(zone), octave: 0, resting: false }
            }
            Layout::Split | Layout::Scale => {
                let v = self.radial(h);
                let hold = ChordReading {
                    degree: self.pad_degree.or(self.current_chord_degree).unwrap_or(0),
                    octave: self.pad_octave_shift,
                    resting: true,
                };
                if v.radius < SPLIT_DEADZONE {
                    return hold;
                }
                let side = self.chord_side();
                match split_wedge_index(side, v.angle, self.zone_count()) {
                    Some(zone) => ChordReading {
                        degree: self.degree_for_zone(zone),
                        octave: split_octave_shift(side, v.angle, v.radius, zone, self.zone_count()),
                        resting: false,
                    },
                    None => hold,
                }
            }
        }
    }

    fn read_melody_hand(&self, h: &HandData, note_count: i32) -> MelodyReading {
        if note_count <= 0 {
            return MelodyReading { lane: 0, octave: 0, resting: false };
        }
        let rest = || MelodyReading {
            lane: self.last_melody_lane.unwrap_or(note_count / 2).clamp(0, note_count - 1),
            octave: 0,
            resting: true,
        };
        match self.layout {
            Layout::Grid => MelodyReading { lane: y_to_melody_lane(h.pinch_y, note_count), octave: 0, resting: false },
            Layout::Radial => {
                let v = self.radial(h);
                if v.radius < RADIAL_DEADZONE {
                    return rest();
                }
                MelodyReading { lane: radial_wedge_index(v.angle, note_count), octave: 0, resting: false }
            }
            Layout::Split | Layout::Scale => {
                let v = self.radial(h);
                if v.radius < SPLIT_DEADZONE {
                    return rest();
                }
                let side = self.melody_side();
                let Some(wedge) = split_wedge_index(side, v.angle, note_count) else { return rest() };
                let octave = if self.layout == Layout::Scale {
                    split_octave_shift(side, v.angle, v.radius, wedge, note_count)
                } else {
                    0
                };
                MelodyReading { lane: note_count - 1 - wedge, octave, resting: false }
            }
        }
    }

    fn tick(
        &mut self,
        hands: &HandsState,
        tones: &ChordToneTables,
        quantize: bool,
        boundary: bool,
        now: f64,
    ) -> Vec<ChordMelodyAction> {
        let mut actions = Vec::new();
        let chord_tones = |degree: i32| -> Vec<i32> {
            if degree < 0 { return Vec::new(); }
            tones.chord_tones.get(degree as usize).cloned().unwrap_or_default()
        };

        let chord_hand = if self.swap_hands { hands.right.as_ref() } else { hands.left.as_ref() };
        let melody_hand = if self.swap_hands { hands.left.as_ref() } else { hands.right.as_ref() };

        // -------------------- Chord hand (pinch-gated pad + accent) --------------------
        if let Some(touch_degree) = self.touch_chord_degree {
            if self.pad_on {
                actions.push(ChordMelodyAction::PadOff);
            }
            self.pad_on = false;
            self.pad_degree = None;
            self.chord_pinch.reset();
            self.pending_chord_accent = false;
            self.current_chord_degree = Some(touch_degree);
            self.current_octave_shift = self.touch_chord_octave;
            self.current_chord_midi = if self.touch_chord_midi.is_empty() {
                chord_tones(touch_degree).iter().map(|m| m + self.touch_chord_octave * 12).collect()
            } else {
                self.touch_chord_midi.clone()
            };
            self.chord_resting = false;
        } else if let Some(h) = chord_hand {
            self.chord_hand_absent_frames = 0;
            let reading = self.read_chord_hand(h);
            let degree = reading.degree;
            let octave = reading.octave;
            self.current_octave_shift = octave;
            self.current_chord_degree = Some(degree);
            self.current_chord_midi = chord_tones(degree).iter().map(|m| m + octave * 12).collect();

            match self.chord_pinch.update(h.pinch) {
                PinchPhase::Began => {
                    self.pad_on = true;
                    self.pad_degree = Some(degree);
                    self.pad_octave_shift = octave;
                    actions.push(ChordMelodyAction::PadOn { midi_notes: self.current_chord_midi.clone(), degree });
                    if quantize {
                        self.pending_chord_accent = true;
                        self.pending_chord_accent_vel = h.pinch.min(1.0);
                    } else {
                        actions.push(ChordMelodyAction::ChordAccent {
                            midi_notes: self.current_chord_midi.clone(),
                            degree,
                            velocity: h.pinch.min(1.0),
                        });
                    }
                }
                PinchPhase::Held => {
                    if !self.pad_on {
                        self.pad_on = true;
                        self.pad_degree = Some(degree);
                        self.pad_octave_shift = octave;
                        actions.push(ChordMelodyAction::PadOn { midi_notes: self.current_chord_midi.clone(), degree });
                    } else if (Some(degree) != self.pad_degree || octave != self.pad_octave_shift)
                        && !reading.resting
                        && (!quantize || boundary)
                    {
                        self.pad_degree = Some(degree);
                        self.pad_octave_shift = octave;
                        actions.push(ChordMelodyAction::PadSlide { midi_notes: self.current_chord_midi.clone(), degree });
                    }
                }
                PinchPhase::Ended => {
                    if self.pad_on {
                        self.pad_on = false;
                        self.pad_degree = None;
                        actions.push(ChordMelodyAction::PadOff);
                    }
                    self.pending_chord_accent = false;
                }
                PinchPhase::Idle => {}
            }

            if quantize && self.pending_chord_accent && boundary {
                self.pending_chord_accent = false;
                let strike_degree = self.pad_degree.unwrap_or(degree);
                let strike_midi = chord_tones(strike_degree).iter().map(|m| m + self.pad_octave_shift * 12).collect();
                actions.push(ChordMelodyAction::ChordAccent {
                    midi_notes: strike_midi,
                    degree: strike_degree,
                    velocity: self.pending_chord_accent_vel,
                });
            }
        } else {
            self.chord_hand_absent_frames += 1;
            if self.chord_hand_absent_frames >= CHORD_ABSENT_GRACE_FRAMES {
                if self.pad_on {
                    self.pad_on = false;
                    self.pad_degree = None;
                    actions.push(ChordMelodyAction::PadOff);
                }
                self.chord_pinch.reset();
                self.pending_chord_accent = false;
            }
        }

        // -------------------- Melody hand --------------------
        let snap_degree = self.pad_degree.or(self.current_chord_degree).unwrap_or(0);
        let snap_targets: Vec<i32> = if snap_degree < 0 {
            Vec::new()
        } else {
            tones.melody_tones.get(snap_degree as usize).cloned().unwrap_or_default()
        };
        if !snap_targets.is_empty() {
            self.last_melody_target_count = snap_targets.len() as i32;
        }
        let melody_hand_name = self.melody_hand_name();

        match melody_hand {
            Some(h) if !snap_targets.is_empty() => {
                if let Some(missing) = self.melody_hand_missing_since {
                    if now - missing >= MELODY_MISSING_GRACE {
                        if let Some(release) = self.release_tracked_melody() {
                            actions.push(release);
                        }
                    }
                }
                self.melody_hand_missing_since = None;
                let reading = self.read_melody_hand(h, snap_targets.len() as i32);
                let lane = reading.lane.clamp(0, snap_targets.len() as i32 - 1) as usize;
                let midi = snap_targets[lane] + reading.octave * 12;
                let allow_change = !quantize || boundary;

                match self.melody_pinch.update(h.pinch) {
                    PinchPhase::Began => {
                        if allow_change {
                            self.held_melody_midi = Some(midi);
                            actions.push(ChordMelodyAction::MelodyOn {
                                hand: melody_hand_name,
                                midi,
                                name: midi_note_name(midi),
                                velocity: h.pinch.min(1.0),
                            });
                        }
                    }
                    PinchPhase::Held => {
                        if allow_change {
                            if self.held_melody_midi.is_none() {
                                self.held_melody_midi = Some(midi);
                                actions.push(ChordMelodyAction::MelodyOn {
                                    hand: melody_hand_name,
                                    midi,
                                    name: midi_note_name(midi),
                                    velocity: h.pinch.min(1.0),
                                });
                            } else if self.held_melody_midi != Some(midi) && !reading.resting {
                                self.held_melody_midi = Some(midi);
                                actions.push(ChordMelodyAction::MelodySlide {
                                    hand: melody_hand_name,
                                    midi,
                                    name: midi_note_name(midi),
                                });
                            }
                        }
                    }
                    PinchPhase::Ended => {
                        self.held_melody_midi = None;
                        actions.push(ChordMelodyAction::MelodyOff { hand: melody_hand_name });
                    }
                    PinchPhase::Idle => {}
                }
            }
            _ => {
                if self.melody_pinch.is_pinching {
                    // Sustain a held note across short dropouts, but never keep
                    // a pending attack for an unseen hand.
                    if self.held_melody_midi.is_some() && !snap_targets.is_empty() {
                        let missing = *self.melody_hand_missing_since.get_or_insert(now);
                        if now - missing < MELODY_MISSING_GRACE {
                            return actions;
                        }
                    }
                    if let Some(release) = self.release_tracked_melody() {
                        actions.push(release);
                    }
                }
            }
        }
        actions
    }

    fn release_tracked_melody(&mut self) -> Option<ChordMelodyAction> {
        self.melody_hand_missing_since = None;
        self.melody_pinch.release();
        self.held_melody_midi?;
        self.held_melody_midi = None;
        Some(ChordMelodyAction::MelodyOff { hand: self.melody_hand_name() })
    }

    fn current_zones(&mut self, hands: &HandsState) -> ChordMelodyZones {
        let chord_hand = if self.swap_hands { hands.right.as_ref() } else { hands.left.as_ref() };
        let melody_hand = if self.swap_hands { hands.left.as_ref() } else { hands.right.as_ref() };

        if self.touch_chord_degree.is_none() {
            if let Some(h) = chord_hand {
                match self.layout {
                    Layout::Grid => {
                        self.last_chord_zone_index = Some(self.x_to_zone_index(h.pinch_x));
                        self.chord_resting = false;
                    }
                    Layout::Radial => {
                        let v = self.radial(h);
                        self.chord_resting = v.radius < RADIAL_DEADZONE;
                        if !self.chord_resting {
                            self.last_chord_zone_index = Some(radial_wedge_index(v.angle, self.zone_count()));
                        }
                    }
                    Layout::Split | Layout::Scale => {
                        let v = self.radial(h);
                        if v.radius < SPLIT_DEADZONE {
                            self.chord_resting = true;
                        } else if let Some(zone) = split_wedge_index(self.chord_side(), v.angle, self.zone_count()) {
                            self.last_chord_zone_index = Some(zone);
                            self.chord_resting = false;
                        } else {
                            self.chord_resting = true;
                        }
                    }
                }
            }
        }
        if let Some(h) = melody_hand {
            match self.layout {
                Layout::Grid => {
                    let count = self.current_chord_midi.len().max(9) as i32;
                    self.last_melody_lane = Some(y_to_melody_lane(h.pinch_y, count));
                    self.melody_resting = false;
                }
                Layout::Radial => {
                    let v = self.radial(h);
                    self.melody_resting = v.radius < RADIAL_DEADZONE;
                    if !self.melody_resting {
                        self.last_melody_lane = Some(radial_wedge_index(v.angle, 9));
                    }
                }
                Layout::Split => {
                    let v = self.radial(h);
                    if v.radius < SPLIT_DEADZONE {
                        self.melody_resting = true;
                    } else if let Some(wedge) = split_wedge_index(self.melody_side(), v.angle, 9) {
                        self.last_melody_lane = Some(9 - 1 - wedge);
                        self.melody_resting = false;
                    } else {
                        self.melody_resting = true;
                    }
                }
                Layout::Scale => {
                    let v = self.radial(h);
                    let count = self.last_melody_target_count.max(1);
                    if v.radius < SPLIT_DEADZONE {
                        self.melody_resting = true;
                        self.current_melody_octave_shift = 0;
                    } else if let Some(wedge) = split_wedge_index(self.melody_side(), v.angle, count) {
                        self.last_melody_lane = Some(count - 1 - wedge);
                        self.melody_resting = false;
                        self.current_melody_octave_shift =
                            split_octave_shift(self.melody_side(), v.angle, v.radius, wedge, count);
                    } else {
                        self.melody_resting = true;
                        self.current_melody_octave_shift = 0;
                    }
                }
            }
        }
        ChordMelodyZones {
            chord_zone_index: self.last_chord_zone_index,
            melody_lane: self.last_melody_lane,
            chord_resting: self.chord_resting,
            melody_resting: self.melody_resting,
        }
    }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn visible_x(x: f64, video_aspect: f64, screen_aspect: f64) -> f64 {
    if video_aspect <= 0.0 || screen_aspect <= 0.0 {
        return x;
    }
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
    if note_count <= 0 {
        return 0;
    }
    let top_pad = 0.15;
    let bottom_pad = 0.20;
    let usable = 1.0 - top_pad - bottom_pad;
    let normalized = 1.0 - ((y - top_pad) / usable).clamp(0.0, 1.0);
    ((normalized * note_count as f64) as i32).clamp(0, note_count - 1)
}

#[uniffi::export]
pub fn y_to_octave_shift(y: f64) -> i32 {
    let clamped = y.clamp(0.0, 0.9999);
    if clamped < 0.33 {
        return 1;
    }
    if clamped < 0.66 {
        return 0;
    }
    -1
}

struct ChordReading {
    degree: i32,
    octave: i32,
    resting: bool,
}

struct MelodyReading {
    lane: i32,
    octave: i32,
    resting: bool,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::music::{chord_notes, chord_notes_with_seventh, scale_notes_one_octave, MusicKey, Scale};

    fn hand(x: f64, y: f64, pinch: f64) -> HandData {
        HandData { pinch_x: x, pinch_y: y, pinch }
    }

    fn tables(chord: Vec<i32>, melody: Vec<i32>) -> ChordToneTables {
        ChordToneTables { chord_tones: vec![chord; 7], melody_tones: vec![melody; 7] }
    }

    fn radial_manager() -> Arc<ChordMelodyModeManager> {
        let m = ChordMelodyModeManager::new();
        m.set_layout(Layout::Radial);
        m.set_aspects(0.5, 0.5);
        m
    }

    fn is_on(a: &ChordMelodyAction) -> bool { matches!(a, ChordMelodyAction::MelodyOn { .. }) }
    fn is_off(a: &ChordMelodyAction) -> bool { matches!(a, ChordMelodyAction::MelodyOff { .. }) }
    fn is_pad_on(a: &ChordMelodyAction) -> bool { matches!(a, ChordMelodyAction::PadOn { .. }) }

    fn melody_tick(m: &ChordMelodyModeManager, pinch: Option<f64>, now: f64, quantize: bool, boundary: bool) -> Vec<ChordMelodyAction> {
        let hands = HandsState { left: None, right: pinch.map(|p| hand(0.75, 0.3, p)) };
        m.tick_at(hands, tables(vec![], vec![60, 64, 67]), quantize, boundary, now)
    }

    // ---- radialWedgeIndex ----
    #[test]
    fn radial_wedge_index_quadrants() {
        assert_eq!(radial_wedge_index(0.0, 4), 0);
        assert_eq!(radial_wedge_index(90.0, 4), 1);
        assert_eq!(radial_wedge_index(180.0, 4), 2);
        assert_eq!(radial_wedge_index(270.0, 4), 3);
    }

    #[test]
    fn radial_wedge_zero_is_centered_on_top() {
        assert_eq!(radial_wedge_index(44.0, 4), 0);
        assert_eq!(radial_wedge_index(46.0, 4), 1);
        assert_eq!(radial_wedge_index(359.0, 4), 0);
    }

    #[test]
    fn radial_wedge_clamps_and_guards() {
        assert_eq!(radial_wedge_index(0.0, 0), 0);
        assert_eq!(radial_wedge_index(720.0, 7), 0);
    }

    // ---- center rest zone ----
    #[test]
    fn chord_hand_in_center_is_resting() {
        let m = radial_manager();
        m.current_zones(HandsState { left: Some(hand(0.5, 0.5, 0.0)), right: None });
        assert!(m.chord_resting());
    }

    #[test]
    fn chord_hand_reaching_up_selects_top_wedge() {
        let m = radial_manager();
        let z = m.current_zones(HandsState { left: Some(hand(0.5, 0.1, 0.0)), right: None });
        assert!(!m.chord_resting());
        assert_eq!(z.chord_zone_index, Some(0));
    }

    #[test]
    fn melody_hand_in_center_is_resting() {
        let m = radial_manager();
        m.current_zones(HandsState { left: None, right: Some(hand(0.5, 0.5, 0.0)) });
        assert!(m.melody_resting());
    }

    #[test]
    fn grid_layout_never_rests() {
        let m = ChordMelodyModeManager::new();
        m.set_aspects(0.5, 0.5);
        m.current_zones(HandsState { left: Some(hand(0.25, 0.5, 0.0)), right: Some(hand(0.75, 0.5, 0.0)) });
        assert!(!m.chord_resting());
        assert!(!m.melody_resting());
    }

    // ---- melody dropout grace ----
    #[test]
    fn held_melody_glides_through_short_dropout_without_retriggering() {
        let m = radial_manager();
        assert!(melody_tick(&m, Some(0.95), 1.0, false, false).iter().any(is_on));
        assert!(melody_tick(&m, None, 1.016, false, false).is_empty());
        assert!(melody_tick(&m, None, 1.049, false, false).is_empty());
        assert!(melody_tick(&m, Some(0.95), 1.065, false, false).is_empty());
        assert!(m.is_melody_hand_pinching());
        assert!(melody_tick(&m, Some(0.2), 1.066, false, false).iter().any(is_off));
    }

    #[test]
    fn long_tracking_loss_releases_once_and_allows_fresh_attack() {
        let m = radial_manager();
        melody_tick(&m, Some(0.95), 1.0, false, false);
        assert!(melody_tick(&m, None, 1.016, false, false).is_empty());
        assert!(melody_tick(&m, None, 1.100, false, false).iter().any(is_off));
        assert!(melody_tick(&m, None, 1.150, false, false).is_empty());
        assert!(!m.is_melody_hand_pinching());
        assert!(melody_tick(&m, Some(0.95), 1.151, false, false).iter().any(is_on));
    }

    #[test]
    fn reappearance_after_long_gap_does_not_slide_stale_note() {
        let m = radial_manager();
        melody_tick(&m, Some(0.95), 1.0, false, false);
        assert!(melody_tick(&m, None, 1.020, false, false).is_empty());
        let resumed = melody_tick(&m, Some(0.95), 1.150, false, false);
        assert_eq!(resumed.len(), 2);
        assert!(is_off(&resumed[0]));
        assert!(is_on(&resumed[1]));
    }

    #[test]
    fn quantized_melody_never_fires_for_unseen_pending_attack() {
        let m = radial_manager();
        assert!(melody_tick(&m, Some(0.95), 1.0, true, false).is_empty());
        assert!(melody_tick(&m, None, 1.01, true, true).is_empty());
        assert!(!m.is_melody_hand_pinching());
    }

    // ---- split geometry ----
    #[test]
    fn split_wedge_left_side_top_to_bottom() {
        assert_eq!(split_wedge_index(Side::Left, 359.0, 4), Some(0));
        assert_eq!(split_wedge_index(Side::Left, 270.0, 4), Some(2));
        assert_eq!(split_wedge_index(Side::Left, 180.0, 4), Some(3));
    }

    #[test]
    fn split_wedge_right_side_top_to_bottom() {
        assert_eq!(split_wedge_index(Side::Right, 0.0, 4), Some(0));
        assert_eq!(split_wedge_index(Side::Right, 90.0, 4), Some(2));
        assert_eq!(split_wedge_index(Side::Right, 179.0, 4), Some(3));
    }

    #[test]
    fn split_wedge_wrong_half_is_none() {
        assert_eq!(split_wedge_index(Side::Left, 0.0, 4), None);
        assert_eq!(split_wedge_index(Side::Left, 90.0, 4), None);
        assert_eq!(split_wedge_index(Side::Right, 270.0, 4), None);
        assert_eq!(split_wedge_index(Side::Right, 200.0, 4), None);
        assert_eq!(split_wedge_index(Side::Left, 270.0, 0), None);
        assert_eq!(split_wedge_index(Side::Right, 90.0, 0), None);
    }

    #[test]
    fn split_octave_shift_bands() {
        assert_eq!(split_octave_shift(Side::Left, 270.0, 0.5, 2, 4), 0);
        assert_eq!(split_octave_shift(Side::Right, 90.0, 0.5, 2, 4), 0);
        assert_eq!(split_octave_shift(Side::Left, 350.0, 0.9, 0, 4), 1);
        assert_eq!(split_octave_shift(Side::Left, 320.0, 0.9, 0, 4), -1);
        assert_eq!(split_octave_shift(Side::Right, 10.0, 0.9, 0, 4), 1);
        assert_eq!(split_octave_shift(Side::Right, 40.0, 0.9, 0, 4), -1);
        assert_eq!(split_octave_shift(Side::Left, 265.0, 0.9, 2, 4), 1);
        assert_eq!(split_octave_shift(Side::Left, 230.0, 0.9, 2, 4), -1);
        assert_eq!(split_octave_shift(Side::Right, 95.0, 0.9, 2, 4), 1);
        assert_eq!(split_octave_shift(Side::Right, 130.0, 0.9, 2, 4), -1);
    }

    // ---- touch override ----
    #[test]
    fn touch_override_without_chord_hand_sets_published_state() {
        let m = ChordMelodyModeManager::new();
        m.set_zone_degrees(vec![0, 4, 5, 3]);
        m.set_touch_chord(Some(4), 1, vec![67, 71, 74]);
        m.tick_at(HandsState::default(), tables(vec![60, 64, 67], vec![60, 64, 67]), false, false, 0.0);
        assert_eq!(m.current_chord_degree(), Some(4));
        assert_eq!(m.current_chord_midi(), vec![67, 71, 74]);
        assert_eq!(m.current_octave_shift(), 1);
        assert!(!m.chord_resting());
    }

    #[test]
    fn touch_override_cleared_state_lingers() {
        let m = ChordMelodyModeManager::new();
        m.set_zone_degrees(vec![0, 1, 2, 3]);
        m.set_touch_chord(Some(2), 0, vec![62, 65, 69]);
        m.tick_at(HandsState::default(), tables(vec![60, 64, 67], vec![60, 64, 67]), false, false, 0.0);
        assert_eq!(m.current_chord_degree(), Some(2));
        m.set_touch_chord(None, 0, vec![]);
        m.tick_at(HandsState::default(), tables(vec![60, 64, 67], vec![60, 64, 67]), false, false, 0.0);
        assert_eq!(m.current_chord_degree(), Some(2));
    }

    #[test]
    fn touch_chord_emits_no_camera_pad_releases_without_hands() {
        let m = ChordMelodyModeManager::new();
        m.set_layout(Layout::Scale);
        m.set_touch_chord(Some(2), 0, vec![]);
        for _ in 0..30 {
            let a = m.tick_at(HandsState::default(), tables(vec![60, 64, 67], vec![]), false, false, 0.0);
            assert!(a.is_empty());
        }
        m.set_touch_chord(None, 0, vec![]);
        assert!(m.tick_at(HandsState::default(), tables(vec![60, 64, 67], vec![]), false, false, 0.0).is_empty());
    }

    #[test]
    fn touch_takes_over_from_camera_pad_and_pinch_resumes_after_release() {
        let m = ChordMelodyModeManager::new();
        m.set_layout(Layout::Scale);
        let hands = HandsState { left: Some(hand(0.22, 0.45, 1.0)), right: None };
        let tick = || m.tick_at(hands.clone(), tables(vec![60, 64, 67], vec![]), false, false, 0.0);
        assert!((0..6).flat_map(|_| tick()).any(|a| is_pad_on(&a)));
        m.set_touch_chord(Some(2), 0, vec![62, 65, 69, 72]);
        let transition = tick();
        assert_eq!(transition, vec![ChordMelodyAction::PadOff]);
        for _ in 0..6 {
            assert!(tick().is_empty());
        }
        assert_eq!(m.current_chord_midi(), vec![62, 65, 69, 72]);
        m.set_touch_chord(None, 0, vec![]);
        assert!((0..6).flat_map(|_| tick()).any(|a| is_pad_on(&a)));
    }

    // ---- pinch-gated pad (iOS 1.0.1) ----
    #[test]
    fn presence_alone_does_not_sound_pad_and_release_cuts_it() {
        let m = ChordMelodyModeManager::new();
        m.set_layout(Layout::Split);
        let t = tables(vec![48, 52, 55], vec![60]);
        let open = HandsState { left: Some(hand(0.2, 0.3, 0.0)), right: None };
        assert!(m.tick_at(open.clone(), t.clone(), false, false, 0.0).is_empty());
        let pinched = HandsState { left: Some(hand(0.2, 0.3, 0.9)), right: None };
        let a = m.tick_at(pinched, t.clone(), false, false, 0.0);
        assert!(a.iter().any(is_pad_on));
        assert!(a.iter().any(|x| matches!(x, ChordMelodyAction::ChordAccent { .. })));
        let released = HandsState { left: Some(hand(0.2, 0.3, 0.1)), right: None };
        assert_eq!(m.tick_at(released, t, false, false, 0.0), vec![ChordMelodyAction::PadOff]);
    }

    #[test]
    fn chord_hand_absence_rides_out_grace_frames() {
        let m = ChordMelodyModeManager::new();
        m.set_layout(Layout::Split);
        let t = tables(vec![48, 52, 55], vec![60]);
        m.tick_at(HandsState { left: Some(hand(0.2, 0.3, 0.9)), right: None }, t.clone(), false, false, 0.0);
        for _ in 0..(CHORD_ABSENT_GRACE_FRAMES - 1) {
            assert!(m.tick_at(HandsState::default(), t.clone(), false, false, 0.0).is_empty());
        }
        assert_eq!(m.tick_at(HandsState::default(), t, false, false, 0.0), vec![ChordMelodyAction::PadOff]);
    }

    #[test]
    fn quantize_defers_accent_to_boundary() {
        let m = ChordMelodyModeManager::new();
        let t = tables(vec![48, 52, 55], vec![60]);
        let h = HandsState { left: Some(hand(0.2, 0.3, 0.9)), right: None };
        let a = m.tick_at(h.clone(), t.clone(), true, false, 0.0);
        assert!(a.iter().any(is_pad_on));
        assert!(!a.iter().any(|x| matches!(x, ChordMelodyAction::ChordAccent { .. })));
        let b = m.tick_at(h, t, true, true, 0.0);
        assert!(b.iter().any(|x| matches!(x, ChordMelodyAction::ChordAccent { .. })));
    }

    // ---- Scale layout ----
    fn scale_tables() -> ChordToneTables {
        let chord: Vec<Vec<i32>> = (0..7).map(|d| chord_notes_with_seventh(MusicKey::C, Scale::Major, d)).collect();
        let melody = scale_notes_one_octave(MusicKey::C, Scale::Major, 4);
        ChordToneTables { chord_tones: chord, melody_tones: vec![melody; 7] }
    }

    fn scale_manager() -> Arc<ChordMelodyModeManager> {
        let m = ChordMelodyModeManager::new();
        m.set_layout(Layout::Scale);
        m.set_aspects(0.5, 0.5);
        m
    }

    /// Hand position (raw camera coords, identity aspect) at a polar angle /
    /// radius around the shared wheel (radius in units of the 0.92 wheel).
    fn polar(angle_deg: f64, radius: f64) -> (f64, f64) {
        let wheel = 0.25 * RADIAL_RADIUS_FRACTION; // min(0.5*0.5, 0.5) * 0.92
        let r = radius * wheel;
        let a = angle_deg.to_radians();
        // angle is clockwise from 12 o'clock: dx = r sin a, dy_up = r cos a.
        let sx = 0.25 + r * a.sin();
        (sx / 0.5, 0.5 - r * a.cos())
    }

    #[test]
    fn scale_layout_melody_covers_full_scale_top_is_highest() {
        let m = scale_manager();
        let t = scale_tables();
        // Melody on the right arc. Just below 12 o'clock = wedge 0 → lane 6 (B4).
        let (x, y) = polar(5.0, 0.6);
        let a = m.tick_at(HandsState { left: None, right: Some(hand(x, y, 0.95)) }, t.clone(), false, false, 0.0);
        assert!(a.iter().any(|x| matches!(x, ChordMelodyAction::MelodyOn { midi: 71, .. })), "{a:?}");
        // Bottom of the arc = lowest note (C4).
        let m2 = scale_manager();
        let (x, y) = polar(175.0, 0.6);
        let a = m2.tick_at(HandsState { left: None, right: Some(hand(x, y, 0.95)) }, t, false, false, 0.0);
        assert!(a.iter().any(|x| matches!(x, ChordMelodyAction::MelodyOn { midi: 60, .. })), "{a:?}");
    }

    #[test]
    fn scale_layout_outer_band_shifts_melody_octave() {
        let t = scale_tables();
        // Wedge 0 on the right arc spans [0, 180/7). Top half → +1, bottom half → -1.
        let m = scale_manager();
        let (x, y) = polar(3.0, 0.9);
        let a = m.tick_at(HandsState { left: None, right: Some(hand(x, y, 0.95)) }, t.clone(), false, false, 0.0);
        assert!(a.iter().any(|x| matches!(x, ChordMelodyAction::MelodyOn { midi: 83, .. })), "{a:?}");
        let m = scale_manager();
        let (x, y) = polar(20.0, 0.9);
        let a = m.tick_at(HandsState { left: None, right: Some(hand(x, y, 0.95)) }, t.clone(), false, false, 0.0);
        assert!(a.iter().any(|x| matches!(x, ChordMelodyAction::MelodyOn { midi: 59, .. })), "{a:?}");
        // Inner band: no shift; current_zones publishes the melody octave shift.
        let m = scale_manager();
        let (x, y) = polar(3.0, 0.9);
        m.tick_at(HandsState { left: None, right: Some(hand(x, y, 0.0)) }, t, false, false, 0.0);
        let z = m.current_zones(HandsState { left: None, right: Some(hand(x, y, 0.0)) });
        assert_eq!(z.melody_lane, Some(6));
        assert_eq!(m.current_melody_octave_shift(), 1);
    }

    #[test]
    fn scale_layout_uses_scale_length_for_wedges() {
        // Pentatonic: 5 wedges on the melody arc.
        let m = scale_manager();
        let melody = scale_notes_one_octave(MusicKey::C, Scale::Pentatonic, 4);
        let t = ChordToneTables { chord_tones: vec![chord_notes(MusicKey::C, Scale::Pentatonic, 0); 5], melody_tones: vec![melody; 5] };
        let (x, y) = polar(90.0, 0.6); // 3 o'clock = middle wedge (index 2) → lane 2 (E4)
        let h = HandsState { left: None, right: Some(hand(x, y, 0.95)) };
        let a = m.tick_at(h.clone(), t, false, false, 0.0);
        assert!(a.iter().any(|x| matches!(x, ChordMelodyAction::MelodyOn { midi: 64, .. })), "{a:?}");
        assert_eq!(m.current_zones(h).melody_lane, Some(2));
    }

    #[test]
    fn scale_layout_chord_side_uses_split_wedges_and_octave_band() {
        let m = scale_manager();
        m.set_zone_degrees(vec![0, 4, 5, 3]);
        let t = scale_tables();
        // Left arc, 4 wedges of 45°: 300° → offset 60 → wedge 1 (degree 4, V7).
        let (x, y) = polar(300.0, 0.6);
        let a = m.tick_at(HandsState { left: Some(hand(x, y, 0.9)), right: None }, t.clone(), false, false, 0.0);
        assert!(a.contains(&ChordMelodyAction::PadOn { midi_notes: vec![55, 59, 62, 65], degree: 4 }), "{a:?}");
        // Outer band near the top of wedge 1 → +1 octave.
        let m = scale_manager();
        m.set_zone_degrees(vec![0, 4, 5, 3]);
        let (x, y) = polar(312.0, 0.95);
        let a = m.tick_at(HandsState { left: Some(hand(x, y, 0.9)), right: None }, t, false, false, 0.0);
        assert!(a.contains(&ChordMelodyAction::PadOn { midi_notes: vec![67, 71, 74, 77], degree: 4 }), "{a:?}");
        assert_eq!(m.current_octave_shift(), 1);
    }

    #[test]
    fn swap_hands_moves_chords_to_the_right_arc() {
        let m = scale_manager();
        m.set_swap_hands(true);
        assert_eq!(m.chord_side(), Side::Right);
        assert_eq!(m.melody_side(), Side::Left);
        let t = scale_tables();
        let (x, y) = polar(10.0, 0.6);
        let a = m.tick_at(HandsState { left: None, right: Some(hand(x, y, 0.9)) }, t, false, false, 0.0);
        assert!(a.iter().any(is_pad_on), "{a:?}");
    }
}
