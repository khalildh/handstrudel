package com.handstrudel.models

data class Preset(
    val id: String,
    val name: String,
    val emoji: String,
    val description: String,
    val color: Triple<Float, Float, Float>,
    val leftMapping: Map<String, String>,
    val rightMapping: Map<String, String>,
    val isPremium: Boolean = false,
    val packId: String? = null
)

val PRESETS = listOf(
    // Free
    Preset("dreamy", "Dreamy", "\uD83C\uDF19", "Floaty reverb & delay", Triple(0.5f, 0.3f, 1.0f),
        mapOf("y" to "noteIdx", "spread" to "reverb", "x" to "lpf"),
        mapOf("y" to "gain", "spread" to "delay", "x" to "pan")),
    Preset("gritty", "Gritty", "\uD83D\uDD25", "Crunchy distortion vibes", Triple(1.0f, 0.3f, 0.2f),
        mapOf("y" to "noteIdx", "x" to "crush", "spread" to "shape"),
        mapOf("y" to "gain", "x" to "hpf", "spread" to "bpm")),
    Preset("bouncy", "Bouncy", "\uD83C\uDFBE", "Playful filter bounce", Triple(0.2f, 0.9f, 0.4f),
        mapOf("y" to "noteIdx", "spread" to "lpf", "x" to "delay"),
        mapOf("y" to "bpm", "spread" to "gain", "x" to "reverb")),
    Preset("chill", "Chill", "\uD83E\uDDCA", "Slow & spacious", Triple(0.3f, 0.7f, 1.0f),
        mapOf("y" to "noteIdx", "x" to "pan", "spread" to "reverb"),
        mapOf("y" to "gain", "x" to "attack", "spread" to "release")),

    // Party Pack
    Preset("edm", "EDM", "\u26A1", "High energy dancefloor", Triple(1.0f, 0.9f, 0.0f),
        mapOf("y" to "noteIdx", "x" to "lpf", "spread" to "hpf"),
        mapOf("y" to "bpm", "x" to "gain", "spread" to "delay"),
        isPremium = true, packId = "party"),
    Preset("dnb", "DnB", "\uD83E\uDD41", "Fast & aggressive", Triple(0.9f, 0.2f, 0.5f),
        mapOf("y" to "noteIdx", "x" to "lpf", "spread" to "shape"),
        mapOf("y" to "bpm", "x" to "gain", "spread" to "reverb"),
        isPremium = true, packId = "party"),
    Preset("dubstep", "Dubstep", "\uD83D\uDC80", "Heavy bass & wobble", Triple(0.3f, 0.0f, 0.6f),
        mapOf("y" to "noteIdx", "x" to "crush", "spread" to "lpf"),
        mapOf("y" to "gain", "x" to "shape", "spread" to "delay"),
        isPremium = true, packId = "party"),
    Preset("rave", "Rave", "\uD83E\uDE69", "Euphoric dancefloor energy", Triple(1.0f, 0.0f, 1.0f),
        mapOf("y" to "noteIdx", "x" to "lpf", "spread" to "crush"),
        mapOf("y" to "bpm", "x" to "gain", "spread" to "hpf"),
        isPremium = true, packId = "party"),

    // Studio Pack
    Preset("lofi", "Lo-Fi", "\uD83D\uDCFB", "Slow, warm & dusty", Triple(0.8f, 0.6f, 0.4f),
        mapOf("y" to "noteIdx", "x" to "lpf", "spread" to "reverb"),
        mapOf("y" to "gain", "x" to "delay", "spread" to "crush"),
        isPremium = true, packId = "studio"),
    Preset("ambient", "Ambient", "\uD83C\uDF0A", "Spacious & ethereal", Triple(0.4f, 0.6f, 0.9f),
        mapOf("y" to "noteIdx", "x" to "reverb", "spread" to "pan"),
        mapOf("y" to "gain", "x" to "attack", "spread" to "release"),
        isPremium = true, packId = "studio"),
    Preset("glitch", "Glitch", "\uD83D\uDC7E", "Broken & digital", Triple(0.0f, 1.0f, 0.6f),
        mapOf("y" to "noteIdx", "x" to "crush", "spread" to "shape"),
        mapOf("y" to "gain", "x" to "hpf", "spread" to "delay"),
        isPremium = true, packId = "studio"),
    Preset("tape", "Tape", "\uD83D\uDCFC", "Warm analog saturation", Triple(0.7f, 0.5f, 0.3f),
        mapOf("y" to "noteIdx", "x" to "lpf", "spread" to "shape"),
        mapOf("y" to "gain", "x" to "crush", "spread" to "reverb"),
        isPremium = true, packId = "studio"),
)
