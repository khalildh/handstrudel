package com.handstrudel.models

import java.util.Locale

// Port of iOS `Models/ParamDefs.swift`, `MusicConfig.generated.swift` and
// `MappingConfig.swift` (the parts the engine uses). Owner: engine.

/** iOS `NOTES` (shared/music-config.json). */
val NOTES: List<String> = listOf(
    "c2", "d2", "e2", "g2", "a2", "c3", "d3", "e3", "g3", "a3",
    "c4", "d4", "e4", "g4", "a4", "c5", "d5", "e5",
)

/** iOS `MIDI_NOTES`. */
val MIDI_NOTES: List<Int> = listOf(36, 38, 40, 43, 45, 48, 50, 52, 55, 57, 60, 62, 64, 67, 69, 72, 74, 76)

/** iOS `STRUCTS`: rotated every 8 s in the melodic modes. */
val STRUCTS: List<String> = listOf(
    "x ~ x ~ x ~ x ~", "x ~ ~ x ~ ~ x ~", "x x ~ x ~ x x ~", "[x x x] ~ ~ ~", "x ~ x x ~ x ~ ~",
)

/** iOS `FLOW_STRUCT`: dense 16th pulse for Flow mode. */
const val FLOW_STRUCT: String = "x x x x x x x x x x x x x x x x"

/** iOS `NOTE_DISPLAY` ("C2", "D2", …). */
val NOTE_DISPLAY: List<String> = NOTES.map { it.substring(0, 1).uppercase() + it.substring(1) }

/** Swift `String(format:)` always uses a dot decimal separator. */
internal fun fmt(value: Double, decimals: Int): String = String.format(Locale.US, "%.${decimals}f", value)

/** iOS `Int(x.rounded())` (half away from zero). */
internal fun swiftRound(value: Double): Int = Math.round(kotlin.math.abs(value)).toInt().let { if (value < 0) -it else it }

/** iOS `ParamDef` with its formatter kind (`format`). */
data class ParamDef(
    val id: String,
    val label: String,
    val strudelKey: String,
    val min: Double,
    val max: Double,
    val defaultValue: Double,
    val formatKind: String = "fixed2",
) {
    /** Display string (iOS `format`). */
    fun format(v: Double): String = when (formatKind) {
        "note" -> NOTE_DISPLAY[swiftRound(v).coerceIn(0, NOTES.size - 1)]
        "fixed3" -> fmt(v, 3)
        "hz" -> "${swiftRound(v)}hz"
        "bpm" -> "${swiftRound(v)} bpm"
        "int" -> "${swiftRound(v)}"
        else -> fmt(v, 2)
    }

    /** Strudel code literal (iOS `toCode`). */
    fun toCode(v: Double): String = when (formatKind) {
        "note" -> "\"${NOTES[swiftRound(v).coerceIn(0, NOTES.size - 1)]}\""
        "fixed3" -> fmt(v, 3)
        "hz" -> "${swiftRound(v)}"
        "bpm" -> fmt(v / 4, 1)
        "int" -> "${swiftRound(v)}"
        else -> fmt(v, 2)
    }
}

/** iOS `PARAM_SPECS` → `PARAM_DEFS`. */
val PARAM_DEFS: List<ParamDef> = listOf(
    ParamDef("noteIdx", "pitch", "note", 0.0, 17.0, 10.0, "note"),
    ParamDef("gain", "volume", "gain", 0.03, 0.9, 0.55, "fixed2"),
    ParamDef("lpf", "filter", "lpf", 120.0, 6120.0, 3000.0, "hz"),
    ParamDef("hpf", "hi-pass", "hpf", 20.0, 4000.0, 2000.0, "hz"),
    ParamDef("reverb", "reverb", "room", 0.0, 0.9, 0.2, "fixed2"),
    ParamDef("bpm", "tempo", "cpm", 50.0, 205.0, 120.0, "bpm"),
    ParamDef("delay", "delay", "delay", 0.0, 0.55, 0.12, "fixed2"),
    ParamDef("pan", "pan", "pan", 0.0, 1.0, 0.5, "fixed2"),
    ParamDef("crush", "crush", "crush", 1.0, 16.0, 8.0, "int"),
    ParamDef("shape", "shape", "shape", 0.0, 0.9, 0.0, "fixed2"),
    ParamDef("attack", "attack", "attack", 0.001, 0.5, 0.01, "fixed3"),
    ParamDef("release", "release", "release", 0.01, 1.0, 0.1, "fixed2"),
)

