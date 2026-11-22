package com.handstrudel.ui.studio.overlays

import com.handstrudel.ui.theme.StudioFonts
import android.graphics.BlurMaskFilter
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.models.MusicKey
import com.handstrudel.ui.studio.common.StudioMusic
import com.handstrudel.ui.studio.common.WheelGeometry
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlin.math.max

/**
 * iOS `RadialChordMelodyOverlayView`: one wheel centred on the stage. The outer
 * ring is the harmony (chord hand), the inner ring the melody, with a rest hole
 * in the middle that shows the sounding chord.
 *
 * iOS 1.0.1 has no touch layer for Radial (the wheel is hand-only); Android adds
 * one with the same geometry as the drawn wheel: inner ring → melody lane
 * (wedge index, 9 wedges), outer ring and beyond → chord zone, rest hole → nothing.
 */
@Composable
fun RadialWheelOverlay(touchEnabled: Boolean, modifier: Modifier = Modifier) {
    val engine = LocalAppServices.current.engine
    val cm by engine.chordMelody.collectAsState()
    val key by engine.selectedKey.collectAsState()
    val scale by engine.selectedScale.collectAsState()
    val intervals = scale.intervals
    val colors = rememberOverlayColors()

    val progression by engine.chordMelodyProgression.collectAsState()
    // The engine publishes zoneDegrees; fall back to the progression before its first tick.
    val zoneDegrees = cm.zoneDegrees.ifEmpty { progression.degrees }
    val chordNames = zoneDegrees.map { StudioMusic.chordDisplayName(key, intervals, it) }
    val melodyDegree = cm.currentDegree ?: zoneDegrees.firstOrNull() ?: 0
    val melodyNames = RadialGeometry.melodyNames(key, intervals, melodyDegree)
    val zoneCount = max(1, chordNames.size)
    val melodyCount = max(1, melodyNames.size)

    var touches by remember { mutableStateOf<Map<Long, RadialGeometry.Hit>>(emptyMap()) }
    val touchedChords = touches.values.filterIsInstance<RadialGeometry.Hit.Chord>().map { it.zone }.toSet() +
        cm.touchedChordZones.map { it.wedge }
    val touchedLanes = touches.values.filterIsInstance<RadialGeometry.Hit.Melody>().map { it.lane }.toSet() +
        cm.touchedMelodyLanes

    val measurer = rememberTextMeasurer()
    Canvas(
        modifier
            .fillMaxSize()
            .zoneMultitouch(
                enabled = touchEnabled,
                resolve = { p, size ->
                    RadialGeometry.hitForPoint(p.x, p.y, size.width.toFloat(), size.height.toFloat(), zoneCount, melodyCount)
                },
                onEnter = { id, hit ->
                    when (hit) {
                        is RadialGeometry.Hit.Chord -> engine.radialTouchEnterChord(id, hit.zone)
                        is RadialGeometry.Hit.Melody -> engine.radialTouchEnterMelody(id, hit.lane)
                    }
                },
                onExit = { id -> engine.radialTouchExit(id) },
                onActiveChanged = { touches = it },
            ),
    ) {
        val outerR = WheelGeometry.radialOuterRadius(size.width, size.height)
        val center = Offset(size.width / 2f, size.height / 2f)
        val deadR = outerR * WheelGeometry.RADIAL_DEADZONE.toFloat()
        val splitR = outerR * RadialGeometry.RING_SPLIT_FRACTION.toFloat()

        // ---- Melody (inner) ring ----
        val melodyWedge = 360.0 / melodyCount
        for (i in 0 until melodyCount) {
            val touched = i in touchedLanes
            val isCurrent = (cm.melodyLane == i && !cm.melodyResting) || touched
            val isHeld = (isCurrent && cm.isMelodyHandPinching) || touched
            val path = annularWedge(center, deadR, splitR, i * melodyWedge - melodyWedge / 2, i * melodyWedge + melodyWedge / 2)
            if (isHeld) glowPath(path, colors.cyan.copy(alpha = 0.4f), 6.dp.toPx())
            drawPath(
                path,
                when {
                    isHeld -> colors.cyan.copy(alpha = 0.45f)
                    isCurrent -> colors.cyan.copy(alpha = 0.2f)
                    else -> Color.White.copy(alpha = 0.05f)
                },
            )
            drawPath(
                path,
                when {
                    isHeld -> colors.cyan.copy(alpha = 0.85f)
                    isCurrent -> colors.cyan.copy(alpha = 0.45f)
                    else -> Color.White.copy(alpha = 0.08f)
                },
                style = Stroke(width = (if (isHeld) 2.5f else 1f).dp.toPx()),
            )
            drawCenteredText(
                measurer, melodyNames.getOrElse(i) { "" },
                WheelGeometry.polar(center.x, center.y, i * melodyWedge, (deadR + splitR) / 2f),
                TextStyle(
                    fontSize = 10.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Rounded,
                    color = if (isCurrent) Color.White else colors.cyan.copy(alpha = 0.75f),
                    shadow = Shadow(Color.Black.copy(alpha = 0.6f), blurRadius = 2.dp.toPx()),
                ),
            )
        }

        // ---- Chord (outer) ring ----
        val chordWedge = 360.0 / zoneCount
        for (i in 0 until zoneCount) {
            val degree = degreeForZone(zoneDegrees, i)
            val color = colors.forDegree(degree)
            val touched = i in touchedChords
            val isCurrent = (cm.chordHandLane == i && !cm.chordResting) || touched
            val isHeld = (isCurrent && cm.isChordHandPinching) || touched
            val path = annularWedge(center, splitR, outerR, i * chordWedge - chordWedge / 2, i * chordWedge + chordWedge / 2)
            if (isHeld) glowPath(path, color.copy(alpha = 0.5f), 12.dp.toPx())
            drawPath(
                path,
                when {
                    isHeld -> color.copy(alpha = 0.5f)
                    isCurrent -> color.copy(alpha = 0.28f)
                    else -> Color.White.copy(alpha = 0.05f)
                },
            )
            drawPath(
                path,
                when {
                    isHeld -> color.copy(alpha = 0.95f)
                    isCurrent -> color.copy(alpha = 0.6f)
                    else -> Color.White.copy(alpha = 0.1f)
                },
                style = Stroke(width = (if (isHeld) 2.5f else if (isCurrent) 1.5f else 1f).dp.toPx()),
            )
            drawCenteredText(
                measurer, chordNames.getOrElse(i) { "" },
                WheelGeometry.polar(center.x, center.y, i * chordWedge, (splitR + outerR) / 2f),
                TextStyle(
                    fontSize = 15.sp, fontWeight = FontWeight.Black, fontFamily = StudioFonts.Rounded,
                    color = if (isCurrent) Color.White else Color.White.copy(alpha = 0.7f),
                    shadow = Shadow(Color.Black.copy(alpha = 0.6f), blurRadius = 3.dp.toPx()),
                ),
            )
        }

        // ---- Rest hole ----
        val resting = cm.chordResting || cm.melodyResting
        drawCircle(if (resting) colors.green.copy(alpha = 0.16f) else Color.Black.copy(alpha = 0.25f), deadR, center)
        drawCircle(
            if (resting) colors.green.copy(alpha = 0.6f) else Color.White.copy(alpha = 0.15f), deadR, center,
            style = Stroke(width = (if (resting) 2f else 1f).dp.toPx()),
        )
        if (cm.currentChordName.isNotEmpty()) {
            val brush = Brush.horizontalGradient(
                if (cm.isChordHandPinching) listOf(colors.green, colors.cyan)
                else listOf(Color.White.copy(alpha = 0.8f), Color.White.copy(alpha = 0.5f)),
            )
            // iOS `.minimumScaleFactor(0.4)` inside the hole with 4 pt side padding.
            val maxWidth = deadR * 2f - 8.dp.toPx()
            val base = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.Black, fontFamily = StudioFonts.Rounded)
            val natural = measurer.measure(cm.currentChordName, base, maxLines = 1, softWrap = false).size.width
            val factor = if (natural > maxWidth && natural > 0) max(0.4f, maxWidth / natural) else 1f
            val layout = measurer.measure(
                cm.currentChordName, base.copy(fontSize = 22.sp * factor, brush = brush), maxLines = 1, softWrap = false,
            )
            drawText(layout, topLeft = Offset(center.x - layout.size.width / 2f, center.y - layout.size.height / 2f))
        }
    }
}

