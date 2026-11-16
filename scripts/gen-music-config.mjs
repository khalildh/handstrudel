#!/usr/bin/env node
// Generates per-platform data files from the canonical shared/music-config.json.
//
//   shared/music-config.json   (edit this)
//        │
//        ├─► src/lib/music-data.generated.ts                       (web)
//        └─► ios/HandStrudel/HandStrudel/Models/MusicConfig.generated.swift  (iOS)
//
// The generated files contain ONLY data (notes, structs, parameter specs, and
// the web copy of the iOS chord catalog and music theory tables). The
// format()/toCode() closures stay in each platform's hand-written code, keyed by
// the spec's `format` name. Run via `npm run gen:config`; CI runs
// `npm run verify:config` to fail if the generated files drift from their sources.

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const config = JSON.parse(readFileSync(join(root, "shared/music-config.json"), "utf8"));

const { notes, midiNotes, structs } = config;
const chordSource = readFileSync(join(root, "ios/HandStrudel/HandStrudel/Models/ChordProgression.swift"), "utf8");
const chordCatalog = chordSource.split("let CHORD_PROGRESSIONS: [ChordProgression] = [")[1];
const chordProgressions = Array.from(chordCatalog.matchAll(/\.init\(id: "([^"]+)", name: "([^"]+)", emoji: "[^"]*", degrees: \[([^\]]+)\]/g),
  ([, id, name, degrees]) => ({ id, name, degrees: degrees.split(",").map(Number) }));
if (chordProgressions.length !== (chordCatalog.match(/\.init\(/g)?.length ?? 0) || !chordProgressions.length ||
    chordProgressions.some(({ degrees }) => degrees.some(d => !Number.isInteger(d) || d < 0 || d > 6))) {
  throw new Error("Couldn't read the full Swift chord progression catalog");
}

const theorySource = readFileSync(join(root, "ios/HandStrudel/HandStrudel/Models/MusicTheory.swift"), "utf8");
const swiftEnum = (name) => theorySource.match(new RegExp(`^enum ${name}:[^{]+\\{([\\s\\S]*?)^\\}`, "m"))?.[1] ?? "";
const keySource = swiftEnum("MusicKey");
const scaleSource = swiftEnum("BuiltInScale");
const keyCases = Array.from(keySource.matchAll(/^    case ([^\r\n]+)$/gm), ([, list]) => list.split(/,\s*/)).flat();
const keySemitones = new Map(Array.from(keySource.matchAll(/^ +case \.(\w+): +return (\d+)$/gm),
  ([, key, semitone]) => [key, Number(semitone)]));
const scaleNames = new Map(Array.from(scaleSource.matchAll(/^    case (\w+) = ("[^"]+")$/gm),
  ([, id, name]) => [id, JSON.parse(name)]));
const intervals = new Map(Array.from(scaleSource.matchAll(/^ +case \.(\w+): +return (\[[^\r\n]+\])$/gm),
  ([, id, list]) => [id, JSON.parse(list)]));
const noteNames = JSON.parse(theorySource.match(/^private let NOTE_NAMES = (\[[^\r\n]+\])$/m)?.[1] ?? "null");
if (!Array.isArray(noteNames) || noteNames.length !== 12 || noteNames.some(name => typeof name !== "string" || !name)
    || keyCases.length !== 12 || new Set(keyCases).size !== 12 || keySemitones.size !== 12
    || new Set(keySemitones.values()).size !== 12 || keyCases.some(key => !keySemitones.has(key) || keySemitones.get(key) >= 12)
    || !scaleNames.size || scaleNames.size !== (scaleSource.match(/^    case /gm)?.length ?? 0)
    || scaleNames.size !== intervals.size || new Set(scaleNames.values()).size !== scaleNames.size
    || [...scaleNames.keys()].some(id => {
      const scale = intervals.get(id);
      return !Array.isArray(scale) || scale[0] !== 0 ||
        scale.some((n, i) => !Number.isInteger(n) || n >= 12 || (i > 0 && n <= scale[i - 1]));
    })) {
  throw new Error("Couldn't read the full Swift key, scale, and note name tables");
}

// noteIdx's range is always "every note index", so derive its max from the notes
// array rather than trusting a hand-maintained number in the JSON.
const params = config.params.map((p) =>
  p.id === "noteIdx" ? { ...p, max: notes.length - 1 } : p,
);

const BANNER_TS = `// AUTO-GENERATED from shared/music-config.json and iOS music sources by scripts/gen-music-config.mjs.
// Do not edit by hand — run \`npm run gen:config\`.\n`;

const tsArray = (arr) => "[" + arr.map((v) => JSON.stringify(v)).join(", ") + "]";

const ts = `${BANNER_TS}
export const NOTES: string[] = ${tsArray(notes)};

export const MIDI_NOTES: number[] = ${tsArray(midiNotes)};

export const STRUCTS: string[] = ${tsArray(structs)};

// Chord presets come from the iOS catalog in ChordProgression.swift.
export const CHORD_PROGRESSIONS = new Map<string, { name: string; degrees: number[] }>([
${chordProgressions.map(({ id, name, degrees }) =>
  `  [${JSON.stringify(id)}, { name: ${JSON.stringify(name)}, degrees: ${tsArray(degrees)} }],`).join("\n")}
]);

// Codable keys and scales, and iOS pitch-class spellings from MusicTheory.swift.
export const IOS_NOTE_NAMES = ${tsArray(noteNames)};
export const IOS_KEY_SEMITONES = new Map<string, number>([
${keyCases.map(key => `  [${JSON.stringify(key)}, ${keySemitones.get(key)}],`).join("\n")}
]);
export const IOS_SCALE_INTERVALS = new Map<string, number[]>([
${Array.from(scaleNames, ([id, name]) => `  [${JSON.stringify(name)}, ${tsArray(intervals.get(id))}],`).join("\n")}
]);

export interface ParamSpec {
  id: string;
  label: string;
  strudelKey: string;
  min: number;
  max: number;
  default: number;
  /** Formatter kind — resolved to format()/toCode() in music.ts. */
  format: string;
  hlClass: string;
}

export const PARAM_SPECS: ParamSpec[] = [
${params
  .map(
    (p) =>
      `  { id: ${JSON.stringify(p.id)}, label: ${JSON.stringify(p.label)}, strudelKey: ${JSON.stringify(p.strudelKey)}, min: ${p.min}, max: ${p.max}, default: ${p.default}, format: ${JSON.stringify(p.format)}, hlClass: ${JSON.stringify(p.hlClass)} },`,
  )
  .join("\n")}
];
`;

const swiftArray = (arr) =>
  "[" + arr.map((v) => (typeof v === "string" ? JSON.stringify(v) : v)).join(", ") + "]";

const swift = `// AUTO-GENERATED from shared/music-config.json by scripts/gen-music-config.mjs.
// Do not edit by hand — run \`npm run gen:config\` (from the repo root).

import Foundation

let NOTES: [String] = ${swiftArray(notes)}

let MIDI_NOTES: [Int] = ${swiftArray(midiNotes)}

let STRUCTS: [String] = ${swiftArray(structs)}

/// Numeric spec for a music parameter. The \`format\` field names a formatter
/// kind whose closures are attached in ParamDefs.swift.
struct ParamSpec {
    let id: String
    let label: String
    let strudelKey: String
    let min: Double
    let max: Double
    let defaultValue: Double
    let format: String
}

let PARAM_SPECS: [ParamSpec] = [
${params
  .map(
    (p) =>
      `    ParamSpec(id: ${JSON.stringify(p.id)}, label: ${JSON.stringify(p.label)}, strudelKey: ${JSON.stringify(p.strudelKey)}, min: ${p.min}, max: ${p.max}, defaultValue: ${p.default}, format: ${JSON.stringify(p.format)}),`,
  )
  .join("\n")}
]
`;

writeFileSync(join(root, "src/lib/music-data.generated.ts"), ts);
writeFileSync(
  join(root, "ios/HandStrudel/HandStrudel/Models/MusicConfig.generated.swift"),
  swift,
);

console.log("Generated src/lib/music-data.generated.ts");
console.log("Generated ios/HandStrudel/HandStrudel/Models/MusicConfig.generated.swift");
