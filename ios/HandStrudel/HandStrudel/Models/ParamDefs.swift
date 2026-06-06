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

/// Dense, rest-free 16th-note pulse used by Flow mode. Strudel only samples
/// the pitch signal at a note onset, so packing more onsets into each cycle
/// tightens pitch feedback (~125 ms vs. up to ~750 ms with the sparse STRUCTS)
/// while staying 100% Strudel — code snapshots, effects and stack() all intact.
let FLOW_STRUCT = "x x x x x x x x x x x x x x x x"

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

let PARAM_MAP: [String: ParamDef] = Dictionary(uniqueKeysWithValues: PARAM_DEFS.map { ($0.id, $0) })

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
    return Array(ids).sorted()
}

func buildCode(_ p: MusicParams, structIdx: Int, config: MappingConfig, waveform: String = "sawtooth") -> String {
    let ni = max(0, min(NOTES.count - 1, Int((p["noteIdx"] ?? 10).rounded())))
    let note = NOTES[ni]
    let cpm = String(format: "%.1f", (p["bpm"] ?? 120) / 4)
    let st = STRUCTS[max(0, min(STRUCTS.count - 1, structIdx))]

    var code = "note(\"\(note)\").s(\"\(waveform)\").struct(\"\(st)\").cpm(\(cpm))"

    for id in extraParamIds(config) {
        guard let def = PARAM_MAP[id] else { continue }
        code += ".\(def.strudelKey)(\(def.toCode(p[id] ?? def.defaultValue)))"
    }

    return code
}

func buildSignalCode(structIdx: Int, config: MappingConfig, waveform: String = "sawtooth", structOverride: String? = nil) -> String {
    let st = structOverride ?? STRUCTS[max(0, min(STRUCTS.count - 1, structIdx))]

    var code = "note(signal(() => __hp._midi)).s(\"\(waveform)\").struct(\"\(st)\").cpm(signal(() => __hp._cpm))"

    for id in extraParamIds(config) {
        guard let def = PARAM_MAP[id] else { continue }
        code += ".\(def.strudelKey)(signal(() => __hp.\(id)))"
    }

    return code
}

func buildChordSignalCode(structIdx: Int, config: MappingConfig, waveform: String = "sawtooth", structOverride: String? = nil) -> String {
    let st = structOverride ?? STRUCTS[max(0, min(STRUCTS.count - 1, structIdx))]

    // Build extra params chain (shared across all chord voices)
    var extras = ""
    for id in extraParamIds(config) {
        guard let def = PARAM_MAP[id] else { continue }
        extras += ".\(def.strudelKey)(signal(() => __hp.\(id)))"
    }

    // Chord mode: stack 3 note voices using separate MIDI signals
    let voice: (Int) -> String = { i in
        "note(signal(() => __hp._cm\(i))).s(\"\(waveform)\").struct(\"\(st)\").cpm(signal(() => __hp._cpm))\(extras)"
    }

    return "stack(\(voice(0)), \(voice(1)), \(voice(2)))"
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
    let isPremium: Bool
    let packId: String?
}

// Synth drums using proper synthesis techniques:
// Kick = sine with pitch sweep + sub weight
// Snare = noise burst (white/pink) + body oscillator
// Hi-hat = noise through HPF, very short decay
// Clap = noise burst with resonant filter
// See: https://dev.opera.com/articles/drum-sounds-webaudio/

// --- KICKS (sine-based, different pitch/decay per genre) ---
let _deepKick = "note(\"c1\").s(\"sine\").decay(0.3).sustain(0).gain(1.4).lpf(120)"       // 808 sub boom
let _punchKick = "note(\"f1\").s(\"triangle\").decay(0.1).sustain(0).gain(1.2).lpf(300)"   // tight punch
let _houseKick = "note(\"d1\").s(\"sine\").decay(0.2).sustain(0).gain(1.3).lpf(200)"       // four-on-floor

// --- SNARES (noise + tone layered) ---
let _noiseSnare = "note(\"c4\").s(\"white\").decay(0.12).sustain(0).gain(0.7).hpf(1000).lpf(6000)"  // noise burst
let _toneSnare = "note(\"e3\").s(\"triangle\").decay(0.08).sustain(0).gain(0.5).lpf(3000)"           // body tone
let _snare = "stack(\(_noiseSnare), \(_toneSnare))"  // layered snare

// --- CLAPS (noise with resonance) ---
let _clap = "note(\"g4\").s(\"pink\").decay(0.09).sustain(0).gain(0.8).hpf(1500).lpf(8000)"
let _hardClap = "note(\"a4\").s(\"white\").decay(0.07).sustain(0).gain(0.9).hpf(2000).crush(4)"

