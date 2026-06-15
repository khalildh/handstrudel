package com.handstrudel.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.pointer.PointerInputChange
import androidx.compose.ui.input.pointer.changedToDown
import androidx.compose.ui.input.pointer.changedToUp
import androidx.compose.ui.input.pointer.positionChanged
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.engine.ChordSubzone
import com.handstrudel.engine.EngineController
import com.handstrudel.engine.toCoreKey
import com.handstrudel.engine.toCoreScale
import com.handstrudel.models.MusicKey
import com.handstrudel.models.Scale
import uniffi.handstrudel_core.chordDisplayName as coreChordDisplayName
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt
import uniffi.handstrudel_core.Side
import uniffi.handstrudel_core.splitDeadzone
import uniffi.handstrudel_core.splitOctaveBandThreshold
import uniffi.handstrudel_core.splitOctaveShift
import uniffi.handstrudel_core.splitRadiusFraction
import uniffi.handstrudel_core.splitWedgeIndex

private const val MELODY_COUNT = 9

/// Split chord+melody overlay: chord wedges on one half of a single wheel,
/// melody wedges on the other. Drives the engine through camera hand tracking
/// already (in `EngineController.tickChordMelodyMode`) — this composable adds
/// the visual wheel and the multitouch finger overlay so players can also tap
/// + drag directly on the screen.
@Composable
fun SplitChordMelodyOverlay(
    engine: EngineController,
    modifier: Modifier = Modifier,
) {
    val currentZone by engine.chordMelodyCurrentZoneIndex.collectAsState()
    val currentDegree by engine.chordMelodyCurrentDegree.collectAsState()
    val melodyLane by engine.chordMelodyMelodyLane.collectAsState()
    val chordResting by engine.chordMelodyChordResting.collectAsState()
    val melodyResting by engine.chordMelodyMelodyResting.collectAsState()
    val chordHandPinching by engine.chordMelodyIsChordHandPinching.collectAsState()
    val touchedChordZones by engine.chordMelodyTouchedChordZones.collectAsState()
    val touchedMelodyLanes by engine.chordMelodyTouchedMelodyLanes.collectAsState()
    val progression by engine.selectedProgressionFlow.collectAsState()
    val selectedKey by engine.selectedKeyFlow.collectAsState()
    val selectedScale by engine.selectedScaleFlow.collectAsState()
    // Number of chord wedges in the active progression. Pop has 4, Free has 7,
    // Two-Chord has 2, etc. The wheel + touch math reuse this so the wedges
    // resize to fill the chord half-arc regardless of progression length.
    val zoneCount = progression.degrees.size.coerceAtLeast(1)

    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current

    val chordSide: Side = remember { engine.chordMelodyManager.chordSide() }
    val melodySide: Side = remember { engine.chordMelodyManager.melodySide() }

    Box(modifier = modifier.fillMaxSize()) {
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(zoneCount, chordSide, melodySide) {
                    awaitPointerEventScope {
                        val perTouchState = mutableMapOf<Long, TouchState>()
                        while (true) {
                            val event = awaitPointerEvent()
                            for (change in event.changes) {
                                val w = size.width.toFloat()
                                val h = size.height.toFloat()
                                val outerR = min(w, h) / 2f
                                val center = Offset(w / 2f, h / 2f)
                                val zone = zoneForPoint(change.position, center, outerR, chordSide, melodySide, zoneCount)
                                val prev = perTouchState[change.id.value]
                                if (change.changedToDown()) {
                                    val st = enterZone(engine, zone, change.id.value)
                                    perTouchState[change.id.value] = st
                                } else if (change.changedToUp() || !change.pressed) {
                                    prev?.let { leaveZone(engine, it) }
                                    perTouchState.remove(change.id.value)
                                } else if (change.positionChanged()) {
                                    if (zone != prev?.zone) {
                                        prev?.let { leaveZone(engine, it) }
                                        val st = enterZone(engine, zone, change.id.value)
                                        perTouchState[change.id.value] = st
                                    }
                                }
                                if (change.pressed) change.consume()
                            }
                        }
                    }
                }
        ) {
            drawSplitWheel(
                chordSide = chordSide,
                melodySide = melodySide,
                zoneCount = zoneCount,
                currentZone = currentZone,
                chordResting = chordResting,
                chordOctaveShift = engine.chordMelodyManager.currentOctaveShift().toInt(),
                chordHandPinching = chordHandPinching,
                melodyLane = melodyLane,
                melodyResting = melodyResting,
                touchedChordZones = touchedChordZones,
                touchedMelodyLanes = touchedMelodyLanes,
                chordLabels = chordLabels(selectedKey, selectedScale, progression.degrees),
                measurer = measurer,
                labelStyle = TextStyle(
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Black,
                    color = Color.White,
                ),
            )
        }
    }
}

