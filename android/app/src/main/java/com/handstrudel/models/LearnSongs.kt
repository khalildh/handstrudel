package com.handstrudel.models

import java.util.UUID

// Port of iOS `Models/LearnSong.swift`. Songs are referenced by a stable
// [LearnSong.id] (iOS uses a random UUID per launch; Android needs an id the
// StudioEngine seam can pass around).

/** A scale-relative note: degree is an index into the grid's scale notes. */
data class LearnDegreeNote(val degree: Int, val startBeat: Double, val durationBeats: Double)

/** A note resolved to an absolute MIDI pitch. */
data class LearnNote(
    val id: UUID,
    val midi: Int,
    val laneIndex: Int,
    val startBeat: Double,
    val durationBeats: Double,
)

enum class LearnSongCategory(val displayName: String) { MELODY("Melodies"), PRACTICE("Practice"), IMPORTED("Imported") }

data class LearnSong(
    val id: String,
    val name: String,
    val emoji: String,
    val bpm: Double,
    val degreeNotes: List<LearnDegreeNote>,
    val category: LearnSongCategory = LearnSongCategory.MELODY,
    val suggestedScale: ScaleSelection = ScaleSelection.BuiltIn(Scale.MAJOR),
    val suggestedKey: MusicKey = MusicKey.C,
) {
    /** iOS `repeated(_:)`: the melody `times` times with a 1-beat gap. */
    fun repeated(times: Int): LearnSong {
        val lastBeat = degreeNotes.lastOrNull()?.let { it.startBeat + it.durationBeats } ?: 0.0
        val all = (0 until times).flatMap { rep ->
            val offset = rep * (lastBeat + 1)
            degreeNotes.map { it.copy(startBeat = it.startBeat + offset) }
        }
        return copy(degreeNotes = all)
    }

    /** iOS `resolve(scaleNotes:)`: clamps each degree into the available lanes. */
    fun resolve(scaleNotes: List<Int>): List<LearnNote> = degreeNotes.map { dn ->
        val d = dn.degree.coerceIn(0, scaleNotes.size - 1)
        LearnNote(UUID.randomUUID(), scaleNotes[d], d, dn.startBeat, dn.durationBeats)
    }

    companion object {
        fun ascending(noteCount: Int, bpm: Double = 120.0) = LearnSong(
            "ascending_$noteCount", "Ascending $noteCount", "⬆️", bpm,
            (0 until noteCount).map { LearnDegreeNote(it, it.toDouble(), 1.0) }, LearnSongCategory.PRACTICE,
        )

        fun descending(noteCount: Int, bpm: Double = 120.0) = LearnSong(
            "descending_$noteCount", "Descending $noteCount", "⬇️", bpm,
            (0 until noteCount).map { LearnDegreeNote(noteCount - 1 - it, it.toDouble(), 1.0) }, LearnSongCategory.PRACTICE,
        )

        fun ascendingDescending(noteCount: Int, bpm: Double = 120.0): LearnSong {
            val peak = noteCount - 1
            val notes = mutableListOf<LearnDegreeNote>()
            for (i in 0..peak) notes += LearnDegreeNote(i, notes.size.toDouble(), 1.0)
            for (i in peak - 1 downTo 0) notes += LearnDegreeNote(i, notes.size.toDouble(), 1.0)
            return LearnSong("updown_$noteCount", "Up & Down $noteCount", "⛰️", bpm, notes, LearnSongCategory.PRACTICE)
        }

        fun arpeggio(noteCount: Int, bpm: Double = 120.0): LearnSong {
            val steps = listOf(0, 2, 4, 7, 9, 11, 14)
            val notes = (0 until noteCount).map { i ->
                LearnDegreeNote(steps[i % steps.size] + (i / steps.size) * 7, i.toDouble(), 1.0)
            }
            return LearnSong("arpeggio_$noteCount", "Arpeggio $noteCount", "🎶", bpm, notes, LearnSongCategory.PRACTICE)
        }

        fun random(noteCount: Int, bpm: Double = 120.0, rng: kotlin.random.Random = kotlin.random.Random.Default) = LearnSong(
            "random_$noteCount", "Random $noteCount", "🎲", bpm,
            (0 until noteCount).map { LearnDegreeNote(rng.nextInt(noteCount), it.toDouble(), 1.0) }, LearnSongCategory.PRACTICE,
        )
    }
}

