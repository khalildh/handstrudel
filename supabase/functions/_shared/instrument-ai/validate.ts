// Checks a generated instrument before anyone plays it. The app's loader
// (InstrumentSpec.load) still runs on the device; this is the stricter
// generator-side gate: the schema exactly, playability, no music, clean text.
import { checkSchema, type Schema } from "./json-schema.ts";
import { moderateInstrumentText } from "./moderation.ts";

export const BYTE_LIMIT = 16 * 1024;

export type IssueKind = "schema" | "playability" | "music" | "moderation" | "size";
export type Issue = { kind: IssueKind; message: string };

/**
 * Cross-field rules the JSON Schema can't express, keyed by surface `type`.
 * They mirror the loader's repairs (shared/instruments/README.md): a generator
 * must produce values the loader would accept without repairing.
 * A surface type without rules here is checked by the schema alone, so a new
 * format version works before rules are added for it.
 */
export const PLAYABILITY_RULES: Record<string, (instrument: Record<string, any>) => string[]> = {
  split_wheel(instrument) {
    const s = instrument.surface ?? {};
    const errors: string[] = [];
    if (typeof s.rest_radius === "number" && typeof s.octave_band_radius === "number"
        && s.octave_band_radius < Math.round((s.rest_radius + 0.25) * 1e6) / 1e6) {
      errors.push(`surface.octave_band_radius (${s.octave_band_radius}) must be at least rest_radius + 0.25 (${(s.rest_radius + 0.25).toFixed(2)}) so the base band stays playable`);
    }
    return errors;
  },
};

/** Field names that would carry music settings. Flagged wherever they appear
 *  unless the schema itself defines a field with that name. */
export const MUSIC_FIELD_NAMES = [
  "key", "scale", "mode_name", "tonic", "root_note", "tempo", "bpm", "sound", "soundfont", "program",
  "instrument_sound", "waveform", "voicing", "chord_voicing", "progression", "chords_list", "midi", "midi_note",
  "pitch", "pitches", "note_names", "octave_offset", "transpose", "tuning", "volume", "gain", "swing",
];

const KEY_PATTERN = /\b([A-Ga-g])(?:#|♯|♭|b)?(?:\s?(?:sharp|flat))?\s?(?:major|minor|maj|min|dorian|lydian|mixolydian|phrygian|locrian|aeolian|ionian)\b/gi;

/** "D minor", "Eb Major", "F# dorian" — the note letter must be a capital so
 *  "a major upgrade" isn't flagged. */
function namesKey(text: string) {
  return [...text.matchAll(KEY_PATTERN)].some((m) => /[A-G]/.test(m[1]));
}
const SCALE_WORDS = /\b(?:dorian|lydian|mixolydian|phrygian|locrian|aeolian|ionian|pentatonic|hirajoshi|harmonic minor|melodic minor|whole[- ]tone|chromatic scale|blues scale)\b/i;
const TEMPO_PATTERN = /\b\d{2,3}\s?bpm\b|\btempo\b|\bbeats per minute\b/i;

/** Words that name a sound. Not a hard failure (an instrument can be "harp
 *  shaped"), but evals report them as soft music leaks. */
export const SOUND_WORDS = [
  "piano", "guitar", "violin", "viola", "cello", "flute", "saxophone", "sax", "trumpet", "trombone", "clarinet",
  "oboe", "organ", "accordion", "marimba", "xylophone", "vibraphone", "ukulele", "banjo", "sitar", "harpsichord",
  "choir", "808", "synth",
];

function schemaFieldNames(schema: Schema): Set<string> {
  const names = new Set<string>();
  const walk = (node: unknown) => {
    if (Array.isArray(node)) return node.forEach(walk);
    if (!node || typeof node !== "object") return;
    for (const [key, child] of Object.entries(node as Record<string, unknown>)) {
      if (key === "properties" && child && typeof child === "object") {
        for (const name of Object.keys(child as object)) names.add(name);
      }
      walk(child);
    }
  };
  walk(schema);
  return names;
}

export function musicLeaks(instrument: unknown, schema: Schema): string[] {
  const allowed = schemaFieldNames(schema);
  const errors: string[] = [];
  const walk = (node: unknown, path: string) => {
    if (Array.isArray(node)) return node.forEach((child, i) => walk(child, `${path}[${i}]`));
    if (!node || typeof node !== "object") return;
    for (const [key, child] of Object.entries(node as Record<string, unknown>)) {
      if (MUSIC_FIELD_NAMES.includes(key.toLowerCase()) && !allowed.has(key)) {
        errors.push(`${path}.${key}: music settings (key, scale, tempo, sound, voicing) are the player's; remove this field`);
      }
      walk(child, `${path}.${key}`);
    }
  };
  walk(instrument, "$");
  const object = (instrument ?? {}) as Record<string, unknown>;
  for (const field of ["name", "description"]) {
    const text = object[field];
    if (typeof text !== "string") continue;
    if (namesKey(text) || SCALE_WORDS.test(text)) {
      errors.push(`${field}: names a key or scale; instruments adapt to the player's key and scale, so describe the layout and look instead`);
    }
    if (TEMPO_PATTERN.test(text)) errors.push(`${field}: mentions tempo; tempo is the player's setting`);
  }
  return errors;
}

export function soundWordsIn(instrument: Record<string, unknown>): string[] {
  const text = `${instrument.name ?? ""} ${instrument.description ?? ""}`.toLowerCase();
  return SOUND_WORDS.filter((word) => new RegExp(`\\b${word}\\b`).test(text));
}

export function validateInstrument(candidate: unknown, schema: Schema): Issue[] {
  const issues: Issue[] = [];
  const add = (kind: IssueKind, messages: string[]) => messages.forEach((message) => issues.push({ kind, message }));
  const bytes = new TextEncoder().encode(JSON.stringify(candidate ?? null)).length;
  if (bytes > BYTE_LIMIT) add("size", [`instrument is ${bytes} bytes; the limit is ${BYTE_LIMIT}`]);
  const schemaErrors = checkSchema(candidate, schema);
  add("schema", schemaErrors);
  if (!candidate || typeof candidate !== "object" || Array.isArray(candidate)) return issues;
  const instrument = candidate as Record<string, any>;
  // The loader trims text and rejects an empty name; a generator must not need either.
  for (const field of ["name", "description"]) {
    const text = instrument[field];
    if (typeof text === "string" && (text.trim() !== text || (field === "name" && !text.trim()))) {
      add("schema", [`${field}: must not be blank or start or end with spaces`]);
    }
  }
  if (schemaErrors.length === 0) {
    const rules = PLAYABILITY_RULES[instrument.surface?.type];
    if (rules) add("playability", rules(instrument));
  }
  add("music", musicLeaks(instrument, schema));
  add("moderation", moderateInstrumentText({ name: instrument.name, description: instrument.description }));
  return issues;
}
