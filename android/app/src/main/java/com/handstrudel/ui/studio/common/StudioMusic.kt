package com.handstrudel.ui.studio.common

import com.handstrudel.models.MusicKey

/**
 * Display-side music helpers for the studio overlays, ported from iOS
 * `Models/MusicTheory.swift`. They take raw scale intervals so built-in and
 * custom scales work the same (the Rust core only knows built-in scales).
 * Pure Kotlin: unit-tested on the JVM.
 */
object StudioMusic {
    private val NOTE_NAMES = listOf("C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B")

    /** iOS `chordNotes`: root/third/fifth from octave 3. */
    fun chordNotes(key: MusicKey, intervals: List<Int>, degree: Int): List<Int> {
        val count = intervals.size
        if (count == 0) return listOf(60)
        val d = ((degree % count) + count) % count
        val root = 48 + key.semitone + intervals[d]
        var third = 48 + key.semitone + intervals[(d + 2) % count]
        if (third <= root) third += 12
        var fifth = 48 + key.semitone + intervals[(d + 4) % count]
        while (fifth <= third) fifth += 12
        return listOf(root, third, fifth)
    }

    /** iOS `chordNotesWithSeventh` (Scale mode voicing). */
    fun chordNotesWithSeventh(key: MusicKey, intervals: List<Int>, degree: Int): List<Int> {
        val triad = chordNotes(key, intervals, degree)
        val count = intervals.size
        if (count == 0) return triad
        val d = ((degree % count) + count) % count
        var seventh = 48 + key.semitone + intervals[(d + 6) % count]
        while (seventh <= triad.last()) seventh += 12
        return triad + seventh
    }

    /** iOS `scaleNotesOneOctave` (Scale mode melody side). */
    fun scaleNotesOneOctave(key: MusicKey, intervals: List<Int>, octave: Int = 4): List<Int> {
        val base = (octave + 1) * 12 + key.semitone
        return intervals.map { base + it }
    }

    /** iOS `scaleNotes(key:scale:baseOctave:octaveRange:)` (Grid/Learn lanes). */
    fun scaleNotes(key: MusicKey, intervals: List<Int>, baseOctave: Int, octaveRange: Int): List<Int> {
        val notes = mutableListOf<Int>()
        for (octave in baseOctave until baseOctave + octaveRange) {
            val base = (octave + 1) * 12 + key.semitone
            for (interval in intervals) {
                val midi = base + interval
                if (midi <= 96) notes.add(midi)
            }
        }
        return notes
    }

    fun midiNoteName(midi: Int): String = NOTE_NAMES[((midi % 12) + 12) % 12] + (midi / 12 - 1)

    fun pitchClassName(midi: Int): String = NOTE_NAMES[((midi % 12) + 12) % 12]

    /** iOS `chordDisplayName`: "Cmaj", "Dmin", "Bdim", "Caug" or just the root. */
    fun chordDisplayName(key: MusicKey, intervals: List<Int>, degree: Int): String {
        val count = intervals.size
        if (count == 0) return NOTE_NAMES[key.semitone]
        val d = ((degree % count) + count) % count
        val rootName = NOTE_NAMES[(key.semitone + intervals[d]) % 12]
        val third = ((intervals[(d + 2) % count] - intervals[d]) % 12 + 12) % 12
        val fifth = ((intervals[(d + 4) % count] - intervals[d]) % 12 + 12) % 12
        val quality = when {
            third == 4 && fifth == 7 -> "maj"
            third == 3 && fifth == 7 -> "min"
            third == 3 && fifth == 6 -> "dim"
            third == 4 && fifth == 8 -> "aug"
            else -> ""
        }
        return rootName + quality
    }

    /** ContentView `splitChordNames`: Scale mode adds "⁷". */
    fun splitChordNames(key: MusicKey, intervals: List<Int>, zoneDegrees: List<Int>, scaleMode: Boolean): List<String> =
        zoneDegrees.map { chordDisplayName(key, intervals, it) + if (scaleMode) "⁷" else "" }

    /** ContentView `splitMelodyMidis`: Split = triad × 3 octaves (9), Scale = one octave of the scale. */
    fun splitMelodyMidis(key: MusicKey, intervals: List<Int>, melodyDegree: Int, scaleMode: Boolean): List<Int> {
        if (scaleMode) return scaleNotesOneOctave(key, intervals)
        val triad = chordNotes(key, intervals, melodyDegree)
        return (0 until 3).flatMap { oct -> triad.map { it + oct * 12 } }.sorted()
    }

    /** ContentView `splitChordToneLanes`: Scale mode lanes that are tones of the active 7th chord. */
    fun splitChordToneLanes(key: MusicKey, intervals: List<Int>, melodyMidis: List<Int>, melodyDegree: Int, scaleMode: Boolean): Set<Int> {
        if (!scaleMode) return emptySet()
        val classes = chordNotesWithSeventh(key, intervals, melodyDegree).map { it % 12 }.toSet()
        return melodyMidis.withIndex().filter { (it.value % 12) in classes }.map { it.index }.toSet()
    }

    /** iOS `SoundArtworkVoice.previewNotes`: first chord of the progression (+ root octave), or 4 scale notes for Free. */
    fun previewNotes(key: MusicKey, intervals: List<Int>, progressionId: String, degrees: List<Int>): List<Int> {
        val first = degrees.firstOrNull()
        if (progressionId == "free" || first == null) return scaleNotesOneOctave(key, intervals).take(4)
        val chord = chordNotes(key, intervals, first)
        return chord + (chord.first() + 12)
    }
}
