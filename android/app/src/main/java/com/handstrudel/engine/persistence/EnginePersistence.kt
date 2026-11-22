package com.handstrudel.engine.persistence

import com.handstrudel.models.TextRules
import com.handstrudel.app.PrefsStore
import com.handstrudel.engine.SavedLoop
import com.handstrudel.models.CustomScale
import com.handstrudel.models.DEFAULT_SOUNDFONT_INSTRUMENT
import com.handstrudel.models.MusicKey
import com.handstrudel.models.NamedSoundSetup
import com.handstrudel.models.Scale
import com.handstrudel.models.ScaleSelection
import com.handstrudel.models.SoundSetup
import com.handstrudel.models.SoundSetupJson
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import java.io.File
import java.util.UUID

/**
 * Port of iOS `PersistenceManager` (engine namespace). Same keys and defaults
 * as `UserDefaults` on iOS. Values are stored as strings in a [PrefsStore]
 * (SharedPreferences `engine` in the app, in-memory in tests).
 */
class EnginePersistence(private val store: PrefsStore) {

    private fun int(key: String): Int = store.getString(key)?.toIntOrNull() ?: 0
    private fun double(key: String): Double = store.getString(key)?.toDoubleOrNull() ?: 0.0
    private fun bool(key: String): Boolean = store.getString(key) == "true"

    /** Split chord+melody is the first-launch default (Start playing still opens Scale). */
    var lastMode: String
        get() = store.getString("lastMode") ?: "splitchordmelody"
        set(v) = store.putString("lastMode", v)

    var lastKey: String
        get() = store.getString("lastKey") ?: "C"
        set(v) = store.putString("lastKey", v)

    /** Custom scale JSON wins over the built-in raw name, like iOS `lastScale`. */
    var lastScale: ScaleSelection
        get() {
            store.getString("lastCustomScale")?.let { json ->
                runCatching { SoundSetupJson.decodeFromString(CustomScale.serializer(), json) }
                    .getOrNull()?.takeIf { it.isValid }?.let { return ScaleSelection.Custom(it) }
            }
            return Scale.fromRaw(store.getString("lastScale") ?: "Pentatonic")?.let(ScaleSelection::BuiltIn)
                ?: ScaleSelection.PENTATONIC
        }
        set(v) {
            when (v) {
                is ScaleSelection.Custom ->
                    store.putString("lastCustomScale", SoundSetupJson.encodeToString(CustomScale.serializer(), v.scale))
                is ScaleSelection.BuiltIn -> {
                    store.putString("lastCustomScale", null)
                    store.putString("lastScale", v.rawValue)
                }
            }
        }

    var lastWaveform: String
        get() = store.getString("lastWaveform") ?: "sawtooth"
        set(v) = store.putString("lastWaveform", v)

    var lastSoundFont: String
        get() = store.getString("lastSoundFont") ?: DEFAULT_SOUNDFONT_INSTRUMENT.id
        set(v) = store.putString("lastSoundFont", v)

    var lastBPM: Double
        get() = double("lastBPM").takeIf { it != 0.0 } ?: 120.0
        set(v) = store.putString("lastBPM", v.toString())

    var lastFilterId: String
        get() = store.getString("lastFilterId") ?: "none"
        set(v) = store.putString("lastFilterId", v)

    /** Android-only: the hand theme id (iOS keeps it in memory only). */
    var lastHandThemeId: String
        get() = store.getString("lastHandThemeId") ?: "default"
        set(v) = store.putString("lastHandThemeId", v)

    var lastGridBaseOctave: Int
        get() = int("lastGridBaseOctave").takeIf { it != 0 } ?: 3
        set(v) = store.putString("lastGridBaseOctave", v.toString())

    var lastGridOctaveRange: Int
        get() = int("lastGridOctaveRange").takeIf { it != 0 } ?: 2
        set(v) = store.putString("lastGridOctaveRange", v.toString())

    var lastQuantizeEnabled: Boolean
        get() = bool("lastQuantizeEnabled")
        set(v) = store.putString("lastQuantizeEnabled", v.toString())

    var lastQuantizeDiv: Double
        get() = double("lastQuantizeDiv").takeIf { it != 0.0 } ?: 8.0
        set(v) = store.putString("lastQuantizeDiv", v.toString())

    var lastLoopBars: Int
        get() = int("loopRecordingBars").takeIf { it in LOOP_BAR_OPTIONS } ?: 4
        set(v) { if (v in LOOP_BAR_OPTIONS) store.putString("loopRecordingBars", v.toString()) }

    /** iOS `saveEngineState` (minus the unreachable preset id). */
    fun saveEngineState(
        mode: String, key: MusicKey, scale: ScaleSelection, waveform: String, bpm: Double, filterId: String,
        gridBaseOctave: Int, gridOctaveRange: Int, quantizeEnabled: Boolean, quantizeDiv: Double,
    ) {
        lastMode = mode
        lastKey = key.rawValue
        lastScale = scale
        lastWaveform = waveform
        lastBPM = bpm
        lastFilterId = filterId
        lastGridBaseOctave = gridBaseOctave
        lastGridOctaveRange = gridOctaveRange
        lastQuantizeEnabled = quantizeEnabled
        lastQuantizeDiv = quantizeDiv
    }

    // ---- Presets (iOS `savedSoundSetups`) -------------------------------------------

    fun loadSetups(): List<NamedSoundSetup> = store.getString(SETUPS_KEY)?.let { json ->
        runCatching { SoundSetupJson.decodeFromString(ListSerializer(NamedSoundSetup.serializer()), json) }.getOrNull()
    } ?: emptyList()

