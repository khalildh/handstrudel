#!/usr/bin/env node
// Generates per-platform data files from the canonical shared/music-config.json.
//
//   shared/music-config.json   (edit this)
//        │
//        ├─► src/lib/music-data.generated.ts                       (web)
//        └─► ios/HandStrudel/HandStrudel/Models/MusicConfig.generated.swift  (iOS)
//
// The generated files contain ONLY data (notes, structs, parameter specs). The
// format()/toCode() closures stay in each platform's hand-written code, keyed by
// the spec's `format` name. Run via `npm run gen:config`; CI runs
// `npm run verify:config` to fail if the generated files drift from the JSON.

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const config = JSON.parse(readFileSync(join(root, "shared/music-config.json"), "utf8"));

const { notes, midiNotes, structs } = config;

// noteIdx's range is always "every note index", so derive its max from the notes
// array rather than trusting a hand-maintained number in the JSON.
const params = config.params.map((p) =>
  p.id === "noteIdx" ? { ...p, max: notes.length - 1 } : p,
);

const BANNER_TS = `// AUTO-GENERATED from shared/music-config.json by scripts/gen-music-config.mjs.
// Do not edit by hand — run \`npm run gen:config\`.\n`;

const tsArray = (arr) => "[" + arr.map((v) => JSON.stringify(v)).join(", ") + "]";

const ts = `${BANNER_TS}
export const NOTES: string[] = ${tsArray(notes)};

export const MIDI_NOTES: number[] = ${tsArray(midiNotes)};

export const STRUCTS: string[] = ${tsArray(structs)};

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
