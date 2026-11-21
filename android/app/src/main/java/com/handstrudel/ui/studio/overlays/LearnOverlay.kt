package com.handstrudel.ui.studio.overlays

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.TrackChanges
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.engine.LearnNoteState
import com.handstrudel.engine.LearnScore
import com.handstrudel.ui.studio.common.StageMetrics
import com.handstrudel.ui.studio.common.StudioMusic
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * iOS `LearnOverlayView`: Guitar-Hero style lanes. Notes scroll right → left to
 * a glowing hit line at 25 % of the width; tap the lane buttons left of the
 * line (or pinch in the lane) as a note reaches it. Score HUD top-right, and a
 * Song Complete card with PLAY AGAIN / PICK SONG.
 */
@Composable
fun LearnOverlay(touchEnabled: Boolean, onPickSong: () -> Unit, modifier: Modifier = Modifier) {
    val engine = LocalAppServices.current.engine
    val learn by engine.learn.collectAsState()
    val key by engine.selectedKey.collectAsState()
    val scale by engine.selectedScale.collectAsState()
    val baseOctave by engine.gridBaseOctave.collectAsState()
    val octaveRange by engine.gridOctaveRange.collectAsState()
    val hands by engine.handsState.collectAsState()
    val colors = rememberOverlayColors()
    val density = LocalDensity.current

    val scaleNotes = remember(key, scale, baseOctave, octaveRange) {
        StudioMusic.scaleNotes(key, scale.intervals, baseOctave, octaveRange)
    }
    val noteCount = scaleNotes.size
    val songName = learn.currentSongName ?: ""
    val leftPinching = (hands.left?.pinch ?: 0.0) > 0.8
    val rightPinching = (hands.right?.pinch ?: 0.0) > 0.8

    BoxWithConstraints(
        modifier
            .fillMaxSize()
            .onSizeChanged { engine.updateLearnViewport(it.width.toFloat(), it.height.toFloat()) },
    ) {
        val wPx = with(density) { maxWidth.toPx() }
        val hPx = with(density) { maxHeight.toPx() }
        val topPadPx = hPx * LearnGeometry.TOP.toFloat()
        val usablePx = hPx - topPadPx - hPx * LearnGeometry.BOTTOM.toFloat()
        val laneHeightPx = usablePx / max(1, noteCount)
        val hitLineXPx = wPx * LearnGeometry.HIT_LINE_X.toFloat()
        val viewportAspect = wPx / max(1f, hPx)

        val leftLane = hands.left?.let { LearnGeometry.cameraLane(it.pinchY, noteCount, StageMetrics.VIDEO_ASPECT.toDouble(), viewportAspect.toDouble()) }
        val rightLane = hands.right?.let { LearnGeometry.cameraLane(it.pinchY, noteCount, StageMetrics.VIDEO_ASPECT.toDouble(), viewportAspect.toDouble()) }

        // Lanes, hit line, scrolling notes, hand lines.
        Canvas(Modifier.fillMaxSize()) {
            for (i in 0 until noteCount) {
                val noteIdx = noteCount - 1 - i
                val isLeftHere = leftLane == noteIdx
                val isRightHere = rightLane == noteIdx
                val top = topPadPx + i * laneHeightPx
                val fill = when {
                    isLeftHere && leftPinching -> colors.green.copy(alpha = 0.2f)
                    isRightHere && rightPinching -> colors.pink.copy(alpha = 0.2f)
                    isLeftHere -> colors.green.copy(alpha = 0.08f)
                    isRightHere -> colors.pink.copy(alpha = 0.08f)
                    else -> Color.White.copy(alpha = if (i % 2 == 0) 0.03f else 0f)
                }
                drawRect(fill, Offset(0f, top), Size(size.width, laneHeightPx))
                val divider = 0.5.dp.toPx()
                drawRect(Color.White.copy(alpha = 0.06f), Offset(0f, top + laneHeightPx - divider), Size(size.width, divider))
            }

            // Hit line: 2 pt cyan with two glows (radius 8 @ 0.6, radius 16 @ 0.3).
            val lineW = 2.dp.toPx()
            val linePath = Path().apply { addRect(androidx.compose.ui.geometry.Rect(Offset(hitLineXPx - lineW / 2f, topPadPx), Size(lineW, usablePx))) }
            glowPath(linePath, colors.cyan.copy(alpha = 0.3f), 16.dp.toPx())
            glowPath(linePath, colors.cyan.copy(alpha = 0.6f), 8.dp.toPx())
            drawPath(linePath, colors.cyan)

            // Scrolling note capsules.
            val corner = CornerRadius(6.dp.toPx())
            for (note in learn.visibleNotes) {
                val visualRow = noteCount - 1 - note.laneIndex
                val laneY = topPadPx + visualRow * laneHeightPx + laneHeightPx / 2f
                val noteX = (note.xFraction * size.width).toFloat()
                val noteW = max(30.dp.toPx(), (note.widthFraction * size.width).toFloat())
                val noteH = laneHeightPx * 0.7f
                val alpha = if (note.state == LearnNoteState.MISSED) 0.5f else 1f
                val topLeft = Offset(noteX, laneY - noteH / 2f)
                drawRoundRect(noteFill(note.state, colors), topLeft, Size(noteW, noteH), corner, alpha = alpha)
                if (note.state == LearnNoteState.UPCOMING) {
                    drawRoundRect(colors.cyan.copy(alpha = 0.7f), topLeft, Size(noteW, noteH), corner, style = Stroke(1.dp.toPx()), alpha = alpha)
                }
            }

            // Hand position indicators (vertical lines).
            fun handLine(px: Double, pinching: Boolean, color: Color) {
                val x = LearnGeometry.correctedX(px, size.width, size.height, StageMetrics.VIDEO_ASPECT)
                val w = (if (pinching) 2f else 1f).dp.toPx()
                val path = Path().apply { addRect(androidx.compose.ui.geometry.Rect(Offset(x - w / 2f, topPadPx), Size(w, usablePx))) }
                if (pinching) glowPath(path, color.copy(alpha = 0.5f * 0.7f), 6.dp.toPx())
                drawPath(path, color.copy(alpha = if (pinching) 0.7f else 0.25f))
            }
            hands.left?.let { handLine(it.pinchX, leftPinching, colors.green) }
            hands.right?.let { handLine(it.pinchX, rightPinching, colors.pink) }
        }

        // Hit effects (expanding glow at the hit line).
        for (effect in learn.hitEffects) {
            key(effect.id) {
                val visualRow = noteCount - 1 - effect.laneIndex
                HitEffect(
                    effect.type, colors,
                    x = hitLineXPx,
                    y = topPadPx + visualRow * laneHeightPx + laneHeightPx / 2f,
                    laneHeight = laneHeightPx,
                )
            }
        }

        if (!learn.songComplete && songName.isNotEmpty()) {
            // Touch hint above the lanes.
            var hintSize by remember { mutableStateOf(androidx.compose.ui.unit.IntSize.Zero) }
            val hintY = max(with(density) { 20.dp.toPx() }, topPadPx - with(density) { 13.dp.toPx() })
            Text(
                "Tap a note here as it reaches the line",
                fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White, maxLines = 1,
                modifier = Modifier
                    .onSizeChanged { hintSize = it }
                    .offset { IntOffset((wPx / 2f - hintSize.width / 2f).roundToInt(), (hintY - hintSize.height / 2f).roundToInt()) }
                    .background(Color.Black.copy(alpha = 0.70f), CircleShape)
                    .padding(horizontal = 9.dp, vertical = 5.dp)
                    .testTag("learn-touch-hint"),
            )
            // Lane buttons left of the hit line.
            val btnW = max(with(density) { 42.dp.toPx() }, hitLineXPx - with(density) { 12.dp.toPx() })
            val btnH = max(1f, laneHeightPx - with(density) { 1.dp.toPx() })
            for (row in 0 until noteCount) {
                val lane = noteCount - 1 - row
                if (lane !in scaleNotes.indices) continue
                val note = StudioMusic.midiNoteName(scaleNotes[lane])
                val cx = hitLineXPx / 2f
                val cy = topPadPx + (row + 0.5f) * laneHeightPx
                Box(
                    Modifier
                        .offset { IntOffset((cx - btnW / 2f).roundToInt(), (cy - btnH / 2f).roundToInt()) }
                        .size(with(density) { btnW.toDp() }, with(density) { btnH.toDp() })
                        .background(Color.Black.copy(alpha = 0.47f), RoundedCornerShape(5.dp))
                        .clickable(enabled = touchEnabled) { engine.tapLearnLane(lane) }
                        .semantics { contentDescription = "Play $note" }
                        .testTag("learn-lane-$lane"),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(note, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Monospace, color = Color.White, maxLines = 1)
                }
            }
        }

        // Score HUD (top-right corner).
        Row(
            Modifier
                .align(Alignment.TopEnd)
                .padding(end = 16.dp, top = with(density) { topPadPx.toDp() } + 8.dp)
                .background(Color.Black.copy(alpha = 0.6f), CircleShape)
                .border(0.5.dp, Color.White.copy(alpha = 0.1f), CircleShape)
                .padding(horizontal = 12.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            HudStat(Icons.Filled.Star, colors.yellow, "${learn.score.perfectHits + learn.score.goodHits}")
            HudStat(Icons.Filled.TrackChanges, colors.cyan, "${(learn.score.accuracy * 100).toInt()}%")
            if (learn.score.currentStreak > 0) HudStat(Icons.Filled.LocalFireDepartment, colors.orange, "${learn.score.currentStreak}")
        }

        // TODO(engine): iOS shows a 3-2-1 countdown (120 pt, cyan glow) from
        // `learnModeManager.countdownValue`/`isCountingDown`; `LearnDisplay` has neither.

        if (learn.songComplete) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                SongCompleteCard(
                    songName = songName,
                    score = learn.score,
                    colors = colors,
                    onPlayAgain = { learn.currentSongId?.let(engine::loadLearnSong) },
                    onPickSong = onPickSong,
                )
            }
        }
    }
}

