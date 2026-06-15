package com.handstrudel.ui

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import com.handstrudel.engine.HandData
import com.handstrudel.engine.HandsState

private val LEFT_COLOR = Color(0xFF00FF9E)  // Green
private val RIGHT_COLOR = Color(0xFFFF2E6B) // Pink

private val CONNECTIONS = listOf(
    0 to 1, 1 to 2, 2 to 3, 3 to 4,
    0 to 5, 5 to 6, 6 to 7, 7 to 8,
    0 to 9, 9 to 10, 10 to 11, 11 to 12,
    0 to 13, 13 to 14, 14 to 15, 15 to 16,
    0 to 17, 17 to 18, 18 to 19, 19 to 20,
    5 to 9, 9 to 13, 13 to 17,
)

private val TIPS = listOf(4, 8, 12, 16, 20)

/// The camera ImageAnalysis target is 480x640 (portrait), so after rotation
/// the frame's aspect (width / height) is 0.75. PreviewView is set to
/// FILL_CENTER, which scales the camera image up to fill the canvas in the
/// short dimension and crops the long one. The landmark coordinates from
/// MediaPipe are normalized to the *full* camera frame — without this
/// correction they'd be drawn at the wrong place inside the cropped preview.
private const val CAMERA_ASPECT = 0.75f

@Composable
fun HandOverlay(
    handsState: HandsState,
    modifier: Modifier = Modifier
) {
    Canvas(modifier = modifier) {
        handsState.left?.let { drawHand(it, LEFT_COLOR) }
        handsState.right?.let { drawHand(it, RIGHT_COLOR) }
    }
}

private fun DrawScope.drawHand(hand: HandData, color: Color) {
    val landmarks = hand.landmarks
    if (landmarks.size < 21) return

    val screenAspect = size.width / size.height
    // FILL_CENTER scaling: pick whichever fraction makes the camera frame
    // cover the canvas, then the other axis loses content to a centered crop.
    val visibleWidthFrac: Float
    val visibleHeightFrac: Float
    val offsetX: Float
    val offsetY: Float
    if (CAMERA_ASPECT > screenAspect) {
        // Camera is wider than the canvas → height fills, sides are cropped.
        visibleWidthFrac = screenAspect / CAMERA_ASPECT
        visibleHeightFrac = 1f
        offsetX = (1f - visibleWidthFrac) / 2f
        offsetY = 0f
    } else {
        visibleWidthFrac = 1f
        visibleHeightFrac = CAMERA_ASPECT / screenAspect
        offsetX = 0f
        offsetY = (1f - visibleHeightFrac) / 2f
    }

    fun pt(i: Int): Offset {
        val lm = landmarks[i]
        val sx = (lm.x - offsetX) / visibleWidthFrac
        val sy = (lm.y - offsetY) / visibleHeightFrac
        return Offset(sx * size.width, sy * size.height)
    }

    // Glow connections
    for ((a, b) in CONNECTIONS) {
        if (a >= landmarks.size || b >= landmarks.size) continue
        drawLine(
            color = color.copy(alpha = 0.4f),
            start = pt(a),
            end = pt(b),
            strokeWidth = 4f,
            cap = StrokeCap.Round
        )
    }

    // Sharp connections
    for ((a, b) in CONNECTIONS) {
        if (a >= landmarks.size || b >= landmarks.size) continue
        drawLine(
            color = color.copy(alpha = 0.7f),
            start = pt(a),
            end = pt(b),
            strokeWidth = 1.5f,
            cap = StrokeCap.Round
        )
    }

    // Wrist dot
    val wrist = pt(0)
    drawCircle(color = color, radius = 6f, center = wrist)

    // Fingertip dots
    for (i in TIPS) {
        if (i >= landmarks.size) continue
        val p = pt(i)
        drawCircle(color = color.copy(alpha = 0.9f), radius = 5f, center = p)
    }

    // Other landmarks
    for (i in 1 until landmarks.size) {
        if (i == 0 || i in TIPS) continue
        val p = pt(i)
        drawCircle(color = color.copy(alpha = 0.3f), radius = 2.5f, center = p)
    }
}
