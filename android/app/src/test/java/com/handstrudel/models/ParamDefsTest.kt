package com.handstrudel.models

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Ports of iOS ParamDefsTests / MappingConfigTests. */
class ParamDefsTest {
    @Test fun specs_matchSharedMusicConfig() {
        assertEquals(12, PARAM_DEFS.size)
        assertEquals(18, NOTES.size)
        assertEquals(NOTES.size, MIDI_NOTES.size)
        assertEquals(5, STRUCTS.size)
        assertEquals("C4", NOTE_DISPLAY[10])
        val bpm = PARAM_MAP.getValue("bpm")
        assertEquals("cpm", bpm.strudelKey)
        assertEquals("120 bpm", bpm.format(120.0))
        assertEquals("30.0", bpm.toCode(120.0))
        assertEquals("\"c4\"", PARAM_MAP.getValue("noteIdx").toCode(10.4))
        assertEquals("3000hz", PARAM_MAP.getValue("lpf").format(2999.6))
        assertEquals("0.010", PARAM_MAP.getValue("attack").toCode(0.01))
        assertEquals("8", PARAM_MAP.getValue("crush").toCode(7.5)) // half away from zero, like Swift
        assertEquals("0.55", PARAM_MAP.getValue("gain").format(0.55))
    }

    @Test fun defaultMapping_extrasAndDefaults() {
        assertEquals(listOf("delay", "gain", "lpf", "reverb"), DEFAULT_MAPPING.extraParamIds())
        assertTrue(DEFAULT_MAPPING.bpmIsMapped)
        val defaults = DEFAULT_MAPPING.defaultParams()
        assertEquals(6, defaults.size)
        assertEquals(10.0, defaults.getValue("noteIdx"), 0.0)
        val unmapped = MappingConfig(mapOf("y" to "noteIdx", "x" to "none"), mapOf("y" to "save"))
        assertFalse(unmapped.bpmIsMapped)
        assertEquals(emptyList<String>(), unmapped.extraParamIds())
        assertTrue(AXIS_MAP.getValue("x").invert && AXIS_MAP.getValue("y").invert && !AXIS_MAP.getValue("spread").invert)
    }

    @Test fun codeGeneration_matchesIos() {
        val p = mapOf("noteIdx" to 10.0, "bpm" to 120.0, "gain" to 0.5, "lpf" to 3000.0, "reverb" to 0.2, "delay" to 0.1)
        assertEquals(
            "note(\"c4\").s(\"sawtooth\").struct(\"x ~ x ~ x ~ x ~\").cpm(30.0).delay(0.10).gain(0.50).lpf(3000).room(0.20)",
            buildCode(p, 0, DEFAULT_MAPPING),
        )
        assertEquals(
            "note(signal(() => __hp._midi)).s(\"piano\").struct(\"" + FLOW_STRUCT + "\").cpm(signal(() => __hp._cpm))" +
                ".delay(signal(() => __hp.delay)).gain(signal(() => __hp.gain)).lpf(signal(() => __hp.lpf)).room(signal(() => __hp.reverb))",
            buildSignalCode(3, DEFAULT_MAPPING, "piano", FLOW_STRUCT),
        )
        val chord = buildChordSignalCode(9, DEFAULT_MAPPING)
        assertTrue(chord.startsWith("stack(note(signal(() => __hp._cm0)).s(\"sawtooth\").struct(\"x ~ x x ~ x ~ ~\")"))
        assertEquals(3, Regex("__hp\\._cm").findAll(chord).count())
    }
}
