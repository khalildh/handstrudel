package com.handstrudel.models

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.util.UUID

/** Wire-format parity with iOS `SoundSetup` (Swift `JSONEncoder`, `.sortedKeys`). */
class SoundSetupJsonTest {

    // As iOS encodes `SoundSetup(instrument: "violin", waveform: "sine", key: .C, scale: .major,
    // progression: "custom", customDegrees: [0, 3, 4], mode: .scalechordmelody, bpm: 100, ...)`
    // (HandStrudelTests/SocialTests.swift testSoundSetupRoundTripsAndValidatesCustomDegrees).
    private val iosBuiltIn = """
        {"autoStrum":true,"bpm":100,"customDegrees":[0,3,4],"gridOctave":3,"gridRange":2,
         "instrument":"violin","key":"C","mode":"scalechordmelody","padVolume":0.3,
         "progression":"custom","scale":"Major","useSoundFont":true,"version":1,"waveform":"sine"}
    """.trimIndent()

    private val iosCustomScale = """
        {"autoStrum":false,"bpm":96.5,"gridOctave":4,"gridRange":1,"instrument":"grand_piano",
         "key":"Db","mode":"splitchordmelody","padVolume":0.6,"progression":"pop",
         "scale":{"id":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F","intervals":[0,3,5,7,10],"name":"Night Walk"},
         "useSoundFont":true,"version":1,"waveform":"sawtooth"}
    """.trimIndent()

    private fun assertSameJson(expected: String, actual: String) {
        assertTrue("expected $expected\nactual   $actual", JSONObject(expected).similar(JSONObject(actual)))
    }

    @Test fun decodesIosBuiltInScalePayload() {
        val setup = SoundSetup.decode(iosBuiltIn)
        assertEquals(1, setup.version)
        assertEquals("violin", setup.instrument)
        assertEquals(MusicKey.C, setup.key)
        assertEquals(ScaleSelection.BuiltIn(Scale.MAJOR), setup.scale)
        assertEquals(listOf(0, 3, 4), setup.customDegrees)
        assertEquals(SoundSetupMode.SCALE_CHORD_MELODY, setup.mode)
        assertEquals(100.0, setup.bpm, 0.0)
        assertEquals(0.3, setup.padVolume, 0.0)
        assertTrue(setup.isValid)
        assertEquals(listOf(0, 3, 4), setup.resolvedProgression?.degrees)
    }

    @Test fun roundTripsBuiltInScaleToIdenticalJson() {
        val encoded = SoundSetup.decode(iosBuiltIn).encode()
        assertSameJson(iosBuiltIn, encoded)
        // Swift writes whole doubles without a fraction.
        assertTrue(encoded, encoded.contains("\"bpm\":100,") || encoded.contains("\"bpm\":100}"))
        assertEquals(SoundSetup.decode(iosBuiltIn), SoundSetup.decode(encoded))
    }

    @Test fun roundTripsCustomScaleObjectWithUppercaseUuid() {
        val setup = SoundSetup.decode(iosCustomScale)
        val scale = (setup.scale as ScaleSelection.Custom).scale
        assertEquals(UUID.fromString("e621e1f8-c36c-495a-93fc-0c247a3e6e5f"), scale.id)
        assertEquals("Night Walk", scale.name)
        assertEquals(listOf(0, 3, 5, 7, 10), scale.intervals)
        assertEquals(MusicKey.Db, setup.key)
        assertEquals("pro", setup.scale.packId)
        assertTrue(setup.isValid)
        assertSameJson(iosCustomScale, setup.encode())
    }

    @Test fun omitsNullCustomDegrees() {
        val setup = SoundSetup.decode(iosCustomScale)
        assertNull(setup.customDegrees)
        assertFalse(setup.encode().contains("customDegrees"))
    }

    @Test fun isValidMatchesIosBounds() {
        val base = SoundSetup.decode(iosBuiltIn)
        assertFalse(base.copy(version = 99).isValid)
        assertFalse(base.copy(bpm = 19.0).isValid)
        assertFalse(base.copy(bpm = 401.0).isValid)
        assertFalse(base.copy(padVolume = 0.61).isValid)
        assertFalse(base.copy(gridOctave = 7).isValid)
        assertFalse(base.copy(gridRange = 0).isValid)
        assertFalse(base.copy(instrument = "nope").isValid)
        assertFalse(base.copy(waveform = "nope").isValid)
        assertFalse(base.copy(customDegrees = listOf(7)).isValid)
        assertFalse(base.copy(customDegrees = null).isValid)
        // SoundFont routing only for the wheel layouts; SoundFont mode requires it.
        assertFalse(base.copy(mode = SoundSetupMode.MELODIC).isValid)
        assertTrue(base.copy(mode = SoundSetupMode.MELODIC, useSoundFont = false).isValid)
        assertFalse(base.copy(mode = SoundSetupMode.SOUNDFONT, useSoundFont = false).isValid)
    }

    @Test fun rejectsUnknownScaleAndInvalidCustomScale() {
        for (bad in listOf(
            iosBuiltIn.replace("\"Major\"", "\"Klingon\""),
            iosCustomScale.replace("[0,3,5,7,10]", "[1,3,5]"),
            iosBuiltIn.replace("\"scalechordmelody\"", "\"learn\""),
        )) {
            try {
                SoundSetup.decode(bad)
                fail("decoded $bad")
            } catch (_: Exception) {
            }
        }
    }

    @Test fun ignoresUnknownKeys() {
        val setup = SoundSetup.decode(iosBuiltIn.replace("\"version\":1", "\"version\":1,\"futureField\":{\"a\":1}"))
        assertTrue(setup.isValid)
    }
}
