package com.handstrudel.engine

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

data class HandLandmark(val x: Float, val y: Float, val z: Float)

data class HandData(
    val landmarks: List<HandLandmark>,
    val chirality: String, // "Left" or "Right"
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

    fun detectAsync(bitmap: Bitmap, timestampMs: Long) {
        val mpImage = BitmapImageBuilder(bitmap).build()
        handLandmarker?.detectAsync(mpImage, timestampMs)
    }

    private fun processResult(result: HandLandmarkerResult) {
        if (result.landmarks().isEmpty()) {
            onHandsDetected?.invoke(HandsState())
            return
        }

        var left: HandData? = null
        var right: HandData? = null

        for (i in result.landmarks().indices) {
            val landmarks = result.landmarks()[i].map { lm ->
                // Mirror X for front camera (1 - x)
                HandLandmark(1f - lm.x(), lm.y(), lm.z())
            }

            // Chirality is swapped due to mirrored camera
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

        // Y position (wrist, inverted: top of screen = high pitch)
        val y = wrist.y.toDouble()

        // X position (wrist)
        val x = wrist.x.toDouble()

        // Spread: distance between index tip (8) and pinky tip (20)
        val idx = landmarks[8]
        val pinky = landmarks[20]
        val spreadDist = sqrt(
            ((idx.x - pinky.x) * (idx.x - pinky.x) +
             (idx.y - pinky.y) * (idx.y - pinky.y)).toDouble()
        )
        val spread = (spreadDist / 0.3).coerceIn(0.0, 1.0)

        // Pinch: closeness of thumb tip (4) and index tip (8)
        val thumb = landmarks[4]
        val index = landmarks[8]
        val pinchDist = sqrt(
            ((thumb.x - index.x) * (thumb.x - index.x) +
             (thumb.y - index.y) * (thumb.y - index.y)).toDouble()
        )
        val pinch = (1.0 - (pinchDist / 0.15)).coerceIn(0.0, 1.0)

        // Pinch position (midpoint of thumb + index)
        val pinchX = ((thumb.x + index.x) / 2.0).toDouble()
        val pinchY = ((thumb.y + index.y) / 2.0).toDouble()

        // Fist: average curl of all fingers
        val fist = computeFist(landmarks)

        // Fingers up count
        val fingersUp = countFingersUp(landmarks)

        return HandData(
            landmarks = landmarks,
            chirality = chirality,
            y = y, x = x,
            spread = spread, pinch = pinch,
            pinchX = pinchX, pinchY = pinchY,
            fist = fist, fingersUp = fingersUp
        )
    }

    private fun computeFist(landmarks: List<HandLandmark>): Double {
        // Measure how curled each finger is (tip distance to wrist vs MCP distance to wrist)
        val wrist = landmarks[0]
        var totalCurl = 0.0
        val fingers = listOf(8, 12, 16, 20) // index, middle, ring, pinky tips
        val mcps = listOf(5, 9, 13, 17)

        for (i in fingers.indices) {
            val tipDist = dist(landmarks[fingers[i]], wrist)
            val mcpDist = dist(landmarks[mcps[i]], wrist)
            if (mcpDist > 0.01) {
                val curl = 1.0 - (tipDist / mcpDist).coerceIn(0.0, 2.0) / 2.0
                totalCurl += curl
            }
        }
        return (totalCurl / 4.0).coerceIn(0.0, 1.0)
    }

    private fun countFingersUp(landmarks: List<HandLandmark>): Int {
        var count = 0
        val wrist = landmarks[0]
        // Fingers: index(8,6), middle(12,10), ring(16,14), pinky(20,18)
        val tips = listOf(8, 12, 16, 20)
        val pips = listOf(6, 10, 14, 18)
        for (i in tips.indices) {
            val tipDist = dist(landmarks[tips[i]], wrist)
            val pipDist = dist(landmarks[pips[i]], wrist)
            if (tipDist > pipDist * 1.1) count++
        }
        // Thumb: tip(4) vs IP(3) relative to wrist
        val thumbTipDist = dist(landmarks[4], wrist)
        val thumbIpDist = dist(landmarks[3], wrist)
        if (thumbTipDist > thumbIpDist * 1.1) count++
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