/** Pure Radial wheel geometry (JVM-tested). Angles are degrees clockwise from 12 o'clock, as on iOS. */
object RadialGeometry {
    /** iOS overlay `ringSplitFraction`: boundary between the inner melody ring and the outer chord ring. */
    const val RING_SPLIT_FRACTION = 0.60
    /** iOS Radial melody wedge count (`radialWedgeIndex(angle:count: 9)`). */
    const val MELODY_COUNT = 9

    sealed interface Hit {
        data class Chord(val zone: Int) : Hit
        data class Melody(val lane: Int) : Hit
    }

    /** Wedge [index] of [count] spans `[start, end]`; wedge 0 is centred on the top. */
    fun wedgeBounds(index: Int, count: Int): Pair<Double, Double> {
        val w = 360.0 / max(1, count)
        return (index * w - w / 2) to (index * w + w / 2)
    }

    /**
     * Touch → wheel zone in a [width]×[height] stage. Null inside the rest hole.
     * Inner ring (rest edge…60 %) → melody wedge; outer ring and beyond the rim
     * → chord wedge (the rim clamps, like the Split wheel's touch layer).
     */
    fun hitForPoint(x: Float, y: Float, width: Float, height: Float, zoneCount: Int, melodyCount: Int): Hit? {
        val outerR = WheelGeometry.radialOuterRadius(width, height)
        if (outerR <= 0f) return null
        val (deg, r) = WheelGeometry.polarOf(x, y, width / 2f, height / 2f, outerR)
        if (r < WheelGeometry.RADIAL_DEADZONE) return null
        return if (r < RING_SPLIT_FRACTION) Hit.Melody(WheelGeometry.radialWedgeIndex(deg, max(1, melodyCount)))
        else Hit.Chord(WheelGeometry.radialWedgeIndex(deg, max(1, zoneCount)))
    }