private fun noteFill(state: LearnNoteState, colors: OverlayColors): Color = when (state) {
    LearnNoteState.UPCOMING -> colors.cyan.copy(alpha = 0.5f)
    LearnNoteState.ACTIVE -> colors.cyan.copy(alpha = 0.8f)
    LearnNoteState.HIT_PERFECT -> colors.green
    LearnNoteState.HIT_GOOD -> colors.yellow
    LearnNoteState.MISSED -> colors.red.copy(alpha = 0.3f)
}

@Composable
private fun HudStat(icon: androidx.compose.ui.graphics.vector.ImageVector, tint: Color, value: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(11.dp))
        Text(value, fontSize = 12.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = Color.White)
    }
}

/** iOS `HitEffectView`: a circle 1.5 × lane height that scales 0.5 → 1.5 and fades out in 0.3 s. */
@Composable
private fun HitEffect(type: LearnNoteState, colors: OverlayColors, x: Float, y: Float, laneHeight: Float) {
    val color = when (type) {
        LearnNoteState.HIT_PERFECT -> colors.green
        LearnNoteState.HIT_GOOD -> colors.yellow
        LearnNoteState.MISSED -> colors.red
        else -> Color.Transparent
    }
    val progress = remember { Animatable(0f) }
    LaunchedEffect(Unit) { progress.animateTo(1f, tween(300, easing = FastOutSlowInEasing)) }
    Canvas(Modifier.fillMaxSize()) {
        val p = progress.value
        val scale = 0.5f + p
        val alpha = 1f - p
        if (alpha <= 0f || color.alpha == 0f) return@Canvas
        val r = laneHeight * 1.5f / 2f * scale
        val center = Offset(x, y)
        glowPath(Path().apply { addOval(androidx.compose.ui.geometry.Rect(center, r)) }, color.copy(alpha = 0.6f * alpha), 12.dp.toPx())
        drawCircle(color.copy(alpha = 0.4f * alpha), r, center)
        drawCircle(color.copy(alpha = alpha), r, center, style = Stroke(2.dp.toPx() * scale))
    }
}