/** iOS `buildNotes`: (degree, durationBeats) pairs with auto-advancing start beats. */
private fun buildNotes(vararg pairs: Pair<Int, Double>): List<LearnDegreeNote> {
    var beat = 0.0
    return pairs.map { (degree, dur) -> LearnDegreeNote(degree, beat, dur).also { beat += dur } }
}

private fun n(d: Int, b: Number) = d to b.toDouble()

/** iOS `BUNDLED_SONGS`, in order. */
val BUNDLED_SONGS: List<LearnSong> = listOf(
    LearnSong("twinkle_twinkle", "Twinkle Twinkle", "⭐", 100.0, buildNotes(
        n(0, 1), n(0, 1), n(4, 1), n(4, 1), n(5, 1), n(5, 1), n(4, 2),
        n(3, 1), n(3, 1), n(2, 1), n(2, 1), n(1, 1), n(1, 1), n(0, 2),
    )).repeated(3),
    LearnSong("ode_to_joy", "Ode to Joy", "🎵", 108.0, buildNotes(
        n(2, 1), n(2, 1), n(3, 1), n(4, 1), n(4, 1), n(3, 1), n(2, 1), n(1, 1),
        n(0, 1), n(0, 1), n(1, 1), n(2, 1), n(2, 1.5), n(1, 0.5), n(1, 2),
    )).repeated(3),
    LearnSong("mary_had_a_little_lamb", "Mary Had a Little Lamb", "🐑", 110.0, buildNotes(
        n(2, 1), n(1, 1), n(0, 1), n(1, 1), n(2, 1), n(2, 1), n(2, 2),
        n(1, 1), n(1, 1), n(1, 2),
        n(2, 1), n(4, 1), n(4, 2),
    )).repeated(4),
    LearnSong("when_the_saints", "When the Saints", "🎺", 112.0, buildNotes(
        n(0, 1), n(2, 1), n(3, 1), n(4, 2),
        n(0, 1), n(2, 1), n(3, 1), n(4, 2),
        n(0, 1), n(2, 1), n(3, 1), n(4, 1), n(2, 1), n(0, 1), n(2, 1), n(1, 2),
    )).repeated(3),
    LearnSong("amazing_grace", "Amazing Grace", "🕊️", 80.0, buildNotes(
        n(4, 1),
        n(7, 2), n(9, 1), n(7, 2), n(9, 2), n(7, 2),
        n(5, 2), n(4, 2), n(2, 2), n(4, 1), n(4, 2),
    )).repeated(3),
    LearnSong("frere_jacques", "Frere Jacques", "🔔", 120.0, buildNotes(
        n(0, 1), n(1, 1), n(2, 1), n(0, 1),
        n(0, 1), n(1, 1), n(2, 1), n(0, 1),
        n(2, 1), n(3, 1), n(4, 2),
        n(2, 1), n(3, 1), n(4, 2),
    )).repeated(3),
    LearnSong("jingle_bells", "Jingle Bells", "🎄", 130.0, buildNotes(
        n(2, 1), n(2, 1), n(2, 2),
        n(2, 1), n(2, 1), n(2, 2),
        n(2, 1), n(4, 1), n(0, 1.5), n(1, 0.5), n(2, 2),
    )).repeated(3),
    LearnSong("scarborough_fair", "Scarborough Fair", "🌿", 90.0, buildNotes(
        n(5, 2), n(5, 1), n(5, 1), n(2, 2),
        n(5, 1), n(6, 1), n(5, 2),
        n(4, 2), n(2, 2),
    ), suggestedScale = ScaleSelection.BuiltIn(Scale.MINOR), suggestedKey = MusicKey.A).repeated(4),
)

/** The picker's Practice row (iOS `LearnSongPicker`): label → generator. */
val PRACTICE_SONG_IDS: List<String> = listOf("ascending_10", "descending_10", "arpeggio_14", "random_12")

/**
 * Look up a song by id. Practice ids build a fresh song each time (Random
 * reshuffles, like tapping it again on iOS).
 */
fun learnSong(id: String): LearnSong? = BUNDLED_SONGS.firstOrNull { it.id == id } ?: when (id) {
    "ascending_10" -> LearnSong.ascending(10)
    "descending_10" -> LearnSong.descending(10)
    "arpeggio_14" -> LearnSong.arpeggio(14)
    "random_12" -> LearnSong.random(12)
    "updown_10" -> LearnSong.ascendingDescending(10)
    else -> null
}
