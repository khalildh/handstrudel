package com.handstrudel.ui.studio.overlays

import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.ui.studio.common.StudioMusic
import com.handstrudel.ui.studio.common.WheelGeometry
import com.handstrudel.ui.studio.common.WheelGeometry.ChordSubzone
import com.handstrudel.ui.studio.common.WheelGeometry.Zone
import kotlin.math.max

/**
 * The Split and Scale wheels (iOS `SplitChordMelodyOverlayView` +
 * `SplitTouchOverlay`): one circle cut in half, chords on the chord hand's
 * half with a ±1 octave outer band, melody on the other half. Split: 9 melody
 * wedges of chord tones. Scale: one octave of the scale, chord tones of the
 * active 7th chord highlighted, its own ±1 octave band.
 */
@Composable
fun SplitScaleWheelOverlay(scaleMode: Boolean, touchEnabled: Boolean, modifier: Modifier = Modifier) {
    val engine = LocalAppServices.current.engine
    val cm by engine.chordMelody.collectAsState()
    val key by engine.selectedKey.collectAsState()
    val scale by engine.selectedScale.collectAsState()
    val progression by engine.chordMelodyProgression.collectAsState()
    val swap by engine.chordMelodySwapHands.collectAsState()
    val colors = rememberOverlayColors()
    val intervals = scale.intervals

    val zoneDegrees = cm.zoneDegrees.ifEmpty { progression.degrees }
    val chordNames = StudioMusic.splitChordNames(key, intervals, zoneDegrees, scaleMode)
    val melodyDegree = cm.currentDegree ?: zoneDegrees.firstOrNull() ?: 0
    val melodyMidis = StudioMusic.splitMelodyMidis(key, intervals, melodyDegree, scaleMode)
    val melodyNames = melodyMidis.map { StudioMusic.pitchClassName(it) }
    val chordToneLanes = StudioMusic.splitChordToneLanes(key, intervals, melodyMidis, melodyDegree, scaleMode)
    val zoneCount = max(1, chordNames.size)
    // Scale arc: the engine's lane count (the scale length); it can lag a scale change by a
    // frame, so fall back to the drawn names until they agree.
    val melodyCount = max(1, if (scaleMode && cm.melodyLaneCount == melodyNames.size) cm.melodyLaneCount else melodyNames.size)

    var touches by remember { mutableStateOf<Map<Long, Zone>>(emptyMap()) }
    // Accessibility previews (iOS `previewVoices`): voice id → zone, lit like a touch.
    val previews = remember { mutableStateMapOf<String, Zone>() }
    val active = touches.values + previews.values
    val touchedChords = active.filterIsInstance<Zone.Chord>().map { it.sub }.toSet() +
        cm.touchedChordZones.map { ChordSubzone(it.wedge, it.octave) }
    val touchedLanes = active.filterIsInstance<Zone.Melody>().map { it.lane }.toSet() + cm.touchedMelodyLanes

    fun enter(id: String, zone: Zone) = when (zone) {
        is Zone.Chord ->
            if (scaleMode) engine.scaleTouchEnterChord(id, zone.sub.wedge, zone.sub.octave)
            else engine.splitTouchEnterChord(id, zone.sub.wedge, zone.sub.octave)
        is Zone.Melody ->
            if (scaleMode) engine.scaleTouchEnterMelody(id, zone.lane)
            else engine.splitTouchEnterMelody(id, zone.lane)
    }
    fun exit(id: String) = if (scaleMode) engine.scaleTouchExit(id) else engine.splitTouchExit(id)

    // iOS `preview(_:)`: a 0.32 s note per activation, at most 8 at once.
    val scope = rememberCoroutineScope()
    fun preview(zone: Zone): Boolean {
        if (!touchEnabled || previews.size >= 8) return false
        val id = "splittouch-a11y-${nextPreviewVoice++}"
        previews[id] = zone
        enter(id, zone)
        scope.launch {
            delay(320)
            if (previews.remove(id) != null) exit(id)
        }
        return true
    }
    // Release any preview still sounding when the wheel goes away.
    DisposableEffect(Unit) { onDispose { previews.keys.toList().forEach { exit(it) }; previews.clear() } }
    // iOS `currentMelodyOctaveShift` (Scale mode's melody ±1 band).
    val melodyOctaveShift = cm.melodyOctaveShift

    val measurer = rememberTextMeasurer()
    var boxSize by remember { mutableStateOf(IntSize.Zero) }
    Box(modifier.fillMaxSize().onSizeChanged { boxSize = it }) {
    Canvas(
        Modifier
            .fillMaxSize()
            .testTag(if (scaleMode) "scale-wheel" else "split-wheel")
            .zoneMultitouch(
                enabled = touchEnabled,
                resolve = { p, size ->
                    WheelGeometry.splitZoneForPoint(p.x, p.y, size.width.toFloat(), size.height.toFloat(), zoneCount, melodyCount, swap)
                },
                onEnter = { id, zone -> enter(id, zone) },
                onExit = { id -> exit(id) },
                onActiveChanged = { touches = it },
            ),
    ) {
        val outerR = WheelGeometry.splitOuterRadius(size.width, size.height)
        val center = Offset(size.width / 2f, size.height / 2f)
        val deadR = outerR * WheelGeometry.SPLIT_DEADZONE.toFloat()
        val octaveR = outerR * WheelGeometry.SPLIT_OCTAVE_BAND_THRESHOLD.toFloat()

        drawChordHalf(
            measurer, colors, center, deadR, octaveR, outerR, zoneCount, zoneDegrees, chordNames, swap,
            currentZone = cm.chordHandLane ?: cm.chordZoneIndex, resting = cm.chordResting,
            pinching = cm.isChordHandPinching, octaveShift = cm.octaveShift, touched = touchedChords,
        )
        if (scaleMode) {
            drawScaleMelodyHalf(
                measurer, colors, center, deadR, octaveR, outerR, melodyCount, melodyNames, swap,
                lane = cm.melodyLane, resting = cm.melodyResting, pinching = cm.isMelodyHandPinching,
                touched = touchedLanes, chordTones = chordToneLanes, octaveShift = melodyOctaveShift,
            )
        } else {
            drawSplitMelodyHalf(
                measurer, colors, center, deadR, outerR, melodyCount, melodyNames, swap,
                lane = cm.melodyLane, resting = cm.melodyResting, pinching = cm.isMelodyHandPinching, touched = touchedLanes,
            )
        }
        // Divider.
        val div = Color.White.copy(alpha = 0.18f)
        drawLine(div, Offset(center.x, center.y - outerR), Offset(center.x, center.y - deadR), 1.dp.toPx(), StrokeCap.Round)
        drawLine(div, Offset(center.x, center.y + deadR), Offset(center.x, center.y + outerR), 1.dp.toPx(), StrokeCap.Round)
        // Rest hole + current chord.
        val resting = cm.chordResting || cm.melodyResting
        drawCircle(if (resting) colors.green.copy(alpha = 0.16f) else Color.Black.copy(alpha = 0.25f), deadR, center)
        drawCircle(
            if (resting) colors.green.copy(alpha = 0.6f) else Color.White.copy(alpha = 0.15f), deadR, center,
            style = Stroke((if (resting) 2f else 1f).dp.toPx()),
        )
        if (cm.currentChordName.isNotEmpty()) {
            val brush = Brush.horizontalGradient(
                if (cm.isChordHandPinching) listOf(colors.green, colors.cyan)
                else listOf(Color.White.copy(alpha = 0.8f), Color.White.copy(alpha = 0.5f)),
            )
            var fs = 22f
            var layout = measurer.measure(cm.currentChordName, TextStyle(fontSize = fs.sp, fontWeight = FontWeight.Black, fontFamily = StudioFonts.Rounded, brush = brush), maxLines = 1, softWrap = false)
            while (layout.size.width > deadR * 2 - 8.dp.toPx() && fs > 9f) {
                fs -= 1f
                layout = measurer.measure(cm.currentChordName, TextStyle(fontSize = fs.sp, fontWeight = FontWeight.Black, fontFamily = StudioFonts.Rounded, brush = brush), maxLines = 1, softWrap = false)
            }
            drawText(layout, topLeft = Offset(center.x - layout.size.width / 2f, center.y - layout.size.height / 2f))
        }
    }

    // iOS per-wedge accessibility elements (only while the wheel takes touches). They carry
    // semantics only, no pointer input, so finger touches still reach the wheel above.
    if (touchEnabled && boxSize != IntSize.Zero) {
        val density = LocalDensity.current
        val wedges = WheelGeometry.splitAccessibleWedges(
            boxSize.width.toFloat(), boxSize.height.toFloat(),
            chordLabels = chordNames,
            melodyLabels = melodyMidis.map { StudioMusic.midiNoteName(it) },
            swapHands = swap,
            minSize = with(density) { 22.dp.toPx() }, maxSize = with(density) { 44.dp.toPx() },
        )
        for (w in wedges) {
            val side = with(density) { w.size.toDp() }
            Box(
                Modifier
                    .offset { IntOffset((w.x - w.size / 2).roundToInt(), (w.y - w.size / 2).roundToInt()) }
                    .size(side)
                    .testTag(w.id)
                    .semantics {
                        contentDescription = w.label
                        role = Role.Button
                        // TalkBack reads this as "Double-tap to play" (iOS hint).
                        onClick(label = "play") { preview(w.zone) }
                        val chord = w.zone as? Zone.Chord
                        if (chord != null) {
                            customActions = listOf(
                                CustomAccessibilityAction("Play an octave lower") { preview(Zone.Chord(ChordSubzone(chord.sub.wedge, -1))) },
                                CustomAccessibilityAction("Play an octave higher") { preview(Zone.Chord(ChordSubzone(chord.sub.wedge, 1))) },
                            )
                        }
                    },
            )
        }
    }
    }
}

