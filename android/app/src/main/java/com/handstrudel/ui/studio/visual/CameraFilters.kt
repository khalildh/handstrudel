package com.handstrudel.ui.studio.visual

import kotlin.math.cos
import kotlin.math.sin

/** iOS SwiftUI `BlendMode` values used by the filter overlays. */
enum class FilterBlend { NORMAL, MULTIPLY, SCREEN, SOFT_LIGHT }

/** RGB 0…1 (iOS `Color(red:green:blue:)`). */
data class FilterRgb(val r: Float, val g: Float, val b: Float)

/**
 * Port of iOS `CameraFilter` (`Models/CameraFilter.swift`). The look is
 * saturation → contrast → brightness → hue rotation (SwiftUI modifier order,
 * innermost first) plus an optional colour overlay blended over the camera.
 * Owner: studio-ui. The selected id persists through `StudioEngine.setFilter`
 * (`lastFilterId`).
 */
data class CameraFilter(
    val id: String,
    val name: String,
    val emoji: String,
    val isPremium: Boolean,
    val packId: String?,
    val saturation: Float,
    val contrast: Float,
    val brightness: Float,
    val hueRotation: Float,
    val overlayColor: FilterRgb?,
    val overlayOpacity: Float,
    val blendMode: FilterBlend,
) {
    /** 4×5 row-major colour matrix (Android `ColorMatrix` layout, translations in 0…255). */
    val colorMatrix: FloatArray get() = FilterMatrix.forFilter(this)
    val isIdentity: Boolean get() = saturation == 1f && contrast == 1f && brightness == 0f && hueRotation == 0f
}

private fun f(
    id: String, name: String, emoji: String, premium: Boolean,
    sat: Float, con: Float, bri: Float, hue: Float,
    overlay: FilterRgb? = null, opacity: Float = 0f, blend: FilterBlend = FilterBlend.NORMAL,
) = CameraFilter(id, name, emoji, premium, if (premium) "filter_pack" else null, sat, con, bri, hue, overlay, opacity, blend)

/** iOS `CAMERA_FILTERS`, same order and values (10 free + 13 premium). */
val CAMERA_FILTERS: List<CameraFilter> = listOf(
    f("none", "None", "📷", false, 1f, 1f, 0f, 0f),
    f("warm", "Warm", "🌅", false, 1.15f, 1.05f, 0.02f, 0f, FilterRgb(1f, 0.6f, 0.2f), 0.12f, FilterBlend.MULTIPLY),
    f("cool", "Cool", "🧊", false, 1.1f, 1.05f, 0f, 0f, FilterRgb(0.3f, 0.5f, 1.0f), 0.1f, FilterBlend.MULTIPLY),
    f("vivid", "Vivid", "🌈", false, 1.6f, 1.15f, 0.03f, 0f),
    f("noir", "Noir", "🖤", false, 0f, 1.3f, 0.02f, 0f),
    f("vintage", "Vintage", "📼", false, 0.7f, 1.1f, 0.03f, 0f, FilterRgb(0.9f, 0.8f, 0.5f), 0.15f, FilterBlend.MULTIPLY),
    f("sunset", "Sunset", "🌇", false, 1.2f, 1.1f, 0.02f, 0f, FilterRgb(1.0f, 0.3f, 0.2f), 0.1f, FilterBlend.SOFT_LIGHT),
    f("neon", "Neon", "💚", false, 1.8f, 1.2f, 0.05f, 0f, FilterRgb(0f, 1f, 0.6f), 0.06f, FilterBlend.SCREEN),
    f("dreamy", "Dreamy", "💭", false, 0.85f, 0.9f, 0.06f, 0f, FilterRgb(0.8f, 0.7f, 1.0f), 0.12f, FilterBlend.SOFT_LIGHT),
    f("golden", "Golden", "✨", false, 1.1f, 1.05f, 0.04f, 0f, FilterRgb(1.0f, 0.85f, 0.4f), 0.15f, FilterBlend.SOFT_LIGHT),
    f("cyberpunk", "Cyberpunk", "🤖", true, 1.5f, 1.3f, -0.02f, 0f, FilterRgb(1f, 0f, 0.8f), 0.12f, FilterBlend.SCREEN),
    f("ocean", "Ocean", "🌊", true, 1.2f, 1.05f, 0f, 180f, FilterRgb(0f, 0.3f, 0.6f), 0.15f, FilterBlend.MULTIPLY),
    f("rose", "Rose", "🌹", true, 1.1f, 1.05f, 0.03f, 0f, FilterRgb(1.0f, 0.4f, 0.6f), 0.15f, FilterBlend.SOFT_LIGHT),
    f("acid", "Acid", "🧪", true, 2.0f, 1.2f, 0.05f, 90f, FilterRgb(0.5f, 1f, 0f), 0.08f, FilterBlend.SCREEN),
    f("frost", "Frost", "❄️", true, 0.5f, 1.15f, 0.08f, 0f, FilterRgb(0.7f, 0.85f, 1.0f), 0.2f, FilterBlend.SOFT_LIGHT),
    f("fire", "Fire", "🔥", true, 1.4f, 1.25f, 0f, 0f, FilterRgb(1f, 0.3f, 0f), 0.12f, FilterBlend.SCREEN),
    f("midnight", "Midnight", "🌙", true, 0.6f, 1.2f, -0.05f, 220f, FilterRgb(0.1f, 0f, 0.3f), 0.2f, FilterBlend.SOFT_LIGHT),
    f("chrome", "Chrome", "🪩", true, 0.1f, 1.4f, 0.05f, 0f, FilterRgb(0.8f, 0.85f, 0.9f), 0.1f, FilterBlend.SOFT_LIGHT),
    f("thermal", "Thermal", "🌡️", true, 1.3f, 1.4f, 0f, 30f, FilterRgb(1f, 0.5f, 0f), 0.15f, FilterBlend.SCREEN),
    f("vhs", "VHS", "📹", true, 0.8f, 1.3f, 0.04f, 0f, FilterRgb(0.8f, 0.2f, 0.3f), 0.08f, FilterBlend.SCREEN),
    f("matrix_filter", "Matrix", "💻", true, 0.3f, 1.3f, -0.02f, 100f, FilterRgb(0f, 1f, 0.3f), 0.12f, FilterBlend.SCREEN),
    f("infrared", "Infrared", "👁️", true, 1.5f, 1.2f, 0.03f, 300f, FilterRgb(0.8f, 0f, 0.3f), 0.1f, FilterBlend.SOFT_LIGHT),
    f("hologram", "Hologram", "🔮", true, 1.8f, 1.1f, 0.06f, 200f, FilterRgb(0.3f, 0.8f, 1.0f), 0.15f, FilterBlend.SCREEN),
)

