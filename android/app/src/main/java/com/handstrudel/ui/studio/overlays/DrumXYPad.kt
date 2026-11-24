package com.handstrudel.ui.studio.overlays

import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices

/**
 * iOS `ContentView.drumXYPad` (80 pt tall): drag anywhere to set the drum
 * groove. Horizontal = complexity (left SIMPLE → right COMPLEX), vertical =
 * intensity (bottom 0 → top 1). The green dot sits at
 * (complexity × width, (1 − intensity) × height).
 */
@Composable
fun DrumXYPad(modifier: Modifier = Modifier) {
    val engine = LocalAppServices.current.engine
    val intensity by engine.drumIntensity.collectAsState()
    val complexity by engine.drumComplexity.collectAsState()
    val colors = rememberOverlayColors()
    val shape = RoundedCornerShape(12.dp)

    Box(
        modifier
            .fillMaxWidth()
            .height(80.dp)
            .testTag("drum-xy-pad")
            .background(Color.Black.copy(alpha = 0.4f), shape)
            .border(1.dp, Color.White.copy(alpha = 0.1f), shape)
            .pointerInput(Unit) {
                awaitPointerEventScope {
                    while (true) {
                        val event = awaitPointerEvent()
                        val change = event.changes.firstOrNull { it.pressed } ?: continue
                        val (cx, cy) = DrumPadGeometry.valuesForPoint(
                            change.position.x, change.position.y, size.width.toFloat(), size.height.toFloat(),
                        )
                        // Seam: drumPad(x = intensity, y = complexity).
                        engine.drumPad(cy, cx)
                        change.consume()
                    }
                }
            },
    ) {
        // Quadrant labels.
        val labelStyle = TextStyle(fontSize = 9.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Rounded, color = Color.White.copy(alpha = 0.15f))
        Column(Modifier.fillMaxSize().padding(8.dp)) {
            Row(Modifier.fillMaxWidth()) {
                Text("SOFT", style = labelStyle)
                Spacer(Modifier.weight(1f))
                Text("LOUD", style = labelStyle)
            }
            Spacer(Modifier.weight(1f))
            Row(Modifier.fillMaxWidth()) {
                Text("SIMPLE", style = labelStyle)
                Spacer(Modifier.weight(1f))
                Text("COMPLEX", style = labelStyle)
            }
        }
        Canvas(Modifier.fillMaxSize()) {
            val line = Color.White.copy(alpha = 0.06f)
            val px = 1.dp.toPx()
            // Crosshair.
            drawRect(line, topLeft = Offset(size.width / 2f - px / 2f, 0f), size = Size(px, size.height))
            drawRect(line, topLeft = Offset(0f, size.height / 2f - px / 2f), size = Size(size.width, px))
            // Position dot (20 pt, green glow radius 8).
            val dot = Offset(complexity.toFloat() * size.width, (1f - intensity.toFloat()) * size.height)
            val r = 10.dp.toPx()
            glowPath(Path().apply { addOval(androidx.compose.ui.geometry.Rect(dot, r)) }, colors.green.copy(alpha = 0.5f), 8.dp.toPx())
            drawCircle(colors.green, r, dot)
        }
    }
}

/** Pure XY pad mapping (JVM-tested). */
object DrumPadGeometry {
    /** Touch → (complexity, intensity), both clamped to 0…1. */
    fun valuesForPoint(x: Float, y: Float, width: Float, height: Float): Pair<Double, Double> {
        if (width <= 0f || height <= 0f) return 0.0 to 0.0
        val complexity = (x / width).toDouble().coerceIn(0.0, 1.0)
        val intensity = (1.0 - y / height).coerceIn(0.0, 1.0)
        return complexity to intensity
    }

    /** Dot centre for the current values. */
    fun dotForValues(complexity: Double, intensity: Double, width: Float, height: Float): Pair<Float, Float> =
        (complexity * width).toFloat() to ((1 - intensity) * height).toFloat()
}
