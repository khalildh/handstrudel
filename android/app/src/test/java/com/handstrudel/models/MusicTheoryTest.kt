package com.handstrudel.models

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Ports of iOS MusicTheoryTests / ChordProgressionTests expectations. */
class MusicTheoryTest {
    private val major = ScaleSelection.BuiltIn(Scale.MAJOR)

    @Test fun scaleNotes_octaves2to5CappedAtC6() {
        val notes = scaleNotes(MusicKey.C, major)
        assertEquals(36, notes.first())
        assertEquals(83, notes.last())
        assertEquals(28, notes.size)
        assertEquals(listOf(48, 50, 52, 53, 55, 57, 59), scaleNotes(MusicKey.C, major, 3, 1))
        assertEquals(96, scaleNotes(MusicKey.C, major, 6, 3).last())
    }

    @Test fun chords_triadsSeventhsAndNames() {
        assertEquals(listOf(48, 52, 55), chordNotes(MusicKey.C, major, 0))
        assertEquals(listOf(57, 60, 64), chordNotes(MusicKey.C, major, 5))
        assertEquals(listOf(55, 59, 62, 65), chordNotesWithSeventh(MusicKey.C, major, 4))
        assertEquals("Cmaj", chordDisplayName(MusicKey.C, major, 0))
        assertEquals("Amin", chordDisplayName(MusicKey.C, major, 5))
        assertEquals("Bdim", chordDisplayName(MusicKey.C, major, 6))
        assertEquals("Dbmaj", chordDisplayName(MusicKey.Db, major, 7)) // wraps
        assertEquals(listOf(60, 62, 64, 65, 67, 69, 71), scaleNotesOneOctave(MusicKey.C, major))
    }

    @Test fun customScales_useTheirIntervals() {
        val custom = ScaleSelection.Custom(CustomScale.create(name = "Tri", intervals = listOf(0, 4, 7))!!)
        assertEquals(listOf(48, 55, 64), chordNotes(MusicKey.C, custom, 0))
        assertEquals(listOf(48, 55, 64, 72), chordNotesWithSeventh(MusicKey.C, custom, 0))
        assertEquals(listOf(60, 64, 67), scaleNotesOneOctave(MusicKey.C, custom))
        assertEquals("Custom", custom.rawValue)
        assertEquals(custom.scale.id.toString().uppercase(), custom.id)
    }

    @Test fun noteNames() {
        assertEquals("C4", midiNoteName(60))
        assertEquals("Eb", pitchClassName(63))
        assertEquals("db5", midiToStrudelNote(73))
        assertEquals(2, midiToLaneIndex(64, listOf(60, 62, 64)))
        assertEquals(64, quantizeToScale(63, listOf(60, 64, 67)))
    }

    @Test fun progressionParse_acceptsIosNotations() {
        val pop = listOf(0, 4, 5, 3)
        for (text in listOf("I V vi IV", "1 5 6 4", "I-V-vi-IV", "I, V, vi, IV", "I → V → vi → IV", "I/V/vi/IV", "Imaj7 V7 vi9 IVadd9")) {
            assertEquals(text, pop, ChordProgression.parse(text)?.degrees)
        }
        assertEquals(listOf(1, 4, 0), ChordProgression.parse("ii7 V7 Imaj7")?.degrees)
        assertEquals(listOf(0, 3, 4), ChordProgression.parse("i iv v")?.degrees)
        assertEquals(listOf(2), ChordProgression.parse("3rd")?.degrees)
        assertEquals(listOf(0, 6), ChordProgression.parse("1 8 9 vii°")?.degrees)
        assertNull(ChordProgression.parse("hello"))
        assertNull(ChordProgression.parse(""))
        val custom = ChordProgression.parse("1 4 5 1")!!
        assertEquals("custom", custom.id)
        assertEquals(true, custom.isCustom)
        assertEquals(null, custom.packId)
        assertEquals(ProgressionCategory.CUSTOM, custom.category)
    }

    @Test fun soundSetup_customProgressionResolvesThroughParse() {
        val setup = SoundSetup(
            instrument = "violin", waveform = "sine", key = MusicKey.C, scale = major, progression = "custom",
            customDegrees = listOf(0, 3, 4), mode = SoundSetupMode.SCALE_CHORD_MELODY, bpm = 100.0, useSoundFont = true,
            autoStrum = false, padVolume = 0.6, gridOctave = 3, gridRange = 2,
        )
        assertEquals(listOf(0, 3, 4), setup.resolvedProgression?.degrees)
        assertEquals("C Major · 100 BPM · 1-4-5", setup.presetDetails)
        assertEquals(emptyList<String>(), setup.requiredPacks)
        val pro = setup.copy(progression = "blues12", customDegrees = null, instrument = "harpsichord", scale = ScaleSelection.BuiltIn(Scale.LYDIAN))
        assertEquals(listOf("pro", "pro", "pro"), pro.requiredPacks)
        assertEquals("C Lydian · 100 BPM · 12-Bar Blues", pro.presetDetails)
    }
}
