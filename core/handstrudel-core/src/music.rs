#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum MusicKey {
    C, Db, D, Eb, E, F, Gb, G, Ab, A, Bb, B,
}

impl MusicKey {
    pub fn semitone(self) -> i32 {
        match self {
            MusicKey::C => 0,
            MusicKey::Db => 1,
            MusicKey::D => 2,
            MusicKey::Eb => 3,
            MusicKey::E => 4,
            MusicKey::F => 5,
            MusicKey::Gb => 6,
            MusicKey::G => 7,
            MusicKey::Ab => 8,
            MusicKey::A => 9,
            MusicKey::Bb => 10,
            MusicKey::B => 11,
        }
    }
}

/// The 23 built-in scales of iOS `BuiltInScale` (`Models/MusicTheory.swift`),
/// in the same order. Custom scales use the `*_for_intervals` functions.
#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum Scale {
    Major, Minor, Dorian, Pentatonic, Blues,
    HarmonicMinor, MelodicMinor, Phrygian, Lydian, Mixolydian,
    Locrian, WholeTone, Chromatic, HungarianMinor, Hirajoshi,
    MinorPentatonic, MajorBlues, PhrygianDominant, Diminished,
    HarmonicMajor, LydianDominant, Altered, DominantBebop,
}

impl Scale {
    pub fn intervals(self) -> &'static [i32] {
        match self {
            Scale::Major            => &[0, 2, 4, 5, 7, 9, 11],
            Scale::Minor            => &[0, 2, 3, 5, 7, 8, 10],
            Scale::Dorian           => &[0, 2, 3, 5, 7, 9, 10],
            Scale::Pentatonic       => &[0, 2, 4, 7, 9],
            Scale::Blues            => &[0, 3, 5, 6, 7, 10],
            Scale::HarmonicMinor    => &[0, 2, 3, 5, 7, 8, 11],
            Scale::MelodicMinor     => &[0, 2, 3, 5, 7, 9, 11],
            Scale::Phrygian         => &[0, 1, 3, 5, 7, 8, 10],
            Scale::Lydian           => &[0, 2, 4, 6, 7, 9, 11],
            Scale::Mixolydian       => &[0, 2, 4, 5, 7, 9, 10],
            Scale::Locrian          => &[0, 1, 3, 5, 6, 8, 10],
            Scale::WholeTone        => &[0, 2, 4, 6, 8, 10],
            Scale::Chromatic        => &[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
            Scale::HungarianMinor   => &[0, 2, 3, 6, 7, 8, 11],
            Scale::Hirajoshi        => &[0, 2, 3, 7, 8],
            Scale::MinorPentatonic  => &[0, 3, 5, 7, 10],
            Scale::MajorBlues       => &[0, 2, 3, 4, 7, 9],
            Scale::PhrygianDominant => &[0, 1, 4, 5, 7, 8, 10],
            Scale::Diminished       => &[0, 1, 3, 4, 6, 7, 9, 10],
            Scale::HarmonicMajor    => &[0, 2, 4, 5, 7, 8, 11],
            Scale::LydianDominant   => &[0, 2, 4, 6, 7, 9, 10],
            Scale::Altered          => &[0, 1, 3, 4, 6, 8, 10],
            Scale::DominantBebop    => &[0, 2, 4, 5, 7, 9, 10, 11],
        }
    }

    /// iOS `BuiltInScale.isPremium`: everything but the five free scales.
    pub fn is_premium(self) -> bool {
        !matches!(self, Scale::Major | Scale::Minor | Scale::Dorian | Scale::Pentatonic | Scale::Blues)
    }
}

const NOTE_NAMES: [&str; 12] =
    ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"];
const STRUDEL_NAMES: [&str; 12] =
    ["c", "db", "d", "eb", "e", "f", "gb", "g", "ab", "a", "bb", "b"];

#[uniffi::export]
pub fn music_key_semitone(key: MusicKey) -> i32 {
    key.semitone()
}

