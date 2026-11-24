package com.handstrudel.ui.studio.overlays

import androidx.compose.material.icons.outlined.DoNotTouch
import com.handstrudel.ui.theme.StudioIcons
import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.PanTool
import androidx.compose.material.icons.outlined.PanTool
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.outlined.Timer
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.ui.studio.common.StageMetrics
import com.handstrudel.ui.studio.common.StudioMusic
import kotlin.math.max

/**
 * iOS `ContentView.noteGridOverlay` + `GridTouchOverlay`: scale-note lanes
 * (highest on top) between a 15 % top pad and a 20 % bottom pad. Each lane is
 * split into a left-hand (green) and right-hand (pink) half lit from the
 * camera-tracked pinch, and cyan where a finger is down.
 *
 * Touch: iOS `GridTouchUIView` semantics. A finger lands → `gridLaneTouchOn`,
 * crossing into another lane → `gridLaneTouchSlide`, lift → `gridLaneTouchOff`.
 * The lane passed is the visual row (0 = top lane); its note is
 * `scaleNotes[count - 1 - lane]`. Touch ids are iOS's voices: the first finger
 * is "touch1", the next "touch2" (further fingers share "touch2", as on iOS).
 */
@Composable
fun GridLanesOverlay(touchEnabled: Boolean, modifier: Modifier = Modifier) {
    val engine = LocalAppServices.current.engine
    val key by engine.selectedKey.collectAsState()
    val scale by engine.selectedScale.collectAsState()
    val baseOctave by engine.gridBaseOctave.collectAsState()
    val octaveRange by engine.gridOctaveRange.collectAsState()
    val hands by engine.handsState.collectAsState()
    val lanes by engine.lanes.collectAsState()
    val colors = rememberOverlayColors()
    val density = LocalDensity.current

    val notes = remember(key, scale, baseOctave, octaveRange) {
        StudioMusic.scaleNotes(key, scale.intervals, baseOctave, octaveRange)
    }
    val count = notes.size
    var touchActiveLanes by remember { mutableStateOf<Set<Int>>(emptySet()) }
    val countState = rememberUpdatedState(count)

    BoxWithConstraints(modifier.fillMaxSize()) {
        val wPx = with(density) { maxWidth.toPx() }
        val hPx = with(density) { maxHeight.toPx() }
        val topPad = maxHeight * GridGeometry.TOP_PAD.toFloat()
        val bottomPad = maxHeight * GridGeometry.BOTTOM_PAD.toFloat()
        val laneHeight = (maxHeight - topPad - bottomPad) / max(1, count)

        val leftVisualLane = hands.left?.let { GridGeometry.visualLaneForPinch(it.pinchY, wPx, hPx, StageMetrics.videoAspect(engine), count) }
        val rightVisualLane = hands.right?.let { GridGeometry.visualLaneForPinch(it.pinchY, wPx, hPx, StageMetrics.videoAspect(engine), count) }

        Column(Modifier.fillMaxSize()) {
            Spacer(Modifier.height(topPad))
            for (i in 0 until count) {
                val name = StudioMusic.midiNoteName(notes[count - 1 - i])
                val leftActive = leftVisualLane == i
                val rightActive = rightVisualLane == i
                val isEven = i % 2 == 0
                val isTouchActive = i in touchActiveLanes
                Box(Modifier.fillMaxWidth().height(laneHeight)) {
                    Row(Modifier.fillMaxSize()) {
                        Box(
                            Modifier.weight(1f).fillMaxHeight().background(
                                when {
                                    isTouchActive -> colors.cyan.copy(alpha = 0.3f)
                                    leftActive -> colors.green.copy(alpha = if (lanes.gridLeftPinching) 0.25f else 0.1f)
                                    else -> Color.White.copy(alpha = if (isEven) 0.03f else 0f)
                                },
                            ),
                        )
                        Box(
                            Modifier.weight(1f).fillMaxHeight().background(
                                when {
                                    isTouchActive -> colors.cyan.copy(alpha = 0.3f)
                                    rightActive -> colors.pink.copy(alpha = if (lanes.gridRightPinching) 0.25f else 0.1f)
                                    else -> Color.White.copy(alpha = if (isEven) 0.03f else 0f)
                                },
                            ),
                        )
                    }
                    Row(
                        Modifier.fillMaxSize().padding(horizontal = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        LaneLabel(
                            name, active = leftActive || isTouchActive,
                            color = if (isTouchActive) colors.cyan else if (leftActive) colors.green else Color.White.copy(alpha = 0.5f),
                            background = if (leftActive || isTouchActive) colors.green.copy(alpha = 0.2f) else Color.Black.copy(alpha = 0.3f),
                        )
                        Spacer(Modifier.weight(1f))
                        LaneLabel(
                            name, active = rightActive || isTouchActive,
                            color = if (isTouchActive) colors.cyan else if (rightActive) colors.pink else Color.White.copy(alpha = 0.3f),
                            background = if (rightActive || isTouchActive) colors.pink.copy(alpha = 0.2f) else Color.Black.copy(alpha = 0.2f),
                        )
                    }
                    // Top divider.
                    Box(
                        Modifier.fillMaxWidth().height(1.dp).align(Alignment.TopCenter).background(
                            Color.White.copy(alpha = if (leftActive || rightActive || isTouchActive) 0.2f else 0.06f),
                        ),
                    )
                }
            }
        }

        // Multitouch layer on top for two-finger play.
        if (touchEnabled) {
            Box(
                Modifier.fillMaxSize().pointerInput(Unit) {
                    val touchLanes = HashMap<Long, Int>()
                    val touchVoices = HashMap<Long, String>()
                    fun publish() { touchActiveLanes = touchLanes.values.toSet() }
                    try {
                        awaitPointerEventScope {
                            while (true) {
                                val event = awaitPointerEvent()
                                for (change in event.changes) {
                                    val id = change.id.value
                                    val c = countState.value
                                    if (change.pressed) {
                                        val lane = GridGeometry.laneForY(change.position.y, size.height.toFloat(), c)
                                        if (!touchVoices.containsKey(id)) {
                                            if (lane != null) {
                                                val voice = if (touchVoices.values.contains("touch1")) "touch2" else "touch1"
                                                touchVoices[id] = voice
                                                touchLanes[id] = lane
                                                engine.gridLaneTouchOn(voice, lane)
                                            }
                                        } else if (lane != null && lane != touchLanes[id]) {
                                            touchLanes[id] = lane
                                            engine.gridLaneTouchSlide(touchVoices.getValue(id), lane)
                                        }
                                        change.consume()
                                    } else {
                                        touchVoices.remove(id)?.let { engine.gridLaneTouchOff(it) }
                                        touchLanes.remove(id)
                                    }
                                }
                                publish()
                            }
                        }
                    } finally {
                        touchVoices.values.toSet().forEach { engine.gridLaneTouchOff(it) }
                        touchVoices.clear()
                        touchLanes.clear()
                        publish()
                    }
                },
            )
        }
    }
}

@Composable
private fun LaneLabel(name: String, active: Boolean, color: Color, background: Color) {
    Text(
        name,
        fontSize = if (active) 14.sp else 11.sp,
        fontWeight = if (active) FontWeight.Black else FontWeight.Medium,
        fontFamily = StudioFonts.Mono,
        color = color,
        maxLines = 1,
        softWrap = false,
        modifier = Modifier.background(background, CircleShape).padding(horizontal = 8.dp, vertical = 3.dp),
    )
}

/**
 * iOS `ContentView.gridQuickBar`: octave readout and ↓/↑ steppers (1…6), the
 * sync-to-beat (quantize) toggle and the 1/2/3-octave range pills.
 */
@Composable
fun GridQuickBar(modifier: Modifier = Modifier) {
    val engine = LocalAppServices.current.engine
    val baseOctave by engine.gridBaseOctave.collectAsState()
    val octaveRange by engine.gridOctaveRange.collectAsState()
    val quantize by engine.quantizeEnabled.collectAsState()
    val fingerOctave by engine.fingerOctaveEnabled.collectAsState()
    val fingerCount by engine.currentFingerCount.collectAsState()
    val colors = rememberOverlayColors()

    Row(
        modifier
            .background(Color.Black.copy(alpha = 0.5f), CircleShape)
            .padding(horizontal = 8.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Finger count dots (finger octave on).
        if (fingerOctave) {
            Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                for (i in 1..5) {
                    Box(
                        Modifier
                            .size(8.dp)
                            .background(if (i <= fingerCount) colors.green else Color.White.copy(alpha = 0.15f), CircleShape),
                    )
                }
            }
        }
        Text("Oct $baseOctave", fontSize = 12.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Mono, color = colors.green)

        // Manual octave steppers (finger octave off).
        if (!fingerOctave) {
            RoundIconButton(StudioIcons.ChevronDown, "Octave down", Color.White.copy(alpha = 0.7f), Color.White.copy(alpha = 0.1f)) {
                if (baseOctave > 1) engine.setGridBaseOctave(baseOctave - 1)
            }
            RoundIconButton(StudioIcons.ChevronUp, "Octave up", Color.White.copy(alpha = 0.7f), Color.White.copy(alpha = 0.1f)) {
                if (baseOctave < 6) engine.setGridBaseOctave(baseOctave + 1)
            }
        }

        Spacer(Modifier.weight(1f))

        // Sync-to-beat (iOS SF Symbol "metronome" / "metronome.fill").
        RoundIconButton(
            if (quantize) StudioIcons.MetronomeFill else StudioIcons.Metronome,
            "Sync to beat",
            if (quantize) colors.green else Color.White.copy(alpha = 0.5f),
            if (quantize) colors.green.copy(alpha = 0.15f) else Color.White.copy(alpha = 0.1f),
            selected = quantize,
        ) { engine.setQuantizeEnabled(!quantize) }

        // Finger octave toggle (iOS "hand.raised.fingers.spread" / "hand.raised.slash").
        RoundIconButton(
            if (fingerOctave) StudioIcons.HandRaised else StudioIcons.HandRaisedSlash,
            "Finger octave",
            if (fingerOctave) colors.green else Color.White.copy(alpha = 0.5f),
            if (fingerOctave) colors.green.copy(alpha = 0.15f) else Color.White.copy(alpha = 0.1f),
            selected = fingerOctave,
        ) { engine.setFingerOctaveEnabled(!fingerOctave) }

        for (range in 1..3) {
            val selected = octaveRange == range
            Box(
                Modifier
                    .size(26.dp)
                    .background(if (selected) colors.green else Color.White.copy(alpha = 0.1f), CircleShape)
                    .clickable { engine.setGridOctaveRange(range) }
                    .testTag("grid-range-$range")
                    .semantics {
                        contentDescription = if (range == 1) "One octave" else "$range octaves"
                        this.selected = selected
                    },
                contentAlignment = Alignment.Center,
            ) {
                // iOS 12 pt bold SF Rounded: Nunito's Bold is lighter and its digits smaller,
                // so use its ExtraBold (wght 800) at 13.5 sp to match the measured glyphs.
                Text(
                    "$range", fontSize = 13.5.sp, fontWeight = FontWeight.ExtraBold, fontFamily = StudioFonts.Rounded,
                    color = if (selected) Color.Black else Color.White.copy(alpha = 0.6f),
                )
            }
        }
    }
}

@Composable
private fun RoundIconButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    description: String,
    tint: Color,
    background: Color,
    selected: Boolean = false,
    onClick: () -> Unit,
) {
    Box(
        Modifier
            .size(26.dp)
            .background(background, CircleShape)
            .clickable(onClick = onClick)
            .semantics { this.selected = selected },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = description, tint = tint, modifier = Modifier.size(14.dp))
    }
}