    /** ContentView: melody wedges are the current chord's triad over 3 octaves, as pitch-class names. */
    fun melodyMidis(key: MusicKey, intervals: List<Int>, melodyDegree: Int): List<Int> {
        val triad = StudioMusic.chordNotes(key, intervals, melodyDegree)
        return (0 until 3).flatMap { oct -> triad.map { it + oct * 12 } }.sorted()
    }

    fun melodyNames(key: MusicKey, intervals: List<Int>, melodyDegree: Int): List<String> =
        melodyMidis(key, intervals, melodyDegree).map { StudioMusic.pitchClassName(it) }
}

// ---------------------------------------------------------------------------------
// Shared overlay internals (used by the other overlay files in this package).
// ---------------------------------------------------------------------------------

internal fun degreeForZone(zoneDegrees: List<Int>, index: Int): Int {
    if (zoneDegrees.isEmpty()) return 0
    return zoneDegrees[index.coerceIn(0, zoneDegrees.size - 1)]
}

/** SwiftUI system colours (light/dark variants) used by the iOS overlays. */
@Immutable
internal data class OverlayColors(
    val green: Color,
    val cyan: Color,
    val pink: Color,
    val yellow: Color,
    val orange: Color,
    val red: Color,
    val purple: Color,
    val gray: Color,
) {
    /** iOS overlays' `colorForDegree`. */
    fun forDegree(degree: Int): Color = when (degree) {
        0 -> green
        1 -> Color(0.6f, 0.5f, 0.9f)
        2 -> Color(0.7f, 0.6f, 0.9f)
        3 -> Color(0.4f, 0.8f, 0.9f)
        4 -> pink
        5 -> Color(0.9f, 0.6f, 0.4f)
        6 -> Color(0.9f, 0.4f, 0.4f)
        else -> gray
    }

    companion object {
        val DARK = OverlayColors(
            green = Color(0xFF30D158), cyan = Color(0xFF64D2FF), pink = Color(0xFFFF375F),
            yellow = Color(0xFFFFD60A), orange = Color(0xFFFF9F0A), red = Color(0xFFFF453A),
            purple = Color(0xFFBF5AF2), gray = Color(0xFF8E8E93),
        )
        val LIGHT = OverlayColors(
            green = Color(0xFF34C759), cyan = Color(0xFF32ADE6), pink = Color(0xFFFF2D55),
            yellow = Color(0xFFFFCC00), orange = Color(0xFFFF9500), red = Color(0xFFFF3B30),
            purple = Color(0xFFAF52DE), gray = Color(0xFF8E8E93),
        )
    }
}