/** iOS `SplitTouchUIView.nextVoiceCounter`. */
private var nextPreviewVoice = 0

private fun labelStyle(size: Float, color: Color, shadowAlpha: Float = 0.6f, weight: FontWeight = FontWeight.Black) =
    TextStyle(
        fontSize = size.sp, fontWeight = weight, fontFamily = StudioFonts.Rounded, color = color,
        shadow = Shadow(Color.Black.copy(alpha = shadowAlpha), blurRadius = 6f),
    )

private fun DrawScope.drawChordHalf(
    measurer: TextMeasurer, colors: OverlayColors, center: Offset, innerR: Float, octaveR: Float, outerR: Float,
    count: Int, zoneDegrees: List<Int>, names: List<String>, swap: Boolean,
    currentZone: Int?, resting: Boolean, pinching: Boolean, octaveShift: Int, touched: Set<ChordSubzone>,
) {
    val wedge = 180.0 / count
    val chordIsRight = swap
    for (i in 0 until count) {
        val color = colors.forDegree(degreeForZone(zoneDegrees, i))
        val isCurrent = currentZone == i && !resting
        val isHeld = isCurrent && pinching
        val centerAngle = WheelGeometry.chordCenterAngle(i, count, swap)
        val start = centerAngle - wedge / 2
        val end = centerAngle + wedge / 2
        val baseActive = (isCurrent && octaveShift == 0) || ChordSubzone(i, 0) in touched
        val baseHeld = isHeld && octaveShift == 0
        val upActive = (isCurrent && octaveShift == 1) || ChordSubzone(i, 1) in touched
        val upHeld = isHeld && octaveShift == 1
        val downActive = (isCurrent && octaveShift == -1) || ChordSubzone(i, -1) in touched
        val downHeld = isHeld && octaveShift == -1

        sector(annularWedge(center, innerR, octaveR, start, end), color, baseActive, baseHeld, 1f, 12f)
        val (upS, upE) = if (chordIsRight) start to centerAngle else centerAngle to end
        val (dnS, dnE) = if (chordIsRight) centerAngle to end else start to centerAngle
        sector(annularWedge(center, octaveR, outerR, upS, upE), color, upActive, upHeld, 0.5f, 10f, idleStroke = 0.08f)
        sector(annularWedge(center, octaveR, outerR, dnS, dnE), color, downActive, downHeld, 0.5f, 10f, idleStroke = 0.08f)

        val labelActive = baseActive || upActive || downActive
        drawCenteredText(
            measurer, names.getOrElse(i) { "" },
            WheelGeometry.polar(center.x, center.y, centerAngle, (innerR + octaveR) / 2f),
            labelStyle(14f, if (labelActive) Color.White else Color.White.copy(alpha = 0.7f)),
        )
        val sign = if (chordIsRight) -1 else 1
        val arrowR = (octaveR + outerR) / 2f
        drawCenteredText(measurer, "↑", WheelGeometry.polar(center.x, center.y, centerAngle + sign * wedge / 4, arrowR),
            labelStyle(11f, if (upActive) Color.White else Color.White.copy(alpha = 0.35f), weight = FontWeight.Bold))
        drawCenteredText(measurer, "↓", WheelGeometry.polar(center.x, center.y, centerAngle - sign * wedge / 4, arrowR),
            labelStyle(11f, if (downActive) Color.White else Color.White.copy(alpha = 0.35f), weight = FontWeight.Bold))
    }
}

