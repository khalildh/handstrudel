import UIKit

struct HandTheme: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let leftColor: UIColor
    let rightColor: UIColor
    let glowIntensity: CGFloat  // 0.0 to 2.0, default 1.0
    let trailLength: TimeInterval  // seconds, default 0.8
    let isPremium: Bool
    let packId: String?
}

let HAND_THEMES: [HandTheme] = [
    // Free themes
    HandTheme(id: "default", name: "Neon", emoji: "💚",
              leftColor: UIColor(red: 0, green: 1, blue: 0.62, alpha: 1),
              rightColor: UIColor(red: 1, green: 0.18, blue: 0.42, alpha: 1),
              glowIntensity: 1.0, trailLength: 0.8,
              isPremium: false, packId: nil),

    HandTheme(id: "mono", name: "Mono", emoji: "⚪",
              leftColor: UIColor.white,
              rightColor: UIColor(white: 0.7, alpha: 1),
              glowIntensity: 0.8, trailLength: 0.8,
              isPremium: false, packId: nil),

    // Premium themes
    HandTheme(id: "fire_ice", name: "Fire & Ice", emoji: "🔥",
              leftColor: UIColor(red: 0, green: 0.6, blue: 1.0, alpha: 1),
              rightColor: UIColor(red: 1, green: 0.3, blue: 0, alpha: 1),
              glowIntensity: 1.5, trailLength: 1.0,
              isPremium: true, packId: "visual_pack"),

    HandTheme(id: "purple_gold", name: "Royal", emoji: "👑",
              leftColor: UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 1),
              rightColor: UIColor(red: 1, green: 0.8, blue: 0, alpha: 1),
              glowIntensity: 1.3, trailLength: 0.9,
              isPremium: true, packId: "visual_pack"),

    HandTheme(id: "matrix", name: "Matrix", emoji: "🟢",
              leftColor: UIColor(red: 0, green: 0.9, blue: 0, alpha: 1),
              rightColor: UIColor(red: 0, green: 0.7, blue: 0, alpha: 1),
              glowIntensity: 1.8, trailLength: 1.2,
              isPremium: true, packId: "visual_pack"),

    HandTheme(id: "sunset", name: "Sunset", emoji: "🌅",
              leftColor: UIColor(red: 1.0, green: 0.5, blue: 0, alpha: 1),
              rightColor: UIColor(red: 1.0, green: 0, blue: 0.5, alpha: 1),
              glowIntensity: 1.2, trailLength: 0.9,
              isPremium: true, packId: "visual_pack"),

    HandTheme(id: "ocean", name: "Ocean", emoji: "🌊",
              leftColor: UIColor(red: 0, green: 0.8, blue: 0.9, alpha: 1),
              rightColor: UIColor(red: 0, green: 0.4, blue: 0.8, alpha: 1),
              glowIntensity: 1.0, trailLength: 1.1,
              isPremium: true, packId: "visual_pack"),
]
