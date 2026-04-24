import Foundation

struct ParamDef: Identifiable {
    let id: String
    let label: String
    let strudelKey: String
    let min: Double
    let max: Double
    let defaultValue: Double
    let format: (Double) -> String
    let toCode: (Double) -> String
}

let NOTES = [
    "c2", "d2", "e2", "g2", "a2",
    "c3", "d3", "e3", "g3", "a3",
    "c4", "d4", "e4", "g4", "a4",
    "c5", "d5", "e5",
]

let MIDI_NOTES = [
    36, 38, 40, 43, 45,
    48, 50, 52, 55, 57,
    60, 62, 64, 67, 69,
    72, 74, 76,
]

let NOTE_DISPLAY = NOTES.map { n in
    n.prefix(1).uppercased() + n.dropFirst()
}

let STRUCTS = [
    "x ~ x ~ x ~ x ~",
    "x ~ ~ x ~ ~ x ~",
    "x x ~ x ~ x x ~",
    "[x x x] ~ ~ ~",
    "x ~ x x ~ x ~ ~",
]

let PARAM_DEFS: [ParamDef] = [
    ParamDef(
        id: "noteIdx", label: "pitch", strudelKey: "note",
        min: 0, max: Double(NOTES.count - 1), defaultValue: 10,
        format: { v in NOTE_DISPLAY[max(0, min(NOTES.count - 1, Int(v.rounded())))] },
        toCode: { v in "\"\(NOTES[max(0, min(NOTES.count - 1, Int(v.rounded())))])\"" }
    ),
    ParamDef(
        id: "gain", label: "volume", strudelKey: "gain",
        min: 0.03, max: 0.9, defaultValue: 0.55,
        format: { String(format: "%.2f", $0) },
        toCode: { String(format: "%.2f", $0) }
    ),
    ParamDef(
        id: "lpf", label: "filter", strudelKey: "lpf",
        min: 120, max: 6120, defaultValue: 3000,
        format: { "\(Int($0.rounded()))hz" },
        toCode: { "\(Int($0.rounded()))" }
    ),
    ParamDef(
        id: "hpf", label: "hi-pass", strudelKey: "hpf",
        min: 20, max: 4000, defaultValue: 2000,
        format: { "\(Int($0.rounded()))hz" },
        toCode: { "\(Int($0.rounded()))" }
    ),
    ParamDef(
        id: "reverb", label: "reverb", strudelKey: "room",
        min: 0, max: 0.9, defaultValue: 0.2,
        format: { String(format: "%.2f", $0) },
        toCode: { String(format: "%.2f", $0) }
    ),
    ParamDef(
        id: "bpm", label: "tempo", strudelKey: "cpm",
        min: 50, max: 205, defaultValue: 120,
        format: { "\(Int($0.rounded())) bpm" },
        toCode: { String(format: "%.1f", $0 / 4) }
    ),
    ParamDef(
        id: "delay", label: "delay", strudelKey: "delay",
        min: 0, max: 0.55, defaultValue: 0.12,
        format: { String(format: "%.2f", $0) },
        toCode: { String(format: "%.2f", $0) }
    ),
    ParamDef(
        id: "pan", label: "pan", strudelKey: "pan",
        min: 0, max: 1, defaultValue: 0.5,
        format: { String(format: "%.2f", $0) },
        toCode: { String(format: "%.2f", $0) }
    ),
    ParamDef(
        id: "crush", label: "crush", strudelKey: "crush",
        min: 1, max: 16, defaultValue: 8,
        format: { "\(Int($0.rounded()))" },
        toCode: { "\(Int($0.rounded()))" }
    ),
    ParamDef(
        id: "shape", label: "shape", strudelKey: "shape",
        min: 0, max: 0.9, defaultValue: 0,
        format: { String(format: "%.2f", $0) },
        toCode: { String(format: "%.2f", $0) }
    ),
    ParamDef(
        id: "attack", label: "attack", strudelKey: "attack",
        min: 0.001, max: 0.5, defaultValue: 0.01,
        format: { String(format: "%.3f", $0) },
        toCode: { String(format: "%.3f", $0) }
    ),
    ParamDef(
        id: "release", label: "release", strudelKey: "release",
        min: 0.01, max: 1.0, defaultValue: 0.1,
        format: { String(format: "%.2f", $0) },
        toCode: { String(format: "%.2f", $0) }
    ),
]

