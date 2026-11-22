package com.handstrudel.ui.social.feed

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeOff
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.Fullscreen
import androidx.compose.material.icons.filled.FullscreenExit
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.Download
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.currentStateAsState
import com.handstrudel.app.LocalAppServices
import com.handstrudel.models.SoundSetup
import com.handstrudel.social.model.CreatorActivity
import com.handstrudel.social.model.Video
import com.handstrudel.ui.social.FeedVideoIcon
import com.handstrudel.ui.social.ProfileActionButton
import com.handstrudel.ui.social.SocialScreen
import com.handstrudel.ui.social.SocialToast
import com.handstrudel.ui.social.StudioActionButton
import com.handstrudel.ui.social.comments.CommentsSheet
import com.handstrudel.ui.social.rememberSocial
import com.handstrudel.ui.social.viewsLabel
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.launch

/**
 * iOS `CreatorVideoView`: one post (deep link `watch`, profile tiles, search
 * results, saved list) with swipe through the creator's [playlist].
 */
@Composable
fun CreatorVideoSheet(
    video: Video,
    onDismiss: () -> Unit,
    onPlayAlong: ((Video) -> Unit)? = null,
    onTrySound: ((SoundSetup) -> Unit)? = null,
    allowsSharing: Boolean = true,
    playlist: List<Video> = emptyList(),
    notification: CreatorActivity? = null,
    onNotificationRead: () -> Unit = {},
) {
    var playing by remember(video.id) { mutableStateOf<Video?>(null) }
    val current = playing ?: video
    val clips = playlist.filter { it.userId == current.userId && it.hidden != true }
    var isFullscreen by remember { mutableStateOf(false) }

    fun move(step: Int): Boolean {
        if (clips.isEmpty()) return false
        val index = clips.indexOfFirst { it.id == current.id }.takeIf { it >= 0 }?.let { (it + step + clips.size) % clips.size }
            ?: if (step > 0) 0 else clips.size - 1
        val next = clips[index]
        if (next.id == current.id) return false
        playing = next
        return true
    }

    val social = rememberSocial()
    SocialScreen(
        title = "@${current.username ?: social?.auth?.profile?.value?.username ?: "creator"}",
        onDismiss = { if (isFullscreen) isFullscreen = false else onDismiss() },
        dismissOnLeading = true,
        background = if (isFullscreen) Color.Black else null,
    ) {
        androidx.compose.runtime.key(current.id) {
            PerformanceDetail(
                video = current,
                isFullscreen = isFullscreen,
                setFullscreen = { isFullscreen = it },
                notification = notification,
                onNotificationRead = onNotificationRead,
                onPlayAlong = onPlayAlong,
                onTrySound = onTrySound,
                allowsSharing = allowsSharing && current.hidden != true,
                onSwipe = if (clips.any { it.id != current.id }) { step -> move(step) } else null,
                advance = { move(1) },
            )
        }
    }
}

