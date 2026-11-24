package com.handstrudel.ui.social.feed

import com.handstrudel.ui.theme.StudioIcons

import androidx.compose.material.icons.filled.Sync
import com.handstrudel.ui.theme.StudioFonts
import android.view.LayoutInflater
import androidx.annotation.OptIn
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.util.UnstableApi
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import com.handstrudel.R
import com.handstrudel.social.model.Video
import com.handstrudel.social.model.VideoEngagement
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlin.math.abs

/**
 * iOS `ClipPlaybackSurface`: the video, tap to pause (or to toggle fullscreen
 * controls), the paused glyph and the "Couldn't play this video." retry card.
 */
@OptIn(UnstableApi::class)
@Composable
fun ClipSurface(
    clip: FeedClip,
    isCurrent: Boolean,
    aspectFit: Boolean,
    modifier: Modifier = Modifier,
    onToggleFullscreenControls: (() -> Unit)? = null,
    onSwipe: ((Int) -> Unit)? = null,
    showsFullscreenControls: Boolean = false,
    /** TalkBack "Next video" / "Previous video" when the parent pages (the feed pager). */
    onAccessibilityMove: ((Int) -> Boolean)? = null,
) {
    val p = LocalStudioPalette.current
    val failed by clip.failed.collectAsState()
    val paused by clip.paused.collectAsState()
    val density = LocalDensity.current
    Box(modifier.fillMaxSize().background(Color.Black)) {
        AndroidView(
            factory = { ctx ->
                (LayoutInflater.from(ctx).inflate(R.layout.social_feed_player, null) as PlayerView)
            },
            update = { view ->
                if (view.player !== clip.player) view.player = clip.player
                view.resizeMode = if (aspectFit) AspectRatioFrameLayout.RESIZE_MODE_FIT else AspectRatioFrameLayout.RESIZE_MODE_ZOOM
            },
            onRelease = { it.player = null },
            modifier = Modifier.fillMaxSize(),
        )
        // Touch layer (the player itself ignores touches).
        Box(
            Modifier.fillMaxSize()
                .pointerInput(clip, onToggleFullscreenControls) {
                    detectTapGestures {
                        if (onToggleFullscreenControls != null) onToggleFullscreenControls() else clip.togglePause()
                    }
                }
                .then(if (onSwipe != null) Modifier.pointerInput(clip) {
                    var dy = 0f
                    val threshold = with(density) { 48.dp.toPx() }
                    detectVerticalDragGestures(onDragStart = { dy = 0f }, onDragEnd = {
                        if (abs(dy) >= threshold) onSwipe(if (dy < 0) 1 else -1)
                    }) { _, amount -> dy += amount }
                } else Modifier)
                .semantics {
                    contentDescription = if (paused) "Play video" else "Pause video"
                    // iOS ClipPlaybackSurface `.accessibilityActions`.
                    customActions = clipAccessibilityActions(
                        showsFullscreenControls = onToggleFullscreenControls?.let { showsFullscreenControls },
                        paused = paused, failed = failed,
                        toggleControls = { onToggleFullscreenControls?.invoke() },
                        togglePause = clip::togglePause,
                        move = onSwipe?.let { swipe -> { by: Int -> swipe(by); true } } ?: onAccessibilityMove,
                    )
                },
        )
        if (isCurrent && failed) {
            Column(
                Modifier.align(Alignment.Center).clip(RoundedCornerShape(12.dp)).background(Color.Black.copy(alpha = 0.8f)).padding(12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("Couldn't play this video.", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                Spacer(Modifier.size(8.dp))
                Button(
                    onClick = { clip.retry() },
                    colors = ButtonDefaults.buttonColors(containerColor = p.mediaAccent, contentColor = p.mediaOnAccent),
                    modifier = Modifier.testTag("feed-retry-video"),
                ) { Text("Retry video") }
            }
        } else if (paused && !failed && onToggleFullscreenControls == null) {
            Icon(Icons.Filled.PlayCircle, null, tint = Color.White, modifier = Modifier.align(Alignment.Center).size(64.dp))
        }
    }
}

/**
 * iOS ClipPlaybackSurface accessibility actions, in its order. [showsFullscreenControls] is
 * null when the surface has no fullscreen controls; [move] null when it can't page.
 */
internal fun clipAccessibilityActions(
    showsFullscreenControls: Boolean?,
    paused: Boolean,
    failed: Boolean,
    toggleControls: () -> Unit,
    togglePause: () -> Unit,
    move: ((Int) -> Boolean)?,
): List<CustomAccessibilityAction> = buildList {
    if (showsFullscreenControls != null) {
        add(CustomAccessibilityAction(if (showsFullscreenControls) "Hide playback controls" else "Show playback controls") { toggleControls(); true })
    }
    if (!failed) add(CustomAccessibilityAction(if (paused) "Play video" else "Pause video") { togglePause(); true })
    if (move != null) {
        add(CustomAccessibilityAction("Next video") { move(1) })
        add(CustomAccessibilityAction("Previous video") { move(-1) })
    }
}

/** iOS `FeedCell`: the clip with its bottom gradient and post details. */
@Composable
fun FeedCell(
    video: Video,
    clip: FeedClip,
    isCurrent: Boolean,
    isFullscreen: Boolean,
    showsFullscreenControls: Boolean,
    onToggleFullscreenControls: () -> Unit,
    engagement: VideoEngagement?,
    bottomInset: Dp,
    isMine: Boolean,
    isFollowing: Boolean,
    follow: () -> Unit,
    creator: () -> Unit,
    showSound: () -> Unit,
    source: (java.util.UUID) -> Unit,
    onAccessibilityMove: ((Int) -> Boolean)? = null,
) {
    Box(Modifier.fillMaxSize()) {
        ClipSurface(
            clip, isCurrent, aspectFit = isFullscreen,
            onToggleFullscreenControls = if (isFullscreen) onToggleFullscreenControls else null,
            showsFullscreenControls = showsFullscreenControls,
            onAccessibilityMove = onAccessibilityMove,
        )
        if (!isFullscreen || showsFullscreenControls) {
            Box(
                Modifier.fillMaxSize().background(
                    Brush.verticalGradient(
                        0f to Color.Transparent,
                        (if (isFullscreen) 0.8f else 0.5f) to Color.Transparent,
                        1f to Color.Black.copy(alpha = if (isFullscreen) 0.58f else 0.88f),
                    ),
                ),
            )
        }
        if (!isFullscreen) {
            PostControls(
                video, engagement, isMine, isFollowing, follow, creator, showSound, source,
                Modifier.align(Alignment.BottomStart).padding(start = 15.dp, end = 79.dp, bottom = bottomInset),
            )
        }
    }
}

@Composable
private fun PostControls(
    video: Video,
    engagement: VideoEngagement?,
    isMine: Boolean,
    isFollowing: Boolean,
    follow: () -> Unit,
    creator: () -> Unit,
    showSound: () -> Unit,
    source: (java.util.UUID) -> Unit,
    modifier: Modifier,
) {
    val p = LocalStudioPalette.current
    Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (engagement?.repostedByMe == true) {
            RepostLabel("You reposted", p.mediaAccent)
        } else if (video.repostedBy != null) {
            RepostLabel("@${video.repostedBy} reposted", Color.White.copy(alpha = 0.9f))
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (!isMine) {
                Text(
                    if (isFollowing) "Following" else "Follow",
                    color = if (isFollowing) Color.White else p.mediaOnAccent,
                    fontWeight = FontWeight.SemiBold, fontSize = 12.sp,
                    modifier = Modifier.heightIn(min = 30.dp).clip(RoundedCornerShape(50))
                        .background(if (isFollowing) Color.White.copy(alpha = 0.16f) else p.mediaAccent)
                        .clickable(onClick = follow).padding(horizontal = 11.dp, vertical = 6.dp)
                        .testTag("feed-follow"),
                )
            }
            Text(
                "@${video.username ?: "user"}", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 17.sp,
                maxLines = 1, overflow = TextOverflow.Ellipsis,
                modifier = Modifier.clickable(onClick = creator).semantics { contentDescription = "@${video.username ?: "user"}, opens creator profile" },
            )
        }
        if (video.caption.isNotEmpty()) {
            Text(video.caption, color = Color.White, fontSize = 15.sp, maxLines = 3, overflow = TextOverflow.Ellipsis)
        }
        if (video.soundSetup != null || video.backingEnabled == true) {
            val title = video.soundSetup?.instrumentName ?: video.instrument ?: "Sound"
            Row(
                Modifier.heightIn(min = 34.dp).clip(RoundedCornerShape(50)).background(Color.Black.copy(alpha = 0.66f))
                    .border(1.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(50))
                    .clickable(onClick = showSound).padding(horizontal = 11.dp, vertical = 7.dp)
                    .semantics { contentDescription = "Sound options: $title" }.testTag("feed-sound-options"),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(StudioIcons.Waveform, null, tint = p.mediaAccent, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(6.dp))
                Text(title, color = p.mediaAccent, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
                Spacer(Modifier.width(6.dp))
                Icon(Icons.Filled.KeyboardArrowUp, null, tint = p.mediaAccent, modifier = Modifier.size(12.dp))
            }
        } else if (video.instrument != null) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(StudioIcons.Waveform, null, tint = p.mediaAccent, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(4.dp))
                Text(video.instrument, color = p.mediaAccent, fontSize = 12.sp, fontFamily = StudioFonts.Mono)
            }
        }
        val sourceId = video.sourceVideoId
        val sourceName = video.sourceUsername
        if (sourceId != null && sourceName != null) {
            Text(
                "Inspired by @$sourceName", color = p.mediaAccent, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickable { source(sourceId) }.padding(vertical = 4.dp),
            )
        }
    }
}

@Composable
private fun RepostLabel(text: String, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Filled.Sync, null, tint = color, modifier = Modifier.size(14.dp))
        Spacer(Modifier.width(4.dp))
        Text(text, color = color, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
    }
}