private data class TouchState(
    val voiceId: String,
    val zone: ResolvedZone?,
    val side: Side?,
)

private sealed class ResolvedZone {
    data class Chord(val wedge: Int, val octave: Int) : ResolvedZone()
    data class Melody(val lane: Int) : ResolvedZone()
}

private fun zoneForPoint(p: Offset, center: Offset, outerR: Float, chordSide: Side, melodySide: Side, zoneCount: Int): ResolvedZone? {
    val dx = (p.x - center.x).toDouble()
    val dy = (center.y - p.y).toDouble()  // up positive
    val r = sqrt(dx * dx + dy * dy)
    if (outerR <= 0f) return null
    val radius = (r / outerR).coerceAtMost(1.0)
    if (radius < splitDeadzone()) return null
    var deg = 90.0 - Math.atan2(dy, dx) * 180.0 / Math.PI
    deg = ((deg % 360.0) + 360.0) % 360.0
    splitWedgeIndex(chordSide, deg, zoneCount)?.let { wedge ->
        val oct = splitOctaveShift(chordSide, deg, radius, wedge, zoneCount)
        return ResolvedZone.Chord(wedge.toInt(), oct.toInt())
    }
    splitWedgeIndex(melodySide, deg, MELODY_COUNT.toInt())?.let { wedge ->
        // Top of arc = highest pitch — invert.
        return ResolvedZone.Melody(MELODY_COUNT - 1 - wedge.toInt())
    }
    return null
}

private var voiceCounter = 0

private fun enterZone(engine: EngineController, zone: ResolvedZone?, pointerId: Long): TouchState {
    voiceCounter += 1
    val voiceId = "splittouch-$voiceCounter"
    when (zone) {
        is ResolvedZone.Chord -> engine.splitTouchEnterChord(voiceId, zone.wedge, zone.octave)
        is ResolvedZone.Melody -> engine.splitTouchEnterMelody(voiceId, zone.lane)
        null -> { /* in the rest hole — track without spawning a voice */ }
    }
    // Highlight set update — read-modify-write the StateFlow snapshot.
    when (zone) {
        is ResolvedZone.Chord -> {
            engine.chordMelodyTouchedChordZones.value =
                engine.chordMelodyTouchedChordZones.value + ChordSubzone(zone.wedge, zone.octave)
        }
        is ResolvedZone.Melody -> {
            engine.chordMelodyTouchedMelodyLanes.value =
                engine.chordMelodyTouchedMelodyLanes.value + zone.lane
        }
        null -> {}
    }
    return TouchState(voiceId, zone, null)
}

private fun leaveZone(engine: EngineController, st: TouchState) {
    engine.splitTouchExit(st.voiceId)
    when (val z = st.zone) {
        is ResolvedZone.Chord -> {
            engine.chordMelodyTouchedChordZones.value =
                engine.chordMelodyTouchedChordZones.value - ChordSubzone(z.wedge, z.octave)
        }
        is ResolvedZone.Melody -> {
            engine.chordMelodyTouchedMelodyLanes.value =
                engine.chordMelodyTouchedMelodyLanes.value - z.lane
        }
        null -> {}
    }
}

// ---------------------------------------------------------------------------
// Drawing
// ---------------------------------------------------------------------------

/// Rust angle: clockwise from 12 o'clock. Compose angle: clockwise from 3
/// o'clock. Add 270° (mod 360) to convert.
private fun composeAngle(rustDeg: Double): Float =
    (((rustDeg - 90.0) % 360.0).let { if (it < 0) it + 360 else it }).toFloat()

