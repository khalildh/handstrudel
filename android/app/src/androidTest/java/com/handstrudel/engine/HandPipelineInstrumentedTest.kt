package com.handstrudel.engine

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.os.SystemClock
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.handstrudel.ui.studio.orientFrameForDetection
import org.junit.AfterClass
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.BeforeClass
import org.junit.FixMethodOrder
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.MethodSorters
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * The real hand pipeline on a device: photos of real hands → the production
 * frame transform (`orientFrameForDetection`, rotate + selfie mirror) →
 * `HandTrackingManager` (MediaPipe, LIVE_STREAM) → `HandStrudelEngine` hands
 * path → Scale-mode wheel (Rust core) → native SoundFont voices.
 *
 * Only the CameraX delivery of frames is replaced: each "raw camera frame" is
 * built as the unmirrored image a front sensor would capture.
 *
 * Test images (src/androidTest/assets):
 *  - open_right.jpg: crop of MediaPipe's `right_hands.jpg` test asset (Apache-2.0,
 *    storage.googleapis.com/mediapipe-assets), a real right hand, open.
 *  - thumb_up.jpg, victory.jpg: MediaPipe test assets (Apache-2.0), right hands.
 *  - pinch_right.jpg: crop of "Gebaar - Okay.JPG" by Milliped, Wikimedia Commons,
 *    CC BY-SA 4.0 (https://commons.wikimedia.org/wiki/File:Gebaar_-_Okay.JPG),
 *    a real right hand with thumb and index tips touching.
 *
 * Run: ./gradlew :app:connectedDebugAndroidTest
 *      (logcat tag HandPipelineTest has the measured numbers).
 */
@RunWith(AndroidJUnit4::class)
@FixMethodOrder(MethodSorters.NAME_ASCENDING)
class HandPipelineInstrumentedTest {

    companion object {
        private const val TAG = "HandPipelineTest"
        private const val W = 480
        private const val H = 640

        // promo/lib/choreo.mjs GEOM (mirrors iOS ChordMelodyModeManager geometry).
        private const val RADIUS_FRACTION = 0.92
        private const val BASE_RADIUS = 0.62

        private lateinit var engine: HandStrudelEngine
        private val results = LinkedBlockingQueue<HandsState>()
        private var timestampMs = 1_000L
        private val latenciesMs = mutableListOf<Double>()

        private val instrumentation get() = InstrumentationRegistry.getInstrumentation()

        @BeforeClass @JvmStatic
        fun setUp() {
            instrumentation.runOnMainSync {
                engine = HandStrudelEngine(instrumentation.targetContext)
                engine.switchMode(StudioMode.SCALE)
                engine.setUseSoundFont(StudioMode.SCALE, true)
                engine.setSwapHands(false)
                engine.start(PlayInput.AIR)
                // Tap the tracker's output; the engine's own callback still runs.
                val original = engine.handTracker.onHandsDetected
                engine.handTracker.onHandsDetected = { hands -> results.offer(hands); original?.invoke(hands) }
            }
            val deadline = SystemClock.uptimeMillis() + 10_000
            while (!engine.isRunning.value && SystemClock.uptimeMillis() < deadline) SystemClock.sleep(50)
            assertTrue("engine running", engine.isRunning.value)
            assertTrue("hand tracker active (air input)", engine.handTracker.isActive)
            // Warm-up: keep frames flowing like a camera until the tracker answers
            // (the first GPU inference, or the GPU→CPU watchdog, can take seconds).
            val blank = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
            val warmEnd = SystemClock.uptimeMillis() + 20_000
            var answered = false
            while (!answered && SystemClock.uptimeMillis() < warmEnd) {
                timestampMs += 33
                engine.handTracker.detectAsync(orientFrameForDetection(blank, 0), timestampMs)
                answered = results.poll(100, TimeUnit.MILLISECONDS) != null
            }
            assertTrue("hand tracker produced a result", answered)
        }

        @AfterClass @JvmStatic
        fun tearDown() {
            instrumentation.runOnMainSync { engine.stop() }
        }

        private fun asset(name: String): Bitmap =
            instrumentation.context.assets.open(name).use { BitmapFactory.decodeStream(it) }!!

        private fun mirrored(b: Bitmap): Bitmap =
            Bitmap.createBitmap(b, 0, 0, b.width, b.height, Matrix().apply { postScale(-1f, 1f) }, true)

        private fun scaledToHeight(b: Bitmap, h: Int): Bitmap =
            Bitmap.createScaledBitmap(b, b.width * h / b.height, h, true)

        /** A selfie-space frame (what the user sees) with each image pasted at its top-left. */
        private fun selfie(vararg layers: Pair<Bitmap, Pair<Float, Float>>): Bitmap {
            val out = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
            val c = Canvas(out)
            c.drawColor(Color.rgb(128, 128, 128))
            for ((img, pos) in layers) c.drawBitmap(img, pos.first, pos.second, null)
            return out
        }

        /** Raw (unmirrored, rotation-0) sensor frame that shows [selfieFrame] after the production transform. */
        private fun rawFor(selfieFrame: Bitmap): Bitmap = mirrored(selfieFrame)

        /** One frame through the production transform + tracker; waits for its result. */
        private fun feed(raw: Bitmap, rotation: Int = 0): HandsState {
            results.clear()
            val oriented = orientFrameForDetection(raw, rotation)
            timestampMs += 33
            val t0 = System.nanoTime()
            engine.handTracker.detectAsync(oriented, timestampMs)
            val r = results.poll(3, TimeUnit.SECONDS) ?: error("no tracker result within 3 s")
            latenciesMs += (System.nanoTime() - t0) / 1e6
            return r
        }

        /** Feed the same frame at ~30 fps for [ms] so the engine's frame loop ticks on it. */
        private fun hold(raw: Bitmap, ms: Long): HandsState {
            var last = HandsState()
            val end = SystemClock.uptimeMillis() + ms
            while (SystemClock.uptimeMillis() < end) {
                val start = SystemClock.uptimeMillis()
                last = feed(raw)
                val spent = SystemClock.uptimeMillis() - start
                if (spent < 33) SystemClock.sleep(33 - spent)
            }
            return last
        }

        private fun <T> onMain(block: () -> T): T {
            var v: T? = null
            instrumentation.runOnMainSync { v = block() }
            @Suppress("UNCHECKED_CAST") return v as T
        }

        private fun nativeVoices(): Int = onMain { engine.soundFont.activeVoiceCount }
        private fun nativePeak(): Float = onMain { engine.soundFont.output.takePeak() }

        /** choreo.mjs polarToScreen → camera coords (undo the aspect-fill crop like iOS DemoDirector). */
        private fun wheelPointToCamera(angleDeg: Double, radius: Double): Pair<Double, Double> {
            val sa = engine.screenAspect
            val va = engine.handTracker.videoAspect
            val r = min(0.5 * sa, 0.5) * RADIUS_FRACTION
            val a = Math.toRadians(angleDeg)
            val sx = 0.5 + radius * r * sin(a) / sa
            val sy = 0.5 - radius * r * cos(a)
            val camX = if (va > sa) (1 - sa / va) / 2 + sx * (sa / va) else sx
            return camX to sy
        }

        /** Selfie-space top-left at which [img] puts its pinch point on (tx, ty). */
        private val pinchOffsets = mutableMapOf<Bitmap, Pair<Float, Float>>()
        private fun placeFor(img: Bitmap, isLeft: Boolean, tx: Double, ty: Double): Pair<Float, Float> {
            val rel = pinchOffsets.getOrPut(img) {
                val at = (W - img.width) / 2f to (H - img.height) / 2f
                val s = feed(rawFor(selfie(img to at)))
                val hand = (if (isLeft) s.left else s.right) ?: error("calibration: hand not detected")
                (hand.pinchX * W - at.first).toFloat() to (hand.pinchY * H - at.second).toFloat()
            }
            return (tx * W - rel.first).toFloat() to (ty * H - rel.second).toFloat()
        }

        private fun waitFor(timeoutMs: Long, keepFeeding: Bitmap, cond: () -> Boolean): Boolean {
            val end = SystemClock.uptimeMillis() + timeoutMs
            while (SystemClock.uptimeMillis() < end) {
                if (cond()) return true
                hold(keepFeeding, 100)
            }
            return cond()
        }
    }

    private val pinchSelfieRight by lazy { mirrored(scaledToHeight(asset("pinch_right.jpg"), 300)) } // user's right hand as seen in the mirror
    private val pinchSelfieLeft by lazy { scaledToHeight(asset("pinch_right.jpg"), 300) }            // user's left hand
    private val openSelfieRight by lazy { mirrored(scaledToHeight(asset("open_right.jpg"), 300)) }

    @Test
    fun a_handednessLandmarksAndRotation() {
        for (name in listOf("open_right.jpg", "thumb_up.jpg", "victory.jpg", "pinch_right.jpg")) {
            val photo = scaledToHeight(asset(name), 360) // an unmirrored photo of a RIGHT hand
            // Raw sensor frame: the user's right hand appears on the image's left.
            val raw = selfie(photo to ((W * 0.3f - photo.width / 2f) to (H - 360) / 2f))
            val s = feed(raw)
            assertNotNull("$name: right hand detected", s.right)
            assertNull("$name: no phantom left hand", s.left)
            val hand = s.right!!
            assertEquals("$name: 21 landmarks", 21, hand.landmarks.size)
            assertTrue("$name: landmarks normalized", hand.landmarks.all { it.x in -0.05f..1.05f && it.y in -0.05f..1.05f })
            // Mirrored preview: a hand on the raw frame's left shows on the screen's right.
            assertTrue("$name: wrist on the right half after mirroring (x=${hand.x})", hand.x > 0.5)

            // The same frame as a portrait phone's front sensor delivers it (landscape,
            // rotationDegrees = 270) must land in the same place.
            val sensor = Bitmap.createBitmap(raw, 0, 0, W, H, Matrix().apply { postRotate(90f) }, true)
            val r = feed(sensor, rotation = 270)
            assertNotNull("$name: right hand detected from a rotated sensor frame", r.right)
            Log.i(TAG, "rotation $name: rot0 wrist=(%.3f,%.3f) rot270 wrist=(%.3f,%.3f)".format(hand.x, hand.y, r.right!!.x, r.right!!.y))
            assertTrue("$name: same wrist after rotation", abs(r.right!!.x - hand.x) < 0.03 && abs(r.right!!.y - hand.y) < 0.03)

            // The mirror image of a right hand is a left hand.
            val l = feed(mirrored(raw))
            assertNotNull("$name mirrored: left hand detected", l.left)
            assertNull("$name mirrored: no right hand", l.right)
            Log.i(TAG, "handedness $name: right wrist=(%.3f,%.3f) pinch=%.2f; mirrored → left wrist=(%.3f,%.3f)".format(
                hand.x, hand.y, hand.pinch, l.left!!.x, l.left!!.y))
        }
        // Both hands at once.
        val photo = scaledToHeight(asset("open_right.jpg"), 300)
        val both = selfie(mirrored(photo) to ((W * 0.75f - photo.width / 2f) to 170f), photo to ((W * 0.25f - photo.width / 2f) to 170f))
        val s = feed(rawFor(both))
        assertNotNull("two hands: right", s.right)
        assertNotNull("two hands: left", s.left)
        assertTrue("two hands: right hand on screen right", s.right!!.x > s.left!!.x)
    }

    @Test
    fun b_detectionRateAndLatencyOnAMovingHand() {
        latenciesMs.clear()
        var detected = 0
        val n = 60
        for (i in 0 until n) {
            val t = i / (n - 1.0)
            val img = if (i % 2 == 0) openSelfieRight else pinchSelfieRight
            val x = (W * (0.15 + 0.5 * t)).toFloat()
            val y = (H * (0.15 + 0.25 * sin(t * Math.PI * 2) + 0.15)).toFloat()
            val s = feed(rawFor(selfie(img to (x to y))))
            if (s.right != null) detected++
        }
        val sorted = latenciesMs.sorted()
        val avg = sorted.average()
        val p95 = sorted[(sorted.size * 0.95).toInt().coerceAtMost(sorted.size - 1)]
        Log.i(TAG, "detection %d/%d (%.0f%%), submit→result ms avg=%.1f p95=%.1f max=%.1f".format(
            detected, n, 100.0 * detected / n, avg, p95, sorted.last()))
        assertTrue("detection rate ≥ 90% ($detected/$n)", detected >= n * 0.9)
        assertTrue("avg latency < 200 ms ($avg)", avg < 200)
    }

    @Test
    fun c_scaleMelodyHandPlaysTheLaneUnderThePinch() {
        val laneCount = engine.scale.intervals.size
        val played = mutableListOf<String>()
        for (lane in 0 until laneCount) {
            // choreo.mjs melodyPoint(lane, laneCount, 0): top of the right arc = highest pitch.
            val wedge = laneCount - 1 - lane
            val (cx, cy) = wheelPointToCamera(180.0 * (wedge + 0.5) / laneCount, BASE_RADIUS)
            val at = placeFor(pinchSelfieRight, isLeft = false, tx = cx, ty = cy)
            val pinchFrame = rawFor(selfie(pinchSelfieRight to at))
            nativePeak()
            val s = hold(pinchFrame, 400)
            val hand = s.right
            assertNotNull("lane $lane: right hand detected", hand)
            assertTrue("lane $lane: pinch > 0.8 (${hand!!.pinch})", hand.pinch > 0.8)
            assertTrue("lane $lane: engine sees melody pinch", waitFor(1000, pinchFrame) { engine.chordMelody.value.isMelodyHandPinching })
            val display = engine.chordMelody.value
            assertEquals("lane $lane: wheel lane (pinch at %.3f,%.3f)".format(hand.pinchX, hand.pinchY), lane, display.melodyLane)
            val voices = nativeVoices()
            val peak = nativePeak()
            Log.i(TAG, "melody lane $lane target=(%.3f,%.3f) got=(%.3f,%.3f) pinch=%.2f lane=%s note=%s voices=%d peak=%.3f".format(
                cx, cy, hand.pinchX, hand.pinchY, hand.pinch, display.melodyLane, onMain { engine.lastGridNote }, voices, peak))
            assertTrue("lane $lane: native voice sounding ($voices)", voices > 0)
            assertTrue("lane $lane: audible output (peak $peak)", peak > 0.001f)
            played += onMain { engine.lastGridNote }

            // Open the hand at the same spot: the note releases.
            val openFrame = rawFor(selfie(openSelfieRight to at))
            assertTrue("lane $lane: pinch released", waitFor(1500, openFrame) { !engine.chordMelody.value.isMelodyHandPinching })
            assertTrue("lane $lane: voices back to 0", waitFor(4000, openFrame) { nativeVoices() == 0 })
        }
        Log.i(TAG, "melody notes by lane: $played")
        assertEquals("each lane plays a different note", laneCount, played.toSet().size)
    }

    @Test
    fun d_scaleChordHandPlaysTheZoneUnderThePinch() {
        val zones = engine.chordMelody.value.zoneDegrees.size.takeIf { it > 0 } ?: 7
        for (zone in 0 until zones) {
            // choreo.mjs chordPoint(zone, zoneCount, 0): left arc, zone 0 at the top.
            val (cx, cy) = wheelPointToCamera(360 - 180.0 * (zone + 0.5) / zones, BASE_RADIUS)
            val at = placeFor(pinchSelfieLeft, isLeft = true, tx = cx, ty = cy)
            val frame = rawFor(selfie(pinchSelfieLeft to at))
            val s = hold(frame, 400)
            assertNotNull("zone $zone: left hand detected", s.left)
            assertNull("zone $zone: not reported as the right hand", s.right)
            assertTrue("zone $zone: engine sees chord pinch", waitFor(1000, frame) { engine.chordMelody.value.isChordHandPinching })
            val d = engine.chordMelody.value
            val voices = nativeVoices()
            Log.i(TAG, "chord zone $zone degrees=${d.zoneDegrees} target=(%.3f,%.3f) got=(%.3f,%.3f) zone=%s chord=%s voices=%d".format(
                cx, cy, s.left!!.pinchX, s.left!!.pinchY, d.chordZoneIndex, d.currentChordName, voices))
            assertEquals("zone $zone: wheel zone", zone, d.chordZoneIndex)
            assertEquals("zone $zone: degree", d.zoneDegrees[zone], d.currentDegree)
            assertTrue("zone $zone: pad voices sounding ($voices)", voices >= 3)
            val open = rawFor(selfie(scaledToHeight(asset("open_right.jpg"), 300) to at))
            assertTrue("zone $zone: pad stops on release", waitFor(4000, open) { nativeVoices() == 0 })
        }
    }

    @Test
    fun e_noHandsMeansSilence() {
        val empty = rawFor(selfie())
        val s = hold(empty, 300)
        assertNull(s.left); assertNull(s.right)
        assertTrue("no voices without hands", waitFor(3000, empty) { nativeVoices() == 0 })
    }
}
