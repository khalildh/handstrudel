package com.handstrudel.models

// GENERATED from ios/HandStrudel/HandStrudel/Models/CameraFilter.swift (data only; drawing is studio-ui).

data class FilterColor(val red: Double, val green: Double, val blue: Double)

/** SwiftUI `BlendMode` cases used by the filters. */
enum class FilterBlendMode { NORMAL, MULTIPLY, SCREEN, OVERLAY, SOFT_LIGHT, HARD_LIGHT, COLOR, COLOR_DODGE, COLOR_BURN, DIFFERENCE, LUMINOSITY, PLUS_LIGHTER, HUE, SATURATION, LIGHTEN, DARKEN, EXCLUSION }

/** iOS `CameraFilter`: saturation/contrast/brightness/hue-rotation plus an optional colour overlay. */
data class CameraFilter(
    val id: String, val name: String, val emoji: String, val isPremium: Boolean, val packId: String?,
    val saturation: Double, val contrast: Double, val brightness: Double, val hueRotation: Double,
    val overlayColor: FilterColor?, val overlayOpacity: Double, val blendMode: FilterBlendMode,
)

val CAMERA_FILTERS: List<CameraFilter> = listOf(
    CameraFilter("none", "None", "📷", false, null, 1.0, 1.0, 0.0, 0.0, null, 0.0, FilterBlendMode.NORMAL),
    CameraFilter("warm", "Warm", "🌅", false, null, 1.15, 1.05, 0.02, 0.0, FilterColor(1.0, 0.6, 0.2), 0.12, FilterBlendMode.MULTIPLY),
    CameraFilter("cool", "Cool", "🧊", false, null, 1.1, 1.05, 0.0, 0.0, FilterColor(0.3, 0.5, 1.0), 0.1, FilterBlendMode.MULTIPLY),
    CameraFilter("vivid", "Vivid", "🌈", false, null, 1.6, 1.15, 0.03, 0.0, null, 0.0, FilterBlendMode.NORMAL),
    CameraFilter("noir", "Noir", "🖤", false, null, 0.0, 1.3, 0.02, 0.0, null, 0.0, FilterBlendMode.NORMAL),
    CameraFilter("vintage", "Vintage", "📼", false, null, 0.7, 1.1, 0.03, 0.0, FilterColor(0.9, 0.8, 0.5), 0.15, FilterBlendMode.MULTIPLY),
    CameraFilter("sunset", "Sunset", "🌇", false, null, 1.2, 1.1, 0.02, 0.0, FilterColor(1.0, 0.3, 0.2), 0.1, FilterBlendMode.SOFT_LIGHT),
    CameraFilter("neon", "Neon", "💚", false, null, 1.8, 1.2, 0.05, 0.0, FilterColor(0.0, 1.0, 0.6), 0.06, FilterBlendMode.SCREEN),
    CameraFilter("dreamy", "Dreamy", "💭", false, null, 0.85, 0.9, 0.06, 0.0, FilterColor(0.8, 0.7, 1.0), 0.12, FilterBlendMode.SOFT_LIGHT),
    CameraFilter("golden", "Golden", "✨", false, null, 1.1, 1.05, 0.04, 0.0, FilterColor(1.0, 0.85, 0.4), 0.15, FilterBlendMode.SOFT_LIGHT),
    CameraFilter("cyberpunk", "Cyberpunk", "🤖", true, "filter_pack", 1.5, 1.3, -0.02, 0.0, FilterColor(1.0, 0.0, 0.8), 0.12, FilterBlendMode.SCREEN),
    CameraFilter("ocean", "Ocean", "🌊", true, "filter_pack", 1.2, 1.05, 0.0, 180.0, FilterColor(0.0, 0.3, 0.6), 0.15, FilterBlendMode.MULTIPLY),
    CameraFilter("rose", "Rose", "🌹", true, "filter_pack", 1.1, 1.05, 0.03, 0.0, FilterColor(1.0, 0.4, 0.6), 0.15, FilterBlendMode.SOFT_LIGHT),
    CameraFilter("acid", "Acid", "🧪", true, "filter_pack", 2.0, 1.2, 0.05, 90.0, FilterColor(0.5, 1.0, 0.0), 0.08, FilterBlendMode.SCREEN),
    CameraFilter("frost", "Frost", "❄️", true, "filter_pack", 0.5, 1.15, 0.08, 0.0, FilterColor(0.7, 0.85, 1.0), 0.2, FilterBlendMode.SOFT_LIGHT),
    CameraFilter("fire", "Fire", "🔥", true, "filter_pack", 1.4, 1.25, 0.0, 0.0, FilterColor(1.0, 0.3, 0.0), 0.12, FilterBlendMode.SCREEN),
    CameraFilter("midnight", "Midnight", "🌙", true, "filter_pack", 0.6, 1.2, -0.05, 220.0, FilterColor(0.1, 0.0, 0.3), 0.2, FilterBlendMode.SOFT_LIGHT),
    CameraFilter("chrome", "Chrome", "🪩", true, "filter_pack", 0.1, 1.4, 0.05, 0.0, FilterColor(0.8, 0.85, 0.9), 0.1, FilterBlendMode.SOFT_LIGHT),
    CameraFilter("thermal", "Thermal", "🌡️", true, "filter_pack", 1.3, 1.4, 0.0, 30.0, FilterColor(1.0, 0.5, 0.0), 0.15, FilterBlendMode.SCREEN),
    CameraFilter("vhs", "VHS", "📹", true, "filter_pack", 0.8, 1.3, 0.04, 0.0, FilterColor(0.8, 0.2, 0.3), 0.08, FilterBlendMode.SCREEN),
    CameraFilter("matrix_filter", "Matrix", "💻", true, "filter_pack", 0.3, 1.3, -0.02, 100.0, FilterColor(0.0, 1.0, 0.3), 0.12, FilterBlendMode.SCREEN),
    CameraFilter("infrared", "Infrared", "👁️", true, "filter_pack", 1.5, 1.2, 0.03, 300.0, FilterColor(0.8, 0.0, 0.3), 0.1, FilterBlendMode.SOFT_LIGHT),
    CameraFilter("hologram", "Hologram", "🔮", true, "filter_pack", 1.8, 1.1, 0.06, 200.0, FilterColor(0.3, 0.8, 1.0), 0.15, FilterBlendMode.SCREEN),
)

fun cameraFilter(id: String): CameraFilter = CAMERA_FILTERS.firstOrNull { it.id == id } ?: CAMERA_FILTERS[0]
