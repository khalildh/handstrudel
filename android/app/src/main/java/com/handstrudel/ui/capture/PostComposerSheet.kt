package com.handstrudel.ui.capture

import androidx.compose.foundation.layout.statusBarsPadding
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.handstrudel.capture.CaptureControllerImpl
import com.handstrudel.capture.graphemePrefix
import com.handstrudel.capture.drafts.DraftExport
import com.handstrudel.capture.drafts.MediaInfo
import com.handstrudel.capture.drafts.RecordingDraft
import com.handstrudel.capture.upload.PostSharingOptions
import com.handstrudel.capture.upload.VideoUploader
import com.handstrudel.models.SoundSetup
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** iOS `PostComposerView`: preview, caption, sharing toggles, then the upload. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun PostComposerSheet(controller: CaptureControllerImpl, draft: RecordingDraft, clip: DraftExport, onDismiss: () -> Unit) {
    val palette = LocalStudioPalette.current
    val context = LocalContext.current
    val uploader = remember(draft.id) { controller.uploader(draft.id) }
    val phase by uploader.phase.collectAsState()
    val userId by controller.auth.userId.collectAsState()
    val drafts by controller.drafts.drafts.collectAsState()
    val submission = userId?.let { id -> drafts.firstOrNull { it.id == draft.id }?.postSubmission(id) }
    var caption by remember { mutableStateOf("") }
    var sharing by remember { mutableStateOf(PostSharingOptions()) }
    var commentsEnabled by remember { mutableStateOf(true) }
    var hasAudio by remember { mutableStateOf<Boolean?>(null) }
    val busy = phase == VideoUploader.Phase.Preparing || phase is VideoUploader.Phase.Uploading || phase == VideoUploader.Phase.Checking
    val credit = draft.backingCredit
    val checkingAudio = credit == null && hasAudio == null
    val locked = busy || submission != null

    val player = remember(clip) {
        ExoPlayer.Builder(context).build().apply {
            setMediaItem(MediaItem.fromUri(Uri.fromFile(clip.file)))
            prepare()
            play()
        }
    }
    DisposableEffect(player) { onDispose { player.release() } }
    LaunchedEffect(clip) {
        if (credit == null) hasAudio = withContext(Dispatchers.IO) { MediaInfo.hasAudioTrack(clip.file) }
    }

    ModalBottomSheet(
        modifier = Modifier.statusBarsPadding(),
        onDismissRequest = { if (!busy) onDismiss() },
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true, confirmValueChange = { !busy }),
        containerColor = palette.background,
        dragHandle = null,
    ) {
        Column(Modifier.fillMaxWidth().fillMaxHeight(0.95f).testTag("post-composer")) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.weight(1f)) {
                    TextButton(onClick = onDismiss, enabled = !busy) {
                        Text(if (submission == null) "Cancel" else "Done", color = palette.accent)
                    }
                }
                Text("New post", fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = palette.ink)
                Box(Modifier.weight(1f))
            }
            Column(
                Modifier.verticalScroll(rememberScrollState()).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                AndroidView(
                    factory = { PlayerView(it).apply { this.player = player } },
                    modifier = Modifier.height(360.dp).fillMaxWidth(0.55f).clip(RoundedCornerShape(14.dp)).background(Color.Black),
                )
                OutlinedTextField(
                    value = caption,
                    onValueChange = { caption = it.graphemePrefix(150) },
                    placeholder = { Text("Say something about it…") },
                    enabled = !locked,
                    minLines = 1, maxLines = 3,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = palette.ink, unfocusedTextColor = palette.ink, disabledTextColor = palette.muted,
                        cursorColor = palette.accent, focusedBorderColor = palette.accent, unfocusedBorderColor = palette.border,
                        focusedPlaceholderColor = palette.muted, unfocusedPlaceholderColor = palette.muted,
                    ),
                    modifier = Modifier.fillMaxWidth().testTag("post-caption"),
                )
                Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    draft.instrument?.let { Text("♪ $it", fontSize = 13.sp, color = palette.muted) }
                    val sound = draft.soundSetup
                    if (sound != null && sound.isValid) {
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            SwitchRow("Share playable preset", sharing.sharePlayablePreset, !locked, "post-share-preset") {
                                sharing = sharing.copy(sharePlayablePreset = it)
                            }
                            Text(if (sharing.sharePlayablePreset) sound.presetDetails else "Your instrument settings won't be shared.",
                                fontSize = 12.sp, color = palette.muted)
                        }
                    }
                    SwitchRow("Allow comments", commentsEnabled, !locked, "post-allow-comments") { commentsEnabled = it }
                    when {
                        credit != null -> Text("〰 Inspired by @${credit.username}", fontSize = 15.sp, color = palette.muted,
                            modifier = Modifier.testTag("post-credit"))
                        PostSharingOptions.canShareBacking(hasAudio == true, credit) -> {
                            SwitchRow("Allow others to play along", sharing.allowPlayAlong, !locked, "post-allow-play-along") {
                                sharing = sharing.copy(allowPlayAlong = it)
                            }
                            Text("When on, anyone can reuse this clip's audio, including any voice, as a credited backing loop.",
                                fontSize = 12.sp, color = palette.muted)
                        }
                        else -> Text(if (checkingAudio) "Checking for play-along audio…" else "Play-along audio isn't available for this take.",
                            fontSize = 12.sp, color = palette.muted)
                    }
                }
                UploadStatus(phase)
                Button(
                    onClick = {
                        if (userId == null || (submission == null && checkingAudio)) return@Button
                        controller.post(
                            draft, clip, caption,
                            soundSetup = sharing.sharedPreset(draft.soundSetup),
                            commentsEnabled = commentsEnabled,
                            backingEnabled = sharing.sharesBacking(hasAudio == true, credit),
                            onLeave = onDismiss,
                        )
                    },
                    enabled = !busy && userId != null && !(submission == null && checkingAudio) && !(submission != null && !submission.isPending),
                    colors = ButtonDefaults.buttonColors(containerColor = palette.accent, contentColor = palette.onAccent),
                    modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp).testTag("post-publicly"),
                ) {
                    Text(
                        when {
                            busy -> "Posting…"
                            submission == null -> "Post publicly"
                            submission.isPending -> "Check post status"
                            else -> "Posted"
                        },
                        fontWeight = FontWeight.SemiBold, fontSize = 17.sp,
                    )
                }
                Text("We check your video and thumbnail before they appear publicly.", fontSize = 12.sp, color = palette.muted)
            }
        }
    }
}

