// HandStrudel instrument files (`shared/instruments/`), ported from
// `ios/HandStrudel/HandStrudel/Models/InstrumentSpec.swift`.
//
// An instrument is structure, not music: its zones are defined relative to the
// player's key, scale and progression, so it never picks a sound. Nothing in a
// file is executed; the site's own code draws and plays it. Every file goes
// through `loadInstrument`, which rejects anything outside the vocabulary and
// repairs values that are merely out of range, exactly like
// `InstrumentSpec.load` on iOS. `shared/instruments/fixtures/` pins the rules
// and `spec.test.mjs` runs every fixture against this file.
//
// Version 1 has one surface, the split wheel. New surfaces (format v2: grids,
// keys, pads, arcs, orbs) add a member to `InstrumentSurface` and a decoder in
// `decodeSurface`, and a renderer in `components/instruments/renderers.tsx`.

export const FORMAT_NAME = "handstrudel.instrument";
export const FORMAT_VERSION = 1;
export const NAME_LIMIT = 40;
export const DESCRIPTION_LIMIT = 200;
export const BYTE_LIMIT = 16 * 1024;

export const SPLIT_WHEEL_LIMITS = {
  radius: [0.7, 1.0],
  restRadius: [0.2, 0.5],
  octaveBandRadiusMin: 0.6,
  octaveBandRadiusMax: 0.92,
  /** The base band (rest hole to octave rim) must stay deep enough to land a hand in. */
  minimumBaseBand: 0.25,
} as const;

export type NoteSource = "scale_one_octave" | "chord_tones_three_octaves";
export type ChordSide = "left" | "right";

/** One circle cut into a chord half and a note half around a rest hole. */
export interface SplitWheelSurface {
  type: "split_wheel";
  /** Fraction of half the shorter side of the play area. */
  radius: number;
  /** Fractions of the wheel radius. */
  rest_radius: number;
  octave_band_radius: number;
}

/** Every surface this build can draw. Format v2 adds members here. */
export type InstrumentSurface = SplitWheelSurface;
export type SurfaceType = InstrumentSurface["type"];

export interface InstrumentSpec {
  format: typeof FORMAT_NAME;
  format_version: number;
  id: string;
  name: string;
  description?: string;
  surface: InstrumentSurface;
  chords: { side: ChordSide };
  notes: { source: NoteSource; octave_band: boolean; highlight_chord_tones?: boolean };
}

/** Raw values match the codes in `shared/instruments/fixtures/`. */
export type InstrumentIssue =
  // Rejections
  | "too_large"
  | "malformed"
  | "unsupported_format"
  | "unsupported_version"
  | "id_invalid"
  | "name_missing"
  // Repairs
  | "name_trimmed"
  | "description_trimmed"
  | "radius_clamped"
  | "rest_radius_clamped"
  | "octave_band_radius_clamped";

export interface InstrumentLoadResult {
  /** The playable instrument after repairs, or null when rejected. */
  spec: InstrumentSpec | null;
  /** The rejection reason, or the repairs made, in a fixed order. */
  issues: InstrumentIssue[];
  accepted: boolean;
}

const rejected = (issue: InstrumentIssue): InstrumentLoadResult => ({ spec: null, issues: [issue], accepted: false });

class Malformed extends Error {}

/**
 * Decode, check and repair an instrument file. Pure: the result depends only on
 * the bytes. Fields this version doesn't know are ignored.
 */