val PARAM_MAP: Map<String, ParamDef> = PARAM_DEFS.associateBy { it.id }

/** iOS `AxisDef`. `invert` flips the raw 0…1 value before mapping. */
data class AxisDef(val key: String, val label: String, val basic: Boolean, val invert: Boolean)

val AXIS_DEFS: List<AxisDef> = listOf(
    AxisDef("y", "Y pos", true, true),
    AxisDef("x", "X pos", true, true),
    AxisDef("spread", "spread", true, false),
    AxisDef("pinch", "pinch", false, false),
    AxisDef("fist", "fist", false, false),
    AxisDef("rotation", "rotation", false, false),
    AxisDef("thumbCurl", "thumb curl", false, false),
    AxisDef("indexCurl", "index curl", false, false),
    AxisDef("middleCurl", "middle curl", false, false),
    AxisDef("ringCurl", "ring curl", false, false),
    AxisDef("pinkyCurl", "pinky curl", false, false),
)

val AXIS_MAP: Map<String, AxisDef> = AXIS_DEFS.associateBy { it.key }

/** iOS `MappingConfig`: axis → param id per hand. */
data class MappingConfig(val left: Map<String, String>, val right: Map<String, String>) {
    private val allValues: List<String> get() = left.values + right.values

    /** iOS `EngineController.bpmIsMapped`. */
    val bpmIsMapped: Boolean get() = "bpm" in allValues

    /** iOS `buildDefaultParams`. */
    fun defaultParams(): Map<String, Double> =
        allValues.toSet().mapNotNull { id -> PARAM_MAP[id]?.let { id to it.defaultValue } }.toMap()

    /** iOS `extraParamIds`: mapped ids minus noteIdx/bpm/none/save, sorted. */
    fun extraParamIds(): List<String> =
        (allValues.toSet() - setOf("noteIdx", "bpm", "none", "save")).sorted()
}

/** iOS `DEFAULT_MAPPING` (the only mapping reachable in 1.0.1). */
val DEFAULT_MAPPING: MappingConfig = MappingConfig(
    left = mapOf("y" to "noteIdx", "x" to "lpf", "spread" to "reverb"),
    right = mapOf("y" to "gain", "x" to "bpm", "spread" to "delay"),
)

private fun structAt(structIdx: Int): String = STRUCTS[structIdx.coerceIn(0, STRUCTS.size - 1)]

/** iOS `buildCode`: a static snapshot of the current melodic pattern. */
fun buildCode(p: Map<String, Double>, structIdx: Int, config: MappingConfig, waveform: String = "sawtooth"): String {
    val note = NOTES[swiftRound(p["noteIdx"] ?: 10.0).coerceIn(0, NOTES.size - 1)]
    val cpm = fmt((p["bpm"] ?: 120.0) / 4, 1)
    val sb = StringBuilder("note(\"$note\").s(\"$waveform\").struct(\"${structAt(structIdx)}\").cpm($cpm)")
    for (id in config.extraParamIds()) {
        val def = PARAM_MAP[id] ?: continue
        sb.append(".${def.strudelKey}(${def.toCode(p[id] ?: def.defaultValue)})")
    }
    return sb.toString()
}

/** iOS `buildSignalCode`: the live pattern, reading `__hp.*` signals. */
fun buildSignalCode(structIdx: Int, config: MappingConfig, waveform: String = "sawtooth", structOverride: String? = null): String {
    val st = structOverride ?: structAt(structIdx)
    val sb = StringBuilder("note(signal(() => __hp._midi)).s(\"$waveform\").struct(\"$st\").cpm(signal(() => __hp._cpm))")
    for (id in config.extraParamIds()) {
        val def = PARAM_MAP[id] ?: continue
        sb.append(".${def.strudelKey}(signal(() => __hp.$id))")
    }
    return sb.toString()
}

/** iOS `buildChordSignalCode`: three stacked voices on `__hp._cm0..2`. */
fun buildChordSignalCode(structIdx: Int, config: MappingConfig, waveform: String = "sawtooth", structOverride: String? = null): String {
    val st = structOverride ?: structAt(structIdx)
    val extras = config.extraParamIds().mapNotNull { id ->
        PARAM_MAP[id]?.let { ".${it.strudelKey}(signal(() => __hp.$id))" }
    }.joinToString("")
    fun voice(i: Int) = "note(signal(() => __hp._cm$i)).s(\"$waveform\").struct(\"$st\").cpm(signal(() => __hp._cpm))$extras"
    return "stack(${voice(0)}, ${voice(1)}, ${voice(2)})"
}
