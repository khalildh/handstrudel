package com.handstrudel.models

import com.handstrudel.engine.persistence.SoundPresetPack
import com.handstrudel.engine.persistence.cleanLoopName
import com.handstrudel.ui.studio.sheet.ControlSheetLogic
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Swift `String.count` / `prefix` and `CharacterSet.controlCharacters` parity for names. */
class TextRulesTest {
    private val emoji25 = "🎵".repeat(25) // 🎵 × 25: 50 UTF-16 units, 25 Characters

    @Test fun graphemes_countLikeSwift() {
        assertEquals(25, TextRules.graphemeCount(emoji25))
        assertEquals(0, TextRules.graphemeCount(""))
        assertEquals(1, TextRules.graphemeCount("é")) // e + combining acute
        assertEquals("🎵🎵", TextRules.prefixGraphemes(emoji25, 2))
        assertEquals("abc", TextRules.prefixGraphemes("abc", 40))
    }

    @Test fun controlCharacters_includeFormat() {
        assertTrue(TextRules.isControl(0x200D)) // ZWJ (Cf)
        assertTrue(TextRules.isControl(0x200F)) // RLM (Cf)
        assertTrue(TextRules.isControl(0x0007)) // BEL (Cc)
        assertFalse(TextRules.isControl('a'.code))
    }

    @Test fun presetEntry_validation() {
        val sound = SoundSetup(
            instrument = "grand_piano", waveform = "sawtooth", key = MusicKey.D,
            scale = ScaleSelection.BuiltIn(Scale.MINOR), progression = "pop", customDegrees = null,
            mode = SoundSetupMode.SCALE_CHORD_MELODY, bpm = 120.0, useSoundFont = true, autoStrum = false,
            padVolume = 0.6, gridOctave = 3, gridRange = 2,
        )
        assertTrue(sound.isValid)
        assertTrue(SoundPresetPack.Entry(emoji25, sound).isValid)
        assertFalse(SoundPresetPack.Entry("a".repeat(41), sound).isValid)
        assertFalse(SoundPresetPack.Entry("Lead‍Pad", sound).isValid)
        assertFalse(SoundPresetPack.Entry("Lead‏Pad", sound).isValid)
    }

    @Test fun names_truncateByCharacters() {
        val long = "🎵".repeat(45)
        assertEquals(40, TextRules.graphemeCount(ControlSheetLogic.cleanPresetName(long)))
        assertEquals(80, ControlSheetLogic.cleanPresetName(long).length)
        assertEquals("ab", cleanLoopName(" a‍b\n "))
    }

    @Test fun customScale_rejectsFormatCharacters() {
        assertNull(CustomScale.create(name = "My‏Scale", intervals = listOf(0, 2, 4)))
        assertNotNull(CustomScale.create(name = "My Scale", intervals = listOf(0, 2, 4)))
    }
}
