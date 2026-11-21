package com.handstrudel.models

/**
 * iOS `SoundFontInstrument`. [program] is the 0-based GM program number
 * (TinySoundFont preset on Android). The 128-entry catalog and the free id
 * set are generated into `SoundFontInstrumentCatalog.kt` from the Swift file.
 */
data class SoundFontInstrument(
    val id: String,
    val name: String,
    val emoji: String,
    val program: Int,
    val category: GMCategory = GMCategory.entries[(program / 8).coerceIn(0, GMCategory.entries.size - 1)],
) {
    val displayName: String get() = "$emoji $name"
    val isPremium: Boolean get() = id !in FREE_SOUNDFONT_INSTRUMENT_IDS
    val packId: String? get() = if (isPremium) "pro" else null
}

/** iOS default: Violin. */
val DEFAULT_SOUNDFONT_INSTRUMENT: SoundFontInstrument =
    SOUNDFONT_INSTRUMENTS.firstOrNull { it.id == "violin" } ?: SOUNDFONT_INSTRUMENTS[0]

/** iOS `soundFontInstrument(id:)`: lookup with the default as fallback. */
fun soundFontInstrument(id: String?): SoundFontInstrument =
    SOUNDFONT_INSTRUMENTS.firstOrNull { it.id == id } ?: DEFAULT_SOUNDFONT_INSTRUMENT