/** iOS `fillStyle` + stroke + shadow for a chord sub-zone. */
private fun DrawScope.sector(
    path: androidx.compose.ui.graphics.Path, color: Color, current: Boolean, held: Boolean,
    idleWidth: Float, glow: Float, idleStroke: Float = 0.1f,
) {
    if (held) glowPath(path, color.copy(alpha = 0.5f), glow.dp.toPx())
    drawPath(path, when { held -> color.copy(alpha = 0.5f); current -> color.copy(alpha = 0.28f); else -> Color.White.copy(alpha = 0.05f) })
    drawPath(
        path,
        when { held -> color.copy(alpha = 0.95f); current -> color.copy(alpha = 0.6f); else -> Color.White.copy(alpha = idleStroke) },
        style = Stroke((if (held) 2.5f else if (current) 1.5f else idleWidth).dp.toPx()),
    )
}

private fun DrawScope.drawSplitMelodyHalf(
    measurer: TextMeasurer, colors: OverlayColors, center: Offset, innerR: Float, outerR: Float,
    count: Int, names: List<String>, swap: Boolean, lane: Int?, resting: Boolean, pinching: Boolean, touched: Set<Int>,
) {
    val wedge = 180.0 / count
    for (i in 0 until count) {
        val handActive = lane == i && !resting
        val isCurrent = handActive || i in touched
        val isHeld = handActive && pinching
        val c = WheelGeometry.melodyCenterAngle(i, count, swap)
        val path = annularWedge(center, innerR, outerR, c - wedge / 2, c + wedge / 2)
        if (isHeld) glowPath(path, colors.cyan.copy(alpha = 0.4f), 6.dp.toPx())
        drawPath(path, when { isHeld -> colors.cyan.copy(alpha = 0.45f); isCurrent -> colors.cyan.copy(alpha = 0.2f); else -> Color.White.copy(alpha = 0.05f) })
        drawPath(
            path,
            when { isHeld -> colors.cyan.copy(alpha = 0.85f); isCurrent -> colors.cyan.copy(alpha = 0.45f); else -> Color.White.copy(alpha = 0.08f) },
            style = Stroke((if (isHeld) 2.5f else 1f).dp.toPx()),
        )
        drawCenteredText(
            measurer, names.getOrElse(i) { "" }, WheelGeometry.polar(center.x, center.y, c, (innerR + outerR) / 2f),
            labelStyle(10f, if (isCurrent) Color.White else colors.cyan.copy(alpha = 0.75f), weight = FontWeight.Bold),
        )
    }
}