export function loadInstrument(input: string | Uint8Array | ArrayBuffer): InstrumentLoadResult {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input)
    : input instanceof Uint8Array ? input : new Uint8Array(input);
  if (bytes.byteLength > BYTE_LIMIT) return rejected("too_large");

  let json: unknown;
  try {
    json = parseJSON(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch {
    return rejected("malformed");
  }

  // Header first (Swift decodes `format` and `format_version` as optionals).
  if (!isObject(json)) return rejected("malformed");
  let format: string | null;
  let version: number | null;
  try {
    format = optional(json.format, decodeString);
    version = optional(json.format_version, decodeInt);
  } catch {
    return rejected("malformed");
  }
  if (format !== FORMAT_NAME) return rejected("unsupported_format");
  if (version !== FORMAT_VERSION) return rejected("unsupported_version");

  let spec: InstrumentSpec;
  try {
    spec = decodeSpec(json);
  } catch {
    return rejected("malformed");
  }
  return validateInstrument(spec);
}

/**
 * Load an instrument that arrived as a JSON value rather than bytes (for
 * example a post's `instrument_spec` jsonb column). Strings are treated as the
 * file's text. The size cap applies to the serialized form.
 */
export function loadInstrumentValue(value: unknown): InstrumentLoadResult {
  if (typeof value === "string") return loadInstrument(value);
  let text: string | undefined;
  try {
    text = JSON.stringify(value);
  } catch {
    return rejected("malformed");
  }
  return text === undefined ? rejected("malformed") : loadInstrument(text);
}

/** Check and repair an already-decoded instrument (`InstrumentSpec.validated()`). */
export function validateInstrument(input: InstrumentSpec): InstrumentLoadResult {
  if (!isValidID(input.id)) return rejected("id_invalid");
  const spec: InstrumentSpec = {
    ...input,
    surface: { ...input.surface },
    chords: { ...input.chords },
    notes: { ...input.notes },
  };
  const issues: InstrumentIssue[] = [];

  const name = trim(input.name, NAME_LIMIT);
  if (!name) return rejected("name_missing");
  if (name !== input.name) {
    spec.name = name;
    issues.push("name_trimmed");
  }
  if (input.description !== undefined) {
    const description = trim(input.description, DESCRIPTION_LIMIT);
    if (description !== input.description) {
      if (description) spec.description = description;
      else delete spec.description;
      issues.push("description_trimmed");
    }
  }

  const limits = SPLIT_WHEEL_LIMITS;
  const surface = input.surface;
  const radius = clamp(surface.radius, limits.radius[0], limits.radius[1]);
  if (radius !== surface.radius) {
    spec.surface.radius = radius;
    issues.push("radius_clamped");
  }
  const rest = clamp(surface.rest_radius, limits.restRadius[0], limits.restRadius[1]);
  if (rest !== surface.rest_radius) {
    spec.surface.rest_radius = rest;
    issues.push("rest_radius_clamped");
  }
  const bandMin = Math.max(limits.octaveBandRadiusMin, rounded(rest + limits.minimumBaseBand));
  const band = clamp(surface.octave_band_radius, bandMin, limits.octaveBandRadiusMax);
  if (band !== surface.octave_band_radius) {
    spec.surface.octave_band_radius = band;
    issues.push("octave_band_radius_clamped");
  }

  return { spec, issues, accepted: true };
}

export const isBuiltIn = (spec: InstrumentSpec) => spec.id.startsWith("builtin.");

// MARK: - Decoding (mirrors Swift's JSONDecoder for the Codable struct)

type JSONObject = Record<string, unknown>;

function isObject(value: unknown): value is JSONObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function required<T>(object: JSONObject, key: string, decode: (value: unknown) => T): T {
  const value = object[key];
  if (value === undefined || value === null) throw new Malformed(key);
  return decode(value);
}

/** Missing and null both decode to nil, like `decodeIfPresent`; other types throw. */
function optional<T>(value: unknown, decode: (value: unknown) => T): T | null {
  return value === undefined || value === null ? null : decode(value);
}

function decodeString(value: unknown): string {
  if (typeof value !== "string") throw new Malformed("string");
  return value;
}

function decodeInt(value: unknown): number {
  // Swift's Int decodes integral JSON numbers only.
  if (typeof value !== "number" || !Number.isSafeInteger(value)) throw new Malformed("int");
  return value;
}

function decodeDouble(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) throw new Malformed("double");
  return value;
}

function decodeBool(value: unknown): boolean {
  if (typeof value !== "boolean") throw new Malformed("bool");
  return value;
}

function decodeEnum<T extends string>(cases: readonly T[]) {
  return (value: unknown): T => {
    const text = decodeString(value);
    if (!(cases as readonly string[]).includes(text)) throw new Malformed("enum");
    return text as T;
  };
}

function decodeObject(value: unknown): JSONObject {
  if (!isObject(value)) throw new Malformed("object");
  return value;
}

function decodeSurface(value: unknown): InstrumentSurface {
  const surface = decodeObject(value);
  const type = required(surface, "type", decodeEnum(["split_wheel"] as const));
  return {
    type,
    radius: required(surface, "radius", decodeDouble),
    rest_radius: required(surface, "rest_radius", decodeDouble),
    octave_band_radius: required(surface, "octave_band_radius", decodeDouble),
  };
}