private fun DrawScope.drawSplitWheel(
    chordSide: Side,
    melodySide: Side,
    zoneCount: Int,
    currentZone: Int?,
    chordResting: Boolean,
    chordOctaveShift: Int,
    chordHandPinching: Boolean,
    melodyLane: Int?,
    melodyResting: Boolean,
    touchedChordZones: Set<ChordSubzone>,
    touchedMelodyLanes: Set<Int>,
    chordLabels: List<String>,
    measurer: androidx.compose.ui.text.TextMeasurer,
    labelStyle: TextStyle,
) {
    val w = size.width
    val h = size.height
    val center = Offset(w / 2f, h / 2f)
    val outerR = min(w, h) / 2f * splitRadiusFraction().toFloat()
    val deadR = outerR * splitDeadzone().toFloat()
    val octaveR = outerR * splitOctaveBandThreshold().toFloat()

    // Wheel + deadzone outlines. Solid enough to read on top of the camera feed.
    val outline = Color.White.copy(alpha = 0.35f)
    drawCircle(color = outline, radius = outerR, center = center, style = Stroke(width = 2.5f))
    drawCircle(color = outline, radius = deadR, center = center, style = Stroke(width = 1.5f))
    drawCircle(color = outline.copy(alpha = 0.15f), radius = octaveR, center = center, style = Stroke(width = 1f))

    // ---- Chord side ----
    val chordWedge = 180.0 / zoneCount
    for (i in 0 until zoneCount) {
        val (rustStart, rustEnd) = chordWedgeBounds(chordSide, i, chordWedge)
        val composeStart = composeAngle(rustStart)
        val sweep = chordWedge.toFloat()

        val isCurrent = currentZone == i && !chordResting
        val baseTouched = touchedChordZones.contains(ChordSubzone(i, 0))
        val upTouched = touchedChordZones.contains(ChordSubzone(i, 1))
        val downTouched = touchedChordZones.contains(ChordSubzone(i, -1))

        val baseActive = (isCurrent && chordOctaveShift == 0) || baseTouched
        val upActive = (isCurrent && chordOctaveShift == 1) || upTouched
        val downActive = (isCurrent && chordOctaveShift == -1) || downTouched

        val accent = Color(0xFF00FF9E)
        val baseFill = if (baseActive) accent.copy(alpha = if (chordHandPinching && isCurrent) 0.55f else 0.35f) else Color.White.copy(alpha = 0.10f)
        drawAnnularSector(center, deadR, octaveR, composeStart, sweep, baseFill)

        // Outer band split into +1 octave (closer to top of arc) and -1 (closer to bottom).
        val upStart = composeStart
        val upSweep = sweep / 2f
        val downStart = composeStart + sweep / 2f
        val downSweep = sweep / 2f
        val upFill = if (upActive) accent.copy(alpha = 0.5f) else Color.White.copy(alpha = 0.06f)
        val downFill = if (downActive) accent.copy(alpha = 0.5f) else Color.White.copy(alpha = 0.06f)
        // For Right side, the "top of arc" is at lower compose angle (90° earlier).
        // For Left side, the "top of arc" is at higher compose angle (the END of the wedge).
        if (chordSide == Side.LEFT) {
            // top half of the wedge = the part of the sweep closer to top of arc.
            // top of left arc = compose 270 (closer to wedge end for low-index wedges).
            // Easier: use the rustAngle midpoint. The half with lower rustAngle offset_from_top → +1
            drawAnnularSector(center, octaveR, outerR, upStart + sweep / 2f, sweep / 2f, upFill)  // closer to top → +1
            drawAnnularSector(center, octaveR, outerR, upStart, sweep / 2f, downFill)             // closer to bottom → -1
        } else {
            drawAnnularSector(center, octaveR, outerR, upStart, sweep / 2f, upFill)
            drawAnnularSector(center, octaveR, outerR, downStart, sweep / 2f, downFill)
        }

        // Chord label at the inner-band midline.
        val labelAngleRust = (rustStart + rustEnd) / 2.0
        val labelR = (deadR + octaveR) / 2f
        val labelP = polar(center, labelAngleRust, labelR.toDouble())
        val text = chordLabels.getOrElse(i) { "?" }
        val measured = measurer.measure(AnnotatedString(text), labelStyle)
        drawText(
            measurer,
            text = text,
            topLeft = Offset(labelP.x - measured.size.width / 2f, labelP.y - measured.size.height / 2f),
            style = labelStyle.copy(color = if (baseActive || upActive || downActive) Color.White else Color.White.copy(alpha = 0.7f)),
        )
    }

    // ---- Melody side ----
    val melodyWedge = 180.0 / MELODY_COUNT
    val melodyAccent = Color(0xFFFF9E00)
    for (i in 0 until MELODY_COUNT) {
        // Lane i: top of arc = highest pitch. The wedge at the top of the arc
        // corresponds to lane (MELODY_COUNT - 1). So wedge index `w_idx` = MELODY_COUNT - 1 - lane.
        val laneFromWedge = MELODY_COUNT - 1 - i
        val (rustStart, rustEnd) = melodyWedgeBounds(melodySide, i, melodyWedge)
        val composeStart = composeAngle(rustStart)
        val sweep = melodyWedge.toFloat()

        val handActive = melodyLane == laneFromWedge && !melodyResting
        val isActive = handActive || touchedMelodyLanes.contains(laneFromWedge)
        val fill = if (isActive) melodyAccent.copy(alpha = 0.45f) else Color.White.copy(alpha = 0.10f)
        drawAnnularSector(center, deadR, outerR, composeStart, sweep, fill)

        // Lane number — small label so the player can see how many lanes there are.
        val labelAngleRust = (rustStart + rustEnd) / 2.0
        val labelR = (deadR + outerR) / 2f
        val labelP = polar(center, labelAngleRust, labelR.toDouble())
        val text = (laneFromWedge + 1).toString()
        val style = labelStyle.copy(
            fontSize = 11.sp,
            color = if (isActive) Color.White else Color.White.copy(alpha = 0.55f),
        )
        val measured = measurer.measure(AnnotatedString(text), style)
        drawText(
            measurer,
            text = text,
            topLeft = Offset(labelP.x - measured.size.width / 2f, labelP.y - measured.size.height / 2f),
            style = style,
        )
    }
}

