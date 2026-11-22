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
    private var handLandmarker: HandLandmarker? = null
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
        handLandmarker = createLandmarker(context, Delegate.GPU) ?: createLandmarker(context, Delegate.CPU)
    }

    private fun createLandmarker(context: Context, delegate: Delegate): HandLandmarker? = try {
        val options = HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(BaseOptions.builder().setModelAssetPath("hand_landmarker.task").setDelegate(delegate).build())
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setNumHands(2)
            .setMinHandDetectionConfidence(0.5f)
            .setMinHandPresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .setResultListener { result, _ -> processResult(result) }
            .setErrorListener { e -> Log.e(TAG, "Error: $e") }
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
        handLandmarker?.detectAsync(BitmapImageBuilder(bitmap).build(), timestampMs)
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

    fun close() {
        handLandmarker?.close()
    }

    private companion object { const val TAG = "HandTracking" }
}
