package com.handstrudel.ui.studio.overlays

import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import kotlin.math.max
import kotlin.math.roundToInt

/** iOS `ChordMelodyOverlayView` octave rows, top → bottom (high → mid → low). */
private val OCTAVES = listOf(1, 0, -1)

/**
 * iOS `ChordMelodyOverlayView` (Chord+Melody and SoundFont modes): the chord
 * hand's half holds one column per chord zone (3 octave cells each), the melody
 * hand's half holds 9 lanes (highest pitch on top).
 *
 * iOS has no touch layer for this overlay; Android adds one: a finger on a chord
 * column plays that zone, a finger on the melody half plays the lane under it.
 */
@Composable
fun ChordMelodyZonesOverlay(touchEnabled: Boolean, modifier: Modifier = Modifier) {
    val engine = LocalAppServices.current.engine
    val cm by engine.chordMelody.collectAsState()
    val swapHands by engine.chordMelodySwapHands.collectAsState()
    val colors = rememberOverlayColors()
    val density = LocalDensity.current

    val progression by engine.chordMelodyProgression.collectAsState()
    // The engine publishes zoneDegrees; fall back to the progression before its first tick.
    val zoneDegrees = cm.zoneDegrees.ifEmpty { progression.degrees }
    val zoneCount = max(1, zoneDegrees.size)
    val melodyLaneCount = ZonesGeometry.MELODY_LANES
    val chordsOnLeft = !swapHands

    var touches by remember { mutableStateOf<Map<Long, ZonesGeometry.Zone>>(emptyMap()) }
    val touchedCells = touches.values.filterIsInstance<ZonesGeometry.Zone.Chord>().map { it.zone to it.octave }.toSet() +
        cm.touchedChordZones.map { it.wedge to it.octave }
    val touchedZones = touchedCells.map { it.first }.toSet()
    val touchedLanes = touches.values.filterIsInstance<ZonesGeometry.Zone.Melody>().map { it.lane }.toSet() +
        cm.touchedMelodyLanes
    val padPx = with(density) { 6.dp.toPx() }

    BoxWithConstraints(
        modifier
            .fillMaxSize()
            .zoneMultitouch(
                enabled = touchEnabled,
                resolve = { p, size ->
                    ZonesGeometry.zoneForPoint(
                        p.x, p.y, size.width.toFloat(), size.height.toFloat(),
                        zoneCount, melodyLaneCount, swapHands, padPx,
                    )
                },
                onEnter = { id, zone ->
                    when (zone) {
                        is ZonesGeometry.Zone.Chord -> engine.zonesTouchEnterChord(id, zone.zone, zone.octave)
                        is ZonesGeometry.Zone.Melody -> engine.zonesTouchEnterMelody(id, zone.lane)
                    }
                },
                onExit = { id -> engine.zonesTouchExit(id) },
                onActiveChanged = { touches = it },
            ),
    ) {
        val halfW = maxWidth / 2
        val h = maxHeight

        // ---- chord hand half ----
        Row(
            Modifier
                .width(halfW)
                .fillMaxHeight()
                .offset(x = if (chordsOnLeft) 0.dp else halfW)
                .padding(horizontal = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            for (i in 0 until zoneCount) {
                val touched = i in touchedZones
                val isCurrentZone = cm.chordHandLane == i || touched
                val degree = degreeForZone(zoneDegrees, i)
                val degreeColor = colors.forDegree(degree)
                Column(Modifier.weight(1f).fillMaxHeight(), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    for (oct in OCTAVES) {
                        val isActiveCell = if (touched) (i to oct) in touchedCells else isCurrentZone && oct == cm.octaveShift
                        val isHeld = isActiveCell && (cm.isChordHandPinching || touched)
                        OctaveCell(degree, oct, degreeColor, isCurrentZone, isActiveCell, isHeld, Modifier.weight(1f).fillMaxWidth())
                    }
                }
            }
        }

        // ---- melody hand half ----
        Column(
            Modifier
                .width(halfW)
                .fillMaxHeight()
                .offset(x = if (chordsOnLeft) halfW else 0.dp)
                .padding(vertical = h * 0.15f)
                .padding(horizontal = 6.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            for (i in 0 until melodyLaneCount) {
                // Higher lane index = higher pitch, drawn at the top.
                val pitchPos = melodyLaneCount - 1 - i
                val touched = pitchPos in touchedLanes
                val isCurrent = cm.melodyLane == pitchPos || touched
                val isHeld = isCurrent && (cm.isMelodyHandPinching || touched)
                val shape = RoundedCornerShape(6.dp)
                Box(
                    Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .iosGlow(if (isHeld) colors.cyan.copy(alpha = 0.4f) else Color.Transparent, 6f, 6f)
                        .background(
                            when {
                                isHeld -> colors.cyan.copy(alpha = 0.4f)
                                isCurrent -> colors.cyan.copy(alpha = 0.18f)
                                else -> Color.White.copy(alpha = 0.04f)
                            },
                            shape,
                        )
                        .border(
                            (if (isHeld) 2 else 1).dp,
                            when {
                                isHeld -> colors.cyan.copy(alpha = 0.8f)
                                isCurrent -> colors.cyan.copy(alpha = 0.4f)
                                else -> Color.White.copy(alpha = 0.05f)
                            },
                            shape,
                        ),
                )
            }
        }

        // ---- chord name display ----
        if (cm.currentChordName.isNotEmpty()) {
            var textSize by remember { mutableStateOf(androidx.compose.ui.unit.IntSize.Zero) }
            val cx = with(density) { (maxWidth / 2).toPx() }
            val cy = with(density) { (h * 0.18f).toPx() }
            Text(
                cm.currentChordName,
                maxLines = 1,
                softWrap = false,
                style = TextStyle(
                    fontSize = 56.sp,
                    fontWeight = FontWeight.Black, fontFamily = StudioFonts.Rounded,
                    brush = Brush.horizontalGradient(
                        if (cm.isChordHandPinching) listOf(colors.green, colors.cyan)
                        else listOf(Color.White.copy(alpha = 0.5f), Color.White.copy(alpha = 0.3f)),
                    ),
                    shadow = Shadow(Color.Black.copy(alpha = 0.6f), blurRadius = with(density) { 8.dp.toPx() }),
                ),
                modifier = Modifier
                    .onSizeChanged { textSize = it }
                    .offset { IntOffset((cx - textSize.width / 2f).roundToInt(), (cy - textSize.height / 2f).roundToInt()) },
            )
        }
    }
}

@Composable
private fun OctaveCell(
    degree: Int,
    octave: Int,
    degreeColor: Color,
    isCurrentZone: Boolean,
    isActive: Boolean,
    isHeld: Boolean,
    modifier: Modifier,
) {
    val shape = RoundedCornerShape(8.dp)
    Box(
        modifier
            .iosGlow(if (isHeld) degreeColor.copy(alpha = 0.5f) else Color.Transparent, 12f, 8f)
            .background(
                when {
                    isHeld -> degreeColor.copy(alpha = 0.45f)
                    isActive -> degreeColor.copy(alpha = 0.28f)
                    isCurrentZone -> degreeColor.copy(alpha = 0.1f)
                    else -> Color.White.copy(alpha = 0.04f)
                },
                shape,
            )
            .border(
                when {
                    isHeld -> 2.dp
                    isActive -> 1.5.dp
                    else -> 1.dp
                },
                when {
                    isHeld -> degreeColor.copy(alpha = 0.95f)
                    isActive -> degreeColor.copy(alpha = 0.6f)
                    isCurrentZone -> degreeColor.copy(alpha = 0.25f)
                    else -> Color.White.copy(alpha = 0.07f)
                },
                shape,
            ),
        contentAlignment = Alignment.Center,
    ) {
        if (octave == 0) {
            // Only the middle row carries the degree label.
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    ZonesGeometry.romanNumeral(degree),
                    // iOS `Text` has no line limit here: a narrow lane wraps "vii°" / "TONIC".
                    fontSize = 18.sp, fontWeight = FontWeight.Black, fontFamily = StudioFonts.Rounded,
                    color = if (isCurrentZone) Color.White else Color.White.copy(alpha = 0.55f), textAlign = TextAlign.Center,
                )
                val label = ZonesGeometry.degreeLabel(degree)
                Text(
                    label,
                    fontSize = 9.sp, fontWeight = FontWeight.SemiBold, fontFamily = StudioFonts.Rounded,
                    color = Color.White.copy(alpha = if (isCurrentZone) 0.7f else 0.4f),
                    textAlign = TextAlign.Center,
                )
            }
        } else {
            Text(
                if (octave > 0) "+8va" else "−8va",
                fontSize = 9.sp, fontWeight = FontWeight.SemiBold, fontFamily = StudioFonts.Rounded, maxLines = 1, softWrap = false,
                color = Color.White.copy(alpha = if (isActive) 0.85f else 0.3f),
            )
        }
    }
}

