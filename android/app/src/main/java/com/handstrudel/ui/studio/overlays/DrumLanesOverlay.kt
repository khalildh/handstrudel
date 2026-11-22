package com.handstrudel.ui.studio.overlays

import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices

/** iOS `ContentView.DrumLane`; [colorOf] picks the SwiftUI system colour. */
private data class DrumLaneDef(val id: String, val name: String, val emoji: String, val colorOf: (OverlayColors) -> Color)

/** iOS `drumLanes`, top → bottom. The index is the `drumLaneTap` lane. */
private val DRUM_LANES = listOf(
    DrumLaneDef("crash", "CRASH", "💥") { it.yellow },
    DrumLaneDef("hihat", "HI-HAT", "🔔") { it.cyan },
    DrumLaneDef("snare", "SNARE", "🥁") { it.orange },
    DrumLaneDef("ride", "RIDE", "🛎️") { it.pink },
    DrumLaneDef("tom", "TOM", "🪘") { it.purple },
    DrumLaneDef("kick", "KICK", "🦶") { it.red },
)

/**
 * iOS `ContentView.drumZoneOverlay`: six drum lanes (CRASH, HI-HAT, SNARE, RIDE,
 * TOM, KICK) between a 15 % top pad and a 20 % bottom pad, each with a left and
 * a right pad. A pad lights when touched or when that hand pinches in it.
 * A finger landing on a pad calls `drumLaneTap(lane)` once; the pad stays lit
 * until the finger lifts (a second finger on a lit pad doesn't retrigger).
 */
@Composable
fun DrumLanesOverlay(touchEnabled: Boolean, modifier: Modifier = Modifier) {
    val engine = LocalAppServices.current.engine
    val lanes by engine.lanes.collectAsState()
    val colors = rememberOverlayColors()
    var activePads by remember { mutableStateOf<Set<DrumGeometry.Pad>>(emptySet()) }

    BoxWithConstraints(modifier.fillMaxSize()) {
        val topPad = maxHeight * DrumGeometry.TOP_PAD.toFloat()
        val laneHeight = (maxHeight - topPad - maxHeight * DrumGeometry.BOTTOM_PAD.toFloat()) / DRUM_LANES.size

        Column(Modifier.fillMaxSize()) {
            Spacer(Modifier.height(topPad))
            DRUM_LANES.forEachIndexed { idx, lane ->
                val color = lane.colorOf(colors)
                val leftHand = lanes.drumLeftLane == idx
                val rightHand = lanes.drumRightLane == idx
                val leftActive = DrumGeometry.Pad(idx, left = true) in activePads || (leftHand && lanes.drumLeftPinching)
                val rightActive = DrumGeometry.Pad(idx, left = false) in activePads || (rightHand && lanes.drumRightPinching)
                val leftFill by animateColorAsState(
                    when {
                        leftActive -> color.copy(alpha = 0.35f)
                        leftHand -> color.copy(alpha = 0.1f)
                        else -> Color.White.copy(alpha = 0.03f)
                    },
                    tween(80), label = "drumLeft",
                )
                val rightFill by animateColorAsState(
                    when {
                        rightActive -> color.copy(alpha = 0.35f)
                        rightHand -> color.copy(alpha = 0.1f)
                        else -> Color.White.copy(alpha = 0f)
                    },
                    tween(80), label = "drumRight",
                )
                Box(Modifier.fillMaxWidth().height(laneHeight)) {
                    Row(Modifier.fillMaxSize()) {
                        Box(Modifier.weight(1f).fillMaxHeight().background(leftFill), contentAlignment = Alignment.Center) {
                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                                Text(lane.emoji, fontSize = 20.sp)
                                DrumName(lane.name, if (leftActive) color else Color.White.copy(alpha = 0.4f))
                            }
                        }
                        Box(Modifier.width(1.dp).fillMaxHeight().background(Color.White.copy(alpha = 0.06f)))
                        Box(Modifier.weight(1f).fillMaxHeight().background(rightFill), contentAlignment = Alignment.Center) {
                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                                DrumName(lane.name, if (rightActive) color else Color.White.copy(alpha = 0.4f))
                                Text(lane.emoji, fontSize = 20.sp)
                            }
                        }
                    }
                    Box(
                        Modifier.fillMaxWidth().height(1.dp).align(Alignment.TopCenter)
                            .background(Color.White.copy(alpha = if (leftActive || rightActive) 0.15f else 0.04f)),
                    )
                }
            }
        }

        if (touchEnabled) {
            Box(
                Modifier.fillMaxSize().pointerInput(Unit) {
                    val pointerPads = HashMap<Long, DrumGeometry.Pad>()
                    val lit = HashSet<DrumGeometry.Pad>()
                    try {
                        awaitPointerEventScope {
                            while (true) {
                                val event = awaitPointerEvent()
                                var changed = false
                                for (change in event.changes) {
                                    val id = change.id.value
                                    if (change.pressed) {
                                        if (!pointerPads.containsKey(id)) {
                                            val pad = DrumGeometry.padForPoint(
                                                change.position.x, change.position.y,
                                                size.width.toFloat(), size.height.toFloat(), DRUM_LANES.size,
                                            )
                                            if (pad != null) {
                                                pointerPads[id] = pad
                                                if (lit.add(pad)) {
                                                    engine.drumLaneTap(pad.lane)
                                                    changed = true
                                                }
                                                change.consume()
                                            }
                                        } else {
                                            change.consume()
                                        }
                                    } else {
                                        // iOS removes the pad's key when any finger that started on it lifts.
                                        pointerPads.remove(id)?.let { if (lit.remove(it)) changed = true }
                                    }
                                }
                                if (changed) activePads = lit.toSet()
                            }
                        }
                    } finally {
                        pointerPads.clear()
                        lit.clear()
                        activePads = emptySet()
                    }
                },
            )
        }
    }
}

@Composable
private fun DrumName(name: String, color: Color) {
    Text(name, fontSize = 12.sp, fontWeight = FontWeight.Black, fontFamily = StudioFonts.Rounded, color = color, maxLines = 1, softWrap = false)
}

/** Pure drum lane geometry (JVM-tested). */
object DrumGeometry {
    const val TOP_PAD = 0.15
    const val BOTTOM_PAD = 0.20
    const val LANE_COUNT = 6

    /** A drum pad: [lane] 0…5 top → bottom, [left] = the left-hand half. */
    data class Pad(val lane: Int, val left: Boolean)

    /** The pad under ([x], [y]); null above or below the lanes. */
    fun padForPoint(x: Float, y: Float, width: Float, height: Float, laneCount: Int = LANE_COUNT): Pad? {
        if (width <= 0f || height <= 0f || laneCount <= 0) return null
        val top = height * TOP_PAD.toFloat()
        val usable = height - top - height * BOTTOM_PAD.toFloat()
        if (y < top || y >= top + usable) return null
        val lane = ((y - top) / (usable / laneCount)).toInt().coerceIn(0, laneCount - 1)
        return Pad(lane, left = x < width / 2f)
    }
}