@Composable
private fun SongCompleteCard(
    songName: String,
    score: LearnScore,
    colors: OverlayColors,
    onPlayAgain: () -> Unit,
    onPickSong: () -> Unit,
) {
    val cardShape = RoundedCornerShape(24.dp)
    Column(
        Modifier
            .padding(horizontal = 32.dp)
            .iosGlow(Color.Black.copy(alpha = 0.5f), 30f, 24f)
            .background(Color.Black.copy(alpha = 0.85f), cardShape)
            .border(1.dp, Color.White.copy(alpha = 0.1f), cardShape)
            .padding(28.dp)
            .testTag("learn-song-complete"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Text(songName, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Color.White)
        val gradient = when {
            score.accuracy >= 0.9 -> listOf(colors.green, colors.cyan)
            score.accuracy >= 0.7 -> listOf(colors.yellow, colors.green)
            else -> listOf(colors.red, colors.orange)
        }
        Text(
            "${(score.accuracy * 100).toInt()}%",
            style = TextStyle(fontSize = 56.sp, fontWeight = FontWeight.Black, brush = Brush.horizontalGradient(gradient)),
        )
        Text("ACCURACY", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.4f), letterSpacing = 2.sp)
        Row(Modifier.padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(24.dp)) {
            ScoreColumn(score.perfectHits, "PERFECT", colors.green)
            ScoreColumn(score.goodHits, "GOOD", colors.yellow)
            ScoreColumn(score.misses, "MISS", colors.red)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.LocalFireDepartment, contentDescription = null, tint = colors.orange, modifier = Modifier.size(15.dp))
            Text("Best Streak: ${score.bestStreak}", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.7f))
        }
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(50.dp)
                    .background(Brush.horizontalGradient(listOf(colors.green, Color(0f, 0.8f, 0.6f))), RoundedCornerShape(14.dp))
                    .clickable(onClick = onPlayAgain)
                    .testTag("learn-play-again"),
                contentAlignment = Alignment.Center,
            ) {
                Text("PLAY AGAIN", fontSize = 16.sp, fontWeight = FontWeight.Black, color = Color.Black)
            }
            val pickShape = RoundedCornerShape(12.dp)
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(44.dp)
                    .background(Color.White.copy(alpha = 0.06f), pickShape)
                    .border(1.dp, Color.White.copy(alpha = 0.15f), pickShape)
                    .clickable(onClick = onPickSong)
                    .testTag("learn-pick-song"),
                contentAlignment = Alignment.Center,
            ) {
                Text("PICK SONG", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.8f))
            }
        }
    }
}

