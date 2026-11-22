package com.handstrudel.ui.studio.sheet

import com.handstrudel.engine.StudioMode
import com.handstrudel.models.ChordProgression
import com.handstrudel.models.NOTES
import com.handstrudel.models.NamedSoundSetup
import com.handstrudel.models.ParamDef
import com.handstrudel.models.SoundSetup
import java.util.Locale
import kotlin.math.roundToInt

/**
 * Pure (Compose-free) logic behind the control sheet and the presets sheet,
 * ported from iOS `ControlSheetView.swift`, `ChordProgression.parse`,
 * `ParamDefs.swift` and `PersistenceManager.swift`. Unit-tested in
 * `test/.../ui/studio/ControlSheetLogicTest.kt`.
 */
object ControlSheetLogic {

    // ---- Custom progression -------------------------------------------------------

    /** iOS `ChordProgression.parse(_:)` degrees (the engine's port). Null when nothing parses. */
    fun parseProgressionDegrees(text: String): List<Int>? = ChordProgression.parse(text)?.degrees

    /** iOS `romanNumeral(_:)`: diatonic numeral for a 0-based degree (0 = I … 6 = vii°). */
    fun romanNumeral(degree: Int): String {
        val numerals = listOf("I", "ii", "iii", "IV", "V", "vi", "vii°")
        return numerals.getOrNull(degree) ?: "${degree + 1}"
    }

    /** iOS `applyCustomProgression()`: id "custom", Roman-numeral label, ✍️. Null when nothing parses. */
    fun customProgression(text: String): ChordProgression? {
        val degrees = parseProgressionDegrees(text) ?: return null
        return ChordProgression(
            "custom", degrees.joinToString(" ", transform = ::romanNumeral), "✍️", degrees,
            com.handstrudel.models.ProgressionCategory.CUSTOM,
        )
    }

    // ---- Formatting ---------------------------------------------------------------

    /** Pad volume shown as a percentage of its 0.6 maximum (iOS `"%.0f%%", v / 0.6 * 100`). */
    fun padVolumePercent(volume: Double): String = String.format(Locale.US, "%.0f%%", volume / 0.6 * 100)

    /** Drum volume label (iOS `"%.0f%%", volume * 100`). */
    fun percent(value: Double): String = String.format(Locale.US, "%.0f%%", value * 100)

    /** iOS `Int(x.rounded())` (half away from zero). */
    fun roundedInt(value: Double): Int = if (value >= 0) (value + 0.5).toInt() else -((-value + 0.5).toInt())

    /** iOS `paramFormatter(spec.format).format` (the engine's [ParamDef.format]). */
    fun formatParam(def: ParamDef, value: Double): String = def.format(value)

    /**
     * iOS `DEFAULT_MAPPING`'s param ids (left y/x/spread = noteIdx/lpf/reverb, right =
     * gain/bpm/delay). The sheet reads the live `StudioEngine.mappedParamIds`; this is the
     * fallback when the engine reports none.
     */
    val DEFAULT_MAPPED_PARAM_IDS: Set<String> = setOf("noteIdx", "lpf", "reverb", "gain", "bpm", "delay")

    /** iOS `LoopRecorder.barOptions`. */
    val LOOP_BAR_OPTIONS: List<Int> = listOf(1, 2, 4, 8, 16, 32)

    // ---- Mode ---------------------------------------------------------------------

    /** iOS `hasModeContextControls`. */
    fun hasModeContextControls(mode: StudioMode): Boolean = mode.isChordMelodyFamily || mode == StudioMode.GRID

    /** iOS `activePathUsesSoundFont`. */
    fun activePathUsesSoundFont(mode: StudioMode, radialSF: Boolean, splitSF: Boolean, scaleSF: Boolean): Boolean = when (mode) {
        StudioMode.SOUNDFONT -> true
        StudioMode.SPLIT -> splitSF
        StudioMode.SCALE -> scaleSF
        StudioMode.RADIAL -> radialSF
        else -> false
    }

    /** iOS `currentModeName`. */
    fun modeName(mode: StudioMode): String = when (mode) {
        StudioMode.MELODIC -> "Melodic"
        StudioMode.FLOW -> "Flow"
        StudioMode.HYBRID -> "Hybrid"
        StudioMode.LEAD -> "Lead"
        StudioMode.GRID -> "Grid"
        StudioMode.DRUM -> "Drums"
        StudioMode.LEARN -> "Learn"
        StudioMode.CHORD_MELODY -> "Chord + Melody"
        StudioMode.RADIAL -> "Radial"
        StudioMode.SPLIT -> "Split"
        StudioMode.SCALE -> "Scale"
        StudioMode.SOUNDFONT -> "SoundFont"
    }

    /** iOS `otherModesPickerSection.onAppear`: expanded unless in Split or Scale. */
    fun otherModesInitiallyExpanded(mode: StudioMode): Boolean = mode != StudioMode.SPLIT && mode != StudioMode.SCALE

    /** iOS `modeSection` description for the wheel/zones chord family. */
    fun chordFamilyDescription(mode: StudioMode): String = when (mode) {
        StudioMode.RADIAL -> "Chords are on the outer ring, notes on the inner ring. Rest in the center to hold."
        StudioMode.SPLIT -> "One side of the wheel plays chords, the other plays melody. Rest in the center to hold."
        StudioMode.SCALE -> "Play the full scale on the melody side. Use the outer ring to shift octaves."
        else -> "Hold a chord with one hand and play its notes with the other. Pinch the chord hand for an accent."
    }

    // ---- Presets ------------------------------------------------------------------

    /** iOS `SoundSetupsView.cleanName`: trimmed, first 40 characters. */
    fun cleanPresetName(name: String): String = name.trim().take(40)

    /** iOS: Save disabled when the name is empty or the same (name, sound) exists. */
    fun canSavePreset(name: String, sound: SoundSetup, setups: List<NamedSoundSetup>): Boolean {
        val clean = cleanPresetName(name)
        return clean.isNotEmpty() && setups.none { it.name == clean && it.sound == sound }
    }

    /** iOS `SoundSetup.presetDetails`: "Key Scale · 120 BPM · Progression". */
    fun presetDetails(sound: SoundSetup): String = sound.presetDetails

    /** iOS row subtitle: `[instrumentName, presetDetails].compactMap.joined(" / ")`. */
    fun presetSubtitle(sound: SoundSetup): String = listOfNotNull(sound.instrumentName, presetDetails(sound)).joinToString(" / ")

    /** iOS import result copy. */
    fun importResultMessage(imported: Int, total: Int): String =
        if (imported == 0) "These presets are already saved on this device." else "Imported $imported of $total presets."

    /** iOS `RecordedLoop.cleanName`: control characters dropped, trimmed, ≤40. */
    fun cleanLoopName(value: String): String = value.filterNot { it.isISOControl() }.trim().take(40)

    /** iOS `"%.1f"s` loop duration. */
    fun loopDuration(seconds: Double): String = String.format(Locale.US, "%.1fs", seconds)

    /** Rounds a slider value to the step iOS uses for BPM sliders. */
    fun stepped(value: Double): Double = value.roundToInt().toDouble()
}