fun cameraFilter(id: String): CameraFilter = CAMERA_FILTERS.firstOrNull { it.id == id } ?: CAMERA_FILTERS[0]

/**
 * Builds the 4×5 colour matrix for a filter the way SwiftUI's colour modifiers
 * compose (`.saturation` → `.contrast` → `.brightness` → `.hueRotation`), in
 * Android's `ColorMatrix` layout (offsets on the 0…255 scale). Pure math so
 * it's unit-tested on the JVM.
 */
object FilterMatrix {
    // Rec. 709 luminance, as used by SwiftUI/Core Image saturation.
    private const val LR = 0.2126f
    private const val LG = 0.7152f
    private const val LB = 0.0722f

    fun identity(): FloatArray = floatArrayOf(
        1f, 0f, 0f, 0f, 0f,
        0f, 1f, 0f, 0f, 0f,
        0f, 0f, 1f, 0f, 0f,
        0f, 0f, 0f, 1f, 0f,
    )

    fun saturation(s: Float): FloatArray {
        val i = 1f - s
        return floatArrayOf(
            LR * i + s, LG * i, LB * i, 0f, 0f,
            LR * i, LG * i + s, LB * i, 0f, 0f,
            LR * i, LG * i, LB * i + s, 0f, 0f,
            0f, 0f, 0f, 1f, 0f,
        )
    }

    /** out = (in − 0.5)·c + 0.5. */
    fun contrast(c: Float): FloatArray {
        val t = (1f - c) * 0.5f * 255f
        return floatArrayOf(
            c, 0f, 0f, 0f, t,
            0f, c, 0f, 0f, t,
            0f, 0f, c, 0f, t,
            0f, 0f, 0f, 1f, 0f,
        )
    }

    /** out = in + b. */
    fun brightness(b: Float): FloatArray {
        val t = b * 255f
        return floatArrayOf(
            1f, 0f, 0f, 0f, t,
            0f, 1f, 0f, 0f, t,
            0f, 0f, 1f, 0f, t,
            0f, 0f, 0f, 1f, 0f,
        )
    }

    /** Hue rotation by [degrees] (the SVG/W3C `hueRotate` matrix). */
    fun hueRotation(degrees: Float): FloatArray {
        val rad = Math.toRadians(degrees.toDouble())
        val c = cos(rad).toFloat()
        val s = sin(rad).toFloat()
        return floatArrayOf(
            0.213f + c * 0.787f - s * 0.213f, 0.715f - c * 0.715f - s * 0.715f, 0.072f - c * 0.072f + s * 0.928f, 0f, 0f,
            0.213f - c * 0.213f + s * 0.143f, 0.715f + c * 0.285f + s * 0.140f, 0.072f - c * 0.072f - s * 0.283f, 0f, 0f,
            0.213f - c * 0.213f - s * 0.787f, 0.715f - c * 0.715f + s * 0.715f, 0.072f + c * 0.928f + s * 0.072f, 0f, 0f,
            0f, 0f, 0f, 1f, 0f,
        )
    }

    /** a · b (apply b first, then a). */
    fun concat(a: FloatArray, b: FloatArray): FloatArray {
        val out = FloatArray(20)
        for (row in 0 until 4) {
            for (col in 0 until 5) {
                var sum = if (col == 4) a[row * 5 + 4] else 0f
                for (k in 0 until 4) sum += a[row * 5 + k] * b[k * 5 + col]
                out[row * 5 + col] = sum
            }
        }
        return out
    }

    fun forFilter(filter: CameraFilter): FloatArray {
        var m = saturation(filter.saturation)
        m = concat(contrast(filter.contrast), m)
        m = concat(brightness(filter.brightness), m)
        if (filter.hueRotation != 0f) m = concat(hueRotation(filter.hueRotation), m)
        return m
    }

    /** Applies [m] to an RGB colour in 0…1 (clamped), for tests and previews. */
    fun apply(m: FloatArray, r: Float, g: Float, b: Float): FilterRgb {
        fun ch(row: Int) = ((m[row * 5] * r + m[row * 5 + 1] * g + m[row * 5 + 2] * b) + m[row * 5 + 4] / 255f).coerceIn(0f, 1f)
        return FilterRgb(ch(0), ch(1), ch(2))
    }
}