// --- HI-HATS (noise through HPF) ---
let _closedHat = "note(\"a5\").s(\"white\").decay(0.025).sustain(0).gain(0.35).hpf(8000)"   // tight closed
let _openHat = "note(\"a5\").s(\"white\").decay(0.12).sustain(0).gain(0.3).hpf(7000)"        // ringing open
let _tinyHat = "note(\"c6\").s(\"pink\").decay(0.015).sustain(0).gain(0.25).hpf(10000)"      // tiny tick

// --- PERC ---
let _rimshot = "note(\"b4\").s(\"triangle\").decay(0.02).sustain(0).gain(0.6).hpf(5000)"
let _clave = "note(\"d5\").s(\"sine\").decay(0.03).sustain(0).gain(0.5).hpf(3000)"

let DRUM_LOOPS: [DrumLoop] = [
    DrumLoop(id: "none", name: "None", emoji: "🔇", code: "",
             isPremium: false, packId: nil),

    // Basic — kick-snare-hat straight groove
    DrumLoop(id: "basic", name: "Basic", emoji: "🥁",
             code: "stack(\(_punchKick).struct(\"x ~ x ~\"), \(_snare).struct(\"~ x ~ x\"), \(_closedHat).struct(\"x x x x\"))",
             isPremium: false, packId: nil),

    // Hip Hop — deep 808, syncopated, boom bap
    DrumLoop(id: "hiphop", name: "Hip Hop", emoji: "🎤",
             code: "stack(\(_deepKick).struct(\"x ~ ~ x ~ ~ x ~\"), \(_hardClap).struct(\"~ ~ ~ ~ x ~ ~ ~\"), \(_closedHat).struct(\"~ x ~ x ~ x ~ x\"), \(_openHat).struct(\"~ ~ x ~ ~ ~ x ~\"))",
             isPremium: false, packId: nil),

    // House — four on the floor, offbeat hats, clap on 3
    DrumLoop(id: "house", name: "House", emoji: "🏠",
             code: "stack(\(_houseKick).struct(\"x x x x\"), \(_clap).struct(\"~ ~ x ~\"), \(_openHat).struct(\"~ x ~ x ~ x ~ x\"), \(_tinyHat).struct(\"[x x] [x x] [x x] [x x]\"))",
             isPremium: false, packId: nil),

    // Trap — 808 boom, rapid hats, hard clap
    DrumLoop(id: "trap", name: "Trap", emoji: "🔊",
             code: "stack(\(_deepKick).struct(\"x ~ ~ ~ x ~ ~ ~\").gain(1.6), \(_hardClap).struct(\"~ ~ ~ ~ x ~ ~ ~\").gain(1.1), \(_closedHat).struct(\"[x x x x] [x x x x] [x x x x] [x x x x]\"), \(_openHat).struct(\"~ ~ ~ ~ ~ ~ [~ x] ~\"))",
             isPremium: false, packId: nil),

    // Minimal — sparse, clicky
    DrumLoop(id: "minimal", name: "Minimal", emoji: "✨",
             code: "stack(\(_punchKick).struct(\"x ~ ~ x\"), \(_rimshot).struct(\"~ ~ x ~\"), \(_clave).struct(\"~ x ~ ~\"))",
             isPremium: false, packId: nil),

    // MARK: - Premium Drum Loops

    // Boom Bap — syncopated deep kick, snappy snare on 2&4, open hats
    DrumLoop(id: "boombap", name: "Boom Bap", emoji: "🎧",
             code: "stack(\(_deepKick).struct(\"x ~ ~ ~ ~ ~ x ~\"), \(_snare).struct(\"~ ~ ~ ~ x ~ ~ ~\"), \(_closedHat).struct(\"x ~ x ~ x ~ x ~\"), \(_openHat).struct(\"~ ~ ~ x ~ ~ ~ x\"))",
             isPremium: true, packId: "kit_808"),

    // Drill — sliding 808 kick, rapid hats, sparse clap
    DrumLoop(id: "drill", name: "Drill", emoji: "🔫",
             code: "stack(\(_deepKick).struct(\"x ~ ~ ~ ~ x ~ ~\").gain(1.5), \(_hardClap).struct(\"~ ~ ~ ~ ~ ~ ~ x\"), \(_closedHat).struct(\"[x x x] [x x x] [x x x] [x x x]\"), \(_openHat).struct(\"~ ~ [~ x] ~ ~ ~ [~ x] ~\"))",
             isPremium: true, packId: "kit_808"),

    // Techno — four-on-floor tight kick, metallic hats, clap on 2&4
    DrumLoop(id: "techno", name: "Techno", emoji: "🤖",
             code: "stack(\(_punchKick).struct(\"x x x x\").gain(1.3), \(_clap).struct(\"~ x ~ x\"), \(_tinyHat).struct(\"[x x] [x x] [x x] [x x]\"), \(_openHat).struct(\"~ [~ x] ~ [~ x]\"))",
             isPremium: true, packId: "kit_electronic"),

    // Breakbeat — broken kick pattern, fast snare rolls, open hats
    DrumLoop(id: "breakbeat", name: "Breakbeat", emoji: "💥",
             code: "stack(\(_punchKick).struct(\"x ~ x ~ ~ x ~ ~\"), \(_snare).struct(\"~ ~ ~ ~ x ~ [x x] ~\"), \(_closedHat).struct(\"[x x] [x x] [x x] [x x]\"), \(_openHat).struct(\"~ ~ ~ ~ ~ ~ ~ x\"))",
             isPremium: true, packId: "kit_electronic"),

    // Bossa Nova — syncopated light kick, rim on offbeats, shaker 16ths
    DrumLoop(id: "bossanova", name: "Bossa Nova", emoji: "🌴",
             code: "stack(\(_houseKick).struct(\"x ~ ~ x ~ ~ x ~\").gain(0.9), \(_rimshot).struct(\"~ ~ x ~ ~ x ~ x\"), \(_tinyHat).struct(\"[x x x x] [x x x x] [x x x x] [x x x x]\").gain(0.3))",
             isPremium: true, packId: "kit_808"),

    // Reggae — one-drop kick on 3, rim on 2&4, offbeat clicks
    DrumLoop(id: "reggae", name: "Reggae", emoji: "🟢",
             code: "stack(\(_deepKick).struct(\"~ ~ x ~\").gain(1.2), \(_rimshot).struct(\"~ x ~ x\"), \(_clave).struct(\"~ x ~ x ~ x ~ x\").gain(0.4))",
             isPremium: true, packId: "kit_808"),

    // Lo-Fi Hip Hop — lazy sparse kick, late snare, ghost rimshot
    DrumLoop(id: "lofi_hiphop", name: "Lo-Fi Hip Hop", emoji: "☕",
             code: "stack(\(_deepKick).struct(\"x ~ ~ ~ x ~ ~ ~\"), \(_snare).struct(\"~ ~ ~ ~ ~ ~ x ~\"), \(_closedHat).struct(\"x ~ x ~ x ~ x ~\"), \(_rimshot).struct(\"~ ~ ~ x ~ ~ ~ ~\"))",
             isPremium: true, packId: "kit_808"),

    // R&B — bouncy kick, clap on 3, 16th hats, open hat tail
    DrumLoop(id: "rnb", name: "R&B", emoji: "💜",
             code: "stack(\(_deepKick).struct(\"x ~ ~ x ~ ~ ~ ~\"), \(_clap).struct(\"~ ~ ~ ~ x ~ ~ ~\"), \(_closedHat).struct(\"[x x] [x x] [x x] [x x]\"), \(_openHat).struct(\"~ ~ ~ ~ ~ ~ ~ x\"))",
             isPremium: true, packId: "kit_808"),

    // Afrobeat — syncopated kick, double snare, triplet hats, clave
    DrumLoop(id: "afrobeat", name: "Afrobeat", emoji: "🌍",
             code: "stack(\(_houseKick).struct(\"x ~ x ~ ~ x ~ ~\"), \(_snare).struct(\"~ ~ ~ ~ x ~ ~ x\"), \(_closedHat).struct(\"[x x x] [x x x] [x x x] [x x x]\"), \(_clave).struct(\"x ~ ~ x ~ ~ x ~\"))",
             isPremium: true, packId: "kit_808"),

    // Bounce — steady bounce kick, big clap, skippy hats
    DrumLoop(id: "bounce", name: "Bounce", emoji: "🏀",
             code: "stack(\(_deepKick).struct(\"x ~ x ~ x ~ x ~\").gain(1.5), \(_hardClap).struct(\"~ ~ ~ ~ x ~ ~ ~\"), \(_closedHat).struct(\"[x x] ~ [x x] ~ [x x] ~ [x x] ~\"), \(_openHat).struct(\"~ ~ ~ ~ ~ ~ [~ x] ~\"))",
             isPremium: true, packId: "kit_808"),

    // Jersey Club — double kicks, off-beat claps, rapid 16th hats
    DrumLoop(id: "jersey", name: "Jersey Club", emoji: "🏙️",
             code: "stack(\(_punchKick).struct(\"[x x] ~ ~ ~ [x x] ~ ~ ~\"), \(_hardClap).struct(\"~ ~ x ~ ~ ~ x ~\"), \(_closedHat).struct(\"[x x x x] [x x x x] [x x x x] [x x x x]\"), \(_tinyHat).struct(\"~ x ~ x ~ x ~ x\"))",
             isPremium: true, packId: "kit_808"),

    // Memphis — sparse heavy kick, crack clap, triplet hats, constant rimshot
    DrumLoop(id: "memphis", name: "Memphis", emoji: "🎪",
             code: "stack(\(_deepKick).struct(\"x ~ ~ ~ ~ ~ x ~\").gain(1.6), \(_clap).struct(\"~ ~ ~ ~ x ~ ~ ~\"), \(_closedHat).struct(\"[x x x] [x x x] [x x x] [x x x]\"), \(_rimshot).struct(\"x ~ x ~ x ~ x ~\"))",
             isPremium: true, packId: "kit_808"),

    // IDM — irregular kick, broken snare, glitchy hats, sparse rimshot
    DrumLoop(id: "idm", name: "IDM", emoji: "🧠",
             code: "stack(\(_punchKick).struct(\"x ~ ~ x ~ x ~ ~\"), \(_snare).struct(\"~ ~ x ~ ~ ~ [x x] ~\"), \(_tinyHat).struct(\"[x x x] ~ [x x] ~ x ~ [x x x] ~\"), \(_rimshot).struct(\"~ x ~ ~ ~ x ~ ~\"))",
             isPremium: true, packId: "kit_electronic"),

    // Jungle — half-time kick, breakbeat snare, frantic hats, open hat accents
    DrumLoop(id: "jungle", name: "Jungle", emoji: "🌿",
             code: "stack(\(_punchKick).struct(\"x ~ ~ ~ x ~ ~ ~\"), \(_snare).struct(\"~ ~ ~ ~ x ~ [x x] ~\"), \(_closedHat).struct(\"[x x x x] [x x x x] [x x x x] [x x x x]\"), \(_openHat).struct(\"~ ~ x ~ ~ ~ x ~\"))",
             isPremium: true, packId: "kit_electronic"),

    // Ambient — very sparse, ghost notes, delicate
    DrumLoop(id: "ambient_beat", name: "Ambient", emoji: "🫧",
             code: "stack(\(_houseKick).struct(\"x ~ ~ ~ ~ ~ ~ ~\").gain(0.8), \(_rimshot).struct(\"~ ~ ~ x ~ ~ ~ ~\").gain(0.4), \(_tinyHat).struct(\"~ ~ x ~ ~ ~ x ~\").gain(0.3), \(_clave).struct(\"~ ~ ~ ~ ~ x ~ ~\").gain(0.3))",
             isPremium: true, packId: "kit_electronic"),

    // Industrial — relentless kick, hard clap, mechanical hats, metallic rimshot
    DrumLoop(id: "industrial", name: "Industrial", emoji: "⚙️",
             code: "stack(\(_punchKick).struct(\"x x ~ x x x ~ x\").gain(1.4), \(_hardClap).struct(\"~ ~ x ~ ~ ~ x ~\"), \(_closedHat).struct(\"[x x] [x x] [x x] [x x]\"), \(_rimshot).struct(\"x ~ x ~ x ~ x ~\"))",
             isPremium: true, packId: "kit_electronic"),

    // 2-Step — skippy kick, clap on 3, shuffle hats, tail open hat
    DrumLoop(id: "garage_beat", name: "2-Step", emoji: "👟",
             code: "stack(\(_houseKick).struct(\"x ~ ~ ~ ~ ~ x ~\"), \(_clap).struct(\"~ ~ ~ ~ x ~ ~ ~\"), \(_closedHat).struct(\"[x x] x [x x] x [x x] x [x x] x\"), \(_openHat).struct(\"~ ~ ~ ~ ~ ~ ~ x\"))",
             isPremium: true, packId: "kit_electronic"),

    // Synthwave — steady kick, big backbeat snare, straight 8ths, offbeat open hat
    DrumLoop(id: "synthwave", name: "Synthwave", emoji: "🌆",
             code: "stack(\(_houseKick).struct(\"x ~ ~ ~ x ~ ~ ~\"), \(_snare).struct(\"~ ~ ~ ~ x ~ ~ ~\"), \(_closedHat).struct(\"x ~ x ~ x ~ x ~\"), \(_openHat).struct(\"~ x ~ x ~ x ~ x\").gain(0.4))",
             isPremium: true, packId: "kit_electronic"),
]

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
