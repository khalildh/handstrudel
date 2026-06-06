// AUTO-GENERATED from shared/music-config.json by scripts/gen-music-config.mjs.
// Do not edit by hand — run `npm run gen:config`.

export const NOTES: string[] = ["c2", "d2", "e2", "g2", "a2", "c3", "d3", "e3", "g3", "a3", "c4", "d4", "e4", "g4", "a4", "c5", "d5", "e5"];

export const MIDI_NOTES: number[] = [36, 38, 40, 43, 45, 48, 50, 52, 55, 57, 60, 62, 64, 67, 69, 72, 74, 76];

export const STRUCTS: string[] = ["x ~ x ~ x ~ x ~", "x ~ ~ x ~ ~ x ~", "x x ~ x ~ x x ~", "[x x x] ~ ~ ~", "x ~ x x ~ x ~ ~"];

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
  { id: "noteIdx", label: "pitch", strudelKey: "note", min: 0, max: 17, default: 10, format: "note", hlClass: "c-str" },
  { id: "gain", label: "volume", strudelKey: "gain", min: 0.03, max: 0.9, default: 0.55, format: "fixed2", hlClass: "c-nr" },
  { id: "lpf", label: "filter", strudelKey: "lpf", min: 120, max: 6120, default: 3000, format: "hz", hlClass: "c-nl" },
  { id: "hpf", label: "hi-pass", strudelKey: "hpf", min: 20, max: 4000, default: 2000, format: "hz", hlClass: "c-nl" },
  { id: "reverb", label: "reverb", strudelKey: "room", min: 0, max: 0.9, default: 0.2, format: "fixed2", hlClass: "c-nl" },
  { id: "bpm", label: "tempo", strudelKey: "cpm", min: 50, max: 205, default: 120, format: "bpm", hlClass: "c-nr" },
  { id: "delay", label: "delay", strudelKey: "delay", min: 0, max: 0.55, default: 0.12, format: "fixed2", hlClass: "c-nr" },
  { id: "pan", label: "pan", strudelKey: "pan", min: 0, max: 1, default: 0.5, format: "fixed2", hlClass: "c-nr" },
  { id: "crush", label: "crush", strudelKey: "crush", min: 1, max: 16, default: 8, format: "int", hlClass: "c-nl" },
  { id: "shape", label: "shape", strudelKey: "shape", min: 0, max: 0.9, default: 0, format: "fixed2", hlClass: "c-nr" },
  { id: "attack", label: "attack", strudelKey: "attack", min: 0.001, max: 0.5, default: 0.01, format: "fixed3", hlClass: "c-nr" },
  { id: "release", label: "release", strudelKey: "release", min: 0.01, max: 1, default: 0.1, format: "fixed2", hlClass: "c-nr" },
];
