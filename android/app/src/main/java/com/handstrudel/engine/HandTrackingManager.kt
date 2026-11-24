package com.handstrudel.engine

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlin.math.atan2
import kotlin.math.sqrt

data class HandLandmark(val x: Float, val y: Float, val z: Float)

/**
 * One tracked hand, every gesture axis computed as in iOS
 * `HandTrackingManager.makeHandData` (2-D distances; Vision has no z).
 * The first ten fields are the Phase 0 shape; rotation and the curls are iOS
 * additions (defaults keep older call sites compiling).
 */
data class HandData(
    val landmarks: List<HandLandmark>,
    val chirality: String,
    val y: Double,
    val x: Double,
    val spread: Double,
    val pinch: Double,
    val pinchX: Double,
    val pinchY: Double,
    val fist: Double,
    val fingersUp: Int,
    val rotation: Double = 0.5,
    val thumbCurl: Double = 0.0,
    val indexCurl: Double = 0.0,
    val middleCurl: Double = 0.0,
    val ringCurl: Double = 0.0,
    val pinkyCurl: Double = 0.0,
) {
    /** iOS `HandData.value(for:)`. */
    fun value(axisKey: String): Double? = when (axisKey) {
        "x" -> x
        "y" -> y
        "spread" -> spread
        "pinch" -> pinch
        "fist" -> fist
        "rotation" -> rotation
        "thumbCurl" -> thumbCurl
        "indexCurl" -> indexCurl
        "middleCurl" -> middleCurl
        "ringCurl" -> ringCurl
        "pinkyCurl" -> pinkyCurl
        else -> null
    }

    companion object {
        /** iOS `makeHandData(landmarks:)`, from 21 normalized top-left-origin landmarks. */
        fun from(landmarks: List<HandLandmark>, chirality: String): HandData {
            fun dist(a: HandLandmark, b: HandLandmark): Double {
                val dx = (a.x - b.x).toDouble()
                val dy = (a.y - b.y).toDouble()
                return sqrt(dx * dx + dy * dy)
            }
            val wrist = landmarks[0]
            val spread = minOf(1.0, dist(landmarks[4], landmarks[20]) * 2.8)
            val thumbCurl = minOf(1.0, dist(landmarks[4], landmarks[2]) * 4)
            val indexCurl = minOf(1.0, dist(landmarks[8], landmarks[5]) * 4)
            val middleCurl = minOf(1.0, dist(landmarks[12], landmarks[9]) * 4)
            val ringCurl = minOf(1.0, dist(landmarks[16], landmarks[13]) * 4)
            val pinkyCurl = minOf(1.0, dist(landmarks[20], landmarks[17]) * 4)
            val pinch = (1 - dist(landmarks[4], landmarks[8]) * 5).coerceIn(0.0, 1.0)
            val fist = (1 - (thumbCurl + indexCurl + middleCurl + ringCurl + pinkyCurl) / 5).coerceIn(0.0, 1.0)
            val dx = (landmarks[9].x - wrist.x).toDouble()
            val dy = (landmarks[9].y - wrist.y).toDouble()
            val rotation = (atan2(dy, dx) / Math.PI + 1) / 2
            val curls = listOf(thumbCurl, indexCurl, middleCurl, ringCurl, pinkyCurl)
            return HandData(
                landmarks = landmarks,
                chirality = chirality,
                y = wrist.y.toDouble(),
                x = wrist.x.toDouble(),
                spread = spread,
                pinch = pinch,
                pinchX = ((landmarks[4].x + landmarks[8].x) / 2.0),
                pinchY = ((landmarks[4].y + landmarks[8].y) / 2.0),
                fist = fist,
                fingersUp = curls.count { it > 0.6 },
                rotation = rotation,
                thumbCurl = thumbCurl,
                indexCurl = indexCurl,
                middleCurl = middleCurl,
                ringCurl = ringCurl,
                pinkyCurl = pinkyCurl,
            )
        }

        /** A synthetic hand at a pinch point (tests and the debug driver). */
        fun synthetic(pinchX: Double, pinchY: Double, pinch: Double, chirality: String = "Left"): HandData = HandData(
            landmarks = emptyList(), chirality = chirality, y = pinchY, x = pinchX, spread = 0.5, pinch = pinch,
            pinchX = pinchX, pinchY = pinchY, fist = 0.0, fingersUp = 0,
            thumbCurl = 0.5, indexCurl = 0.5, middleCurl = 0.5, ringCurl = 0.5, pinkyCurl = 0.5,
        )
    }
}

