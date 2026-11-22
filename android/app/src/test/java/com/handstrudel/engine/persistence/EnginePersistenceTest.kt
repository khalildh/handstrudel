package com.handstrudel.engine.persistence

import com.handstrudel.app.InMemoryPrefsStore
import com.handstrudel.engine.PresetPackException
import com.handstrudel.models.CustomScale
import com.handstrudel.models.MusicKey
import com.handstrudel.models.Scale
import com.handstrudel.models.ScaleSelection
import com.handstrudel.models.SoundSetup
import com.handstrudel.models.SoundSetupMode
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.util.UUID

class EnginePersistenceTest {
    private fun setup(name: String = "violin") = SoundSetup(
        instrument = name, waveform = "sine", key = MusicKey.C, scale = ScaleSelection.BuiltIn(Scale.MAJOR),
        progression = "pop", mode = SoundSetupMode.SCALE_CHORD_MELODY, bpm = 100.0, useSoundFont = true,
        autoStrum = false, padVolume = 0.6, gridOctave = 3, gridRange = 2,
    )

    @Test fun defaults_matchIosPersistenceManager() {
        val p = EnginePersistence(InMemoryPrefsStore())
        assertEquals("splitchordmelody", p.lastMode)
        assertEquals("C", p.lastKey)
        assertEquals(ScaleSelection.BuiltIn(Scale.PENTATONIC), p.lastScale)
        assertEquals("sawtooth", p.lastWaveform)
        assertEquals("violin", p.lastSoundFont)
        assertEquals(120.0, p.lastBPM, 0.0)
        assertEquals("none", p.lastFilterId)
        assertEquals(3, p.lastGridBaseOctave)
        assertEquals(2, p.lastGridOctaveRange)
        assertFalse(p.lastQuantizeEnabled)
        assertEquals(8.0, p.lastQuantizeDiv, 0.0)
        assertEquals(4, p.lastLoopBars)
    }

    @Test fun stateRoundTrips_includingCustomScale() {
        val store = InMemoryPrefsStore()
        val p = EnginePersistence(store)
        val custom = CustomScale.create(name = "Night Walk", intervals = listOf(0, 3, 5, 7, 10))!!
        p.saveEngineState("grid", MusicKey.Db, ScaleSelection.Custom(custom), "piano", 97.0, "noir", 5, 3, true, 16.0)
        val q = EnginePersistence(store)
        assertEquals("grid", q.lastMode)
        assertEquals("Db", q.lastKey)
        assertEquals(ScaleSelection.Custom(custom), q.lastScale)
        assertEquals("piano", q.lastWaveform)
        assertEquals(97.0, q.lastBPM, 0.0)
        assertEquals("noir", q.lastFilterId)
        assertEquals(5, q.lastGridBaseOctave)
        assertTrue(q.lastQuantizeEnabled)
        assertEquals(16.0, q.lastQuantizeDiv, 0.0)
        q.lastScale = ScaleSelection.BuiltIn(Scale.LYDIAN)
        assertEquals(ScaleSelection.BuiltIn(Scale.LYDIAN), EnginePersistence(store).lastScale)
        q.lastLoopBars = 5 // not a bar option: ignored
        assertEquals(4, q.lastLoopBars)
        q.lastLoopBars = 16
        assertEquals(16, q.lastLoopBars)
    }

    @Test fun presets_nameRulesAndDedupe() {
        val p = EnginePersistence(InMemoryPrefsStore())
        assertTrue(p.addPreset(setup(), "  Morning  "))
        assertFalse(p.addPreset(setup(), "Morning"))
        assertFalse(p.addPreset(setup(), "   "))
        assertFalse(p.addPreset(setup("nope"), "Bad"))
        assertTrue(p.addPreset(setup(), "x".repeat(50)))
        assertEquals(listOf("x".repeat(40), "Morning"), p.loadSetups().map { it.name })
        p.deletePreset(p.loadSetups().first().id)
        assertEquals(1, p.loadSetups().size)
    }

    @Test fun customScales_limitAndReplace() {
        val p = EnginePersistence(InMemoryPrefsStore())
        repeat(64) { assertTrue(p.saveCustomScale(CustomScale.create(name = "S$it", intervals = listOf(0, 2, 7))!!)) }
        assertFalse(p.saveCustomScale(CustomScale.create(name = "S64", intervals = listOf(0, 2, 7))!!))
        val first = p.loadCustomScales().first()
        assertEquals("S63", first.name) // newest first
        assertTrue(p.saveCustomScale(first.copy(name = "Renamed")))
        assertEquals("Renamed", p.loadCustomScales().first().name)
        p.removeCustomScale(first.id)
        assertEquals(63, p.loadCustomScales().size)
    }