#[uniffi::export]
pub fn scale_intervals(scale: Scale) -> Vec<i32> {
    scale.intervals().to_vec()
}

#[uniffi::export]
pub fn scale_is_premium(scale: Scale) -> bool {
    scale.is_premium()
}

// ---------------------------------------------------------------------------
// Interval-based API (works for built-in and custom scales). Every Scale-enum
// function below delegates here, so both paths share one implementation.
// ---------------------------------------------------------------------------

/// MIDI notes across octaves 2–5, capped at C6 (84). Swift `scaleNotes(key:scale:)`.
#[uniffi::export]
pub fn scale_notes_for_intervals(key: MusicKey, intervals: Vec<i32>) -> Vec<i32> {
    let mut notes = Vec::new();
    for octave in 2..=5 {
        let base = (octave + 1) * 12 + key.semitone();
        for &interval in &intervals {
            let midi = base + interval;
            if midi <= 84 {
                notes.push(midi);
            }
        }
    }
    notes
}

/// Grid-mode range, capped at C7 (96). Swift `scaleNotes(key:scale:baseOctave:octaveRange:)`.
#[uniffi::export]
pub fn scale_notes_range_for_intervals(
    key: MusicKey,
    intervals: Vec<i32>,
    base_octave: i32,
    octave_range: i32,
) -> Vec<i32> {
    let mut notes = Vec::new();
    let end_octave = base_octave + octave_range - 1;
    if end_octave < base_octave {
        return notes;
    }
    for octave in base_octave..=end_octave {
        let base = (octave + 1) * 12 + key.semitone();
        for &interval in &intervals {
            let midi = base + interval;
            if midi <= 96 {
                notes.push(midi);
            }
        }
    }
    notes
}

/// One octave of scale notes from MIDI octave `octave` (Scale-mode melody side).
/// Swift `scaleNotesOneOctave(key:scale:octave:)`.
#[uniffi::export]
pub fn scale_notes_one_octave_for_intervals(key: MusicKey, intervals: Vec<i32>, octave: i32) -> Vec<i32> {
    let base = (octave + 1) * 12 + key.semitone();
    intervals.iter().map(|i| base + i).collect()
}

/// Triad (root/third/fifth) for a scale degree, root in octave 3. Swift `chordNotes`.
#[uniffi::export]
pub fn chord_notes_for_intervals(key: MusicKey, intervals: Vec<i32>, degree: i32) -> Vec<i32> {
    let count = intervals.len() as i32;
    if count == 0 {
        return vec![60];
    }
    let safe_degree = ((degree % count) + count) % count;
    let s = safe_degree as usize;

    let root = 48 + key.semitone() + intervals[s];
    let third_deg = ((safe_degree + 2) % count) as usize;
    let mut third = 48 + key.semitone() + intervals[third_deg];
    if third <= root {
        third += 12;
    }
    let fifth_deg = ((safe_degree + 4) % count) as usize;
    let mut fifth = 48 + key.semitone() + intervals[fifth_deg];
    while fifth <= third {
        fifth += 12;
    }
    vec![root, third, fifth]
}

/// 7th chord (root/3rd/5th/7th, all diatonic). Swift `chordNotesWithSeventh`.
#[uniffi::export]
pub fn chord_notes_with_seventh_for_intervals(key: MusicKey, intervals: Vec<i32>, degree: i32) -> Vec<i32> {
    let mut triad = chord_notes_for_intervals(key, intervals.clone(), degree);
    let count = intervals.len() as i32;
    if count == 0 {
        return triad;
    }
    let fifth = *triad.last().unwrap();
    let safe_degree = ((degree % count) + count) % count;
    let seventh_deg = ((safe_degree + 6) % count) as usize;
    let mut seventh = 48 + key.semitone() + intervals[seventh_deg];
    while seventh <= fifth {
        seventh += 12;
    }
    triad.push(seventh);
    triad
}

