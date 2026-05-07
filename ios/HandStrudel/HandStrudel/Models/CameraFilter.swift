import SwiftUI

struct CameraFilter: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let isPremium: Bool
    let packId: String?

    // SwiftUI modifiers applied to the camera view
    let saturation: Double
    let contrast: Double
    let brightness: Double
    let hueRotation: Double  // degrees
    let overlayColor: Color?
    let overlayOpacity: Double
    let blendMode: BlendMode
}

let CAMERA_FILTERS: [CameraFilter] = [
    // MARK: - Free Filters

    CameraFilter(id: "none", name: "None", emoji: "📷",
                 isPremium: false, packId: nil,
                 saturation: 1, contrast: 1, brightness: 0, hueRotation: 0,
                 overlayColor: nil, overlayOpacity: 0, blendMode: .normal),

    CameraFilter(id: "warm", name: "Warm", emoji: "🌅",
                 isPremium: false, packId: nil,
                 saturation: 1.15, contrast: 1.05, brightness: 0.02, hueRotation: 0,
                 overlayColor: Color(red: 1, green: 0.6, blue: 0.2), overlayOpacity: 0.12, blendMode: .multiply),

    CameraFilter(id: "cool", name: "Cool", emoji: "🧊",
                 isPremium: false, packId: nil,
                 saturation: 1.1, contrast: 1.05, brightness: 0, hueRotation: 0,
                 overlayColor: Color(red: 0.3, green: 0.5, blue: 1.0), overlayOpacity: 0.1, blendMode: .multiply),

    CameraFilter(id: "vivid", name: "Vivid", emoji: "🌈",
                 isPremium: false, packId: nil,
                 saturation: 1.6, contrast: 1.15, brightness: 0.03, hueRotation: 0,
                 overlayColor: nil, overlayOpacity: 0, blendMode: .normal),

    CameraFilter(id: "noir", name: "Noir", emoji: "🖤",
                 isPremium: false, packId: nil,
                 saturation: 0, contrast: 1.3, brightness: 0.02, hueRotation: 0,
                 overlayColor: nil, overlayOpacity: 0, blendMode: .normal),

    CameraFilter(id: "vintage", name: "Vintage", emoji: "📼",
                 isPremium: false, packId: nil,
                 saturation: 0.7, contrast: 1.1, brightness: 0.03, hueRotation: 0,
                 overlayColor: Color(red: 0.9, green: 0.8, blue: 0.5), overlayOpacity: 0.15, blendMode: .multiply),

    CameraFilter(id: "sunset", name: "Sunset", emoji: "🌇",
                 isPremium: false, packId: nil,
                 saturation: 1.2, contrast: 1.1, brightness: 0.02, hueRotation: 0,
                 overlayColor: Color(red: 1.0, green: 0.3, blue: 0.2), overlayOpacity: 0.1, blendMode: .softLight),

    CameraFilter(id: "neon", name: "Neon", emoji: "💚",
                 isPremium: false, packId: nil,
                 saturation: 1.8, contrast: 1.2, brightness: 0.05, hueRotation: 0,
                 overlayColor: Color(red: 0, green: 1, blue: 0.6), overlayOpacity: 0.06, blendMode: .screen),

    CameraFilter(id: "dreamy", name: "Dreamy", emoji: "💭",
                 isPremium: false, packId: nil,
                 saturation: 0.85, contrast: 0.9, brightness: 0.06, hueRotation: 0,
                 overlayColor: Color(red: 0.8, green: 0.7, blue: 1.0), overlayOpacity: 0.12, blendMode: .softLight),

    CameraFilter(id: "golden", name: "Golden", emoji: "✨",
                 isPremium: false, packId: nil,
                 saturation: 1.1, contrast: 1.05, brightness: 0.04, hueRotation: 0,
                 overlayColor: Color(red: 1.0, green: 0.85, blue: 0.4), overlayOpacity: 0.15, blendMode: .softLight),

    // MARK: - Premium Filters

    CameraFilter(id: "cyberpunk", name: "Cyberpunk", emoji: "🤖",
                 isPremium: true, packId: "filter_pack",
                 saturation: 1.5, contrast: 1.3, brightness: -0.02, hueRotation: 0,
                 overlayColor: Color(red: 1, green: 0, blue: 0.8), overlayOpacity: 0.12, blendMode: .screen),

    CameraFilter(id: "ocean", name: "Ocean", emoji: "🌊",
                 isPremium: true, packId: "filter_pack",
                 saturation: 1.2, contrast: 1.05, brightness: 0, hueRotation: 180,
                 overlayColor: Color(red: 0, green: 0.3, blue: 0.6), overlayOpacity: 0.15, blendMode: .multiply),

    CameraFilter(id: "rose", name: "Rose", emoji: "🌹",
                 isPremium: true, packId: "filter_pack",
                 saturation: 1.1, contrast: 1.05, brightness: 0.03, hueRotation: 0,
                 overlayColor: Color(red: 1.0, green: 0.4, blue: 0.6), overlayOpacity: 0.15, blendMode: .softLight),

    CameraFilter(id: "acid", name: "Acid", emoji: "🧪",
                 isPremium: true, packId: "filter_pack",
                 saturation: 2.0, contrast: 1.2, brightness: 0.05, hueRotation: 90,
                 overlayColor: Color(red: 0.5, green: 1, blue: 0), overlayOpacity: 0.08, blendMode: .screen),

    CameraFilter(id: "frost", name: "Frost", emoji: "❄️",
                 isPremium: true, packId: "filter_pack",
                 saturation: 0.5, contrast: 1.15, brightness: 0.08, hueRotation: 0,
                 overlayColor: Color(red: 0.7, green: 0.85, blue: 1.0), overlayOpacity: 0.2, blendMode: .softLight),

    CameraFilter(id: "fire", name: "Fire", emoji: "🔥",
                 isPremium: true, packId: "filter_pack",
                 saturation: 1.4, contrast: 1.25, brightness: 0, hueRotation: 0,
                 overlayColor: Color(red: 1, green: 0.3, blue: 0), overlayOpacity: 0.12, blendMode: .screen),

    CameraFilter(id: "midnight", name: "Midnight", emoji: "🌙",
                 isPremium: true, packId: "filter_pack",
                 saturation: 0.6, contrast: 1.2, brightness: -0.05, hueRotation: 220,
                 overlayColor: Color(red: 0.1, green: 0, blue: 0.3), overlayOpacity: 0.2, blendMode: .softLight),

    CameraFilter(id: "chrome", name: "Chrome", emoji: "🪩",
                 isPremium: true, packId: "filter_pack",
                 saturation: 0.1, contrast: 1.4, brightness: 0.05, hueRotation: 0,
                 overlayColor: Color(red: 0.8, green: 0.85, blue: 0.9), overlayOpacity: 0.1, blendMode: .softLight),

    CameraFilter(id: "thermal", name: "Thermal", emoji: "🌡️",
                 isPremium: true, packId: "filter_pack",
                 saturation: 1.3, contrast: 1.4, brightness: 0, hueRotation: 30,
                 overlayColor: Color(red: 1, green: 0.5, blue: 0), overlayOpacity: 0.15, blendMode: .screen),

    CameraFilter(id: "vhs", name: "VHS", emoji: "📹",
                 isPremium: true, packId: "filter_pack",
                 saturation: 0.8, contrast: 1.3, brightness: 0.04, hueRotation: 0,
                 overlayColor: Color(red: 0.8, green: 0.2, blue: 0.3), overlayOpacity: 0.08, blendMode: .screen),

    CameraFilter(id: "matrix_filter", name: "Matrix", emoji: "💻",
                 isPremium: true, packId: "filter_pack",
                 saturation: 0.3, contrast: 1.3, brightness: -0.02, hueRotation: 100,
                 overlayColor: Color(red: 0, green: 1, blue: 0.3), overlayOpacity: 0.12, blendMode: .screen),

    CameraFilter(id: "infrared", name: "Infrared", emoji: "👁️",
                 isPremium: true, packId: "filter_pack",
                 saturation: 1.5, contrast: 1.2, brightness: 0.03, hueRotation: 300,
                 overlayColor: Color(red: 0.8, green: 0, blue: 0.3), overlayOpacity: 0.1, blendMode: .softLight),

    CameraFilter(id: "hologram", name: "Hologram", emoji: "🔮",
                 isPremium: true, packId: "filter_pack",
                 saturation: 1.8, contrast: 1.1, brightness: 0.06, hueRotation: 200,
                 overlayColor: Color(red: 0.3, green: 0.8, blue: 1.0), overlayOpacity: 0.15, blendMode: .screen),
]
