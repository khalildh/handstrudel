package com.handstrudel.engine

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.ImageProcessingOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import kotlin.math.sqrt

data class HandLandmark(val x: Float, val y: Float, val z: Float)

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
    val fingersUp: Int
)

data class HandsState(
    val left: HandData? = null,
    val right: HandData? = null
)

class HandTrackingManager(context: Context) {
    private var handLandmarker: HandLandmarker? = null
    var onHandsDetected: ((HandsState) -> Unit)? = null

    init {
        try {
            val options = HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(
                    BaseOptions.builder()
                        .setModelAssetPath("hand_landmarker.task")
                        .build()
                )
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setNumHands(2)
                .setMinHandDetectionConfidence(0.5f)
                .setMinHandPresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setResultListener { result, _ -> processResult(result) }
                .setErrorListener { e -> Log.e("HandTracking", "Error: $e") }
                .build()

            handLandmarker = HandLandmarker.createFromOptions(context, options)
        } catch (e: Exception) {
            Log.e("HandTracking", "Failed to init: $e")
        }
    }

    fun detectAsync(bitmap: Bitmap, rotationDegrees: Int, timestampMs: Long) {
        val mpImage = BitmapImageBuilder(bitmap).build()
        val options = ImageProcessingOptions.builder()
            .setRotationDegrees(rotationDegrees)
            .build()
        handLandmarker?.detectAsync(mpImage, options, timestampMs)
    }

    private fun processResult(result: HandLandmarkerResult) {
        if (result.landmarks().isEmpty()) {
            onHandsDetected?.invoke(HandsState())
            return
        }

        var left: HandData? = null
        var right: HandData? = null

        for (i in result.landmarks().indices) {
            // Landmarks come back in portrait coordinate space (rotation applied by MediaPipe)
            // Mirror X for front camera selfie view
            val landmarks = result.landmarks()[i].map { lm ->
                HandLandmark(1f - lm.x(), lm.y(), lm.z())
            }

            // Swap chirality because we mirror X
            val rawChirality = if (i < result.handednesses().size) {
                result.handednesses()[i][0].categoryName()
            } else "Left"
            val chirality = if (rawChirality == "Left") "Right" else "Left"

            val handData = computeHandData(landmarks, chirality)

            if (chirality == "Left") left = handData
            else right = handData
        }

        onHandsDetected?.invoke(HandsState(left, right))
    }

    private fun computeHandData(landmarks: List<HandLandmark>, chirality: String): HandData {
        val wrist = landmarks[0]
        val y = wrist.y.toDouble()
        val x = wrist.x.toDouble()

        val idx = landmarks[8]
        val pinky = landmarks[20]
        val spreadDist = dist(idx, pinky)
        val spread = (spreadDist / 0.3).coerceIn(0.0, 1.0)

        val thumb = landmarks[4]
        val index = landmarks[8]
        val pinchDist = dist(thumb, index)
        val pinch = (1.0 - (pinchDist / 0.15)).coerceIn(0.0, 1.0)

        val pinchX = ((thumb.x + index.x) / 2.0).toDouble()
        val pinchY = ((thumb.y + index.y) / 2.0).toDouble()

        val fist = computeFist(landmarks)
        val fingersUp = countFingersUp(landmarks)

        return HandData(landmarks, chirality, y, x, spread, pinch, pinchX, pinchY, fist, fingersUp)
    }

    private fun computeFist(landmarks: List<HandLandmark>): Double {
        val wrist = landmarks[0]
        var totalCurl = 0.0
        val tips = listOf(8, 12, 16, 20)
        val mcps = listOf(5, 9, 13, 17)
        for (i in tips.indices) {
            val tipDist = dist(landmarks[tips[i]], wrist)
            val mcpDist = dist(landmarks[mcps[i]], wrist)
            if (mcpDist > 0.01) {
                totalCurl += (1.0 - (tipDist / mcpDist).coerceIn(0.0, 2.0) / 2.0)
            }
        }
        return (totalCurl / 4.0).coerceIn(0.0, 1.0)
    }

    private fun countFingersUp(landmarks: List<HandLandmark>): Int {
        val wrist = landmarks[0]
        var count = 0
        val tips = listOf(8, 12, 16, 20)
        val pips = listOf(6, 10, 14, 18)
        for (i in tips.indices) {
            if (dist(landmarks[tips[i]], wrist) > dist(landmarks[pips[i]], wrist) * 1.1) count++
        }
        if (dist(landmarks[4], wrist) > dist(landmarks[3], wrist) * 1.1) count++
        return count
    }

    private fun dist(a: HandLandmark, b: HandLandmark): Double {
        val dx = (a.x - b.x).toDouble()
        val dy = (a.y - b.y).toDouble()
        return sqrt(dx * dx + dy * dy)
    }

    fun close() {
        handLandmarker?.close()
    }
}
