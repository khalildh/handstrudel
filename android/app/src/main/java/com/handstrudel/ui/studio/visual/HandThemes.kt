package com.handstrudel.ui.studio.visual

import androidx.compose.ui.graphics.Color

/**
 * Port of iOS `HandTheme` (`Models/HandTheme.swift`). Owner: studio-ui. The
 * selected id persists through `StudioEngine.setHandTheme`. Premium themes
 * carry `visual_pack` (the store maps it to `plus_features`).
 */
data class HandTheme(
    val id: String,
    val name: String,
    val emoji: String,
    val leftColor: Color,
    val rightColor: Color,
    /** 0…2, default 1. */
    val glowIntensity: Float,
    /** Seconds, default 0.8. */
    val trailLength: Double,
    val isPremium: Boolean,
    val packId: String?,
)

val HAND_THEMES: List<HandTheme> = listOf(
    HandTheme("default", "Neon", "💚", Color(0f, 1f, 0.62f), Color(1f, 0.18f, 0.42f), 1.0f, 0.8, false, null),
    HandTheme("mono", "Mono", "⚪", Color.White, Color(0.7f, 0.7f, 0.7f), 0.8f, 0.8, false, null),
    HandTheme("fire_ice", "Fire & Ice", "🔥", Color(0f, 0.6f, 1f), Color(1f, 0.3f, 0f), 1.5f, 1.0, true, "visual_pack"),
    HandTheme("purple_gold", "Royal", "👑", Color(0.6f, 0.2f, 1f), Color(1f, 0.8f, 0f), 1.3f, 0.9, true, "visual_pack"),
    HandTheme("matrix", "Matrix", "🟢", Color(0f, 0.9f, 0f), Color(0f, 0.7f, 0f), 1.8f, 1.2, true, "visual_pack"),
    HandTheme("sunset", "Sunset", "🌅", Color(1f, 0.5f, 0f), Color(1f, 0f, 0.5f), 1.2f, 0.9, true, "visual_pack"),
    HandTheme("ocean", "Ocean", "🌊", Color(0f, 0.8f, 0.9f), Color(0f, 0.4f, 0.8f), 1.0f, 1.1, true, "visual_pack"),
)

fun handTheme(id: String): HandTheme = HAND_THEMES.firstOrNull { it.id == id } ?: HAND_THEMES[0]