@Composable
private fun ScoreColumn(value: Int, label: String, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text("$value", fontSize = 24.sp, fontWeight = FontWeight.Black, color = color)
        Text(label, fontSize = 9.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.4f), letterSpacing = 1.sp)
    }
}

/** Pure Learn lane geometry (iOS `LearnLaneLayout` + overlay maths; JVM-tested). */
object LearnGeometry {
    const val TOP = 0.15
    const val BOTTOM = 0.20
    /** iOS `LearnModeManager.hitLineX`. */
    const val HIT_LINE_X = 0.25

    /** iOS `LearnLaneLayout.cameraLane`: the note lane (0 = lowest, at the bottom) a camera pinch at [y] is in. */
    fun cameraLane(y: Double, noteCount: Int, videoAspect: Double, viewportAspect: Double): Int? {
        if (!y.isFinite() || noteCount <= 0 || !videoAspect.isFinite() || videoAspect <= 0 ||
            !viewportAspect.isFinite() || viewportAspect <= 0
        ) return null
        val visible = minOf(1.0, videoAspect / viewportAspect)
        val screenY = (y - (1 - visible) / 2) / visible
        if (screenY < TOP || screenY > 1 - BOTTOM) return null
        val row = minOf(noteCount - 1, ((screenY - TOP) / (1 - TOP - BOTTOM) * noteCount).toInt())
        return noteCount - 1 - row
    }

    /** iOS overlay `correctedX`: normalised camera x → stage px under aspect-fill. */
    fun correctedX(vx: Double, width: Float, height: Float, videoAspect: Float): Float {
        val scrAspect = width / max(1f, height)
        return if (videoAspect > scrAspect) {
            val vis = scrAspect / videoAspect
            val off = (1 - vis) / 2
            ((vx.toFloat() - off) / vis * width)
        } else {
            (vx * width).toFloat()
        }
    }
}
