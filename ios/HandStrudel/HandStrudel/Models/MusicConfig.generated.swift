// AUTO-GENERATED from shared/music-config.json by scripts/gen-music-config.mjs.
// Do not edit by hand — run `npm run gen:config` (from the repo root).

import Foundation

let NOTES: [String] = ["c2", "d2", "e2", "g2", "a2", "c3", "d3", "e3", "g3", "a3", "c4", "d4", "e4", "g4", "a4", "c5", "d5", "e5"]

let MIDI_NOTES: [Int] = [36, 38, 40, 43, 45, 48, 50, 52, 55, 57, 60, 62, 64, 67, 69, 72, 74, 76]

let STRUCTS: [String] = ["x ~ x ~ x ~ x ~", "x ~ ~ x ~ ~ x ~", "x x ~ x ~ x x ~", "[x x x] ~ ~ ~", "x ~ x x ~ x ~ ~"]

/// Numeric spec for a music parameter. The `format` field names a formatter
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
    ParamSpec(id: "noteIdx", label: "pitch", strudelKey: "note", min: 0, max: 17, defaultValue: 10, format: "note"),
    ParamSpec(id: "gain", label: "volume", strudelKey: "gain", min: 0.03, max: 0.9, defaultValue: 0.55, format: "fixed2"),
    ParamSpec(id: "lpf", label: "filter", strudelKey: "lpf", min: 120, max: 6120, defaultValue: 3000, format: "hz"),
    ParamSpec(id: "hpf", label: "hi-pass", strudelKey: "hpf", min: 20, max: 4000, defaultValue: 2000, format: "hz"),
    ParamSpec(id: "reverb", label: "reverb", strudelKey: "room", min: 0, max: 0.9, defaultValue: 0.2, format: "fixed2"),
    ParamSpec(id: "bpm", label: "tempo", strudelKey: "cpm", min: 50, max: 205, defaultValue: 120, format: "bpm"),
    ParamSpec(id: "delay", label: "delay", strudelKey: "delay", min: 0, max: 0.55, defaultValue: 0.12, format: "fixed2"),
    ParamSpec(id: "pan", label: "pan", strudelKey: "pan", min: 0, max: 1, defaultValue: 0.5, format: "fixed2"),
    ParamSpec(id: "crush", label: "crush", strudelKey: "crush", min: 1, max: 16, defaultValue: 8, format: "int"),
    ParamSpec(id: "shape", label: "shape", strudelKey: "shape", min: 0, max: 0.9, defaultValue: 0, format: "fixed2"),
    ParamSpec(id: "attack", label: "attack", strudelKey: "attack", min: 0.001, max: 0.5, defaultValue: 0.01, format: "fixed3"),
    ParamSpec(id: "release", label: "release", strudelKey: "release", min: 0.01, max: 1, defaultValue: 0.1, format: "fixed2"),
]
