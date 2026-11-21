// Runtime rules for the split wheel, ported from `WheelRules` in
// `InstrumentSpec.swift` and the note helpers in `Models/MusicTheory.swift`.
// Pitches are MIDI note numbers; a key is a semitone (C = 0) and a scale is its
// interval list, so these work for built-in and custom scales alike.

import type { InstrumentSpec, NoteSource } from "./spec.ts";

export interface WheelGeometry {
  radius: number;
  restRadius: number;
  octaveBandRadius: number;
}

/** The Scale and Split wheels' geometry (`WheelGeometry.standard`). */
export const STANDARD_GEOMETRY: WheelGeometry = { radius: 1.0, restRadius: 0.36, octaveBandRadius: 0.8 };

/** How chords are voiced. A music setting, never part of an instrument. */
export type ChordVoicing = "triad" | "seventh";

/** The Scale wheel (scale notes) plays 7ths; the Split wheel plays triads. */
export function wheelDefaultVoicing(source: NoteSource): ChordVoicing {
  return source === "scale_one_octave" ? "seventh" : "triad";
}

export interface WheelRules {
  geometry: WheelGeometry;
  chordsOnRight: boolean;
  voicing: ChordVoicing;
  noteSource: NoteSource;
  notesOctaveBand: boolean;
  highlightChordTones: boolean;
}

/**
 * What the wheel needs from an instrument, plus the voicing the player's music
 * implies (`InstrumentSpec.rules`). Pass `voicing` when the sound chooses one.
 */
export function wheelRules(spec: InstrumentSpec, voicing?: ChordVoicing): WheelRules {
  return {
    geometry: {
      radius: spec.surface.radius,
      restRadius: spec.surface.rest_radius,
      octaveBandRadius: spec.surface.octave_band_radius,
    },
    chordsOnRight: spec.chords.side === "right",
    voicing: voicing ?? wheelDefaultVoicing(spec.notes.source),
    noteSource: spec.notes.source,
    notesOctaveBand: spec.notes.octave_band,
    highlightChordTones: spec.notes.highlight_chord_tones ?? false,
  };
}

/** Chord hand on the right half: the instrument's side, mirrored by swap-hands. */
export function swapHands(rules: WheelRules, playerSwap: boolean) {
  return playerSwap !== rules.chordsOnRight;
}

export function chordNameSuffix(rules: WheelRules) {
  return rules.voicing === "seventh" ? "⁷" : "";
}

export function chordTones(rules: WheelRules, key: number, scale: readonly number[], degree: number): number[] {
  return rules.voicing === "triad" ? chordNotes(key, scale, degree) : chordNotesWithSeventh(key, scale, degree);
}

/** The notes the note half fans, bottom to top. An octave band adds ±12. */
export function noteLanes(rules: WheelRules, key: number, scale: readonly number[], chordDegree: number): number[] {
  if (rules.noteSource === "scale_one_octave") return scaleNotesOneOctave(key, scale);
  const triad = chordNotes(key, scale, chordDegree);
  return [0, 1, 2].flatMap((octave) => triad.map((note) => note + octave * 12)).sort((a, b) => a - b);
}

/** Lane indices that belong to the held chord, for tinting (empty when off). */
export function chordToneLanes(
  rules: WheelRules, key: number, scale: readonly number[], chordDegree: number, lanes: readonly number[],
): Set<number> {
  if (!rules.highlightChordTones) return new Set();
  const classes = new Set(chordTones(rules, key, scale, chordDegree).map((note) => mod(note, 12)));
  return new Set(lanes.flatMap((note, index) => (classes.has(mod(note, 12)) ? [index] : [])));
}

// MARK: - MusicTheory.swift

const mod = (value: number, base: number) => ((value % base) + base) % base;

/** Triad on a 0-based scale degree, root in octave 3 (MIDI 48 = C3). */
export function chordNotes(key: number, scale: readonly number[], degree: number): number[] {
  const count = scale.length;
  if (count === 0) return [60];
  const safe = mod(degree, count);
  const root = 48 + key + scale[safe];
  let third = 48 + key + scale[(safe + 2) % count];
  if (third <= root) third += 12;
  let fifth = 48 + key + scale[(safe + 4) % count];
  while (fifth <= third) fifth += 12;
  return [root, third, fifth];
}

/** Root, 3rd, 5th and 7th, all diatonic. */
export function chordNotesWithSeventh(key: number, scale: readonly number[], degree: number): number[] {
  const triad = chordNotes(key, scale, degree);
  const count = scale.length;
  if (count === 0) return triad;
  const fifth = triad[triad.length - 1];
  let seventh = 48 + key + scale[(mod(degree, count) + 6) % count];
  while (seventh <= fifth) seventh += 12;
  return [...triad, seventh];
}

/** One octave of scale notes starting at a MIDI octave (4 = middle C's). */
export function scaleNotesOneOctave(key: number, scale: readonly number[], octave = 4): number[] {
  const base = (octave + 1) * 12 + key;
  return scale.map((interval) => base + interval);
}

const NOTE_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"];

/** Note letter without the octave ("C", "Eb"). */
export function pitchClassName(midi: number) {
  return NOTE_NAMES[mod(midi, 12)];
}

/** Strudel note name, e.g. 60 → "c4". */
export function midiToStrudelNote(midi: number) {
  return `${NOTE_NAMES[mod(midi, 12)].toLowerCase()}${Math.floor(midi / 12) - 1}`;
}

/** Chord name as iOS labels the wheel ("Cmaj", "Am" → "Amin", "Bdim"). */
export function chordDisplayName(key: number, scale: readonly number[], degree: number) {
  const count = scale.length;
  if (!count) return "";
  const safe = mod(degree, count);
  const root = mod(key + scale[safe], 12);
  const third = mod(scale[(safe + 2) % count] - scale[safe], 12);
  const fifth = mod(scale[(safe + 4) % count] - scale[safe], 12);
  const quality = third === 4 && fifth === 7 ? "maj" : third === 3 && fifth === 7 ? "min"
    : third === 3 && fifth === 6 ? "dim" : third === 4 && fifth === 8 ? "aug" : "";
  return `${NOTE_NAMES[root]}${quality}`;
}
