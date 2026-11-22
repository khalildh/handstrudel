package com.handstrudel.engine

import com.handstrudel.engine.strudel.StrudelAssets
import com.handstrudel.engine.strudel.StrudelBridge
import com.handstrudel.models.DEFAULT_MAPPING
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/** Drum code, quantize clock, hand math, mapping, drums lanes, Strudel shim and init polling. */
class EngineLogicTest {

    @Test fun drumCodeParts_matchIosFormatting() {
        val parts = HandStrudelEngine.buildDrumCodeParts(
            DrumTrackState("basic", 1.0, 120.0), DrumTrackState("none"), intensity = 0.5, complexity = 0.5, tempoScale = 1.0,
        )
        assertEquals(1, parts.size)
        assertTrue(parts[0].startsWith("((stack(note(\"f1\")"))
        assertTrue(parts[0].endsWith(").gain(0.90)).cpm(60.0)"))
        val both = HandStrudelEngine.buildDrumCodeParts(
            DrumTrackState("house", 0.5, 100.0), DrumTrackState("trap", 1.0, 140.0), 0.0, 0.0, 0.5,
        )
        assertEquals(2, both.size)
        assertTrue(both[0].endsWith(").gain(0.15)).cpm(12.5)"))
        assertTrue(both[1].endsWith(").gain(0.30)).cpm(17.5)"))
        assertEquals("silence", HandStrudelEngine.stackCode(emptyList()))
        assertEquals("stack(a, b)", HandStrudelEngine.stackCode(listOf("a", "b")))
    }

    @Test fun drumVolume_keepsTheSliderRangeAbove100Percent() {
        assertEquals(1.8, HandStrudelEngine.clampDrumVolume(1.8), 0.0)
        assertEquals(2.0, HandStrudelEngine.clampDrumVolume(2.4), 0.0)
        assertEquals(0.0, HandStrudelEngine.clampDrumVolume(-1.0), 0.0)
        val part = HandStrudelEngine.buildDrumCodeParts(
            DrumTrackState("basic", HandStrudelEngine.clampDrumVolume(1.8), 120.0), DrumTrackState("none"), 0.5, 0.5, 1.0,
        )
        assertTrue(part[0].endsWith(").gain(1.62)).cpm(60.0)")) // 1.8 × (0.3 + 0.5 × 1.2)
    }

    @Test fun foregroundTracker_backgroundsOnlyWhenNoActivityIsStarted() {
        val events = mutableListOf<Boolean>()
        val t = ForegroundTracker { events += it }
        t.activityStarted()
        // "Share one app" relaunch: a second instance starts before the first stops.
        t.activityStarted()
        t.activityStopped()
        assertTrue(t.isForeground)
        t.activityStopped()
        assertFalse(t.isForeground)
        t.activityStopped() // extra stop is ignored
        t.activityStarted()
        assertEquals(listOf(true, false, true), events)
    }

    @Test fun loopDuration_barsAndCap() {
        assertEquals(8.0, HandStrudelEngine.loopDuration(4, 120.0), 1e-9)
        assertEquals(90.0, HandStrudelEngine.loopDuration(32, 60.0), 1e-9)
    }

    @Test fun quantizeClock_firesOncePerSubdivision() {
        val q = QuantizeClock()
        assertFalse(q.boundaryCrossed(0.0)) // disabled
        q.enabled = true
        q.div = 8.0
        assertFalse(q.boundaryCrossed(0.1)) // no beat yet
        q.onBeat(1.0, 1.0)
        q.onBeat(1.5, 1.0) // quarter = 0.5 s → eighths every 0.25 s
        assertEquals(0.5, q.quarterPeriod, 1e-9)
        assertFalse(q.boundaryCrossed(1.55)) // first observation syncs
        assertFalse(q.boundaryCrossed(1.6))
        assertTrue(q.boundaryCrossed(1.76))
        assertFalse(q.boundaryCrossed(1.8))
        assertTrue(q.boundaryCrossed(2.01))
        q.div = 4.0 // resolution change re-syncs
        assertFalse(q.boundaryCrossed(2.02))
    }