/** iOS `PerformanceDetail`: player + details (views, preset card, caption, actions). */
@Composable
fun PerformanceDetail(
    video: Video,
    isFullscreen: Boolean,
    setFullscreen: (Boolean) -> Unit,
    notification: CreatorActivity? = null,
    onNotificationRead: () -> Unit = {},
    onPlayAlong: ((Video) -> Unit)? = null,
    onTrySound: ((SoundSetup) -> Unit)? = null,
    allowsSharing: Boolean = true,
    onSwipe: ((Int) -> Unit)? = null,
    advance: () -> Boolean = { false },
) {
    val social = rememberSocial() ?: return
    val p = LocalStudioPalette.current
    val context = LocalContext.current
    val prefs = LocalAppServices.current.prefs
    val muted by prefs.feedMuted.collectAsState()
    val scope = rememberCoroutineScope()
    val lifecycle by LocalLifecycleOwner.current.lifecycle.currentStateAsState()
    var showComments by remember { mutableStateOf(false) }
    var canDownloadAudio by remember { mutableStateOf(false) }
    var preparingAudio by remember { mutableStateOf(false) }
    var audioMessage by remember { mutableStateOf<String?>(null) }
    var showsFullscreenControls by remember { mutableStateOf(true) }

    val clip = remember(video.id) { FeedClip.standalone(context, social.http, video, scope, social.feed) }
    DisposableEffect(clip) { onDispose { clip.release() } }
    clip.onEnded = advance
    val isCurrent = lifecycle.isAtLeast(Lifecycle.State.RESUMED) && !showComments && !preparingAudio
    LaunchedEffect(isCurrent, muted) { clip.configure(isCurrent = true, allowed = isCurrent, muted = muted) }
    LaunchedEffect(video.id) {
        canDownloadAudio = runCatching { social.feed.audioDownloadsAllowed(listOf(video.id)) }.getOrDefault(emptySet()).contains(video.id)
    }
    LaunchedEffect(notification?.id) {
        val item = notification ?: return@LaunchedEffect
        if (item.readAt == null && runCatching { social.feed.markActivityRead(item) }.isSuccess) onNotificationRead()
    }
    LaunchedEffect(isFullscreen) { if (isFullscreen) showsFullscreenControls = true }

    fun downloadAudio() {
        if (preparingAudio) return
        preparingAudio = true
        scope.launch {
            try {
                if (video.id !in social.feed.audioDownloadsAllowed(listOf(video.id))) {
                    throw com.handstrudel.social.data.SocialException("The creator hasn't allowed audio downloads for this clip.")
                }
                val file = PerformanceAudio.export(context, social.http, video)
                PerformanceAudio.share(context, file)
            } catch (e: com.handstrudel.social.data.SocialException) {
                audioMessage = e.message
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: Exception) {
                audioMessage = "Couldn't prepare the audio. Try again."
            } finally {
                preparingAudio = false
            }
        }
    }

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val playerHeight = if (isFullscreen) maxHeight else minOf(430.dp, maxWidth * 1.19f)
        Column(
            Modifier.fillMaxSize().then(if (isFullscreen) Modifier else Modifier.verticalScroll(rememberScrollState()).padding(16.dp)),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(Modifier.fillMaxWidth().height(playerHeight).clip(RoundedCornerShape(if (isFullscreen) 0.dp else 16.dp)).testTag("performance-video")) {
                ClipSurface(
                    clip, isCurrent = true, aspectFit = true,
                    onToggleFullscreenControls = if (isFullscreen) ({ showsFullscreenControls = !showsFullscreenControls }) else null,
                    onSwipe = onSwipe,
                    showsFullscreenControls = showsFullscreenControls,
                )
                if (!isFullscreen || showsFullscreenControls) {
                    PlaybackControls(clip, showsPause = isFullscreen, muted = muted, toggleMute = { prefs.setFeedMuted(!muted) },
                        durationHint = video.durationS,
                        modifier = Modifier.align(Alignment.BottomCenter).fillMaxWidth().background(Color.Black.copy(alpha = 0.45f)).padding(10.dp))
                }
                IconButton(onClick = { setFullscreen(!isFullscreen) }, modifier = Modifier.align(Alignment.TopEnd).padding(4.dp).testTag("profile-video-fullscreen")) {
                    FeedVideoIcon(if (isFullscreen) Icons.Filled.FullscreenExit else Icons.Filled.Fullscreen, if (isFullscreen) "Exit full screen" else "Full screen")
                }
            }
            if (!isFullscreen) {
                val liveViews by clip.viewCount.collectAsState()
                (liveViews?.let { maxOf(it, video.viewCount ?: 0) } ?: video.viewCount)?.let { count ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Outlined.Visibility, null, tint = p.muted, modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(4.dp))
                        Text(viewsLabel(count), color = p.muted, fontSize = 12.sp, fontWeight = FontWeight.Medium, modifier = Modifier.testTag("video-view-count"))
                    }
                }
                val setup = video.soundSetup
                if (setup != null) {
                    ClipPresetCard(setup, video.username ?: social.auth.profile.value?.username, onTrySound?.let { play -> { s: SoundSetup -> clip.setPaused(true); play(s) } })
                } else if (video.instrument != null) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.GraphicEq, null, tint = p.muted, modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(4.dp)); Text(video.instrument, color = p.muted, fontSize = 12.sp)
                    }
                }
                if (video.caption.isNotEmpty()) Text(video.caption, color = p.ink, fontSize = 16.sp)
                notification?.let { NotificationCard(it) { showComments = true } }
                if (video.backingEnabled == true && onPlayAlong != null) {
                    StudioActionButton("Play along", icon = Icons.Filled.GraphicEq, onClick = { clip.setPaused(true); onPlayAlong(video) })
                }
                if (allowsSharing && canDownloadAudio) {
                    TextButton(onClick = ::downloadAudio, modifier = Modifier.heightIn(min = 44.dp)) {
                        Icon(Icons.Outlined.Download, null, tint = p.accent); Spacer(Modifier.width(6.dp)); Text("Download audio", color = p.accent)
                    }
                }
                if (notification?.commentId == null && video.commentsEnabled == true) {
                    TextButton(onClick = { showComments = true }, modifier = Modifier.heightIn(min = 44.dp).testTag("detail-comments")) {
                        Icon(Icons.Outlined.ChatBubbleOutline, null, tint = p.accent); Spacer(Modifier.width(6.dp)); Text("Comments", color = p.accent)
                    }
                }
                if (allowsSharing) {
                    TextButton(onClick = { VideoShareSheet.share(context, video) { scope.launch { runCatching { social.feed.recordShare(video.id) } } } },
                        modifier = Modifier.heightIn(min = 44.dp)) {
                        Icon(Icons.Filled.Share, null, tint = p.accent); Spacer(Modifier.width(6.dp)); Text("Share video", color = p.accent)
                    }
                }
            }
        }
        if (preparingAudio) SocialToast("Preparing audio…")
    }

    if (showComments) CommentsSheet(video, onDismiss = { showComments = false }, targetComment = notification?.commentId)
    audioMessage?.let { message ->
        AlertDialog(onDismissRequest = { audioMessage = null }, confirmButton = { TextButton(onClick = { audioMessage = null }) { Text("OK") } },
            title = { Text("Download audio") }, text = { Text(message) })
    }
}