/** iOS resolves `.green` etc. against the stage colour scheme (light only for the Paper theme). */
@Composable
internal fun rememberOverlayColors(): OverlayColors {
    val palette = LocalStudioPalette.current
    return if (palette.background.luminance() > 0.5f) OverlayColors.LIGHT else OverlayColors.DARK
}

/** iOS `RadialWedge`: annular sector, angles clockwise from 12 o'clock, 28 steps per arc. */
internal fun annularWedge(center: Offset, innerR: Float, outerR: Float, startDeg: Double, endDeg: Double): Path {
    val path = Path()
    val steps = 28
    for (i in 0..steps) {
        val t = startDeg + (endDeg - startDeg) * i / steps
        val (x, y) = WheelGeometry.polar(center.x, center.y, t, outerR)
        if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
    }
    for (i in 0..steps) {
        val t = endDeg - (endDeg - startDeg) * i / steps
        val (x, y) = WheelGeometry.polar(center.x, center.y, t, innerR)
        path.lineTo(x, y)
    }
    path.close()
    return path
}

/** SwiftUI `.shadow(color:radius:)` on a shape: a blurred copy of the silhouette underneath. */
internal fun DrawScope.glowPath(path: Path, color: Color, radiusPx: Float) {
    if (radiusPx <= 0f || color.alpha <= 0f) return
    drawIntoCanvas { canvas ->
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color.toArgb()
            maskFilter = BlurMaskFilter(radiusPx, BlurMaskFilter.Blur.NORMAL)
        }
        canvas.nativeCanvas.drawPath(path.asAndroidPath(), paint)
    }
}

internal fun DrawScope.glowRoundRect(color: Color, radiusPx: Float, cornerPx: Float, topLeft: Offset = Offset.Zero, size: Size = this.size) {
    if (radiusPx <= 0f || color.alpha <= 0f) return
    val path = Path().apply {
        addRoundRect(androidx.compose.ui.geometry.RoundRect(topLeft.x, topLeft.y, topLeft.x + size.width, topLeft.y + size.height, CornerRadius(cornerPx)))
    }
    glowPath(path, color, radiusPx)
}

/** Modifier form of [glowRoundRect] for layout-based overlays (drawn behind the content). */
internal fun Modifier.iosGlow(color: Color, radiusDp: Float, cornerDp: Float): Modifier =
    if (color.alpha <= 0f) this else drawBehind { glowRoundRect(color, radiusDp.dp.toPx(), cornerDp.dp.toPx()) }

/**
 * iOS draws the octave hints as `Text("↑")`/`Text("↓")` in the SF system font (bold). The
 * Rounded stand-in has no arrow glyph, so the fallback rendered a hairline arrow about half
 * the size; draw SF's arrow instead: an 11 pt bold arrow is ~8.3 pt tall with a ~6.6 pt head
 * and a ~1.3 pt stroke. [fontSize] is the iOS point size (11 chord, 9 melody).
 */
