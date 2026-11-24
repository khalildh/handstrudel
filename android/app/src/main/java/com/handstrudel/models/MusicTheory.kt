package com.handstrudel.models

/** iOS `MusicKey`. The enum names are the wire raw values (`"Db"`). */
enum class MusicKey(val displayName: String, val semitone: Int) {
    C("C", 0), Db("Db", 1), D("D", 2), Eb("Eb", 3),
    E("E", 4), F("F", 5), Gb("Gb", 6), G("G", 7),
    Ab("Ab", 8), A("A", 9), Bb("Bb", 10), B("B", 11);

    /** iOS `MusicKey.rawValue`. */
    val rawValue: String get() = name

    companion object {
        fun fromRaw(raw: String?): MusicKey? = entries.firstOrNull { it.name == raw }
    }
}

/**
 * iOS `BuiltInScale` (`Models/MusicTheory.swift`): the 23 built-in scales, in
 * iOS order. [rawValue] is the wire/persistence name; [displayName] is what
 * the UI shows (iOS renames Pentatonic → "Major Pentatonic", Blues → "Minor Blues").
 */
enum class Scale(val rawValue: String, val intervals: List<Int>) {
    MAJOR("Major", listOf(0, 2, 4, 5, 7, 9, 11)),
    MINOR("Minor", listOf(0, 2, 3, 5, 7, 8, 10)),
    DORIAN("Dorian", listOf(0, 2, 3, 5, 7, 9, 10)),
    PENTATONIC("Pentatonic", listOf(0, 2, 4, 7, 9)),
    BLUES("Blues", listOf(0, 3, 5, 6, 7, 10)),
    HARMONIC_MINOR("Harmonic Minor", listOf(0, 2, 3, 5, 7, 8, 11)),
    MELODIC_MINOR("Melodic Minor", listOf(0, 2, 3, 5, 7, 9, 11)),
    PHRYGIAN("Phrygian", listOf(0, 1, 3, 5, 7, 8, 10)),
    LYDIAN("Lydian", listOf(0, 2, 4, 6, 7, 9, 11)),
    MIXOLYDIAN("Mixolydian", listOf(0, 2, 4, 5, 7, 9, 10)),
    LOCRIAN("Locrian", listOf(0, 1, 3, 5, 6, 8, 10)),
    WHOLE_TONE("Whole Tone", listOf(0, 2, 4, 6, 8, 10)),
    CHROMATIC("Chromatic", listOf(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11)),
    HUNGARIAN_MINOR("Hungarian Minor", listOf(0, 2, 3, 6, 7, 8, 11)),
    HIRAJOSHI("Hirajoshi", listOf(0, 2, 3, 7, 8)),
    MINOR_PENTATONIC("Minor Pentatonic", listOf(0, 3, 5, 7, 10)),
    MAJOR_BLUES("Major Blues", listOf(0, 2, 3, 4, 7, 9)),
    PHRYGIAN_DOMINANT("Phrygian Dominant", listOf(0, 1, 4, 5, 7, 8, 10)),
    DIMINISHED("Diminished (Half-Whole)", listOf(0, 1, 3, 4, 6, 7, 9, 10)),
    HARMONIC_MAJOR("Harmonic Major", listOf(0, 2, 4, 5, 7, 8, 11)),
    LYDIAN_DOMINANT("Lydian Dominant", listOf(0, 2, 4, 6, 7, 9, 10)),
    ALTERED("Altered", listOf(0, 1, 3, 4, 6, 8, 10)),
    DOMINANT_BEBOP("Dominant Bebop", listOf(0, 2, 4, 5, 7, 9, 10, 11));

    val displayName: String
        get() = when (this) {
            PENTATONIC -> "Major Pentatonic"
            BLUES -> "Minor Blues"
            else -> rawValue
        }

    val isPremium: Boolean get() = this !in FREE_SCALES

    val packId: String? get() = if (isPremium) "pro" else null

    companion object {
        val FREE_SCALES: Set<Scale> = setOf(MAJOR, MINOR, DORIAN, PENTATONIC, BLUES)
        fun fromRaw(raw: String): Scale? = entries.firstOrNull { it.rawValue == raw }
    }
}

/** iOS `CIRCLE_OF_FIFTHS`. */
val CIRCLE_OF_FIFTHS: List<MusicKey> = listOf(
    MusicKey.C, MusicKey.G, MusicKey.D, MusicKey.A, MusicKey.E, MusicKey.B,
    MusicKey.Gb, MusicKey.Db, MusicKey.Ab, MusicKey.Eb, MusicKey.Bb, MusicKey.F,
)

private val NOTE_NAMES = listOf("C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B")
private val STRUDEL_NAMES = listOf("c", "db", "d", "eb", "e", "f", "gb", "g", "ab", "a", "bb", "b")

// ---- Note generation (interval-based; mirrors Swift and the Rust core) ----------------

