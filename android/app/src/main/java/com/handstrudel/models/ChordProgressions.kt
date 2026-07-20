package com.handstrudel.models

/// A chord progression — a sequence of scale degrees the player can dial
/// between. With the default [`FREE`], all seven diatonic chords are available;
/// the named progressions restrict the chord-hand zones to a subset, which
/// makes the wheel easier to play and the result more "musical" by default.
data class ChordProgression(
    val id: String,
    val name: String,
    val emoji: String,
    val degrees: List<Int>,
)

val CHORD_PROGRESSIONS: List<ChordProgression> = listOf(
    ChordProgression("free", "Free", "🎛️", listOf(0, 1, 2, 3, 4, 5, 6)),
    ChordProgression("pop", "Pop", "🎤", listOf(0, 4, 5, 3)),
    ChordProgression("sad_pop", "Sad Pop", "🌧️", listOf(5, 3, 0, 4)),
    ChordProgression("fifties", "50s", "🪩", listOf(0, 5, 3, 4)),
    ChordProgression("doo_wop", "Doo-Wop", "🎶", listOf(0, 5, 1, 4)),
    ChordProgression("andalusian", "Andalusian", "🌅", listOf(0, 6, 5, 4)),
    ChordProgression("jazz", "Jazz ii-V-I", "🎷", listOf(1, 4, 0, 5)),
    ChordProgression("blues", "Blues", "🎸", listOf(0, 3, 4)),
    ChordProgression("minor_vamp", "Minor Vamp", "🕯️", listOf(0, 5, 3)),
)

val FREE_PROGRESSION: ChordProgression = CHORD_PROGRESSIONS[0]
