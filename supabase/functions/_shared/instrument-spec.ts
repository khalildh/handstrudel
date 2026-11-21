/**
 * Instruments that travel with posts. The file (shared/instruments/) is opaque data the apps draw
 * with their own code; this mirrors what their loader (iOS `InstrumentSpec.load`) rejects so junk
 * never reaches the table. Values the loader only repairs (long names, out-of-range radii) pass,
 * because every loader repairs them. Newer format versions get the version-independent checks
 * only, so a newer app can post an instrument that older apps decline to open.
 */

export const instrumentByteLimit = 16 * 1024;
const maxFormatVersion = 99;
const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;

export type InstrumentIssue =
  | "too_large" | "malformed" | "unsupported_format" | "unsupported_version" | "id_invalid" | "name_missing";

const isObject = (v: unknown): v is Record<string, unknown> => !!v && typeof v === "object" && !Array.isArray(v);
const isNumber = (v: unknown) => typeof v === "number" && Number.isFinite(v);

/** Why the loader would reject this instrument, or null when it would load. */
export function instrumentIssue(spec: unknown): InstrumentIssue | null {
  if (!isObject(spec)) return "malformed";
  if (new TextEncoder().encode(JSON.stringify(spec)).length > instrumentByteLimit) return "too_large";
  if (spec.format !== "handstrudel.instrument") return "unsupported_format";
  const version = spec.format_version;
  if (!isNumber(version)) return "malformed";
  if (!Number.isInteger(version) || (version as number) < 1 || (version as number) > maxFormatVersion) {
    return "unsupported_version";
  }
  if (typeof spec.id !== "string" || typeof spec.name !== "string" ||
      (spec.description != null && typeof spec.description !== "string")) return "malformed";
  if (!/^[a-z0-9][a-z0-9._-]{0,79}$/.test(spec.id)) return "id_invalid";
  if (spec.name.trim() === "") return "name_missing";
  if (version !== 1) return null;

  // Format version 1: one split_wheel surface, a chord side and a note source.
  const { surface, chords, notes } = spec;
  const valid = isObject(surface) && surface.type === "split_wheel" &&
    isNumber(surface.radius) && isNumber(surface.rest_radius) && isNumber(surface.octave_band_radius) &&
    isObject(chords) && (chords.side === "left" || chords.side === "right") &&
    isObject(notes) && (notes.source === "scale_one_octave" || notes.source === "chord_tones_three_octaves") &&
    typeof notes.octave_band === "boolean" &&
    (notes.highlight_chord_tones == null || typeof notes.highlight_chord_tones === "boolean");
  return valid ? null : "malformed";
}

/** Generated instruments carry `"ai_generated": true` or `"generator": {"kind": "ai"}`. */
export function instrumentIsAIGenerated(spec: unknown): boolean {
  if (!isObject(spec)) return false;
  return spec.ai_generated === true || (isObject(spec.generator) && spec.generator.kind === "ai");
}

/**
 * The instrument fields of a post: the file, the post it came from (the database decides whether
 * that makes it a copy or a remix), "Allow remixes" and the AI flag. An invalid file is dropped,
 * like an invalid note track, so the take still posts.
 */
export function postedInstrument(input: Record<string, unknown>) {
  const spec = input.instrument_spec;
  if (spec == null || instrumentIssue(spec) !== null) {
    return { instrument_spec: null, instrument_source_id: null, instrument_remixes_allowed: true, instrument_ai_generated: false };
  }
  const source = input.instrument_source_id;
  return {
    instrument_spec: spec,
    instrument_source_id: typeof source === "string" && uuid.test(source) ? source.toLowerCase() : null,
    instrument_remixes_allowed: input.instrument_remixes_allowed !== false,
    instrument_ai_generated: input.instrument_ai_generated === true || instrumentIsAIGenerated(spec),
  };
}
