import Foundation

struct AxisDef: Identifiable {
    let key: String
    let label: String
    let icon: String
    let basic: Bool
    let invert: Bool
    var id: String { key }
}

let AXIS_DEFS: [AxisDef] = [
    AxisDef(key: "y",          label: "Y pos",       icon: "arrow.up.arrow.down",  basic: true,  invert: true),
    AxisDef(key: "x",          label: "X pos",       icon: "arrow.left.arrow.right", basic: true, invert: true),
    AxisDef(key: "spread",     label: "spread",      icon: "hand.raised",          basic: true,  invert: false),
    AxisDef(key: "pinch",      label: "pinch",       icon: "hand.pinch",           basic: false, invert: false),
    AxisDef(key: "fist",       label: "fist",        icon: "hand.raised.slash",    basic: false, invert: false),
    AxisDef(key: "rotation",   label: "rotation",    icon: "arrow.triangle.2.circlepath", basic: false, invert: false),
    AxisDef(key: "thumbCurl",  label: "thumb curl",  icon: "hand.thumbsup",        basic: false, invert: false),
    AxisDef(key: "indexCurl",  label: "index curl",  icon: "hand.point.up",        basic: false, invert: false),
    AxisDef(key: "middleCurl", label: "middle curl", icon: "hand.raised",          basic: false, invert: false),
    AxisDef(key: "ringCurl",   label: "ring curl",   icon: "hand.raised",          basic: false, invert: false),
    AxisDef(key: "pinkyCurl",  label: "pinky curl",  icon: "hand.raised",          basic: false, invert: false),
]

let AXIS_MAP: [String: AxisDef] = Dictionary(uniqueKeysWithValues: AXIS_DEFS.map { ($0.key, $0) })

struct MappingConfig {
    var left: [String: String]
    var right: [String: String]
}

let DEFAULT_MAPPING = MappingConfig(
    left:  ["y": "noteIdx", "x": "lpf",  "spread": "reverb"],
    right: ["y": "gain",    "x": "bpm",  "spread": "delay"]
)

let DEFAULT_HYDRA_MAPPING = MappingConfig(
    left:  ["y": "none", "x": "none", "spread": "none"],
    right: ["y": "none", "x": "none", "spread": "none"]
)

let DEFAULT_ADVANCED_MAPPING = MappingConfig(
    left: [
        "y": "noteIdx", "x": "lpf", "spread": "reverb",
        "pinch": "crush", "fist": "shape", "rotation": "pan",
        "thumbCurl": "none", "indexCurl": "none", "middleCurl": "none",
        "ringCurl": "none", "pinkyCurl": "none",
    ],
    right: [
        "y": "gain", "x": "bpm", "spread": "delay",
        "pinch": "hpf", "fist": "attack", "rotation": "release",
        "thumbCurl": "none", "indexCurl": "none", "middleCurl": "none",
        "ringCurl": "none", "pinkyCurl": "none",
    ]
)

// MARK: - Presets

struct Preset: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let description: String
    let color: (Double, Double, Double) // RGB 0-1
    let mapping: MappingConfig
    let hydraMapping: MappingConfig
}

let PRESETS: [Preset] = [
    Preset(
        id: "dreamy", name: "Dreamy", emoji: "🌙",
        description: "Floaty reverb & delay",
        color: (0.5, 0.3, 1.0),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "spread": "reverb", "x": "lpf"],
            right: ["y": "gain", "spread": "delay", "x": "pan"]
        ),
        hydraMapping: MappingConfig(
            left:  ["y": "hRotate", "spread": "hColorama", "x": "hModulate"],
            right: ["y": "hFreq", "spread": "hKaleid", "x": "hScale"]
        )
    ),
    Preset(
        id: "gritty", name: "Gritty", emoji: "🔥",
        description: "Crunchy distortion vibes",
        color: (1.0, 0.3, 0.2),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "crush", "spread": "shape"],
            right: ["y": "gain", "x": "hpf", "spread": "bpm"]
        ),
        hydraMapping: MappingConfig(
            left:  ["y": "hPixel", "spread": "hSaturate", "x": "hColorama"],
            right: ["y": "hFreq", "spread": "hBright", "x": "hRotate"]
        )
    ),
    Preset(
        id: "bouncy", name: "Bouncy", emoji: "🎾",
        description: "Playful filter bounce",
        color: (0.2, 0.9, 0.4),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "spread": "lpf", "x": "delay"],
            right: ["y": "bpm", "spread": "gain", "x": "reverb"]
        ),
        hydraMapping: MappingConfig(
            left:  ["y": "hKaleid", "spread": "hScale", "x": "hFreq"],
            right: ["y": "hRotate", "spread": "hModulate", "x": "hColorama"]
        )
    ),
    Preset(
        id: "chill", name: "Chill", emoji: "🧊",
        description: "Slow & spacious",
        color: (0.3, 0.7, 1.0),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "pan", "spread": "reverb"],
            right: ["y": "gain", "x": "attack", "spread": "release"]
        ),
        hydraMapping: MappingConfig(
            left:  ["y": "hFreq", "spread": "hSync", "x": "hScale"],
            right: ["y": "hBright", "spread": "hModulate", "x": "hSaturate"]
        )
    ),
]

let DEFAULT_ADVANCED_HYDRA_MAPPING = MappingConfig(
    left: [
        "y": "none", "x": "none", "spread": "none",
        "pinch": "none", "fist": "none", "rotation": "none",
        "thumbCurl": "none", "indexCurl": "none", "middleCurl": "none",
        "ringCurl": "none", "pinkyCurl": "none",
    ],
    right: [
        "y": "none", "x": "none", "spread": "none",
        "pinch": "none", "fist": "none", "rotation": "none",
        "thumbCurl": "none", "indexCurl": "none", "middleCurl": "none",
        "ringCurl": "none", "pinkyCurl": "none",
    ]
)