private fun DrawScope.drawScaleMelodyHalf(
    measurer: TextMeasurer, colors: OverlayColors, center: Offset, innerR: Float, octaveR: Float, outerR: Float,
    count: Int, names: List<String>, swap: Boolean, lane: Int?, resting: Boolean, pinching: Boolean,
    touched: Set<Int>, chordTones: Set<Int>, octaveShift: Int,
) {
    val wedge = 180.0 / count
    val melodyIsRight = !swap
    for (i in 0 until count) {
        val isTone = i in chordTones
        val tone = if (isTone) colors.green else colors.cyan
        val handActive = lane == i && !resting
        val isCurrent = handActive || i in touched
        val isHeld = handActive && pinching
        val c = WheelGeometry.melodyCenterAngle(i, count, swap)
        val start = c - wedge / 2
        val end = c + wedge / 2
        val baseActive = isCurrent && octaveShift == 0
        val baseHeld = isHeld && octaveShift == 0

        val inner = annularWedge(center, innerR, octaveR, start, end)
        if (baseHeld) glowPath(inner, tone.copy(alpha = 0.6f), 10.dp.toPx())
        drawPath(inner, when {
            baseHeld -> tone.copy(alpha = 0.6f); baseActive -> tone.copy(alpha = 0.4f)
            isTone -> tone.copy(alpha = 0.30f); else -> colors.cyan.copy(alpha = 0.16f)
        })
        drawPath(inner, Color.Black.copy(alpha = 0.65f), style = Stroke(2.5f.dp.toPx()))
        drawPath(
            inner,
            when { baseHeld -> tone; baseActive -> tone.copy(alpha = 0.9f); isTone -> tone.copy(alpha = 0.85f); else -> colors.cyan.copy(alpha = 0.55f) },
            style = Stroke((if (baseHeld) 2.5f else if (baseActive) 1.8f else 1.2f).dp.toPx()),
        )

        val (upS, upE) = if (melodyIsRight) start to c else c to end
        val (dnS, dnE) = if (melodyIsRight) c to end else start to c
        for ((range, shift) in listOf((upS to upE) to 1, (dnS to dnE) to -1)) {
            val cur = isCurrent && octaveShift == shift
            val held = isHeld && octaveShift == shift
            val path = annularWedge(center, octaveR, outerR, range.first, range.second)
            drawPath(path, tone.copy(alpha = if (cur) (if (held) 0.55f else 0.35f) else if (isTone) 0.16f else 0.10f))
            drawPath(path, Color.Black.copy(alpha = 0.65f), style = Stroke(2.dp.toPx()))
            drawPath(path, tone.copy(alpha = if (cur) 0.95f else if (isTone) 0.55f else 0.35f), style = Stroke((if (cur) 1.8f else 1f).dp.toPx()))
        }

        drawCenteredText(
            measurer, names.getOrElse(i) { "" }, WheelGeometry.polar(center.x, center.y, c, (innerR + octaveR) / 2f),
            labelStyle(12f, Color.White, shadowAlpha = 0.85f),
        )
        val upMid = if (melodyIsRight) c - wedge / 4 else c + wedge / 4
        val dnMid = if (melodyIsRight) c + wedge / 4 else c - wedge / 4
        val arrowR = (octaveR + outerR) / 2f
        drawCenteredText(measurer, "↑", WheelGeometry.polar(center.x, center.y, upMid, arrowR),
            labelStyle(9f, if (isCurrent && octaveShift == 1) Color.White else tone.copy(alpha = 0.35f), 0f, FontWeight.Bold))
        drawCenteredText(measurer, "↓", WheelGeometry.polar(center.x, center.y, dnMid, arrowR),
            labelStyle(9f, if (isCurrent && octaveShift == -1) Color.White else tone.copy(alpha = 0.35f), 0f, FontWeight.Bold))
    }
}