let HYDRA_PARAM_DEFS: [ParamDef] = [
    ParamDef(id: "hFreq", label: "osc freq", strudelKey: "", min: 2, max: 60, defaultValue: 10,
             format: { String(format: "%.1f", $0) }, toCode: { String(format: "%.1f", $0) }),
    ParamDef(id: "hSync", label: "osc sync", strudelKey: "", min: 0, max: 1, defaultValue: 0.1,
             format: { String(format: "%.2f", $0) }, toCode: { String(format: "%.2f", $0) }),
    ParamDef(id: "hKaleid", label: "kaleid", strudelKey: "", min: 1, max: 12, defaultValue: 3,
             format: { "\(Int($0.rounded()))" }, toCode: { "\(Int($0.rounded()))" }),
    ParamDef(id: "hRotate", label: "rotate", strudelKey: "", min: 0, max: 3.14, defaultValue: 0,
             format: { String(format: "%.2f", $0) }, toCode: { String(format: "%.2f", $0) }),
    ParamDef(id: "hColorama", label: "colorama", strudelKey: "", min: 0, max: 0.5, defaultValue: 0.05,
             format: { String(format: "%.3f", $0) }, toCode: { String(format: "%.3f", $0) }),
    ParamDef(id: "hBright", label: "bright", strudelKey: "", min: 0, max: 2, defaultValue: 1,
             format: { String(format: "%.2f", $0) }, toCode: { String(format: "%.2f", $0) }),
    ParamDef(id: "hPixel", label: "pixelate", strudelKey: "", min: 2, max: 200, defaultValue: 200,
             format: { "\(Int($0.rounded()))" }, toCode: { "\(Int($0.rounded()))" }),
    ParamDef(id: "hModulate", label: "modulate", strudelKey: "", min: 0, max: 0.15, defaultValue: 0.02,
             format: { String(format: "%.3f", $0) }, toCode: { String(format: "%.3f", $0) }),
    ParamDef(id: "hScale", label: "scale", strudelKey: "", min: 0.5, max: 3, defaultValue: 1,
             format: { String(format: "%.2f", $0) }, toCode: { String(format: "%.2f", $0) }),
    ParamDef(id: "hSaturate", label: "saturate", strudelKey: "", min: 0, max: 4, defaultValue: 1,
             format: { String(format: "%.2f", $0) }, toCode: { String(format: "%.2f", $0) }),
]

let HYDRA_IDS: Set<String> = Set(HYDRA_PARAM_DEFS.map(\.id))

let ALL_PARAM_DEFS: [ParamDef] = PARAM_DEFS + HYDRA_PARAM_DEFS

let PARAM_MAP: [String: ParamDef] = Dictionary(uniqueKeysWithValues: ALL_PARAM_DEFS.map { ($0.id, $0) })

typealias MusicParams = [String: Double]

func buildDefaultParams(_ config: MappingConfig) -> MusicParams {
    var params = MusicParams()
    var ids = Set<String>()
    for v in config.left.values { ids.insert(v) }
    for v in config.right.values { ids.insert(v) }
    for id in ids {
        if let def = PARAM_MAP[id] {
            params[id] = def.defaultValue
        }
    }
    return params
}

func extraParamIds(_ config: MappingConfig) -> [String] {
    var ids = Set<String>()
    for v in config.left.values { ids.insert(v) }
    for v in config.right.values { ids.insert(v) }
    ids.remove("noteIdx")
    ids.remove("bpm")
    ids.remove("none")
    ids.remove("save")
    for hid in HYDRA_IDS { ids.remove(hid) }
    return Array(ids).sorted()
}

func buildCode(_ p: MusicParams, structIdx: Int, config: MappingConfig) -> String {
    let ni = max(0, min(NOTES.count - 1, Int((p["noteIdx"] ?? 10).rounded())))
    let note = NOTES[ni]
    let cpm = String(format: "%.1f", (p["bpm"] ?? 120) / 4)
    let st = STRUCTS[structIdx]

    var code = "note(\"\(note)\").s(\"sawtooth\").struct(\"\(st)\").cpm(\(cpm))"

    for id in extraParamIds(config) {
        guard let def = PARAM_MAP[id] else { continue }
        code += ".\(def.strudelKey)(\(def.toCode(p[id] ?? def.defaultValue)))"
    }

    return code
}

func buildSignalCode(structIdx: Int, config: MappingConfig) -> String {
    let st = STRUCTS[structIdx]

    var code = "note(signal(() => __hp._midi)).s(\"sawtooth\").struct(\"\(st)\").cpm(signal(() => __hp._cpm))"

    for id in extraParamIds(config) {
        guard let def = PARAM_MAP[id] else { continue }
        code += ".\(def.strudelKey)(signal(() => __hp.\(id)))"
    }

    return code
}

