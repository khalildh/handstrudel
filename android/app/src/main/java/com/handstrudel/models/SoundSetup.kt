package com.handstrudel.models

import com.handstrudel.common.SwiftDoubleSerializer
import com.handstrudel.common.SwiftUuidSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import java.util.UUID

/**
 * Port of iOS `SoundSetup` (`Engine/PersistenceManager.swift`). Owner: engine.
 *
 * **Wire format shared with iOS and the server** (`videos.sound_setup` jsonb,
 * ≤4096 bytes, and preset packs). Field names, enum raw values and value shapes
 * must stay identical to the Swift `Codable` output:
 *
 * * `version` Int (1), `instrument` SoundFont id, `waveform` Strudel id
 * * `key` raw (`"Db"`), `scale` built-in raw name **or** a custom-scale object
 * * `progression` id or `"custom"`, `customDegrees` 0-based, omitted when null
 * * `mode` raw (see [SoundSetupMode]), `bpm` 20–400, `useSoundFont`, `autoStrum`
 * * `padVolume` 0–0.6, `gridOctave` 1–6, `gridRange` 1–3
 *
 * Encode/decode only through [SoundSetupJson] so whole doubles print as `120`
 * (like Swift) and null `customDegrees` is omitted.
 */
@Serializable
data class SoundSetup(
    val version: Int = 1,
    val instrument: String,
    val waveform: String,
    val key: MusicKey,
    val scale: ScaleSelection,
    val progression: String,
    val customDegrees: List<Int>? = null,
    val mode: SoundSetupMode,
    @Serializable(with = SwiftDoubleSerializer::class) val bpm: Double,
    val useSoundFont: Boolean,
    val autoStrum: Boolean,
    @Serializable(with = SwiftDoubleSerializer::class) val padVolume: Double,
    val gridOctave: Int,
    val gridRange: Int,
) {
    val resolvedInstrument: SoundFontInstrument? get() = SOUNDFONT_INSTRUMENTS.firstOrNull { it.id == instrument }
    val resolvedWaveform: Waveform? get() = WAVEFORMS.firstOrNull { it.id == waveform }
    val instrumentName: String? get() = if (useSoundFont) resolvedInstrument?.name else resolvedWaveform?.name
    val keyAndScale: String get() = "${key.displayName} ${scale.displayName}"

    /// iOS `resolvedProgression`: custom degrees go through `ChordProgression.parse`.
    val resolvedProgression: ChordProgression?
        get() {
            if (progression == "custom") {
                val degrees = customDegrees ?: return null
                if (degrees.size !in 1..64 || degrees.any { it !in 0..6 }) return null
                return ChordProgression.parse(degrees.joinToString(" ") { (it + 1).toString() })
            }
            return CHORD_PROGRESSIONS.firstOrNull { it.id == progression }
        }

    /// iOS `presetDetails`: "C Major · 120 BPM · Pop".
    val presetDetails: String
        get() {
            val parts = mutableListOf(keyAndScale)
            if (bpm in 20.0..400.0) parts += "${swiftRound(bpm)} BPM"
            resolvedProgression?.let { p ->
                parts += when {
                    p.id == "free" -> "Free layout"
                    p.isCustom -> p.degrees.joinToString("-") { (it + 1).toString() }
                    else -> p.name
                }
            }
            return parts.joinToString(" · ")
        }

    /// iOS `isValid`, field for field.
    val isValid: Boolean
        get() = version == 1 && resolvedInstrument != null && resolvedWaveform != null && resolvedProgression != null &&
            bpm in 20.0..400.0 && padVolume in 0.0..0.6 &&
            gridOctave in 1..6 && gridRange in 1..3 &&
            (if (mode == SoundSetupMode.SOUNDFONT) useSoundFont else (!useSoundFont || mode in SOUNDFONT_CAPABLE_MODES))

    /// iOS `requiredPacks`: ignores the inactive synth's selection.
    val requiredPacks: List<String>
        get() = listOfNotNull(
            if (useSoundFont) resolvedInstrument?.packId else resolvedWaveform?.packId,
            scale.packId,
            resolvedProgression?.packId,
        )

    fun encode(): String = SoundSetupJson.encodeToString(serializer(), this)

    companion object {
        private val SOUNDFONT_CAPABLE_MODES = setOf(
            SoundSetupMode.RADIAL_CHORD_MELODY, SoundSetupMode.SPLIT_CHORD_MELODY, SoundSetupMode.SCALE_CHORD_MELODY,
        )

        /** Strict decode (throws on malformed JSON, like Swift `JSONDecoder`). Does not check [isValid]. */
        fun decode(json: String): SoundSetup = SoundSetupJson.decodeFromString(serializer(), json)

        /** iOS `Video` lenient rule: anything undecodable or not [isValid] becomes null. */
        fun decodeValidOrNull(element: JsonElement?): SoundSetup? = try {
            element?.let { SoundSetupJson.decodeFromJsonElement(serializer(), it) }?.takeIf { it.isValid }
        } catch (_: Exception) {
            null
        }
    }
}

/** iOS `SoundSetup.Mode`. Raw values are the wire strings. */
@Serializable
enum class SoundSetupMode(val raw: String) {
    @SerialName("melodic") MELODIC("melodic"),
    @SerialName("flow") FLOW("flow"),
    @SerialName("hybrid") HYBRID("hybrid"),
    @SerialName("lead") LEAD("lead"),
    @SerialName("grid") GRID("grid"),
    @SerialName("drum") DRUM("drum"),
    @SerialName("chordmelody") CHORD_MELODY("chordmelody"),
    @SerialName("radialchordmelody") RADIAL_CHORD_MELODY("radialchordmelody"),
    @SerialName("splitchordmelody") SPLIT_CHORD_MELODY("splitchordmelody"),
    @SerialName("scalechordmelody") SCALE_CHORD_MELODY("scalechordmelody"),
    @SerialName("soundfont") SOUNDFONT("soundfont");

    companion object {
        fun fromRaw(raw: String): SoundSetupMode? = entries.firstOrNull { it.raw == raw }
    }
}

/** iOS `NamedSoundSetup` (presets). Owner: engine. */
@Serializable
data class NamedSoundSetup(
    @Serializable(with = SwiftUuidSerializer::class) val id: UUID,
    val name: String,
    val sound: SoundSetup,
)

/**
 * The one JSON configuration for iOS-shared payloads (SoundSetup, preset packs):
 * unknown keys ignored (Swift ignores them too), defaults written (`version`),
 * nulls omitted (Swift `encodeIfPresent`).
 */
val SoundSetupJson: Json = Json {
    ignoreUnknownKeys = true
    encodeDefaults = true
    explicitNulls = false
}