function decodeSpec(json: JSONObject): InstrumentSpec {
  const chords = required(json, "chords", decodeObject);
  const notes = required(json, "notes", decodeObject);
  const description = optional(json.description, decodeString);
  const highlight = optional(notes.highlight_chord_tones, decodeBool);
  const spec: InstrumentSpec = {
    format: required(json, "format", decodeString) as typeof FORMAT_NAME,
    format_version: required(json, "format_version", decodeInt),
    id: required(json, "id", decodeString),
    name: required(json, "name", decodeString),
    surface: required(json, "surface", decodeSurface),
    chords: { side: required(chords, "side", decodeEnum(["left", "right"] as const)) },
    notes: {
      source: required(notes, "source", decodeEnum(["scale_one_octave", "chord_tones_three_octaves"] as const)),
      octave_band: required(notes, "octave_band", decodeBool),
    },
  };
  if (description !== null) spec.description = description;
  if (highlight !== null) spec.notes.highlight_chord_tones = highlight;
  return spec;
}

// MARK: - JSON

/**
 * `JSON.parse`, except that a repeated object key keeps its first value, as
 * Swift's JSONDecoder does (`JSON.parse` keeps the last). Without this a file
 * with two `name`s would show different names on iOS and the web.
 */
export function parseJSON(text: string): unknown {
  let at = 0;
  const fail = (): never => { throw new SyntaxError(`Invalid JSON at ${at}`); };
  const space = () => { while (at < text.length && " \t\n\r".includes(text[at])) at++; };
  const literal = (word: string, value: unknown) => {
    if (text.startsWith(word, at)) { at += word.length; return value; }
    return fail();
  };
  const string = (): string => {
    const start = at;
    at++;
    while (at < text.length && text[at] !== "\"") at += text[at] === "\\" ? 2 : 1;
    if (at >= text.length) fail();
    at++;
    return JSON.parse(text.slice(start, at)) as string;
  };
  const number = (): number => {
    const match = /^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/.exec(text.slice(at, at + 400));
    if (!match) return fail();
    at += match[0].length;
    return Number(match[0]);
  };
  const value = (depth: number): unknown => {
    if (depth > 512) fail();
    space();
    const c = text[at];
    if (c === "{") {
      at++;
      const object: Record<string, unknown> = Object.create(null);
      space();
      if (text[at] === "}") { at++; return { ...object }; }
      for (;;) {
        space();
        if (text[at] !== "\"") fail();
        const key = string();
        space();
        if (text[at++] !== ":") fail();
        const item = value(depth + 1);
        if (!Object.prototype.hasOwnProperty.call(object, key)) object[key] = item;
        space();
        if (text[at] === ",") { at++; continue; }
        if (text[at] === "}") { at++; return { ...object }; }
        fail();
      }
    }
    if (c === "[") {
      at++;
      const array: unknown[] = [];
      space();
      if (text[at] === "]") { at++; return array; }
      for (;;) {
        array.push(value(depth + 1));
        space();
        if (text[at] === ",") { at++; continue; }
        if (text[at] === "]") { at++; return array; }
        fail();
      }
    }
    if (c === "\"") return string();
    if (c === "t") return literal("true", true);
    if (c === "f") return literal("false", false);
    if (c === "n") return literal("null", null);
    return number();
  };
  const result = value(0);
  space();
  if (at !== text.length) fail();
  return result;
}

// MARK: - Helpers

const ID_PATTERN = /^[a-z0-9][a-z0-9._-]{0,79}$/;

function isValidID(id: string) {
  return ID_PATTERN.test(id);
}

// Foundation's `.whitespacesAndNewlines`, enumerated from Swift: the Unicode
// White_Space property plus U+200B ZERO WIDTH SPACE. (`String.trim()` differs:
// it strips U+FEFF and keeps U+0085 and U+200B.)
const EDGE_SPACE = /^[\p{White_Space}​]+|[\p{White_Space}​]+$/gu;

const graphemes: Intl.Segmenter | null =
  typeof Intl !== "undefined" && "Segmenter" in Intl ? new Intl.Segmenter("en", { granularity: "grapheme" }) : null;

/** Swift `prefix(_:)` counts Characters (grapheme clusters), not UTF-16 units. */
function prefixCharacters(text: string, limit: number) {
  const characters = graphemes ? Array.from(graphemes.segment(text), (part) => part.segment) : Array.from(text);
  return characters.length <= limit ? text : characters.slice(0, limit).join("");
}

/** Trim whitespace, cut to `limit` characters, then trim again. */
function trim(text: string, limit: number) {
  return prefixCharacters(text.replace(EDGE_SPACE, ""), limit).replace(EDGE_SPACE, "");
}

function clamp(value: number, lower: number, upper: number) {
  return Math.min(upper, Math.max(lower, value));
}

/** Keep sums like 0.5 + 0.25 exact so repaired files round-trip cleanly. */
function rounded(value: number) {
  // Swift's `.rounded()` rounds halves away from zero; inputs here are positive.
  return Math.round(value * 1_000_000) / 1_000_000;
}