func buildHydraCode(_ p: MusicParams) -> String {
    let freq = p["hFreq"] ?? 10
    let sync = p["hSync"] ?? 0.1
    let kaleid = Int((p["hKaleid"] ?? 3).rounded())
    let rot = p["hRotate"] ?? 0
    let colorama = p["hColorama"] ?? 0.05
    let bright = p["hBright"] ?? 1
    let pixel = Int((p["hPixel"] ?? 200).rounded())
    let mod = p["hModulate"] ?? 0.02
    let scale = p["hScale"] ?? 1
    let sat = p["hSaturate"] ?? 1

    var code = "osc(\(String(format: "%.1f", freq)),\(String(format: "%.2f", sync)),1.5)"
    if kaleid > 1 { code += ".kaleid(\(kaleid))" }
    if rot > 0.01 { code += ".rotate(\(String(format: "%.3f", rot)))" }
    if scale != 1 { code += ".scale(\(String(format: "%.2f", scale)))" }
    if pixel < 190 { code += ".pixelate(\(pixel),\(pixel))" }
    code += ".color(1,1,1)"
    if bright != 1 { code += ".brightness(\(String(format: "%.2f", bright)))" }
    if sat != 1 { code += ".saturate(\(String(format: "%.2f", sat)))" }
    if colorama > 0.01 { code += ".colorama(\(String(format: "%.3f", colorama)))" }
    if mod > 0.005 { code += ".modulate(noise(3),\(String(format: "%.3f", mod)))" }
    code += ".out()"
    return code
}

func hasHydraMapping(_ config: MappingConfig) -> Bool {
    for v in config.left.values where HYDRA_IDS.contains(v) { return true }
    for v in config.right.values where HYDRA_IDS.contains(v) { return true }
    return false
}

func buildTrackCode(slots: [Int], speed: Double, snippets: [SavedSnippet]) -> String? {
    let codes = slots.compactMap { snippets[safe: $0]?.code }
    guard !codes.isEmpty else { return nil }
    let inner = codes.count == 1 ? codes[0] : "slowcat(\(codes.joined(separator: ", ")))"
    return speed == 1 ? inner : "(\(inner)).slow(\(1 / speed))"
}

// MARK: - Drum Loops

struct DrumLoop: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let code: String  // Strudel code for the drum pattern
}

// Synth-based drums — distinct timbres, punchy, won't get buried
let _kick = "note(\"c1\").s(\"sine\").decay(0.2).sustain(0).gain(1.2).lpf(200)"
let _snare = "note(\"g3\").s(\"sawtooth\").decay(0.1).sustain(0).gain(0.9).hpf(800).lpf(5000).crush(6)"
let _hat = "note(\"c6\").s(\"square\").decay(0.02).sustain(0).gain(0.5).hpf(8000)"
let _clap = "note(\"e4\").s(\"sawtooth\").decay(0.12).sustain(0).gain(0.8).hpf(1200).crush(4)"
let _rim = "note(\"a4\").s(\"triangle\").decay(0.03).sustain(0).gain(0.7).hpf(3000)"

let DRUM_LOOPS: [DrumLoop] = [
    DrumLoop(id: "none", name: "None", emoji: "🔇", code: ""),
    DrumLoop(id: "basic", name: "Basic", emoji: "🥁",
             code: "stack(\(_kick).struct(\"x ~ x ~\"), \(_clap).struct(\"~ x ~ x\"), \(_hat).struct(\"x x x x\"))"),
    DrumLoop(id: "hiphop", name: "Hip Hop", emoji: "🎤",
             code: "stack(\(_kick).struct(\"x ~ ~ x ~ ~ x ~\"), \(_clap).struct(\"~ ~ ~ ~ x ~ ~ ~\"), \(_hat).struct(\"~ x ~ x ~ x ~ x\"))"),
    DrumLoop(id: "house", name: "House", emoji: "🏠",
             code: "stack(\(_kick).struct(\"x x x x\"), \(_clap).struct(\"~ ~ x ~\"), \(_hat).struct(\"[~ x] [~ x] [~ x] [~ x]\"))"),
    DrumLoop(id: "trap", name: "Trap", emoji: "🔊",
             code: "stack(\(_kick).struct(\"x ~ ~ ~ x ~ ~ ~\").gain(1.4), \(_clap).struct(\"~ ~ ~ ~ x ~ ~ ~\"), \(_hat).struct(\"[x x x x] [x x x x] [x x x x] [x x x x]\"))"),
    DrumLoop(id: "minimal", name: "Minimal", emoji: "✨",
             code: "stack(\(_kick).struct(\"x ~ x ~\"), \(_rim).struct(\"~ x ~ x\"))"),
]

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