    fun saveSetups(setups: List<NamedSoundSetup>) =
        store.putString(SETUPS_KEY, SoundSetupJson.encodeToString(ListSerializer(NamedSoundSetup.serializer()), setups))

    /** iOS `addPreset`: trimmed name ≤40 chars, valid sound, unique by (sound, name), newest first. */
    fun addPreset(sound: SoundSetup, name: String): Boolean {
        val trimmed = TextRules.prefixGraphemes(name.trim(), 40) // iOS `prefix(40)` (Characters)
        if (!sound.isValid || trimmed.isEmpty()) return false
        val setups = loadSetups()
        if (setups.any { it.sound == sound && it.name == trimmed }) return false
        saveSetups(listOf(NamedSoundSetup(UUID.randomUUID(), trimmed, sound)) + setups)
        return true
    }

    fun deletePreset(id: UUID) = saveSetups(loadSetups().filterNot { it.id == id })

    /** iOS `importPresetPack`: skips duplicates (existing or within the pack); returns how many were added. */
    fun importPresetPack(pack: SoundPresetPack): Int {
        pack.validate()
        val existing = loadSetups()
        val imported = mutableListOf<NamedSoundSetup>()
        for (entry in pack.presets) {
            val dup = existing.any { it.name == entry.name && it.sound == entry.sound } ||
                imported.any { it.name == entry.name && it.sound == entry.sound }
            if (!dup) imported += NamedSoundSetup(UUID.randomUUID(), entry.name, entry.sound)
        }
        if (imported.isNotEmpty()) saveSetups(imported + existing)
        return imported.size
    }

    // ---- Custom scales (iOS `savedCustomScales`) ------------------------------------

    fun loadCustomScales(): List<CustomScale> = store.getString(CUSTOM_SCALES_KEY)?.let { json ->
        runCatching { SoundSetupJson.decodeFromString(ListSerializer(CustomScale.serializer()), json) }.getOrNull()
            ?.filter { it.isValid }
    } ?: emptyList()

    /** Insert (newest first) or replace by id; false at the 64-scale limit. */
    fun saveCustomScale(scale: CustomScale): Boolean {
        val scales = loadCustomScales().toMutableList()
        val index = scales.indexOfFirst { it.id == scale.id }
        if (index >= 0) scales[index] = scale
        else {
            if (scales.size >= CUSTOM_SCALE_LIMIT) return false
            scales.add(0, scale)
        }
        store.putString(CUSTOM_SCALES_KEY, SoundSetupJson.encodeToString(ListSerializer(CustomScale.serializer()), scales))
        return true
    }

    fun removeCustomScale(id: UUID) {
        val scales = loadCustomScales().filterNot { it.id == id }
        store.putString(CUSTOM_SCALES_KEY, SoundSetupJson.encodeToString(ListSerializer(CustomScale.serializer()), scales))
    }

    // ---- Loops (iOS `savedLoops`; captured-audio loops only) --------------------------

    fun loadLoops(audioDir: File): List<SavedLoop> = store.getString(LOOPS_KEY)?.let { json ->
        runCatching { SoundSetupJson.decodeFromString(ListSerializer(StoredLoop.serializer()), json) }.getOrNull()
    }?.map { it.toSavedLoop(audioDir) } ?: emptyList()

    fun saveLoops(loops: List<SavedLoop>) = store.putString(
        LOOPS_KEY,
        SoundSetupJson.encodeToString(ListSerializer(StoredLoop.serializer()), loops.map(StoredLoop::from)),
    )

    companion object {
        const val CUSTOM_SCALE_LIMIT = 64
        /** iOS `LoopRecorder.barOptions`. */
        val LOOP_BAR_OPTIONS: List<Int> = listOf(1, 2, 4, 8, 16, 32)
        private const val SETUPS_KEY = "savedSoundSetups"
        private const val CUSTOM_SCALES_KEY = "savedCustomScales"
        private const val LOOPS_KEY = "savedLoops"
    }
}

/** On-disk loop metadata (the audio file lives at `<audioDir>/<id>.m4a|wav`). */
@Serializable
internal data class StoredLoop(
    val id: String,
    val name: String,
    val duration: Double,
    val bpm: Double,
    val mode: String,
    val createdAt: Long,
    val hasCapturedAudio: Boolean = true,
    val gain: Double? = null,
    val muted: Boolean? = null,
    val fileName: String? = null,
) {
    fun toSavedLoop(audioDir: File) = SavedLoop(
        id = UUID.fromString(id), name = name, durationSeconds = duration, bpm = bpm, mode = mode,
        createdAtMillis = createdAt, hasCapturedAudio = hasCapturedAudio, gain = clampedLoopGain(gain ?: 1.0),
        muted = muted == true, file = fileName?.let { File(audioDir, it) },
    )

    companion object {
        fun from(loop: SavedLoop) = StoredLoop(
            id = loop.id.toString(), name = loop.name, duration = loop.durationSeconds, bpm = loop.bpm, mode = loop.mode,
            createdAt = loop.createdAtMillis, hasCapturedAudio = loop.hasCapturedAudio, gain = loop.gain,
            muted = loop.muted, fileName = loop.file?.name,
        )
    }
}

/** iOS `RecordedLoop.clampedGain`. */
fun clampedLoopGain(value: Double): Double = if (value.isFinite()) value.coerceIn(0.0, 1.0) else 1.0

/** iOS `RecordedLoop.cleanName`: drop control characters, trim, at most 40 characters. */
fun cleanLoopName(value: String): String {
    val sb = StringBuilder()
    value.codePoints().forEach { cp -> if (!TextRules.isControl(cp)) sb.appendCodePoint(cp) }
    return TextRules.prefixGraphemes(sb.toString().trim(), 40)
}