data class HandsState(
    val left: HandData? = null,
    val right: HandData? = null,
)

/**
 * MediaPipe hand landmarker. The camera itself is bound by `CameraPreview`
 * (studio-ui), which feeds oriented, mirrored frames to [detectAsync] and
 * should report CameraX failures through [onCameraBindFailed] / [onCameraInUse].
 */
class HandTrackingManager(context: Context) {
    private val appContext = context.applicationContext
    @Volatile private var handLandmarker: HandLandmarker? = null
    @Volatile private var delegate: Delegate = Delegate.GPU

    // GPU watchdog: some GPU drivers (and the emulator's GL) pass delegate init
    // but fail every inference ("Graph has errors"); MediaPipe only logs that,
    // results never arrive and the error listener is not called. Until the
    // first result arrives, too many unanswered GPU frames switch to the CPU.
    @Volatile private var gotResult = false
    private var unansweredSince = 0L
    private var unansweredFrames = 0

    // Slow-GPU check: on low-end GPUs (e.g. PowerVR GE8320 in the Nokia G10) the GPU
    // delegate works but takes ~400 ms a frame and starves the UI of the GPU, while the
    // CPU is several times faster. Measure submit→result latency once tracking settles;
    // if the GPU is slow, try the CPU, and go back to the GPU if the CPU is no better.
    private val submitNanos = java.util.concurrent.ConcurrentHashMap<Long, Long>()
    private val speed = SpeedWindow()
    @Volatile private var pendingDelegate: Delegate? = null
    private var gpuLatencyMs = Double.NaN
    @Volatile private var delegateSettled = false

    // One frame in flight at a time. Submitting every camera frame (30/s) on a slow
    // phone queues stale frames behind inference (≈0.4 s lag on a Nokia G10) and burns
    // CPU converting frames that are thrown away. Uptime of the frame in flight, 0 = idle.
    @Volatile private var inFlightSinceMs = 0L

    /**
     * True when the tracker can take a frame now. Callers skip the bitmap conversion
     * otherwise. Before the first result every frame goes through (GPU watchdog).
     */
    fun wantsFrame(): Boolean {
        if (!gotResult) return true
        val since = inFlightSinceMs
        return since == 0L || android.os.SystemClock.uptimeMillis() - since > IN_FLIGHT_TIMEOUT_MS
    }
    var onHandsDetected: ((HandsState) -> Unit)? = null

    /** When false (touch input), frames are dropped so no hands reach the engine. */
    @Volatile var isActive: Boolean = true

    private val _cameraIssue = MutableStateFlow<CameraIssue?>(null)
    /** iOS `HandTrackingManager.cameraIssue`. */
    val cameraIssue: StateFlow<CameraIssue?> = _cameraIssue
    /** Engine hook: denial falls back to touch (iOS `onCameraAccessBlocked`). */
    internal var onCameraIssue: ((CameraIssue?) -> Unit)? = null

    /** Oriented frame size, for aspect-fill correction (iOS `videoWidth/videoHeight`). */
    @Volatile var videoWidth: Double = 480.0
        private set
    @Volatile var videoHeight: Double = 640.0
        private set
    val videoAspect: Double get() = if (videoHeight > 0) videoWidth / videoHeight else 0.75

    init {
        // GPU is 2–3× faster; some drivers fail to init it, so fall back to CPU.
        handLandmarker = createLandmarker(appContext, Delegate.GPU)
            ?: createLandmarker(appContext, Delegate.CPU).also { delegate = Delegate.CPU }
    }

    private fun createLandmarker(context: Context, delegate: Delegate): HandLandmarker? = try {
        val options = HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(BaseOptions.builder().setModelAssetPath("hand_landmarker.task").setDelegate(delegate).build())
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setNumHands(2)
            .setMinHandDetectionConfidence(0.5f)
            .setMinHandPresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .setResultListener { result, _ ->
                gotResult = true
                inFlightSinceMs = 0L
                val submitted = submitNanos.remove(result.timestampMs())
                if (submitted != null) checkSpeed((System.nanoTime() - submitted) / 1e6)
                recordStats(submitted, result.landmarks().size)
                processResult(result)
            }
            .setErrorListener { e -> inFlightSinceMs = 0L; Log.e(TAG, "Error: $e") }
            .build()
        HandLandmarker.createFromOptions(context, options).also { Log.i(TAG, "HandLandmarker initialized on $delegate") }
    } catch (e: Exception) {
        Log.w(TAG, "Failed to init on $delegate, trying fallback", e)
        null
    }

