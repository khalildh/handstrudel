package com.handstrudel.ui.studio.overlays

import android.graphics.BlurMaskFilter
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.semantics.clearAndSetSemantics
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * iOS `WeaveView`: the music made visible. Three additive layers of rose curves
 * that orbit and breathe with the live parameters, drawn over the camera.
 * Inputs are 0…1: [hue] pitch colour (wrapped), [energy] volume → size and
 * intensity, [space] reverb → glow, [brightness] filter → line crispness,
 * [speed] tempo → rotation, [complexity] crush/shape → petals and wobble.
 */
@Composable
fun WeaveView(
    hue: Double,
    energy: Double,
    space: Double,
    brightness: Double,
    speed: Double,
    complexity: Double,
    modifier: Modifier = Modifier,
) {
    var t by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        val start = withFrameNanos { it }
        while (true) {
            withFrameNanos { now -> t = (now - start) / 1_000_000_000f }
        }
    }
    val paths = remember { List(WeaveMath.LAYERS) { android.graphics.Path() } }
    val glowPaint = remember {
        android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            style = android.graphics.Paint.Style.STROKE
            blendMode = android.graphics.BlendMode.PLUS
        }
    }
    val corePaint = remember {
        android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            style = android.graphics.Paint.Style.STROKE
            blendMode = android.graphics.BlendMode.PLUS
        }
    }

    Canvas(modifier.fillMaxSize().clearAndSetSemantics { }) {
        val time = t.toDouble()
        val cx = size.width / 2f
        val cy = size.height / 2f
        val base = min(size.width, size.height) * 0.30
        val dp = density
        val blurPx = ((4 + space * 22) * dp).toFloat()
        val glowBlur = BlurMaskFilter(blurPx, BlurMaskFilter.Blur.NORMAL)

        drawIntoCanvas { canvas ->
            val native = canvas.nativeCanvas
            for (layer in 0 until WeaveMath.LAYERS) {
                val path = paths[layer]
                path.rewind()
                WeaveMath.forEachPoint(layer, time, base, energy, speed, complexity) { i, x, y ->
                    val px = cx + x.toFloat()
                    val py = cy + y.toFloat()
                    if (i == 0) path.moveTo(px, py) else path.lineTo(px, py)
                }
                path.close()

                val color = android.graphics.Color.HSVToColor(
                    floatArrayOf((WeaveMath.layerHue(hue, layer) * 360).toFloat(), 0.72f, 1f),
                )

                // Soft outer glow (reverb opens it up).
                glowPaint.color = color
                glowPaint.alpha = ((0.14 + energy * 0.22).coerceIn(0.0, 1.0) * 255).roundToInt()
                glowPaint.strokeWidth = ((2 + brightness * 3) * dp).toFloat()
                glowPaint.maskFilter = glowBlur
                native.drawPath(path, glowPaint)

                // Crisp inner thread (filter brightness sharpens it).
                corePaint.color = color
                corePaint.alpha = ((0.30 + brightness * 0.30).coerceIn(0.0, 1.0) * 255).roundToInt()
                corePaint.strokeWidth = ((1 + brightness * 1.2) * dp).toFloat()
                native.drawPath(path, corePaint)
            }
        }
    }
}

/** The Weave's curve maths, ported from iOS (JVM-tested). */
object WeaveMath {
    const val LAYERS = 3
    const val STEPS = 180

    /** 2…6 petals. */
    fun petals(complexity: Double): Int = 2 + (complexity * 4).roundToInt()

    /** Layer colour hue in 0…1 (iOS adds 0.05 per layer; negative hues wrap). */
    fun layerHue(hue: Double, layer: Int): Double {
        val h = (hue + layer * 0.05) % 1.0
        return if (h < 0) h + 1.0 else h
    }

    /** Calls [point] for each of the `STEPS + 1` curve points, offsets from the centre in px. */
    inline fun forEachPoint(
        layer: Int, t: Double, base: Double, energy: Double, speed: Double, complexity: Double,
        point: (index: Int, x: Double, y: Double) -> Unit,
    ) {
        val rot = t * (0.06 + speed * 0.5)
        val k = petals(complexity).toDouble()
        val lp = layer.toDouble()
        val phase = rot + lp * 0.7
        val breathe = 0.85 + 0.15 * sin(t * (0.6 + speed * 0.8) + lp)
        for (i in 0..STEPS) {
            val th = i.toDouble() / STEPS * PI * 2
            // Rose curve warped over time into a woven swirl.
            val petal = 0.55 + 0.45 * sin(k * th + phase)
            val wobble = 1 + complexity * 0.18 * sin(3 * th - rot * 1.3)
            val rr = base * petal * wobble * breathe * (0.8 + energy * 0.5)
            val a = th + rot * 0.35
            point(i, cos(a) * rr, sin(a) * rr)
        }
    }
}