/** iOS `ClipPlaybackControls`: optional pause button, scrubber, mute. */
@Composable
fun PlaybackControls(clip: FeedClip, showsPause: Boolean, muted: Boolean, toggleMute: () -> Unit, durationHint: Double?,
                     modifier: Modifier = Modifier, onVerticalSwipe: ((Float) -> Unit)? = null) {
    val paused by clip.paused.collectAsState()
    val failed by clip.failed.collectAsState()
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        if (showsPause) {
            Box(Modifier.clickable(enabled = !failed) { clip.togglePause() }.testTag("fullscreen-playback-toggle")) {
                FeedVideoIcon(if (paused) Icons.Filled.PlayArrow else Icons.Filled.Pause, if (paused) "Play video" else "Pause video")
            }
        }
        FeedProgressStrip(clip, durationHint, Modifier.weight(1f), onVerticalSwipe)
        Box(Modifier.clickable(onClick = toggleMute).testTag("video-playback-mute")) {
            FeedVideoIcon(if (muted) Icons.AutoMirrored.Filled.VolumeOff else Icons.AutoMirrored.Filled.VolumeUp, if (muted) "Unmute" else "Mute")
        }
    }
}

/** iOS `ClipPresetCard`: the shared sound with "Play this sound" and a private save. */
@Composable
private fun ClipPresetCard(setup: SoundSetup, username: String?, onPlay: ((SoundSetup) -> Unit)?) {
    val p = LocalStudioPalette.current
    val title = setup.instrumentName ?: "Performance preset"
    Column(Modifier.clip(RoundedCornerShape(12.dp)).background(Color.Black.copy(alpha = 0.7f)).padding(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.GraphicEq, null, tint = p.mediaAccent, modifier = Modifier.size(14.dp)); Spacer(Modifier.width(4.dp))
            Text(title, color = p.mediaAccent, fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1)
        }
        Text(setup.presetDetails, color = Color.White, fontSize = 12.sp, maxLines = 2)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            if (onPlay != null) {
                Row(
                    Modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(9.dp)).background(p.mediaAccent).clickable { onPlay(setup) }
                        .padding(horizontal = 11.dp).testTag("play-clip-preset"),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.PlayArrow, null, tint = p.mediaOnAccent, modifier = Modifier.size(16.dp)); Spacer(Modifier.width(4.dp))
                    Text("Play this sound", color = p.mediaOnAccent, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }
            }
            SavePresetButton(setup, savedName(title, username), compact = true)
        }
    }
}

@Composable
private fun NotificationCard(item: CreatorActivity, openComments: () -> Unit) {
    val p = LocalStudioPalette.current
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(p.surface).padding(horizontal = 14.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(item.title, color = p.ink, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
        if (item.commentId != null) {
            Text(item.body, color = p.muted, fontSize = 15.sp, maxLines = 3)
            TextButton(onClick = openComments, modifier = Modifier.heightIn(min = 44.dp).testTag("notification-view-comment")) {
                Icon(Icons.Outlined.ChatBubbleOutline, null, tint = p.accent); Spacer(Modifier.width(6.dp))
                Text(item.kind.commentAction, color = p.accent, fontWeight = FontWeight.Bold)
            }
        }
    }
}
