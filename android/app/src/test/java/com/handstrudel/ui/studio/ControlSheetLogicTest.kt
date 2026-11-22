package com.handstrudel.ui.studio

import com.handstrudel.engine.StudioMode
import com.handstrudel.models.MusicKey
import com.handstrudel.models.NamedSoundSetup
import com.handstrudel.models.PARAM_MAP
import com.handstrudel.models.Scale
import com.handstrudel.models.ScaleSelection
import com.handstrudel.models.SoundSetup
import com.handstrudel.models.SoundSetupMode
import com.handstrudel.ui.studio.sheet.ControlSheetLogic
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

class ControlSheetLogicTest {

    // ---- Custom progression parser (iOS ChordProgression.parse) ----

    @Test
    fun parsesNumbersToZeroBasedDegrees() {
        assertEquals(listOf(0, 3, 4, 0), ControlSheetLogic.parseProgressionDegrees("1 4 5 1"))
    }

    @Test
    fun parsesRomanNumeralsAndSeparatorsLikeIos() {
        val pop = listOf(0, 4, 5, 3)
        listOf("I V vi IV", "1 5 6 4", "I-V-vi-IV", "I, V, vi, IV", "I → V → vi → IV", "Imaj7 V7 vi9 IVadd9", "i|v|VI/iv")
            .forEach { assertEquals(it, pop, ControlSheetLogic.parseProgressionDegrees(it)) }
        assertEquals(listOf(6, 1, 2), ControlSheetLogic.parseProgressionDegrees("vii° ii iii"))
        assertEquals(listOf(2), ControlSheetLogic.parseProgressionDegrees("3rd"))
    }

    @Test
    fun skipsOutOfRangeAndUnknownTokens() {
        assertEquals(listOf(0, 6), ControlSheetLogic.parseProgressionDegrees("1 0 8 x 7 viii9 99999999999"))
        assertNull(ControlSheetLogic.parseProgressionDegrees(""))
        assertNull(ControlSheetLogic.parseProgressionDegrees("  - , "))
        assertNull(ControlSheetLogic.parseProgressionDegrees("0 8 9 hello"))
    }

    @Test
    fun noUpperBoundOnCountLikeIos() {
        val text = List(70) { "1" }.joinToString(" ")
        assertEquals(70, ControlSheetLogic.parseProgressionDegrees(text)?.size)
    }

    @Test
    fun customProgressionUsesRomanLabelAndCustomId() {
        val prog = ControlSheetLogic.customProgression("1 4 5 1")!!
        assertEquals("custom", prog.id)
        assertEquals("I IV V I", prog.name)
        assertEquals("✍️", prog.emoji)
        assertEquals(listOf(0, 3, 4, 0), prog.degrees)
        assertTrue(prog.isCustom)
        assertEquals("ii iii vi vii°", ControlSheetLogic.customProgression("2 3 6 7")!!.name)
        assertNull(ControlSheetLogic.customProgression("nothing"))
    }

    // ---- Formatting ----

    @Test
    fun padVolumeIsPercentOfPointSix() {
        assertEquals("100%", ControlSheetLogic.padVolumePercent(0.6))
        assertEquals("0%", ControlSheetLogic.padVolumePercent(0.0))
        assertEquals("50%", ControlSheetLogic.padVolumePercent(0.3))
        assertEquals("25%", ControlSheetLogic.padVolumePercent(0.15))
    }

    @Test
    fun paramFormatsMatchIosKinds() {
        assertEquals("C4", ControlSheetLogic.formatParam(PARAM_MAP.getValue("noteIdx"), 10.0))
        assertEquals("E5", ControlSheetLogic.formatParam(PARAM_MAP.getValue("noteIdx"), 40.0))
        assertEquals("3000hz", ControlSheetLogic.formatParam(PARAM_MAP.getValue("lpf"), 2999.6))
        assertEquals("120 bpm", ControlSheetLogic.formatParam(PARAM_MAP.getValue("bpm"), 120.4))
        assertEquals("0.55", ControlSheetLogic.formatParam(PARAM_MAP.getValue("gain"), 0.55))
        assertEquals("0.010", ControlSheetLogic.formatParam(PARAM_MAP.getValue("attack"), 0.01))
        assertEquals("8", ControlSheetLogic.formatParam(PARAM_MAP.getValue("crush"), 8.0))
    }

