package com.handstrudel.ui.capture

import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.annotation.OptIn
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.C
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import com.handstrudel.ui.theme.StudioFonts
import kotlinx.coroutines.delay

/**
 * The review-take preview, drawn like iOS's inline AVKit `VideoPlayer` instead of
 * ExoPlayer's stock controller: a centred play/pause disc over the video while paused
 * (or briefly after a tap), and a slim bottom bar with elapsed time, a scrubber and the
 * remaining time. [player] should already be in output time ([TimeScaledPlayer]).
 */
@OptIn(UnstableApi::class)
@Composable
internal fun DraftPreviewPlayer(player: Player, modifier: Modifier = Modifier) {
    var isPlaying by remember { mutableStateOf(player.isPlaying) }
    var position by remember { mutableLongStateOf(0L) }
    var duration by remember { mutableLongStateOf(0L) }
    var scrubbing by remember { mutableStateOf<Float?>(null) }
    var controlsVisible by remember { mutableStateOf(true) }
    var lastInteraction by remember { mutableLongStateOf(0L) }

    DisposableEffect(player) {
        val listener = object : Player.Listener {
            override fun onIsPlayingChanged(playing: Boolean) { isPlaying = playing }
        }
        player.addListener(listener)
        onDispose { player.removeListener(listener) }
    }
    LaunchedEffect(player) {
        while (true) {
            position = player.currentPosition.coerceAtLeast(0)
            duration = player.duration.takeIf { it != C.TIME_UNSET && it > 0 } ?: 0L
            delay(100)
        }
    }
    // AVKit hides its chrome a few seconds into playback; it stays while paused.
    LaunchedEffect(isPlaying, controlsVisible, lastInteraction) {
        if (isPlaying && controlsVisible && scrubbing == null) {
            delay(2500)
            controlsVisible = false
        } else if (!isPlaying) {
            controlsVisible = true
        }
    }

    fun touch() { lastInteraction = System.nanoTime() }

    Box(
        modifier
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {
                controlsVisible = !controlsVisible; touch()
            },
    ) {
        AndroidView(
            factory = {
                PlayerView(it).apply {
                    useController = false
                    resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
                    setShutterBackgroundColor(android.graphics.Color.BLACK)
                    this.player = player
                }
            },
            update = { it.player = player },
            modifier = Modifier.fillMaxSize(),
        )
        if (controlsVisible) {
            Box(
                Modifier.align(Alignment.Center).size(64.dp).clip(CircleShape)
                    .background(Color.Black.copy(alpha = 0.42f))
                    .clickable {
                        if (player.isPlaying) player.pause() else {
                            if (player.playbackState == Player.STATE_ENDED) player.seekTo(0)
                            player.play()
                        }
                        touch()
                    }
                    .semantics { contentDescription = if (isPlaying) "Pause" else "Play" }
                    .testTag("draft-player-toggle"),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    if (isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow, null,
                    tint = Color.White, modifier = Modifier.size(34.dp),
                )
            }
            if (duration > 0) {
                val shown = scrubbing ?: (position.toFloat() / duration).coerceIn(0f, 1f)
                Row(
                    Modifier.align(Alignment.BottomCenter).fillMaxWidth().padding(10.dp)
                        .clip(CircleShape).background(Color.Black.copy(alpha = 0.42f))
                        .padding(horizontal = 12.dp).height(34.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    val shownMs = (shown * duration).toLong()
                    TimeLabel(formatClock(shownMs))
                    Scrubber(
                        fraction = shown,
                        onScrub = { scrubbing = it; touch() },
                        onCommit = {
                            scrubbing?.let { player.seekTo((it * duration).toLong()) }
                            scrubbing = null
                        },
                        modifier = Modifier.weight(1f),
                    )
                    TimeLabel("-" + formatClock(duration - shownMs))
                }
            }
        }
    }
}

/** AVKit-style thin white track with a small round thumb; drag or tap to seek. */
@Composable
private fun Scrubber(fraction: Float, onScrub: (Float) -> Unit, onCommit: () -> Unit, modifier: Modifier = Modifier) {
    BoxWithConstraints(
        modifier.height(24.dp).testTag("draft-player-scrubber")
            .pointerInput(Unit) {
                detectTapGestures { onScrub((it.x / size.width).coerceIn(0f, 1f)); onCommit() }
            }
            .pointerInput(Unit) {
                detectHorizontalDragGestures(
                    onDragEnd = onCommit, onDragCancel = onCommit,
                ) { change, _ -> onScrub((change.position.x / size.width).coerceIn(0f, 1f)) }
            },
        contentAlignment = Alignment.CenterStart,
    ) {
        val thumb = 12.dp
        Box(Modifier.fillMaxWidth().height(4.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.3f)))
        Box(Modifier.fillMaxWidth(fraction).height(4.dp).clip(CircleShape).background(Color.White))
        Box(Modifier.offset(x = (maxWidth - thumb) * fraction).size(thumb).clip(CircleShape).background(Color.White))
    }
}

@Composable
private fun TimeLabel(text: String) {
    Text(
        text, color = Color.White.copy(alpha = 0.85f), fontSize = 11.sp, fontWeight = FontWeight.Medium,
        fontFamily = StudioFonts.Mono, maxLines = 1, modifier = Modifier.width(38.dp),
    )
}

internal fun formatClock(ms: Long): String {
    val total = (ms.coerceAtLeast(0) + 500) / 1000
    return "%d:%02d".format(total / 60, total % 60)
}
