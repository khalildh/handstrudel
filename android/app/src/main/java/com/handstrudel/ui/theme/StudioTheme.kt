package com.handstrudel.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ProvidableCompositionLocal
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/**
 * iOS `StudioTheme` (`Views/StudioTheme.swift`). Owner: shell. Stored under pref
 * key `studioTheme` (raw value), default [VOLT]. Hex values copied from iOS.
 */
enum class StudioTheme(val raw: String, val title: String, val subtitle: String) {
    VOLT("volt", "Volt", "Lime on charcoal"),
    TIDE("tide", "Deep Tide", "Glacier blue on deep navy"),
    AFTERGLOW("afterglow", "Afterglow", "Honey and coral on indigo"),
    PAPER("paper", "Paper & Ink", "Rust red on warm ivory");

    val isLight: Boolean get() = this == PAPER

    val palette: StudioPalette
        get() = when (this) {
            VOLT -> StudioPalette.of(0x0A0C0C, 0x141816, 0xF3F6EE, 0xA5AFA5, 0xD3F974, 0x0A0C0C, 0xD3F974, 0x2B401F, 0x42BD8C)
            TIDE -> StudioPalette.of(0x081320, 0x102339, 0xF0F8FF, 0xA1B9D0, 0x84E5FF, 0x081320, 0x84E5FF, 0x15405D, 0x8B9DFF)
            AFTERGLOW -> StudioPalette.of(0x181326, 0x292038, 0xFFF4E8, 0xC2AFC5, 0xFFBE76, 0x241625, 0xFFBE76, 0x533047, 0xFF7D9C)
            PAPER -> StudioPalette.of(0xFAF4E8, 0xEFE4D2, 0x261C19, 0x614B41, 0x963424, 0xFFF8EF, 0xFFAA92, 0xEFD2AD, 0xB75447, borderOpacity = 0.17f)
        }

    companion object {
        const val STORAGE_KEY = "studioTheme"
        fun fromRaw(raw: String?): StudioTheme = entries.firstOrNull { it.raw == raw } ?: VOLT
    }
}

/** iOS `StudioPalette`. */
data class StudioPalette(
    val background: Color,
    val surface: Color,
    val ink: Color,
    val muted: Color,
    val accent: Color,
    val onAccent: Color,
    val mediaAccent: Color,
    val mediaOnAccent: Color,
    val glow: Color,
    val overtone: Color,
    val border: Color,
    val recording: Color = Color(0xFFFF524F),
) {
    companion object {
        fun of(
            background: Int, surface: Int, ink: Int, muted: Int, accent: Int, onAccent: Int,
            mediaAccent: Int, glow: Int, overtone: Int, borderOpacity: Float = 0.12f,
        ) = StudioPalette(
            background = rgb(background), surface = rgb(surface), ink = rgb(ink), muted = rgb(muted),
            accent = rgb(accent), onAccent = rgb(onAccent), mediaAccent = rgb(mediaAccent),
            mediaOnAccent = rgb(if (mediaAccent == accent) onAccent else 0x25100C),
            glow = rgb(glow), overtone = rgb(overtone), border = rgb(ink).copy(alpha = borderOpacity),
        )

        private fun rgb(hex: Int) = Color(0xFF000000.toInt() or hex)
    }
}

val LocalStudioPalette: ProvidableCompositionLocal<StudioPalette> = staticCompositionLocalOf { StudioTheme.VOLT.palette }

/** The active theme (for code that needs [StudioTheme.isLight], e.g. system bar icons). */
val LocalStudioTheme: ProvidableCompositionLocal<StudioTheme> = staticCompositionLocalOf { StudioTheme.VOLT }

/**
 * Material 3 colours derived from a palette, so stock components (sheets, dialogs,
 * switches, text fields) follow the studio theme the way iOS `.tint(palette.accent)` and
 * `preferredColorScheme` do. [light] = iOS `colorScheme == .light` (Paper only).
 */
fun StudioPalette.materialColorScheme(light: Boolean): ColorScheme {
    val base = if (light) lightColorScheme() else darkColorScheme()
    return base.copy(
        primary = accent,
        onPrimary = onAccent,
        primaryContainer = glow,
        onPrimaryContainer = ink,
        secondary = overtone,
        onSecondary = onAccent,
        tertiary = mediaAccent,
        onTertiary = mediaOnAccent,
        background = background,
        onBackground = ink,
        surface = background,
        onSurface = ink,
        surfaceVariant = surface,
        onSurfaceVariant = muted,
        surfaceContainerLowest = background,
        surfaceContainerLow = surface,
        surfaceContainer = surface,
        surfaceContainerHigh = surface,
        surfaceContainerHighest = surface,
        surfaceBright = surface,
        surfaceDim = background,
        inverseSurface = ink,
        inverseOnSurface = background,
        outline = muted,
        outlineVariant = border,
        error = recording,
        onError = Color.White,
        scrim = Color.Black,
    )
}

/**
 * Provides [LocalStudioPalette], [LocalStudioTheme] and a matching [MaterialTheme].
 * [forceDark] mirrors iOS forcing `.dark` over feed video.
 */
@Composable
fun StudioMaterialTheme(theme: StudioTheme, forceDark: Boolean = false, content: @Composable () -> Unit) {
    val palette = theme.palette
    CompositionLocalProvider(LocalStudioPalette provides palette, LocalStudioTheme provides theme) {
        MaterialTheme(colorScheme = palette.materialColorScheme(light = theme.isLight && !forceDark), content = content)
    }
}
