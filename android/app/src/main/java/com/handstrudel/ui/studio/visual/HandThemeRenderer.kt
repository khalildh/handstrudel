package com.handstrudel.ui.studio.visual

import android.graphics.BlurMaskFilter
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import com.handstrudel.engine.HandLandmark
import com.handstrudel.engine.HandsState
import com.handstrudel.ui.studio.common.StageMetrics

private val CONNECTIONS = listOf(
    0 to 1, 1 to 2, 2 to 3, 3 to 4,
    0 to 5, 5 to 6, 6 to 7, 7 to 8,
    0 to 9, 9 to 10, 10 to 11, 11 to 12,
    0 to 13, 13 to 14, 14 to 15, 15 to 16,
    0 to 17, 17 to 18, 18 to 19, 19 to 20,
    5 to 9, 9 to 13, 13 to 17,
)
private val TIPS = listOf(4, 8, 12, 16, 20)
private val TRACKED = listOf(0, 4, 8, 12, 16, 20)
private const val MAX_TRAIL_POINTS = 48

/** Fixed-size ring buffer of (x, y, time) per tracked landmark (iOS `HandCanvasView.trails`). */
internal class HandTrails {
    class Point(val x: Float, val y: Float, val t: Double)
    val trails = HashMap<String, Array<Point>>()
    private val writeIdx = HashMap<String, Int>()

    fun record(side: String, landmarks: List<HandLandmark>, now: Double) {
        for (idx in TRACKED) {
            if (idx >= landmarks.size) continue
            val key = "${side}_$idx"
            val p = Point(landmarks[idx].x, landmarks[idx].y, now)
            val buf = trails.getOrPut(key) { Array(MAX_TRAIL_POINTS) { p } }
            val w = writeIdx[key] ?: 0
            buf[w] = p
            writeIdx[key] = (w + 1) % MAX_TRAIL_POINTS
        }
    }
}

/** iOS `visionToScreen`: aspect-fill correction from the camera frame to the view. */
internal fun visionToScreen(vx: Float, vy: Float, w: Float, h: Float, videoAspect: Float): Offset {
    val screenAspect = w / h
    return if (videoAspect > screenAspect) {
        val vis = screenAspect / videoAspect
        val off = (1 - vis) / 2
        Offset((vx - off) / vis * w, vy * h)
    } else {
        val vis = videoAspect / screenAspect
        val off = (1 - vis) / 2
        Offset(vx * w, (vy - off) / vis * h)
    }
}

/**
 * iOS `HandOverlayView`: themed skeleton with glow and fading motion trails
 * (wrist + fingertips), aspect-corrected to the video.
 */
@Composable
fun HandOverlay(handsState: HandsState, theme: HandTheme, modifier: Modifier = Modifier, videoAspect: Float = StageMetrics.VIDEO_ASPECT) {
    val trails = remember { HandTrails() }
    SideEffect {
        val now = System.nanoTime() / 1e9
        handsState.left?.let { trails.record("left", it.landmarks, now) }
        handsState.right?.let { trails.record("right", it.landmarks, now) }
    }
    Canvas(modifier) {
        val now = System.nanoTime() / 1e9
        drawTrails(trails, "left", theme.leftColor, theme.trailLength, now, videoAspect)
        drawTrails(trails, "right", theme.rightColor, theme.trailLength, now, videoAspect)
        handsState.left?.let { drawHand(it.landmarks, theme.leftColor, theme.glowIntensity, videoAspect) }
        handsState.right?.let { drawHand(it.landmarks, theme.rightColor, theme.glowIntensity, videoAspect) }
    }
}

private fun DrawScope.glowStroke(a: Offset, b: Offset, color: Color, width: Float, blur: Float, crisp: Boolean = true) {
    drawIntoCanvas { c ->
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color.toArgb()
            strokeWidth = width
            style = android.graphics.Paint.Style.STROKE
            strokeCap = android.graphics.Paint.Cap.ROUND
            if (blur > 0f) maskFilter = BlurMaskFilter(blur, BlurMaskFilter.Blur.NORMAL)
        }
        c.nativeCanvas.drawLine(a.x, a.y, b.x, b.y, paint)
    }
    // CoreGraphics `setShadow` + stroke paints the stroke itself crisply on top of its blurred
    // shadow, so the iOS glow layer reads as a solid 4 pt band, not only a haze.
    if (crisp && blur > 0f) drawLine(color, a, b, strokeWidth = width, cap = StrokeCap.Round)
}

private fun DrawScope.glowDot(center: Offset, radius: Float, color: Color, blur: Float) {
    if (blur > 0f) {
        drawIntoCanvas { c ->
            val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                this.color = color.toArgb()
                maskFilter = BlurMaskFilter(blur, BlurMaskFilter.Blur.NORMAL)
            }
            c.nativeCanvas.drawCircle(center.x, center.y, radius + blur / 2, paint)
        }
    }
    drawCircle(color, radius, center)
}

private fun DrawScope.drawTrails(trails: HandTrails, side: String, color: Color, duration: Double, now: Double, aspect: Float) {
    val d = density
    for (idx in TRACKED) {
        val points = trails.trails["${side}_$idx"] ?: continue
        val isTip = idx != 0
        val baseWidth = (if (isTip) 3f else 2f) * d
        for (i in 1 until points.size) {
            val age = now - points[i].t
            val fade = (1 - age / duration).coerceAtLeast(0.0).toFloat()
            val alpha = fade * if (isTip) 0.6f else 0.3f
            if (alpha < 0.01f) continue
            val p0 = visionToScreen(points[i - 1].x, points[i - 1].y, size.width, size.height, aspect)
            val p1 = visionToScreen(points[i].x, points[i].y, size.width, size.height, aspect)
            if (isTip && fade > 0.3f) glowStroke(p0, p1, color.copy(alpha = alpha * 0.5f), baseWidth * fade + 4 * d * fade, 6 * d * fade, crisp = false)
            drawLine(color.copy(alpha = alpha), p0, p1, strokeWidth = baseWidth * fade, cap = StrokeCap.Round)
        }
    }
}

private fun DrawScope.drawHand(landmarks: List<HandLandmark>, color: Color, glow: Float, aspect: Float) {
    if (landmarks.size < 21) return
    val d = density
    fun pt(i: Int) = visionToScreen(landmarks[i].x, landmarks[i].y, size.width, size.height, aspect)
    // Glow layer, then sharp lines.
    for ((a, b) in CONNECTIONS) glowStroke(pt(a), pt(b), color.copy(alpha = 0.4f), 4 * d, 12 * d * glow * 0.5f)
    for ((a, b) in CONNECTIONS) drawLine(color.copy(alpha = 0.7f), pt(a), pt(b), strokeWidth = 1.5f * d, cap = StrokeCap.Round)
    glowDot(pt(0), 6 * d, color, 10 * d * glow * 0.5f)
    for (i in TIPS) glowDot(pt(i), 4 * d, color.copy(alpha = 0.9f), 8 * d * glow * 0.5f)
    for (i in 1 until landmarks.size) {
        if (i in TIPS) continue
        drawCircle(color.copy(alpha = 0.3f), 2 * d, pt(i))
    }
}
