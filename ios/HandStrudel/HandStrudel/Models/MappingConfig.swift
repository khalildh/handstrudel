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
    let isPremium: Bool
    let packId: String?
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
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: false, packId: nil
    ),
    Preset(
        id: "gritty", name: "Gritty", emoji: "🔥",
        description: "Crunchy distortion vibes",
        color: (1.0, 0.3, 0.2),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "crush", "spread": "shape"],
            right: ["y": "gain", "x": "hpf", "spread": "bpm"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: false, packId: nil
    ),
    Preset(
        id: "bouncy", name: "Bouncy", emoji: "🎾",
        description: "Playful filter bounce",
        color: (0.2, 0.9, 0.4),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "spread": "lpf", "x": "delay"],
            right: ["y": "bpm", "spread": "gain", "x": "reverb"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: false, packId: nil
    ),
    Preset(
        id: "chill", name: "Chill", emoji: "🧊",
        description: "Slow & spacious",
        color: (0.3, 0.7, 1.0),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "pan", "spread": "reverb"],
            right: ["y": "gain", "x": "attack", "spread": "release"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: false, packId: nil
    ),

    // MARK: - Party Pack

    Preset(
        id: "edm", name: "EDM", emoji: "⚡",
        description: "High energy dancefloor",
        color: (1.0, 0.9, 0.0),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "lpf", "spread": "hpf"],
            right: ["y": "bpm", "x": "gain", "spread": "delay"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "party"
    ),
    Preset(
        id: "dnb", name: "DnB", emoji: "🥁",
        description: "Fast & aggressive",
        color: (0.9, 0.2, 0.5),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "lpf", "spread": "shape"],
            right: ["y": "bpm", "x": "gain", "spread": "reverb"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "party"
    ),
    Preset(
        id: "dubstep", name: "Dubstep", emoji: "💀",
        description: "Heavy bass & wobble",
        color: (0.3, 0.0, 0.6),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "crush", "spread": "lpf"],
            right: ["y": "gain", "x": "shape", "spread": "delay"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "party"
    ),
    Preset(
        id: "rave", name: "Rave", emoji: "🪩",
        description: "Euphoric dancefloor energy",
        color: (1.0, 0.0, 1.0),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "lpf", "spread": "crush"],
            right: ["y": "bpm", "x": "gain", "spread": "hpf"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "party"
    ),
    Preset(
        id: "reggaeton", name: "Reggaeton", emoji: "🌴",
        description: "Latin bounce & bass",
        color: (1.0, 0.7, 0.0),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "lpf", "spread": "shape"],
            right: ["y": "gain", "x": "bpm", "spread": "pan"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "party"
    ),
    Preset(
        id: "futurebass", name: "Future Bass", emoji: "🌌",
        description: "Lush supersaws & drops",
        color: (0.4, 0.2, 1.0),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "lpf", "spread": "reverb"],
            right: ["y": "gain", "x": "bpm", "spread": "crush"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "party"
    ),
    Preset(
        id: "techno2", name: "Techno", emoji: "🏭",
        description: "Dark industrial pulse",
        color: (0.3, 0.3, 0.3),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "hpf", "spread": "shape"],
            right: ["y": "bpm", "x": "gain", "spread": "crush"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "party"
    ),
    Preset(
        id: "garage", name: "Garage", emoji: "🇬🇧",
        description: "Skippy 2-step swing",
        color: (0.0, 0.6, 0.8),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "lpf", "spread": "delay"],
            right: ["y": "gain", "x": "bpm", "spread": "reverb"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "party"
    ),
    Preset(
        id: "phonk", name: "Phonk", emoji: "🚗",
        description: "Cowbell drift vibes",
        color: (0.5, 0.0, 0.0),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "crush", "spread": "shape"],
            right: ["y": "gain", "x": "hpf", "spread": "delay"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "party"
    ),

    // MARK: - Studio Pack

    Preset(
        id: "lofi", name: "Lo-Fi", emoji: "📻",
        description: "Slow, warm & dusty",
        color: (0.8, 0.6, 0.4),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "lpf", "spread": "reverb"],
            right: ["y": "gain", "x": "delay", "spread": "crush"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "studio"
    ),
    Preset(
        id: "ambient", name: "Ambient", emoji: "🌊",
        description: "Spacious & ethereal",
        color: (0.4, 0.6, 0.9),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "reverb", "spread": "pan"],
            right: ["y": "gain", "x": "attack", "spread": "release"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "studio"
    ),
    Preset(
        id: "glitch", name: "Glitch", emoji: "👾",
        description: "Broken & digital",
        color: (0.0, 1.0, 0.6),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "crush", "spread": "shape"],
            right: ["y": "gain", "x": "hpf", "spread": "delay"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "studio"
    ),
    Preset(
        id: "tape", name: "Tape", emoji: "📼",
        description: "Warm analog saturation",
        color: (0.7, 0.5, 0.3),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "lpf", "spread": "shape"],
            right: ["y": "gain", "x": "crush", "spread": "reverb"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "studio"
    ),
    Preset(
        id: "glass", name: "Glass", emoji: "🪟",
        description: "Crystal clear highs",
        color: (0.6, 0.9, 1.0),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "hpf", "spread": "delay"],
            right: ["y": "gain", "x": "pan", "spread": "attack"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "studio"
    ),
    Preset(
        id: "deep", name: "Deep", emoji: "🕳️",
        description: "Subterranean bass",
        color: (0.2, 0.1, 0.4),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "lpf", "spread": "reverb"],
            right: ["y": "gain", "x": "shape", "spread": "release"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "studio"
    ),
    Preset(
        id: "foggy", name: "Foggy", emoji: "🌫️",
        description: "Hazy & muted",
        color: (0.6, 0.6, 0.7),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "lpf", "spread": "attack"],
            right: ["y": "gain", "x": "reverb", "spread": "release"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "studio"
    ),
    Preset(
        id: "pulse", name: "Pulse", emoji: "💓",
        description: "Rhythmic & driving",
        color: (0.9, 0.2, 0.3),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "bpm", "spread": "shape"],
            right: ["y": "gain", "x": "lpf", "spread": "delay"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "studio"
    ),
    Preset(
        id: "cosmic", name: "Cosmic", emoji: "🪐",
        description: "Vast space echoes",
        color: (0.3, 0.2, 0.8),
        mapping: MappingConfig(
            left:  ["y": "noteIdx", "x": "pan", "spread": "reverb"],
            right: ["y": "gain", "x": "delay", "spread": "hpf"]
        ),
        hydraMapping: DEFAULT_HYDRA_MAPPING,
        isPremium: true, packId: "studio"
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