    // ---- Modes ----

    @Test
    fun modeRules() {
        assertFalse(ControlSheetLogic.otherModesInitiallyExpanded(StudioMode.SPLIT))
        assertFalse(ControlSheetLogic.otherModesInitiallyExpanded(StudioMode.SCALE))
        assertTrue(ControlSheetLogic.otherModesInitiallyExpanded(StudioMode.RADIAL))
        assertTrue(ControlSheetLogic.hasModeContextControls(StudioMode.GRID))
        assertTrue(ControlSheetLogic.hasModeContextControls(StudioMode.SOUNDFONT))
        assertFalse(ControlSheetLogic.hasModeContextControls(StudioMode.DRUM))
        assertFalse(ControlSheetLogic.hasModeContextControls(StudioMode.LEARN))
        assertTrue(ControlSheetLogic.activePathUsesSoundFont(StudioMode.SOUNDFONT, false, false, false))
        assertTrue(ControlSheetLogic.activePathUsesSoundFont(StudioMode.SPLIT, false, true, false))
        assertFalse(ControlSheetLogic.activePathUsesSoundFont(StudioMode.RADIAL, false, true, true))
        assertFalse(ControlSheetLogic.activePathUsesSoundFont(StudioMode.MELODIC, true, true, true))
        assertEquals("Chord + Melody", ControlSheetLogic.modeName(StudioMode.CHORD_MELODY))
        assertEquals("Drums", ControlSheetLogic.modeName(StudioMode.DRUM))
    }

    // ---- Presets ----

    private fun setup(bpm: Double = 120.0, progression: String = "pop", degrees: List<Int>? = null) = SoundSetup(
        instrument = "grand_piano", waveform = "sawtooth", key = MusicKey.D,
        scale = ScaleSelection.BuiltIn(Scale.MINOR), progression = progression, customDegrees = degrees,
        mode = SoundSetupMode.SCALE_CHORD_MELODY, bpm = bpm, useSoundFont = true, autoStrum = false,
        padVolume = 0.6, gridOctave = 3, gridRange = 2,
    )

    @Test
    fun presetNameAndDuplicateRules() {
        assertEquals("Warm pad", ControlSheetLogic.cleanPresetName("  Warm pad \n"))
        assertEquals(40, ControlSheetLogic.cleanPresetName("x".repeat(60)).length)
        val sound = setup()
        val saved = listOf(NamedSoundSetup(UUID.randomUUID(), "Warm", sound))
        assertFalse(ControlSheetLogic.canSavePreset("   ", sound, saved))
        assertFalse(ControlSheetLogic.canSavePreset(" Warm ", sound, saved))
        assertTrue(ControlSheetLogic.canSavePreset("Warm", setup(bpm = 90.0), saved))
        assertTrue(ControlSheetLogic.canSavePreset("Cold", sound, saved))
    }

    @Test
    fun presetDetailsMatchIos() {
        assertEquals("D Minor · 120 BPM · Pop", ControlSheetLogic.presetDetails(setup()))
        assertEquals("D Minor · 90 BPM · Free layout", ControlSheetLogic.presetDetails(setup(bpm = 90.0, progression = "free")))
        assertEquals(
            "D Minor · 120 BPM · 1-4-5-1",
            ControlSheetLogic.presetDetails(setup(progression = "custom", degrees = listOf(0, 3, 4, 0))),
        )
        assertEquals("D Minor · Pop", ControlSheetLogic.presetDetails(setup(bpm = 500.0)))
        assertEquals("Grand Piano / D Minor · 120 BPM · Pop", ControlSheetLogic.presetSubtitle(setup()))
    }

    @Test
    fun importMessages() {
        assertEquals("These presets are already saved on this device.", ControlSheetLogic.importResultMessage(0, 3))
        assertEquals("Imported 2 of 3 presets.", ControlSheetLogic.importResultMessage(2, 3))
    }

    @Test
    fun loopNameCleaning() {
        assertEquals("Loop one", ControlSheetLogic.cleanLoopName("  Loop\u0000 one\n"))
        assertEquals("", ControlSheetLogic.cleanLoopName(" \t\n "))
        assertEquals("2.5s", ControlSheetLogic.loopDuration(2.46))
    }
}