    @Test fun loopNames_cleaned() {
        assertEquals("Loop", cleanLoopName("  Lo\u0007op\n "))
        assertEquals(40, cleanLoopName("y".repeat(60)).length)
        assertEquals(1.0, clampedLoopGain(Double.NaN), 0.0)
        assertEquals(0.0, clampedLoopGain(-1.0), 0.0)
    }

    // ---- Preset packs (iOS SoundPresetPack) ----

    private fun packJson(presets: String, format: String = "handstrudel-presets", version: Int = 1) =
        """{"format":"$format","version":$version,"presets":[$presets]}"""

    private fun entry(name: String) = """{"name":"$name","sound":${setup().encode()}}"""

    private fun expectError(kind: PresetPackException.Kind, bytes: ByteArray) {
        try {
            SoundPresetPack.decode(bytes)
            fail("expected $kind")
        } catch (e: PresetPackException) {
            assertEquals(kind, e.kind)
            assertEquals(kind.message, e.message)
        }
    }

    @Test fun pack_errorsUseIosMessages() {
        expectError(PresetPackException.Kind.CAPACITY, ByteArray(0))
        expectError(PresetPackException.Kind.CAPACITY, packJson("").toByteArray())
        expectError(PresetPackException.Kind.CAPACITY, packJson((0..128).joinToString(",") { entry("P$it") }).toByteArray())
        expectError(PresetPackException.Kind.CAPACITY, ByteArray(256 * 1024 + 1) { ' '.code.toByte() })
        expectError(PresetPackException.Kind.WRONG_FORMAT, packJson(entry("A"), format = "other").toByteArray())
        expectError(PresetPackException.Kind.WRONG_FORMAT, packJson(entry("A"), version = 2).toByteArray())
        expectError(PresetPackException.Kind.WRONG_FORMAT, """{"presets":[${entry("A")}]}""".toByteArray())
        expectError(PresetPackException.Kind.WRONG_FORMAT, "not json".toByteArray())
        expectError(PresetPackException.Kind.INVALID_PRESET, packJson(entry(" padded ")).toByteArray())
        expectError(PresetPackException.Kind.INVALID_PRESET, packJson(entry("x".repeat(41))).toByteArray())
        assertEquals("This isn't a compatible HandStrudel preset file.", PresetPackException.Kind.WRONG_FORMAT.message)
    }

    @Test fun pack_importSkipsDuplicatesAndExportRoundTrips() {
        val p = EnginePersistence(InMemoryPrefsStore())
        p.addPreset(setup(), "Existing")
        val pack = SoundPresetPack.decode(packJson(listOf(entry("Existing"), entry("New"), entry("New")).joinToString(",")).toByteArray())
        assertEquals(1, p.importPresetPack(pack))
        assertEquals(listOf("New", "Existing"), p.loadSetups().map { it.name })

        val bytes = SoundPresetPack.from(p.loadSetups()).encoded()
        val text = bytes.toString(Charsets.UTF_8)
        assertTrue(text.startsWith("{\n  \"format\" : \"handstrudel-presets\",\n  \"presets\" : ["))
        assertTrue(text.contains("\"progression\" : \"pop\""))
        val again = SoundPresetPack.decode(bytes)
        assertEquals(listOf("New", "Existing"), again.presets.map { it.name })
        assertEquals(2, JSONObject(text).getJSONArray("presets").length())
    }

    @Test fun pack_iosExportDecodesAndReExportsIdentically() {
        // An iOS-shaped export (prettyPrinted + sortedKeys), with a custom scale and an escaped slash.
        val ios = """
{
  "format" : "handstrudel-presets",
  "presets" : [
    {
      "name" : "Night \/ Walk",
      "sound" : {
        "autoStrum" : false,
        "bpm" : 96.5,
        "gridOctave" : 4,
        "gridRange" : 1,
        "instrument" : "grand_piano",
        "key" : "Db",
        "mode" : "splitchordmelody",
        "padVolume" : 0.6,
        "progression" : "pop",
        "scale" : {
          "id" : "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
          "intervals" : [
            0,
            3,
            5,
            7,
            10
          ],
          "name" : "Night Walk"
        },
        "useSoundFont" : true,
        "version" : 1,
        "waveform" : "sawtooth"
      }
    }
  ],
  "version" : 1
}
""".trim()
        val pack = SoundPresetPack.decode(ios.toByteArray())
        assertEquals("Night / Walk", pack.presets.single().name)
        assertEquals(ios, pack.encoded().toString(Charsets.UTF_8))
    }
}
