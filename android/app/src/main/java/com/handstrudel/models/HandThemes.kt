package com.handstrudel.models

// GENERATED from ios/HandStrudel/HandStrudel/Models/HandTheme.swift (data only; drawing is studio-ui).

data class HandTheme(
    val id: String, val name: String, val emoji: String, val leftColor: FilterColor, val rightColor: FilterColor,
    val glowIntensity: Double, val trailLength: Double, val isPremium: Boolean, val packId: String?,
)

val HAND_THEMES: List<HandTheme> = listOf(
    HandTheme("default", "Neon", "💚", FilterColor(0.0, 1.0, 0.62), FilterColor(1.0, 0.18, 0.42), 1.0, 0.8, false, null),
    HandTheme("mono", "Mono", "⚪", FilterColor(1.0, 1.0, 1.0), FilterColor(0.7, 0.7, 0.7), 0.8, 0.8, false, null),
    HandTheme("fire_ice", "Fire & Ice", "🔥", FilterColor(0.0, 0.6, 1.0), FilterColor(1.0, 0.3, 0.0), 1.5, 1.0, true, "visual_pack"),
    HandTheme("purple_gold", "Royal", "👑", FilterColor(0.6, 0.2, 1.0), FilterColor(1.0, 0.8, 0.0), 1.3, 0.9, true, "visual_pack"),
    HandTheme("matrix", "Matrix", "🟢", FilterColor(0.0, 0.9, 0.0), FilterColor(0.0, 0.7, 0.0), 1.8, 1.2, true, "visual_pack"),
    HandTheme("sunset", "Sunset", "🌅", FilterColor(1.0, 0.5, 0.0), FilterColor(1.0, 0.0, 0.5), 1.2, 0.9, true, "visual_pack"),
    HandTheme("ocean", "Ocean", "🌊", FilterColor(0.0, 0.8, 0.9), FilterColor(0.0, 0.4, 0.8), 1.0, 1.1, true, "visual_pack"),
)

fun handTheme(id: String): HandTheme = HAND_THEMES.firstOrNull { it.id == id } ?: HAND_THEMES[0]