    /**
     * [bitmap] must already be rotated to the display orientation and mirrored
     * for selfie view (done in `CameraPreview.processFrame`).
     */
    fun detectAsync(bitmap: Bitmap, timestampMs: Long) {
        videoWidth = bitmap.width.toDouble()
        videoHeight = bitmap.height.toDouble()
        if (!isActive) return
        val issue = _cameraIssue.value
        if (issue == CameraIssue.UNAVAILABLE || issue == CameraIssue.INTERRUPTED) reportCameraIssue(null) // frames flow again
        if (!wantsFrame()) return
        if (shouldAbandonGpu()) fallBackToCpu()
        pendingDelegate?.let { pendingDelegate = null; switchDelegate(it) }
        val landmarker = handLandmarker ?: return
        // MediaPipe's live-stream graph throws (and takes the app down) on a timestamp that
        // isn't strictly increasing, e.g. a camera rebind or a second frame source; clamp it.
        // Stamp and submit under one lock so two threads can't hand MediaPipe out-of-order stamps.
        synchronized(timestampLock) {
            val ts = maxOf(timestampMs, lastTimestampMs + 1)
            lastTimestampMs = ts
            if (submitNanos.size > 64) submitNanos.clear()
            submitNanos[ts] = System.nanoTime()
            inFlightSinceMs = android.os.SystemClock.uptimeMillis()
            landmarker.detectAsync(BitmapImageBuilder(bitmap).build(), ts)
        }
    }
    private val timestampLock = Any()
    private var lastTimestampMs = Long.MIN_VALUE / 2

    /** DEBUG only: once a second, log frames/s and submit→result latency (verification). */
    private class Stats { var windowStart = 0L; var frames = 0; var withHands = 0; var latencyNanos = 0L; var maxNanos = 0L }
    private val stats: Stats? = if (com.handstrudel.BuildConfig.DEBUG) Stats() else null

    private fun recordStats(submitted: Long?, hands: Int) {
        val s = stats ?: return
        val now = System.nanoTime()
        if (submitted == null) return
        if (s.windowStart == 0L) s.windowStart = now
        s.frames += 1
        if (hands > 0) s.withHands += 1
        val latency = now - submitted
        s.latencyNanos += latency
        if (latency > s.maxNanos) s.maxNanos = latency
        val window = now - s.windowStart
        if (window >= 1_000_000_000L) {
            Log.d(TAG, "stats fps=%.1f frames=%d withHands=%d avgMs=%.1f maxMs=%.1f".format(
                s.frames * 1e9 / window, s.frames, s.withHands, s.latencyNanos / 1e6 / s.frames, s.maxNanos / 1e6))
            s.windowStart = now; s.frames = 0; s.withHands = 0; s.latencyNanos = 0; s.maxNanos = 0
        }
    }

    private fun processResult(result: HandLandmarkerResult) {
        if (!isActive) return
        if (result.landmarks().isEmpty()) {
            onHandsDetected?.invoke(HandsState())
            return
        }
        var left: HandData? = null
        var right: HandData? = null
        for (i in result.landmarks().indices) {
            val raw = result.landmarks()[i]
            if (raw.size < 21) continue
            val rawChirality = result.handednesses().getOrNull(i)?.firstOrNull()?.categoryName() ?: "Left"
            // The frame is mirrored upstream, which also flips MediaPipe's
            // handedness: swap to the user's anatomical hand (matches iOS).
            val chirality = if (rawChirality == "Left") "Right" else "Left"
            val hand = HandData.from(raw.map { HandLandmark(it.x(), it.y(), it.z()) }, chirality)
            if (chirality == "Left") left = hand else right = hand
        }
        onHandsDetected?.invoke(HandsState(left, right))
    }

    /** Shell (permission) and the camera binding report issues here; null clears. */
    fun reportCameraIssue(issue: CameraIssue?) {
        if (_cameraIssue.value == issue) return
        _cameraIssue.value = issue
        onCameraIssue?.invoke(issue)
    }

    /** CameraX `bindToLifecycle` failed (iOS `.unavailable`). */
    fun onCameraBindFailed(error: Throwable?) {
        Log.w(TAG, "camera bind failed", error)
        reportCameraIssue(CameraIssue.UNAVAILABLE)
    }

