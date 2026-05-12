package com.handstrudel.models

enum class MusicKey(val displayName: String, val semitone: Int) {
    C("C", 0), Db("Db", 1), D("D", 2), Eb("Eb", 3),
    E("E", 4), F("F", 5), Gb("Gb", 6), G("G", 7),
    Ab("Ab", 8), A("A", 9), Bb("Bb", 10), B("B", 11);
}

enum class Scale(val displayName: String, val intervals: List<Int>, val isPremium: Boolean = false) {
    MAJOR("Major", listOf(0, 2, 4, 5, 7, 9, 11)),
    MINOR("Minor", listOf(0, 2, 3, 5, 7, 8, 10)),
    DORIAN("Dorian", listOf(0, 2, 3, 5, 7, 9, 10)),
    PENTATONIC("Pentatonic", listOf(0, 2, 4, 7, 9)),
    BLUES("Blues", listOf(0, 3, 5, 6, 7, 10)),
    HARMONIC_MINOR("Harmonic Minor", listOf(0, 2, 3, 5, 7, 8, 11), true),
    MELODIC_MINOR("Melodic Minor", listOf(0, 2, 3, 5, 7, 9, 11), true),
    PHRYGIAN("Phrygian", listOf(0, 1, 3, 5, 7, 8, 10), true),
    LYDIAN("Lydian", listOf(0, 2, 4, 6, 7, 9, 11), true),
    MIXOLYDIAN("Mixolydian", listOf(0, 2, 4, 5, 7, 9, 10), true),
    LOCRIAN("Locrian", listOf(0, 1, 3, 5, 6, 8, 10), true),
    WHOLE_TONE("Whole Tone", listOf(0, 2, 4, 6, 8, 10), true),
    CHROMATIC("Chromatic", listOf(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11), true),
    HUNGARIAN_MINOR("Hungarian Minor", listOf(0, 2, 3, 6, 7, 8, 11), true),
    HIRAJOSHI("Hirajoshi", listOf(0, 2, 3, 7, 8), true);

    val packId: String? get() = if (isPremium) "pro" else null
}

private val NOTE_NAMES = listOf("C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B")
private val STRUDEL_NAMES = listOf("c", "db", "d", "eb", "e", "f", "gb", "g", "ab", "a", "bb", "b")

fun scaleNotes(key: MusicKey, scale: Scale, baseOctave: Int = 2, octaveRange: Int = 4): List<Int> {
    val notes = mutableListOf<Int>()
    val endOctave = baseOctave + octaveRange - 1
    for (octave in baseOctave..endOctave) {
        val base = (octave + 1) * 12 + key.semitone
        for (interval in scale.intervals) {
            val midi = base + interval
            if (midi <= 96) notes.add(midi)
        }
    }
    return notes
}

fun chordNotes(key: MusicKey, scale: Scale, degree: Int): List<Int> {
    val intervals = scale.intervals
    val count = intervals.size
    if (count == 0) return listOf(60)
    val safeDegree = ((degree % count) + count) % count

    val root = 48 + key.semitone + intervals[safeDegree]
    val thirdDeg = (safeDegree + 2) % count
    var third = 48 + key.semitone + intervals[thirdDeg]
    if (third <= root) third += 12
    val fifthDeg = (safeDegree + 4) % count
    var fifth = 48 + key.semitone + intervals[fifthDeg]
    if (fifth <= third) fifth += 12

    return listOf(root, third, fifth)
}

fun midiNoteName(midi: Int): String {
    val name = NOTE_NAMES[((midi % 12) + 12) % 12]
    val octave = midi / 12 - 1
    return "$name$octave"
}

fun midiToStrudelNote(midi: Int): String {
    val name = STRUDEL_NAMES[((midi % 12) + 12) % 12]
    val octave = midi / 12 - 1
    return "$name$octave"
}