@Composable
private fun UploadStatus(phase: VideoUploader.Phase) {
    val palette = LocalStudioPalette.current
    val modifier = Modifier.fillMaxWidth().testTag("post-status")
    when (phase) {
        VideoUploader.Phase.Preparing -> Spinner("Preparing video…")
        is VideoUploader.Phase.Uploading -> Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("Uploading…", color = palette.ink)
            LinearProgressIndicator(progress = { phase.fraction.toFloat() }, modifier = Modifier.fillMaxWidth(), color = palette.accent)
        }
        VideoUploader.Phase.Checking -> Spinner("Submitting video…")
        is VideoUploader.Phase.Pending -> Text(phase.message, fontSize = 13.sp, color = palette.muted, modifier = modifier)
        is VideoUploader.Phase.Failed -> Text(phase.message, fontSize = 13.sp, color = Color.Red, modifier = modifier)
        else -> Unit
    }
}

@Composable
private fun Spinner(label: String) {
    val palette = LocalStudioPalette.current
    Row(Modifier.testTag("post-status"), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        CircularProgressIndicator(Modifier.height(18.dp), strokeWidth = 2.dp, color = palette.accent)
        Text(label, color = palette.muted)
    }
}

@Composable
private fun SwitchRow(label: String, checked: Boolean, enabled: Boolean, tag: String, onChange: (Boolean) -> Unit) {
    val palette = LocalStudioPalette.current
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, fontSize = 15.sp, color = palette.ink, modifier = Modifier.weight(1f))
        Switch(checked, onChange, enabled = enabled, modifier = Modifier.testTag(tag),
            colors = SwitchDefaults.colors(checkedTrackColor = palette.accent, checkedThumbColor = palette.onAccent))
    }
}