    @Test fun handData_matchesIosMakeHandData() {
        val lm = MutableList(21) { HandLandmark(0.5f, 0.5f, 0f) }
        lm[0] = HandLandmark(0.5f, 0.8f, 0f)  // wrist
        lm[9] = HandLandmark(0.5f, 0.6f, 0f)  // middle MCP straight up
        lm[4] = HandLandmark(0.40f, 0.5f, 0f) // thumb tip
        lm[8] = HandLandmark(0.44f, 0.5f, 0f) // index tip, 0.04 away
        lm[20] = HandLandmark(0.65f, 0.5f, 0f)
        val h = HandData.from(lm, "Left")
        assertEquals(0.8, h.pinch, 1e-5)
        assertEquals(0.42, h.pinchX, 1e-5)
        assertEquals(0.25, h.rotation, 1e-6) // atan2(-0.2, 0) = -π/2 → 0.25
        assertEquals(minOf(1.0, 0.25 * 2.8), h.spread, 1e-5)
        assertEquals(h.value("pinch")!!, h.pinch, 0.0)
        assertNull(h.value("nope"))
    }

    @Test fun handMapper_invertsXAndY() {
        val params = mutableMapOf<String, Double>()
        val left = HandData.synthetic(0.0, 0.0, 0.0).copy(x = 0.0, y = 0.0, spread = 1.0)
        HandMapper.mapHandsToParams(HandsState(left = left), params, DEFAULT_MAPPING)
        assertEquals(17.0, params.getValue("noteIdx"), 1e-9) // y = 0 (top) → highest note
        assertEquals(6120.0, params.getValue("lpf"), 1e-9)   // x inverted
        assertEquals(0.9, params.getValue("reverb"), 1e-9)
        val smoothed = mutableMapOf("gain" to 0.0)
        ParamSmoother.smooth(mapOf("gain" to 1.0, "lpf" to 100.0), smoothed)
        assertEquals(0.6, smoothed.getValue("gain"), 1e-9)
        assertEquals(100.0, smoothed.getValue("lpf"), 1e-9)
    }

    @Test fun drumManager_lanesAndRetrigger() {
        val d = DrumModeManager()
        assertEquals(0, d.yToDrumIndex(0.0))
        assertEquals(5, d.yToDrumIndex(1.0))
        assertEquals(listOf(DrumHit("left", "crash")), d.checkHits(0.1 to 0.9, null))
        assertTrue(d.checkHits(0.1 to 0.9, null).isEmpty())
        assertEquals(listOf(DrumHit("left", "kick")), d.checkHits(0.95 to 0.9, null))
        assertTrue(d.checkHits(0.95 to 0.5, null).isEmpty()) // dead band
        assertTrue(d.isLeftPinching)
        d.checkHits(null, null)
        assertNull(d.leftLane)
        assertFalse(d.isLeftPinching)
    }

    @Test fun strudelShim_injectedFirstInHead() {
        val html = "<html>\n<head>\n<meta charset=\"utf-8\">\n<script>x()</script></head><body></body></html>"
        val out = StrudelAssets.injectShim(html)
        assertTrue(out.indexOf("android-shim.js") < out.indexOf("x()"))
        assertTrue(out.startsWith("<html>\n<head>"))
        assertEquals("audio/mpeg", StrudelAssets.mimeFor("audio/piano/A0.mp3"))
        assertEquals("application/javascript", StrudelAssets.mimeFor("strudel-bundle.js"))
    }

    @Test fun strudelInitPolling() = runTest {
        var n = 0
        StrudelBridge.waitForWebAudio(timeoutMillis = 5_000, pollMillis = 1) { if (++n < 3) "loading" else "ready" }
        assertEquals(3, n)
        try {
            StrudelBridge.waitForWebAudio(timeoutMillis = 5_000, pollMillis = 1) { "failed" }
            fail()
        } catch (e: StrudelBridge.StrudelInitException) {
            assertTrue(e.failed)
            assertEquals("The web audio engine couldn't start.", e.message)
        }
    }
}
