package com.handstrudel.models

data class ParamDef(
    val id: String,
    val label: String,
    val strudelKey: String,
    val min: Double,
    val max: Double,
    val defaultValue: Double
)

val PARAM_DEFS = listOf(
    ParamDef("noteIdx", "pitch", "note", 0.0, 17.0, 10.0),
    ParamDef("gain", "volume", "gain", 0.03, 0.9, 0.55),
    ParamDef("lpf", "filter", "lpf", 120.0, 6120.0, 3000.0),
    ParamDef("hpf", "hi-pass", "hpf", 20.0, 4000.0, 2000.0),
    ParamDef("reverb", "reverb", "room", 0.0, 0.9, 0.2),
    ParamDef("bpm", "tempo", "cpm", 50.0, 205.0, 120.0),
    ParamDef("delay", "delay", "delay", 0.0, 0.55, 0.12),
    ParamDef("pan", "pan", "pan", 0.0, 1.0, 0.5),
    ParamDef("crush", "crush", "crush", 1.0, 16.0, 8.0),
    ParamDef("shape", "shape", "shape", 0.0, 0.9, 0.0),
    ParamDef("attack", "attack", "attack", 0.001, 0.5, 0.01),
    ParamDef("release", "release", "release", 0.01, 1.0, 0.1),
)

val PARAM_MAP = PARAM_DEFS.associateBy { it.id }

val NOTES = listOf(
    "c2", "d2", "e2", "g2", "a2",
    "c3", "d3", "e3", "g3", "a3",
    "c4", "d4", "e4", "g4", "a4",
    "c5", "d5", "e5",
)

val STRUCTS = listOf(
    "x ~ x ~ x ~ x ~",
    "x ~ ~ x ~ ~ x ~",
    "x x ~ x ~ x x ~",
    "[x x x] ~ ~ ~",
    "x ~ x x ~ x ~ ~",
)

data class DrumLoop(
    val id: String,
    val name: String,
    val emoji: String,
    val code: String,
    val isPremium: Boolean = false,
    val packId: String? = null
)

// Drum sound building blocks (Strudel synth code)
private const val DEEP_KICK = """note("c1").s("sine").decay(0.3).sustain(0).gain(1.4).lpf(120)"""
private const val PUNCH_KICK = """note("f1").s("triangle").decay(0.1).sustain(0).gain(1.2).lpf(300)"""
private const val HOUSE_KICK = """note("d1").s("sine").decay(0.2).sustain(0).gain(1.3).lpf(200)"""
private const val NOISE_SNARE = """note("c4").s("white").decay(0.12).sustain(0).gain(0.7).hpf(1000).lpf(6000)"""
private const val TONE_SNARE = """note("e3").s("triangle").decay(0.08).sustain(0).gain(0.5).lpf(3000)"""
private val SNARE = "stack($NOISE_SNARE, $TONE_SNARE)"
private const val CLAP = """note("g4").s("pink").decay(0.09).sustain(0).gain(0.8).hpf(1500).lpf(8000)"""
private const val HARD_CLAP = """note("a4").s("white").decay(0.07).sustain(0).gain(0.9).hpf(2000).crush(4)"""
private const val CLOSED_HAT = """note("a5").s("white").decay(0.025).sustain(0).gain(0.35).hpf(8000)"""
private const val OPEN_HAT = """note("a5").s("white").decay(0.12).sustain(0).gain(0.3).hpf(7000)"""
private const val TINY_HAT = """note("c6").s("pink").decay(0.015).sustain(0).gain(0.25).hpf(10000)"""
private const val RIMSHOT = """note("b4").s("triangle").decay(0.02).sustain(0).gain(0.6).hpf(5000)"""
private const val CLAVE = """note("d5").s("sine").decay(0.03).sustain(0).gain(0.5).hpf(3000)"""

val DRUM_LOOPS = listOf(
    DrumLoop("none", "None", "\uD83D\uDD07", ""),
    DrumLoop("basic", "Basic", "\uD83E\uDD41",
        """stack($PUNCH_KICK.struct("x ~ x ~"), $SNARE.struct("~ x ~ x"), $CLOSED_HAT.struct("x x x x"))"""),
    DrumLoop("hiphop", "Hip Hop", "\uD83C\uDFA4",
        """stack($DEEP_KICK.struct("x ~ ~ x ~ ~ x ~"), $HARD_CLAP.struct("~ ~ ~ ~ x ~ ~ ~"), $CLOSED_HAT.struct("~ x ~ x ~ x ~ x"), $OPEN_HAT.struct("~ ~ x ~ ~ ~ x ~"))"""),
    DrumLoop("house", "House", "\uD83C\uDFE0",
        """stack($HOUSE_KICK.struct("x x x x"), $CLAP.struct("~ ~ x ~"), $OPEN_HAT.struct("~ x ~ x ~ x ~ x"), $TINY_HAT.struct("[x x] [x x] [x x] [x x]"))"""),
    DrumLoop("trap", "Trap", "\uD83D\uDD0A",
        """stack($DEEP_KICK.struct("x ~ ~ ~ x ~ ~ ~").gain(1.6), $HARD_CLAP.struct("~ ~ ~ ~ x ~ ~ ~").gain(1.1), $CLOSED_HAT.struct("[x x x x] [x x x x] [x x x x] [x x x x]"), $OPEN_HAT.struct("~ ~ ~ ~ ~ ~ [~ x] ~"))"""),
    DrumLoop("minimal", "Minimal", "\u2728",
        """stack($PUNCH_KICK.struct("x ~ ~ x"), $RIMSHOT.struct("~ ~ x ~"), $CLAVE.struct("~ x ~ ~"))"""),
)

data class Waveform(
    val id: String,
    val name: String,
    val emoji: String,
    val isPremium: Boolean = false,
    val packId: String? = null
)

val WAVEFORMS = listOf(
    Waveform("sawtooth", "Saw", "\uD83E\uDE9A"),
    Waveform("square", "Square", "\u2B1C"),
    Waveform("triangle", "Triangle", "\uD83D\uDD3A"),
    Waveform("sine", "Sine", "\uD83D\uDD2E"),
)
