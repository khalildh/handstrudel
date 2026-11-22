package com.handstrudel.models

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Catalog parity with iOS 1.0.1 (SoundFontInstrumentTests, ChordProgressionTests, CameraFilterTests, …). */
class CatalogTest {

    @Test fun instruments_are128GmProgramsInOrderWithIosFreeSet() {
        assertEquals(128, SOUNDFONT_INSTRUMENTS.size)
        SOUNDFONT_INSTRUMENTS.forEachIndexed { i, inst ->
            assertEquals(i, inst.program)
            assertEquals(GMCategory.entries[i / 8], inst.category)
        }
        assertEquals(SOUNDFONT_INSTRUMENTS.size, SOUNDFONT_INSTRUMENTS.map { it.id }.toSet().size)
        assertEquals(
            setOf("grand_piano", "electric_piano_1", "nylon_guitar", "clean_guitar", "acoustic_bass", "violin", "strings", "choir"),
            FREE_SOUNDFONT_INSTRUMENT_IDS,
        )
        assertTrue(FREE_SOUNDFONT_INSTRUMENT_IDS.all { id -> SOUNDFONT_INSTRUMENTS.any { it.id == id } })
        SOUNDFONT_INSTRUMENTS.forEach { assertEquals(if (it.id in FREE_SOUNDFONT_INSTRUMENT_IDS) null else "pro", it.packId) }
        assertEquals(16, GMCategory.entries.size)
        assertEquals("Mallets", GMCategory.CHROMATIC_PERCUSSION.displayName)
    }

    @Test fun instruments_defaultIsViolinAndLookupFallsBack() {
        assertEquals("violin", DEFAULT_SOUNDFONT_INSTRUMENT.id)
        assertEquals("Rhodes EP", soundFontInstrument("electric_piano_1").name)
        assertEquals(DEFAULT_SOUNDFONT_INSTRUMENT, soundFontInstrument("does-not-exist"))
        val inst = soundFontInstrument("grand_piano")
        assertTrue(inst.displayName.contains(inst.name) && inst.displayName.contains(inst.emoji))
    }

    @Test fun progressions_matchIosLibrary() {
        assertEquals(144, CHORD_PROGRESSIONS.size)
        assertEquals(CHORD_PROGRESSIONS.size, CHORD_PROGRESSIONS.map { it.id }.toSet().size)
        CHORD_PROGRESSIONS.forEach { p ->
            assertTrue(p.id, p.degrees.isNotEmpty() && p.degrees.all { it in 0..6 })
            assertEquals(p.category != ProgressionCategory.ESSENTIALS, p.isPremium)
        }
        assertEquals(listOf(0, 1, 2, 3, 4, 5, 6), chordProgression("free")?.degrees)
        assertEquals(9, CHORD_PROGRESSIONS.count { !it.isPremium })
        assertEquals("pop", DEFAULT_PROGRESSION.id)
        assertEquals(14, ProgressionCategory.entries.size)
        assertEquals(listOf(0, 0, 0, 0, 3, 3, 0, 0, 4, 3, 0, 4), chordProgression("blues12")?.degrees)
        assertEquals("Long-form", ProgressionCategory.LONG_FORM.displayName)
        // Every built-in category except Custom has at least one progression.
        ProgressionCategory.entries.filter { it != ProgressionCategory.CUSTOM }
            .forEach { c -> assertTrue(c.name, CHORD_PROGRESSIONS.any { it.category == c }) }
    }

    @Test fun scales_are23WithIosRawAndDisplayNames() {
        assertEquals(23, Scale.entries.size)
        assertEquals(setOf(Scale.MAJOR, Scale.MINOR, Scale.DORIAN, Scale.PENTATONIC, Scale.BLUES), Scale.entries.filter { !it.isPremium }.toSet())
        assertEquals("Pentatonic", Scale.PENTATONIC.rawValue)
        assertEquals("Major Pentatonic", Scale.PENTATONIC.displayName)
        assertEquals("Minor Blues", Scale.BLUES.displayName)
        assertEquals(Scale.DIMINISHED, Scale.fromRaw("Diminished (Half-Whole)"))
        assertEquals(listOf(0, 2, 4, 5, 7, 9, 10, 11), Scale.DOMINANT_BEBOP.intervals)
        Scale.entries.forEach { s ->
            assertEquals(0, s.intervals.first())
            assertEquals(s.intervals.sorted(), s.intervals)
            assertTrue(s.intervals.last() < 12)
            assertEquals(s.packId, if (s.isPremium) "pro" else null)
        }
    }