/** Pure Chord+Melody zones geometry and labels (JVM-tested). */
object ZonesGeometry {
    /** ContentView passes `melodyLaneCount: 9`. */
    const val MELODY_LANES = 9
    /** Melody lanes are inset by 15 % of the height top and bottom. */
    const val MELODY_VERTICAL_INSET = 0.15

    sealed interface Zone {
        /** [octave]: the touched row, +1 (top third), 0 (middle), −1 (bottom third). */
        data class Chord(val zone: Int, val octave: Int = 0) : Zone
        data class Melody(val lane: Int) : Zone
    }

    /**
     * Touch → zone. The chord half (left unless [swapHands]) is split into
     * [zoneCount] columns inside a [padPx] side inset; the melody half into
     * [melodyCount] rows inside the 15 % vertical inset, lane 0 = lowest pitch at
     * the bottom. Touches above/below the lanes clamp to the nearest lane.
     */
    fun zoneForPoint(
        x: Float, y: Float, width: Float, height: Float,
        zoneCount: Int, melodyCount: Int, swapHands: Boolean, padPx: Float = 0f,
    ): Zone? {
        if (width <= 0f || height <= 0f) return null
        val half = width / 2f
        val chordsOnLeft = !swapHands
        val inLeft = x < half
        return if (inLeft == chordsOnLeft) {
            val start = (if (chordsOnLeft) 0f else half) + padPx
            val usable = half - 2 * padPx
            val count = max(1, zoneCount)
            val row = kotlin.math.floor(y / (height / 3f)).toInt().coerceIn(0, 2)
            val octave = 1 - row
            if (usable <= 0f) return Zone.Chord(0, octave)
            val col = kotlin.math.floor((x - start) / (usable / count)).toInt()
            Zone.Chord(col.coerceIn(0, count - 1), octave)
        } else {
            val count = max(1, melodyCount)
            val top = height * MELODY_VERTICAL_INSET.toFloat()
            val usable = height - 2 * top
            val row = kotlin.math.floor((y - top) / (usable / count)).toInt().coerceIn(0, count - 1)
            Zone.Melody(count - 1 - row)
        }
    }

    /** iOS `romanNumeral(degree:)`. */
    fun romanNumeral(degree: Int): String = when (degree) {
        0 -> "I"
        1 -> "ii"
        2 -> "iii"
        3 -> "IV"
        4 -> "V"
        5 -> "vi"
        6 -> "vii°"
        else -> "${degree + 1}"
    }

    /** iOS `degreeLabel(degree:)`. */
    fun degreeLabel(degree: Int): String = when (degree) {
        0 -> "TONIC"
        3 -> "SUB"
        4 -> "DOM"
        else -> ""
    }
}