/// Chord display name ("Cmaj", "Amin", "Bdim"). Swift `chordDisplayName`.
#[uniffi::export]
pub fn chord_display_name_for_intervals(key: MusicKey, intervals: Vec<i32>, degree: i32) -> String {
    let count = intervals.len() as i32;
    if count == 0 {
        return NOTE_NAMES[key.semitone() as usize].to_string();
    }
    let safe_degree = ((degree % count) + count) % count;
    let s = safe_degree as usize;
    let root_semitone = (((key.semitone() + intervals[s]) % 12) + 12) % 12;
    let root_name = NOTE_NAMES[root_semitone as usize];

    let third_deg = ((safe_degree + 2) % count) as usize;
    let fifth_deg = ((safe_degree + 4) % count) as usize;
    let third_interval = (((intervals[third_deg] - intervals[s]) % 12) + 12) % 12;
    let fifth_interval = (((intervals[fifth_deg] - intervals[s]) % 12) + 12) % 12;

    let quality = match (third_interval, fifth_interval) {
        (4, 7) => "maj",
        (3, 7) => "min",
        (3, 6) => "dim",
        (4, 8) => "aug",
        _ => "",
    };
    format!("{}{}", root_name, quality)
}

// ---------------------------------------------------------------------------
// Scale-enum API (kept for existing callers).
// ---------------------------------------------------------------------------

/// MIDI notes in a key+scale across octaves 2–5, capped at C6 (84).
#[uniffi::export]
pub fn scale_notes(key: MusicKey, scale: Scale) -> Vec<i32> {
    scale_notes_for_intervals(key, scale.intervals().to_vec())
}

/// Limited-range version used by grid mode. Caps at C7 (96).
#[uniffi::export]
pub fn scale_notes_range(key: MusicKey, scale: Scale, base_octave: i32, octave_range: i32) -> Vec<i32> {
    scale_notes_range_for_intervals(key, scale.intervals().to_vec(), base_octave, octave_range)
}

/// Triad notes (root/third/fifth) for a scale degree. Root in octave 3.
#[uniffi::export]
pub fn chord_notes(key: MusicKey, scale: Scale, degree: i32) -> Vec<i32> {
    chord_notes_for_intervals(key, scale.intervals().to_vec(), degree)
}

#[uniffi::export]
pub fn chord_notes_with_seventh(key: MusicKey, scale: Scale, degree: i32) -> Vec<i32> {
    chord_notes_with_seventh_for_intervals(key, scale.intervals().to_vec(), degree)
}

#[uniffi::export]
pub fn scale_notes_one_octave(key: MusicKey, scale: Scale, octave: i32) -> Vec<i32> {
    scale_notes_one_octave_for_intervals(key, scale.intervals().to_vec(), octave)
}

#[uniffi::export]
pub fn chord_display_name(key: MusicKey, scale: Scale, degree: i32) -> String {
    chord_display_name_for_intervals(key, scale.intervals().to_vec(), degree)
}

#[uniffi::export]
pub fn midi_note_name(midi: i32) -> String {
    let idx = (((midi % 12) + 12) % 12) as usize;
    // Swift integer division truncates toward zero (`midi / 12 - 1`).
    let octave = midi / 12 - 1;
    format!("{}{}", NOTE_NAMES[idx], octave)
}

/// Note letter without octave ("C", "Eb"). Swift `pitchClassName`.
#[uniffi::export]
pub fn pitch_class_name(midi: i32) -> String {
    NOTE_NAMES[(((midi % 12) + 12) % 12) as usize].to_string()
}

#[uniffi::export]
pub fn midi_to_strudel_note(midi: i32) -> String {
    let idx = (((midi % 12) + 12) % 12) as usize;
    let octave = midi / 12 - 1;
    format!("{}{}", STRUDEL_NAMES[idx], octave)
}