    @Test fun waveforms_matchIosList() {
        assertEquals(38, WAVEFORMS.size)
        assertEquals(8, WAVEFORMS.indexOfFirst { it.id == "piano" })
        assertTrue(WAVEFORMS.none { it.isPremium })
        assertEquals(WAVEFORMS.size, WAVEFORMS.map { it.id }.toSet().size)
    }

    @Test fun drumLoops_matchIosAndPremiumUseKits() {
        assertEquals(24, DRUM_LOOPS.size)
        assertEquals("none", DRUM_LOOPS[0].id)
        assertEquals("", DRUM_LOOPS[0].code)
        assertEquals(6, DRUM_LOOPS.count { !it.isPremium })
        DRUM_LOOPS.filter { it.isPremium }.forEach { assertTrue(it.packId in setOf("kit_808", "kit_electronic")) }
        assertFalse("variable references must be expanded", DRUM_LOOPS.any { "\\(" in it.code || "_deepKick" in it.code })
        assertTrue(drumLoop("basic").code.startsWith("stack(note(\"f1\").s(\"triangle\")"))
        assertEquals("none", drumLoop("missing").id)
    }

    @Test fun learnSongs_bundledEightPlusPractice() {
        assertEquals(8, BUNDLED_SONGS.size)
        assertEquals(BUNDLED_SONGS.size, BUNDLED_SONGS.map { it.id }.toSet().size)
        val twinkle = BUNDLED_SONGS[0]
        assertEquals("Twinkle Twinkle", twinkle.name)
        assertEquals(14 * 3, twinkle.degreeNotes.size)
        // repeated(3): 1-beat gap after the 16-beat phrase.
        assertEquals(17.0, twinkle.degreeNotes[14].startBeat, 0.0)
        val scarborough = BUNDLED_SONGS.last()
        assertEquals(ScaleSelection.BuiltIn(Scale.MINOR), scarborough.suggestedScale)
        assertEquals(MusicKey.A, scarborough.suggestedKey)
        assertEquals(10, learnSong("ascending_10")!!.degreeNotes.size)
        assertEquals(14, learnSong("arpeggio_14")!!.degreeNotes.size)
        assertEquals(listOf(0, 2, 4, 7, 9, 11, 14, 7, 9, 11, 14, 16, 18, 21), learnSong("arpeggio_14")!!.degreeNotes.map { it.degree })
        assertEquals(12, learnSong("random_12")!!.degreeNotes.size)
        PRACTICE_SONG_IDS.forEach { assertTrue(learnSong(it) != null) }
        assertNull(learnSong("nope"))
    }

    @Test fun learnSong_resolveClampsDegrees() {
        val song = LearnSong("t", "T", "T", 120.0, listOf(LearnDegreeNote(9, 0.0, 1.0), LearnDegreeNote(-1, 1.0, 1.0)))
        val notes = song.resolve(listOf(60, 62, 64))
        assertEquals(listOf(64, 60), notes.map { it.midi })
        assertEquals(listOf(2, 0), notes.map { it.laneIndex })
    }

    @Test fun cameraFiltersAndHandThemes_matchIos() {
        assertEquals(23, CAMERA_FILTERS.size)
        val none = cameraFilter("none")
        assertEquals(1.0, none.saturation, 0.0)
        assertEquals(1.0, none.contrast, 0.0)
        assertEquals(0.0, none.brightness, 0.0)
        assertNull(none.overlayColor)
        assertFalse(none.isPremium)
        assertEquals(0.0, cameraFilter("noir").saturation, 0.0)
        assertEquals(setOf("filter_pack"), CAMERA_FILTERS.filter { it.isPremium }.mapNotNull { it.packId }.toSet())
        assertTrue(CAMERA_FILTERS.count { !it.isPremium } >= 5)
        assertEquals(CAMERA_FILTERS.size, CAMERA_FILTERS.map { it.id }.toSet().size)
        assertEquals(7, HAND_THEMES.size)
        assertEquals("default", HAND_THEMES[0].id)
        assertEquals(5, HAND_THEMES.count { it.isPremium && it.packId == "visual_pack" })
        assertEquals(FilterColor(0.0, 1.0, 0.62), handTheme("default").leftColor)
    }
}