internal fun DrawScope.drawArrowGlyph(at: Pair<Float, Float>, up: Boolean, fontSize: Float, color: Color, shadowAlpha: Float = 0f) {
    val u = (fontSize / 11f) * 1.dp.toPx()
    val half = 4.15f * u
    val head = 3.3f * u
    val d = if (up) -1f else 1f
    val (x, y) = at
    val path = androidx.compose.ui.graphics.Path().apply {
        moveTo(x, y - d * half); lineTo(x, y + d * half)
        moveTo(x - head, y + d * (half - head)); lineTo(x, y + d * half); lineTo(x + head, y + d * (half - head))
    }
    val stroke = Stroke(width = 1.35f * u, cap = androidx.compose.ui.graphics.StrokeCap.Round, join = androidx.compose.ui.graphics.StrokeJoin.Round)
    if (shadowAlpha > 0f) drawPath(path, Color.Black.copy(alpha = shadowAlpha * 0.5f), style = Stroke(width = 3.5f * u, cap = androidx.compose.ui.graphics.StrokeCap.Round))
    drawPath(path, color, style = stroke)
}

internal fun DrawScope.drawCenteredText(measurer: TextMeasurer, text: String, at: Pair<Float, Float>, style: TextStyle) {
    if (text.isEmpty()) return
    val layout = measurer.measure(text, style, maxLines = 1, softWrap = false)
    drawText(layout, topLeft = Offset(at.first - layout.size.width / 2f, at.second - layout.size.height / 2f))
}

/**
 * Per-pointer zone tracking (iOS `SplitTouchUIView` semantics): a finger enters
 * the zone it lands in, re-fires when it crosses into another zone (exit then
 * enter), and exits on lift. Touch ids are `"touch-<pointerId>"`. All active
 * touches are exited when the layer is disabled or leaves the composition.
 */
internal fun <Z : Any> Modifier.zoneMultitouch(
    enabled: Boolean,
    resolve: (Offset, IntSize) -> Z?,
    onEnter: (touchId: String, zone: Z) -> Unit,
    onExit: (touchId: String) -> Unit,
    onActiveChanged: (Map<Long, Z>) -> Unit = {},
): Modifier = composed {
    val resolveState = rememberUpdatedState(resolve)
    val enterState = rememberUpdatedState(onEnter)
    val exitState = rememberUpdatedState(onExit)
    val activeState = rememberUpdatedState(onActiveChanged)
    if (!enabled) return@composed Modifier
    Modifier.pointerInput(Unit) {
        // Pointer id → zone (null while the finger is down outside every zone).
        val pressed = HashMap<Long, Z?>()
        fun publish() = activeState.value(pressed.entries.mapNotNull { (k, v) -> v?.let { k to it } }.toMap())
        try {
            awaitPointerEventScope {
                while (true) {
                    val event = awaitPointerEvent()
                    var changed = false
                    for (change in event.changes) {
                        val id = change.id.value
                        val touchId = "touch-$id"
                        if (change.pressed) {
                            val zone = resolveState.value(change.position, size)
                            if (!pressed.containsKey(id)) {
                                pressed[id] = zone
                                zone?.let { enterState.value(touchId, it) }
                                changed = true
                            } else if (zone != pressed[id]) {
                                if (pressed[id] != null) exitState.value(touchId)
                                pressed[id] = zone
                                zone?.let { enterState.value(touchId, it) }
                                changed = true
                            }
                            change.consume()
                        } else if (pressed.containsKey(id)) {
                            if (pressed.remove(id) != null) exitState.value(touchId)
                            changed = true
                        }
                    }
                    if (changed) publish()
                }
            }
        } finally {
            pressed.forEach { (id, zone) -> if (zone != null) exitState.value("touch-$id") }
            pressed.clear()
            publish()
        }
    }
}