#[uniffi::export]
pub fn quantize_to_scale(midi: i32, scale_notes: Vec<i32>) -> i32 {
    if scale_notes.is_empty() {
        return midi;
    }
    *scale_notes.iter().min_by_key(|n| (**n - midi).abs()).unwrap()
}

#[uniffi::export]
pub fn midi_to_lane_index(midi: i32, scale_notes: Vec<i32>) -> i32 {
    if scale_notes.is_empty() {
        return 0;
    }
    let mut best_idx = 0i32;
    let mut best_dist = i32::MAX;
    for (i, sn) in scale_notes.iter().enumerate() {
        let dist = (*sn - midi).abs();
        if dist < best_dist {
            best_dist = dist;
            best_idx = i as i32;
        }
    }
    best_idx
}

#[cfg(test)]
mod tests {
    use super::*;

    const ALL: [Scale; 23] = [
        Scale::Major, Scale::Minor, Scale::Dorian, Scale::Pentatonic, Scale::Blues,
        Scale::HarmonicMinor, Scale::MelodicMinor, Scale::Phrygian, Scale::Lydian, Scale::Mixolydian,
        Scale::Locrian, Scale::WholeTone, Scale::Chromatic, Scale::HungarianMinor, Scale::Hirajoshi,
        Scale::MinorPentatonic, Scale::MajorBlues, Scale::PhrygianDominant, Scale::Diminished,
        Scale::HarmonicMajor, Scale::LydianDominant, Scale::Altered, Scale::DominantBebop,
    ];

    #[test]
    fn c_major_scale_starts_at_c2() {
        let notes = scale_notes(MusicKey::C, Scale::Major);
        assert_eq!(notes[0], 36);
        assert!(notes.contains(&60));
        assert_eq!(*notes.last().unwrap(), 83);
        assert!(!notes.contains(&84));
    }

    #[test]
    fn c_major_chord_is_c_e_g() {
        assert_eq!(chord_notes(MusicKey::C, Scale::Major, 0), vec![48, 52, 55]);
    }

    #[test]
    fn vi_chord_in_c_major_is_a_minor() {
        assert_eq!(chord_notes(MusicKey::C, Scale::Major, 5), vec![57, 60, 64]);
    }

    #[test]
    fn chord_quality_naming() {
        assert_eq!(chord_display_name(MusicKey::C, Scale::Major, 0), "Cmaj");
        assert_eq!(chord_display_name(MusicKey::C, Scale::Major, 5), "Amin");
        assert_eq!(chord_display_name(MusicKey::C, Scale::Major, 6), "Bdim");
    }

    #[test]
    fn midi_60_is_c4() {
        assert_eq!(midi_note_name(60), "C4");
        assert_eq!(midi_to_strudel_note(60), "c4");
        assert_eq!(pitch_class_name(63), "Eb");
    }

    #[test]
    fn quantize_picks_nearest() {
        let notes = vec![60, 64, 67];
        assert_eq!(quantize_to_scale(62, notes.clone()), 60);
        assert_eq!(quantize_to_scale(63, notes.clone()), 64);
        assert_eq!(quantize_to_scale(70, notes), 67);
    }

    // The 8 scales added in iOS 1.0.1, intervals from MusicTheory.swift.
    #[test]
    fn new_scale_intervals_match_ios() {
        assert_eq!(Scale::MinorPentatonic.intervals(), &[0, 3, 5, 7, 10]);
        assert_eq!(Scale::MajorBlues.intervals(), &[0, 2, 3, 4, 7, 9]);
        assert_eq!(Scale::PhrygianDominant.intervals(), &[0, 1, 4, 5, 7, 8, 10]);
        assert_eq!(Scale::Diminished.intervals(), &[0, 1, 3, 4, 6, 7, 9, 10]);
        assert_eq!(Scale::HarmonicMajor.intervals(), &[0, 2, 4, 5, 7, 8, 11]);
        assert_eq!(Scale::LydianDominant.intervals(), &[0, 2, 4, 6, 7, 9, 10]);
        assert_eq!(Scale::Altered.intervals(), &[0, 1, 3, 4, 6, 8, 10]);
        assert_eq!(Scale::DominantBebop.intervals(), &[0, 2, 4, 5, 7, 9, 10, 11]);
    }