/** Pure Grid lane geometry (JVM-tested). */
object GridGeometry {
    /** Top pad: avoids the dead zone where the camera can't see hands. */
    const val TOP_PAD = 0.15
    /** Bottom pad: more room for the UI controls. */
    const val BOTTOM_PAD = 0.20

    /** iOS `GridTouchUIView.laneForTouch`: visual row (0 = top) under [y], clamped; null with no lanes. */
    fun laneForY(y: Float, height: Float, count: Int): Int? {
        val usable = height - height * TOP_PAD.toFloat() - height * BOTTOM_PAD.toFloat()
        if (usable <= 0f || count <= 0) return null
        val laneHeight = usable / count
        val lane = ((y - height * TOP_PAD.toFloat()) / laneHeight).toInt()
        return lane.coerceIn(0, count - 1)
    }

    /**
     * iOS noteGridOverlay `correctedY`: normalised camera y → stage px under
     * aspect-fill. When the video is wider than the stage it fills the height;
     * otherwise it fills the width and is cropped top/bottom.
     */
    fun correctedY(vy: Double, width: Float, height: Float, videoAspect: Float): Float {
        if (height <= 0f) return 0f
        val scrAspect = width / height
        return if (videoAspect > scrAspect) {
            (vy * height).toFloat()
        } else {
            val vis = videoAspect / scrAspect
            val off = (1 - vis) / 2
            ((vy.toFloat() - off) / vis * height)
        }
    }

    /** iOS `leftVisualLane`/`rightVisualLane`: the visual row a camera pinch at [pinchY] sits in, clamped. */
    fun visualLaneForPinch(pinchY: Double, width: Float, height: Float, videoAspect: Float, count: Int): Int? {
        if (count <= 0) return null
        val topPad = height * TOP_PAD.toFloat()
        val laneHeight = (height - topPad - height * BOTTOM_PAD.toFloat()) / count
        if (laneHeight <= 0f) return null
        val screenY = correctedY(pinchY, width, height, videoAspect) - topPad
        return (screenY / laneHeight).toInt().coerceIn(0, count - 1)
    }
}