/** Swift `scaleNotes(key:scale:)`: octaves 2–5, capped at C6 (84). */
fun scaleNotes(key: MusicKey, intervals: List<Int>): List<Int> {
    val notes = mutableListOf<Int>()
    for (octave in 2..5) {
        val base = (octave + 1) * 12 + key.semitone
        for (interval in intervals) {
            val midi = base + interval
            if (midi <= 84) notes.add(midi)
        }
    }
    return notes
}

/** Swift `scaleNotes(key:scale:baseOctave:octaveRange:)`: capped at C7 (96). */
fun scaleNotes(key: MusicKey, intervals: List<Int>, baseOctave: Int, octaveRange: Int): List<Int> {
    val notes = mutableListOf<Int>()
    val endOctave = baseOctave + octaveRange - 1
    for (octave in baseOctave..endOctave) {
        val base = (octave + 1) * 12 + key.semitone
        for (interval in intervals) {
            val midi = base + interval
            if (midi <= 96) notes.add(midi)
        }
    }
    return notes
}

/** Kept for existing callers: `baseOctave`/`octaveRange` default to the full 2–5 range (capped at 96). */
fun scaleNotes(key: MusicKey, scale: Scale, baseOctave: Int = 2, octaveRange: Int = 4): List<Int> =
    scaleNotes(key, scale.intervals, baseOctave, octaveRange)

fun scaleNotes(key: MusicKey, scale: ScaleSelection): List<Int> = scaleNotes(key, scale.intervals)

fun scaleNotes(key: MusicKey, scale: ScaleSelection, baseOctave: Int, octaveRange: Int): List<Int> =
    scaleNotes(key, scale.intervals, baseOctave, octaveRange)

/** Swift `chordNotes`: root/third/fifth, root in octave 3. */
fun chordNotes(key: MusicKey, intervals: List<Int>, degree: Int): List<Int> {
    val count = intervals.size
    if (count == 0) return listOf(60)
    val safeDegree = ((degree % count) + count) % count
    val root = 48 + key.semitone + intervals[safeDegree]
    var third = 48 + key.semitone + intervals[(safeDegree + 2) % count]
    if (third <= root) third += 12
    var fifth = 48 + key.semitone + intervals[(safeDegree + 4) % count]
    while (fifth <= third) fifth += 12
    return listOf(root, third, fifth)
}

fun chordNotes(key: MusicKey, scale: Scale, degree: Int): List<Int> = chordNotes(key, scale.intervals, degree)
fun chordNotes(key: MusicKey, scale: ScaleSelection, degree: Int): List<Int> = chordNotes(key, scale.intervals, degree)

/** Swift `chordNotesWithSeventh`: triad plus the diatonic 7th (Scale mode). */
fun chordNotesWithSeventh(key: MusicKey, intervals: List<Int>, degree: Int): List<Int> {
    val triad = chordNotes(key, intervals, degree)
    val count = intervals.size
    if (count == 0) return triad
    val fifth = triad.last()
    val safeDegree = ((degree % count) + count) % count
    var seventh = 48 + key.semitone + intervals[(safeDegree + 6) % count]
    while (seventh <= fifth) seventh += 12
    return triad + seventh
}

fun chordNotesWithSeventh(key: MusicKey, scale: ScaleSelection, degree: Int): List<Int> =
    chordNotesWithSeventh(key, scale.intervals, degree)

/** Swift `scaleNotesOneOctave(key:scale:octave:)`. */
fun scaleNotesOneOctave(key: MusicKey, intervals: List<Int>, octave: Int = 4): List<Int> {
    val base = (octave + 1) * 12 + key.semitone
    return intervals.map { base + it }
}

fun scaleNotesOneOctave(key: MusicKey, scale: ScaleSelection, octave: Int = 4): List<Int> =
    scaleNotesOneOctave(key, scale.intervals, octave)

/** Swift `chordDisplayName`: "Cmaj", "Amin", "Bdim", "Caug" or just the root. */
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

fun chordDisplayName(key: MusicKey, scale: ScaleSelection, degree: Int): String =
    chordDisplayName(key, scale.intervals, degree)

fun midiNoteName(midi: Int): String {
    val name = NOTE_NAMES[((midi % 12) + 12) % 12]
    val octave = midi / 12 - 1
    return "$name$octave"
}

/** Swift `pitchClassName`: note letter without the octave. */
fun pitchClassName(midi: Int): String = NOTE_NAMES[((midi % 12) + 12) % 12]

fun midiToStrudelNote(midi: Int): String {
    val name = STRUDEL_NAMES[((midi % 12) + 12) % 12]
    val octave = midi / 12 - 1
    return "$name$octave"
}

/** Swift `midiToLaneIndex`. */
fun midiToLaneIndex(midi: Int, scaleNotes: List<Int>): Int {
    if (scaleNotes.isEmpty()) return 0
    var best = 0
    var bestDist = Int.MAX_VALUE
    scaleNotes.forEachIndexed { i, n ->
        val d = kotlin.math.abs(n - midi)
        if (d < bestDist) { bestDist = d; best = i }
    }
    return best
}

/** Swift `quantizeToScale`. */
fun quantizeToScale(midi: Int, scaleNotes: List<Int>): Int =
    scaleNotes.minByOrNull { kotlin.math.abs(it - midi) } ?: midi