    #[test]
    fn every_scale_is_ascending_from_zero_and_free_set_matches_ios() {
        assert_eq!(ALL.len(), 23);
        for s in ALL {
            let iv = s.intervals();
            assert_eq!(iv[0], 0);
            assert!(iv.windows(2).all(|w| w[0] < w[1]));
            assert!(*iv.last().unwrap() < 12);
        }
        let free: Vec<Scale> = ALL.iter().copied().filter(|s| !s.is_premium()).collect();
        assert_eq!(free, vec![Scale::Major, Scale::Minor, Scale::Dorian, Scale::Pentatonic, Scale::Blues]);
    }

    #[test]
    fn every_chord_is_strictly_ascending_for_all_scales_and_degrees() {
        for s in ALL {
            for d in 0..s.intervals().len() as i32 {
                let c = chord_notes(MusicKey::C, s, d);
                assert!(c[0] < c[1] && c[1] < c[2], "{s:?} degree {d}: {c:?}");
                let c7 = chord_notes_with_seventh(MusicKey::C, s, d);
                assert_eq!(c7.len(), 4);
                assert!(c7[2] < c7[3], "{s:?} degree {d}: {c7:?}");
            }
        }
    }

    #[test]
    fn seventh_chords_in_c_major() {
        // I → Cmaj7, V → G7, ii → Dm7.
        assert_eq!(chord_notes_with_seventh(MusicKey::C, Scale::Major, 0), vec![48, 52, 55, 59]);
        assert_eq!(chord_notes_with_seventh(MusicKey::C, Scale::Major, 4), vec![55, 59, 62, 65]);
        assert_eq!(chord_notes_with_seventh(MusicKey::C, Scale::Major, 1), vec![50, 53, 57, 60]);
    }

    #[test]
    fn one_octave_scale_starts_at_octave_four() {
        assert_eq!(scale_notes_one_octave(MusicKey::C, Scale::Major, 4), vec![60, 62, 64, 65, 67, 69, 71]);
        assert_eq!(scale_notes_one_octave(MusicKey::D, Scale::Pentatonic, 4), vec![62, 64, 66, 69, 71]);
    }

    #[test]
    fn custom_interval_chords_match_builtin_equivalent() {
        let custom = vec![0, 2, 4, 5, 7, 9, 11];
        for d in 0..7 {
            assert_eq!(
                chord_notes_for_intervals(MusicKey::Eb, custom.clone(), d),
                chord_notes(MusicKey::Eb, Scale::Major, d)
            );
            assert_eq!(
                chord_display_name_for_intervals(MusicKey::Eb, custom.clone(), d),
                chord_display_name(MusicKey::Eb, Scale::Major, d)
            );
        }
    }

    #[test]
    fn custom_three_note_scale_chords_wrap_octaves() {
        // [0, 4, 7]: root C3, third = degree 2 → G3, fifth = degree 1 → E, pushed above G.
        assert_eq!(chord_notes_for_intervals(MusicKey::C, vec![0, 4, 7], 0), vec![48, 55, 64]);
        assert_eq!(chord_notes_with_seventh_for_intervals(MusicKey::C, vec![0, 4, 7], 0), vec![48, 55, 64, 72]);
    }

    #[test]
    fn grid_range_caps_at_c7() {
        let notes = scale_notes_range(MusicKey::C, Scale::Major, 6, 3);
        assert!(notes.iter().all(|n| *n <= 96));
        assert_eq!(*notes.last().unwrap(), 96);
        assert!(scale_notes_range(MusicKey::C, Scale::Major, 3, 0).is_empty());
    }
}