private fun chordWedgeBounds(side: Side, i: Int, wedge: Double): Pair<Double, Double> =
    when (side) {
        Side.LEFT -> {
            // Left side: top of arc at rustAngle 360 (= 0). Wedge i spans
            // (360 - (i+1)*wedge, 360 - i*wedge].  rustStart = 360 - (i+1)*wedge.
            val end = 360.0 - i * wedge
            val start = 360.0 - (i + 1) * wedge
            Pair(start, end)
        }
        Side.RIGHT -> {
            val start = i * wedge
            val end = (i + 1) * wedge
            Pair(start, end)
        }
    }

private fun melodyWedgeBounds(side: Side, i: Int, wedge: Double): Pair<Double, Double> =
    chordWedgeBounds(side, i, wedge)

private fun polar(center: Offset, rustAngleDeg: Double, r: Double): Offset {
    val composeRad = Math.toRadians(rustAngleDeg - 90.0)
    return Offset(
        x = center.x + (r * cos(composeRad)).toFloat(),
        y = center.y + (r * sin(composeRad)).toFloat(),
    )
}

/// Fill the area between two concentric arcs with the same angular bounds.
/// Compose's drawArc only fills a pie slice from the center, so we layer two
/// arcs and mask with an even-odd path.
private fun DrawScope.drawAnnularSector(
    center: Offset,
    innerR: Float,
    outerR: Float,
    startAngle: Float,
    sweepAngle: Float,
    color: Color,
) {
    val path = Path()
    val topLeftOuter = Offset(center.x - outerR, center.y - outerR)
    val sizeOuter = Size(outerR * 2f, outerR * 2f)
    val topLeftInner = Offset(center.x - innerR, center.y - innerR)
    val sizeInner = Size(innerR * 2f, innerR * 2f)

    // Outer arc (forward)
    path.arcTo(
        rect = androidx.compose.ui.geometry.Rect(topLeftOuter, sizeOuter),
        startAngleDegrees = startAngle,
        sweepAngleDegrees = sweepAngle,
        forceMoveTo = true,
    )
    // Inner arc (reverse)
    path.arcTo(
        rect = androidx.compose.ui.geometry.Rect(topLeftInner, sizeInner),
        startAngleDegrees = startAngle + sweepAngle,
        sweepAngleDegrees = -sweepAngle,
        forceMoveTo = false,
    )
    path.close()
    drawPath(path, color)
}

// ---------------------------------------------------------------------------

/// Display names like "Cmaj", "Am", "Bdim" for the current key/scale,
/// one per chord *zone* — so a Pop progression's [I, V, vi, IV] picks 4
/// labels from the diatonic 7. Computed in the Rust core.
private fun chordLabels(key: MusicKey, scale: Scale, progressionDegrees: List<Int>): List<String> {
    val coreKey = key.toCoreKey()
    val coreScale = scale.toCoreScale()
    return progressionDegrees.map { d -> coreChordDisplayName(coreKey, coreScale, d) }
}