    /** CameraX `CameraState.ERROR_CAMERA_IN_USE` / `ERROR_MAX_CAMERAS_IN_USE` (iOS `.interrupted`). */
    fun onCameraInUse() = reportCameraIssue(CameraIssue.INTERRUPTED)

    /** Called per submitted frame (camera executor thread). */
    private fun shouldAbandonGpu(): Boolean {
        if (delegate != Delegate.GPU || gotResult) return false
        val now = android.os.SystemClock.uptimeMillis()
        if (unansweredFrames == 0) unansweredSince = now
        unansweredFrames += 1
        return unansweredFrames >= GPU_WATCHDOG_FRAMES && now - unansweredSince >= GPU_WATCHDOG_MS
    }

    /** Latency over a window after a warm-up; one decision per delegate (result thread). */
    private class SpeedWindow { var firstAt = 0L; var start = 0L; var n = 0; var sumMs = 0.0
        fun reset() { firstAt = 0L; start = 0L; n = 0; sumMs = 0.0 } }

    private fun checkSpeed(latencyMs: Double) {
        if (delegateSettled || pendingDelegate != null) return
        val w = speed
        val now = android.os.SystemClock.uptimeMillis()
        if (w.firstAt == 0L) { w.firstAt = now; return }
        if (now - w.firstAt < SPEED_WARMUP_MS) return
        if (w.start == 0L) w.start = now
        w.n += 1; w.sumMs += latencyMs
        if (now - w.start < SPEED_WINDOW_MS || w.n < 3) return
        val avg = w.sumMs / w.n
        w.reset()
        when (delegate) {
            Delegate.GPU -> if (avg > SLOW_GPU_MS) {
                Log.w(TAG, "GPU delegate is slow (avg %.0f ms); trying CPU".format(avg))
                gpuLatencyMs = avg
                pendingDelegate = Delegate.CPU
            } else { Log.i(TAG, "GPU delegate keeps up (avg %.0f ms)".format(avg)); delegateSettled = true }
            else -> {
                // Keep the CPU unless it's clearly slower: a slow GPU running the tracker also
                // has to draw the UI, so sharing it makes the whole stage stutter.
                if (!gpuLatencyMs.isNaN() && avg > gpuLatencyMs * CPU_TOLERANCE) {
                    Log.w(TAG, "CPU (avg %.0f ms) is no faster than GPU (%.0f ms); back to GPU".format(avg, gpuLatencyMs))
                    pendingDelegate = Delegate.GPU
                } else Log.i(TAG, "Using CPU delegate (avg %.0f ms)".format(avg))
                delegateSettled = true
            }
        }
    }

    /** Camera executor thread, between frames. */
    private fun switchDelegate(to: Delegate) {
        if (to == delegate) return
        val next = createLandmarker(appContext, to) ?: return
        val old = handLandmarker
        handLandmarker = next
        delegate = to
        submitNanos.clear()
        inFlightSinceMs = 0L
        speed.reset()
        try { old?.close() } catch (e: Exception) { Log.w(TAG, "closing $old", e) }
    }

    private fun fallBackToCpu() {
        Log.w(TAG, "GPU delegate produced no results for $unansweredFrames frames; switching to CPU")
        delegate = Delegate.CPU
        // Closing a graph that has failed rethrows its error.
        try { handLandmarker?.close() } catch (e: Exception) { Log.w(TAG, "closing failed GPU landmarker", e) }
        handLandmarker = createLandmarker(appContext, Delegate.CPU)
        submitNanos.clear()
    }

    fun close() {
        try { handLandmarker?.close() } catch (e: Exception) { Log.w(TAG, "close failed", e) }
    }

    private companion object {
        const val TAG = "HandTracking"
        const val GPU_WATCHDOG_FRAMES = 30
        const val GPU_WATCHDOG_MS = 3000L
        const val IN_FLIGHT_TIMEOUT_MS = 1000L
        const val SPEED_WARMUP_MS = 1500L
        const val SPEED_WINDOW_MS = 2000L
        /** ~10 results/s; above this the hand lags visibly behind the camera image. */
        const val SLOW_GPU_MS = 100.0
        /** CPU latency may be this much worse than the slow GPU's and still win. */
        const val CPU_TOLERANCE = 1.5
    }
}
