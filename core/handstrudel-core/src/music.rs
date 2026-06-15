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

#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum Scale {
    Major, Minor, Dorian, Pentatonic, Blues,
    HarmonicMinor, MelodicMinor, Phrygian, Lydian, Mixolydian,
    Locrian, WholeTone, Chromatic, HungarianMinor, Hirajoshi,
}

impl Scale {
    pub fn intervals(self) -> &'static [i32] {
        match self {
            Scale::Major          => &[0, 2, 4, 5, 7, 9, 11],
            Scale::Minor          => &[0, 2, 3, 5, 7, 8, 10],
            Scale::Dorian         => &[0, 2, 3, 5, 7, 9, 10],
            Scale::Pentatonic     => &[0, 2, 4, 7, 9],
            Scale::Blues          => &[0, 3, 5, 6, 7, 10],
            Scale::HarmonicMinor  => &[0, 2, 3, 5, 7, 8, 11],
            Scale::MelodicMinor   => &[0, 2, 3, 5, 7, 9, 11],
            Scale::Phrygian       => &[0, 1, 3, 5, 7, 8, 10],
            Scale::Lydian         => &[0, 2, 4, 6, 7, 9, 11],
            Scale::Mixolydian     => &[0, 2, 4, 5, 7, 9, 10],
            Scale::Locrian        => &[0, 1, 3, 5, 6, 8, 10],
            Scale::WholeTone      => &[0, 2, 4, 6, 8, 10],
            Scale::Chromatic      => &[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
            Scale::HungarianMinor => &[0, 2, 3, 6, 7, 8, 11],
            Scale::Hirajoshi      => &[0, 2, 3, 7, 8],
        }
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

/// MIDI notes in a key+scale across octaves 2–5, capped at C6 (84).
/// Matches Swift `scaleNotes(key:scale:)`.
#[uniffi::export]
pub fn scale_notes(key: MusicKey, scale: Scale) -> Vec<i32> {
    let mut notes = Vec::new();
    let intervals = scale.intervals();
    for octave in 2..=5 {
        let base = (octave + 1) * 12 + key.semitone();
        for &interval in intervals {
            let midi = base + interval;
            if midi <= 84 {
                notes.push(midi);
            }
        }
    }
    notes
}

/// Limited-range version used by grid mode. Caps at C7 (96).
#[uniffi::export]
pub fn scale_notes_range(
    key: MusicKey,
    scale: Scale,
    base_octave: i32,
    octave_range: i32,
) -> Vec<i32> {
    let mut notes = Vec::new();
    let end_octave = base_octave + octave_range - 1;
    let intervals = scale.intervals();
    for octave in base_octave..=end_octave {
        let base = (octave + 1) * 12 + key.semitone();
        for &interval in intervals {
            let midi = base + interval;
            if midi <= 96 {
                notes.push(midi);
            }
        }
    }
    notes
}

/// Triad notes (root/third/fifth) for a scale degree. Root in octave 3.
#[uniffi::export]
pub fn chord_notes(key: MusicKey, scale: Scale, degree: i32) -> Vec<i32> {
    let intervals = scale.intervals();
    let count = intervals.len() as i32;
    if count == 0 { return vec![60]; }
    let safe_degree = ((degree % count) + count) % count;
    let s = safe_degree as usize;

    let root = 48 + key.semitone() + intervals[s];
    let third_deg = ((safe_degree + 2) % count) as usize;
    let mut third = 48 + key.semitone() + intervals[third_deg];
    if third <= root { third += 12; }
    let fifth_deg = ((safe_degree + 4) % count) as usize;
    let mut fifth = 48 + key.semitone() + intervals[fifth_deg];
    if fifth <= third { fifth += 12; }

    vec![root, third, fifth]
}

#[uniffi::export]
pub fn midi_note_name(midi: i32) -> String {
    let idx = (((midi % 12) + 12) % 12) as usize;
    let octave = midi.div_euclid(12) - 1;
    format!("{}{}", NOTE_NAMES[idx], octave)
}

#[uniffi::export]
pub fn midi_to_strudel_note(midi: i32) -> String {
    let idx = (((midi % 12) + 12) % 12) as usize;
    let octave = midi.div_euclid(12) - 1;
    format!("{}{}", STRUDEL_NAMES[idx], octave)
}

#[uniffi::export]
pub fn quantize_to_scale(midi: i32, scale_notes: Vec<i32>) -> i32 {
    if scale_notes.is_empty() { return midi; }
    *scale_notes
        .iter()
        .min_by_key(|n| (**n - midi).abs())
        .unwrap()
}

#[uniffi::export]
pub fn midi_to_lane_index(midi: i32, scale_notes: Vec<i32>) -> i32 {
    if scale_notes.is_empty() { return 0; }
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

#[uniffi::export]
pub fn chord_display_name(key: MusicKey, scale: Scale, degree: i32) -> String {
    let intervals = scale.intervals();
    let count = intervals.len() as i32;
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn c_major_scale_starts_at_c2() {
        let notes = scale_notes(MusicKey::C, Scale::Major);
        // C2 = MIDI 36 (the bottom of the generated range, octaves 2..=5).
        assert_eq!(notes[0], 36);
        assert!(notes.contains(&60)); // C4 = middle C
        assert_eq!(*notes.last().unwrap(), 83); // B5 is the top
        assert!(!notes.contains(&84)); // C6 excluded (loop stops at octave 5)
    }

    #[test]
    fn c_major_chord_is_c_e_g() {
        // Degree 0 in C major → C major triad (C3, E3, G3) = 48, 52, 55
        let chord = chord_notes(MusicKey::C, Scale::Major, 0);
        assert_eq!(chord, vec![48, 52, 55]);
    }

    #[test]
    fn vi_chord_in_c_major_is_a_minor() {
        let chord = chord_notes(MusicKey::C, Scale::Major, 5);
        // A3, C4, E4 → 57, 60, 64
        assert_eq!(chord, vec![57, 60, 64]);
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
    }

    #[test]
    fn quantize_picks_nearest() {
        let notes = vec![60, 64, 67];
        assert_eq!(quantize_to_scale(62, notes.clone()), 60);
        assert_eq!(quantize_to_scale(63, notes.clone()), 64);
        assert_eq!(quantize_to_scale(70, notes), 67);
    }
}
