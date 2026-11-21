package com.handstrudel.ui.capture

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Movie
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackParameters
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.handstrudel.capture.CaptureControllerImpl
import com.handstrudel.capture.drafts.DraftException
import com.handstrudel.capture.drafts.DraftExport
import com.handstrudel.capture.drafts.DraftError
import com.handstrudel.capture.drafts.DraftTrimSelection
import com.handstrudel.capture.drafts.DraftTrimSelection.Edge
import com.handstrudel.capture.drafts.MediaInfo
import com.handstrudel.capture.drafts.RecordingDraft
import com.handstrudel.capture.upload.DraftPostSubmission
import com.handstrudel.capture.upload.VideoUploader
import com.handstrudel.social.SocialEntryPoints
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale
import java.util.UUID

private const val FRAME_COUNT = 7

/** iOS `RecordingDraftEditor`. */
@Composable
internal fun DraftEditor(
    controller: CaptureControllerImpl,
    draftId: UUID,
    onRetake: (() -> Unit)?,
    onBusyChanged: (Boolean) -> Unit,
    onDeleted: () -> Unit,
) {
    val palette = LocalStudioPalette.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val share = rememberShareCopyLauncher()
    val drafts by controller.drafts.drafts.collectAsState()
    val draft = drafts.firstOrNull { it.id == draftId } ?: controller.drafts.draft(draftId)
    if (draft == null) {
        Text(DraftError.MISSING_DRAFT.message, color = palette.muted, modifier = Modifier.padding(20.dp))
        return
    }
    val userId by controller.auth.userId.collectAsState()
    val uploader = remember(draftId) { controller.uploader(draftId) }
    val uploadPhase by uploader.phase.collectAsState()
    val submission = userId?.let { draft.postSubmission(it) }

    var duration by remember { mutableStateOf(0.0) }
    val frames = remember { mutableStateMapOf<Int, Bitmap>() }
    var pendingTrim by remember { mutableStateOf<DraftTrimSelection?>(null) }
    var scrubPosition by remember { mutableStateOf<Double?>(null) }
    var message by remember { mutableStateOf<String?>(null) }
    var exportJob by remember { mutableStateOf<Job?>(null) }
    var showNameEditor by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    var posting by remember { mutableStateOf<DraftExport?>(null) }
    var pendingPost by remember { mutableStateOf<DraftExport?>(null) }
    var signIn by remember { mutableStateOf(false) }
    var playUntil by remember { mutableStateOf<Double?>(null) }
    var fineTrimExpanded by remember { mutableStateOf(false) }
    val busy = exportJob != null
    LaunchedEffect(busy) { onBusyChanged(busy) }

    val player = remember(draftId) {
        ExoPlayer.Builder(context).build().apply {
            setMediaItem(MediaItem.fromUri(Uri.fromFile(controller.drafts.videoFile(draftId))))
            if (draft.outputScale < 1) playbackParameters = PlaybackParameters((1 / draft.outputScale).toFloat())
            prepare()
        }
    }
    DisposableEffect(player) {
        onDispose {
            exportJob?.cancel()
            player.release()
        }
    }

    val savedTrim = DraftTrimSelection.of(duration, draft.trimStart, draft.trimEnd)
    val canExport = savedTrim != null && pendingTrim == null

    fun seek(time: Double) {
        playUntil = null
        scrubPosition = time
        player.pause()
        player.seekTo((time * 1000).toLong())
    }

    LaunchedEffect(draftId) {
        val info = withContext(Dispatchers.IO) { MediaInfo.read(controller.drafts.videoFile(draftId)) }
        if (info == null) { message = DraftError.UNREADABLE.message; return@LaunchedEffect }
        duration = info.durationSeconds
        val trim = DraftTrimSelection.of(info.durationSeconds, draft.trimStart, draft.trimEnd)
        if (trim != null) seek(trim.start) else { message = DraftError.INVALID_TRIM.message; seek(0.0) }
        withContext(Dispatchers.IO) {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(controller.drafts.videoFile(draftId).absolutePath)
                for (i in 0 until FRAME_COUNT) {
                    val atUs = (info.durationSeconds * (i + 0.5) / FRAME_COUNT * 1_000_000).toLong()
                    retriever.getScaledFrameAtTime(atUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, 152, 152)?.let { frames[i] = it }
                }
            } catch (_: Exception) {
            } finally {
                runCatching { retriever.release() }
            }
        }
    }
    // "Play selection": stop at the trim end (iOS forwardPlaybackEndTime).
    LaunchedEffect(playUntil) {
        val end = playUntil ?: return@LaunchedEffect
        while (true) {
            delay(30)
            val position = player.currentPosition / 1000.0
            scrubPosition = position
            if (position >= end || !player.isPlaying && player.playbackState == ExoPlayer.STATE_ENDED) {
                player.pause()
                playUntil = null
                return@LaunchedEffect
            }
        }
    }
    LaunchedEffect(userId) {
        val account = userId ?: return@LaunchedEffect
        if (controller.drafts.postSubmission(draftId, account)?.isPending != true || uploader.isBusy) return@LaunchedEffect
        refreshPostStatus(controller, uploader, draftId, account, waitForResult = false) { message = it }
    }

    fun editTrim(trim: DraftTrimSelection, seekTo: Double, commit: Boolean) {
        if (busy) return
        seek(seekTo)
        if (!commit) { pendingTrim = trim; return }
        pendingTrim = null
        val updated = draft.copy(
            trimStart = if (trim.isFullLength) null else trim.start,
            trimEnd = if (trim.isFullLength) null else trim.end,
        )
        if (updated == draft) return
        try {
            controller.drafts.saveTrim(updated)
            message = null
        } catch (e: Exception) {
            message = e.message
        }
    }

    fun export(audioOnly: Boolean = false, use: suspend (DraftExport) -> Unit) {
        if (busy || savedTrim == null || pendingTrim != null) return
        player.pause()
        playUntil = null
        message = null
        exportJob = scope.launch {
            try {
                val copy = DraftExport.make(context, controller.drafts, draft, audioOnly)
                use(copy)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                message = (e as? DraftException)?.message ?: DraftError.UNREADABLE.message
            } finally {
                exportJob = null
            }
        }
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp).testTag("draft-editor"),
        verticalArrangement = Arrangement.spacedBy(17.dp),
    ) {
        Column {
            Text(draft.displayTitle, fontSize = 22.sp, fontWeight = FontWeight.SemiBold, color = palette.ink)
            Row(
                Modifier.heightIn(min = 44.dp).clickable(enabled = !busy) { player.pause(); showNameEditor = true }
                    .testTag("rename-private-draft"),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(Icons.Filled.Edit, null, tint = palette.accent, modifier = Modifier.size(16.dp))
                Text(if (draft.title == null) "Name private draft" else "Rename private draft",
                    color = palette.accent, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
            }
        }
        AndroidView(
            factory = { PlayerView(it).apply { this.player = player; setShowNextButton(false); setShowPreviousButton(false) } },
            modifier = Modifier.fillMaxWidth().height(330.dp).clip(RoundedCornerShape(16.dp)).background(Color.Black).testTag("draft-player"),
        )
        if (draft.recordedAtHalfSpeed == true) {
            Text("🐢 Recorded at half tempo. Preview and exports play at normal tempo.", fontSize = 13.sp, color = palette.muted)
        }
        message?.let { Text(it, fontSize = 13.sp, color = palette.muted, modifier = Modifier.testTag("draft-message")) }
        if (busy) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp, color = palette.accent)
            Text("Preparing video", color = palette.muted)
        }
        if (controller.canPost) {
            PostAction(
                submission = submission,
                checking = uploader.isBusy && uploadPhase != VideoUploader.Phase.Idle,
                canExport = canExport && !busy,
                onCheck = {
                    val account = userId ?: return@PostAction
                    scope.launch { refreshPostStatus(controller, uploader, draftId, account, waitForResult = true) { message = it } }
                },
                onView = { id -> controller.viewPost(id) },
                onPost = {
                    export { copy ->
                        if (controller.isSignedInForPosting) posting = copy else { pendingPost = copy; signIn = true }
                    }
                },
            )
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedButton(
                enabled = canExport && !busy,
                onClick = {
                    export { copy ->
                        try {
                            DraftExport.saveToGallery(context, copy)
                            message = "Saved to Gallery."
                            controller.recordSuccessfulTake(draft.id)
                        } finally {
                            copy.remove()
                        }
                    }
                },
                modifier = Modifier.testTag("draft-save-gallery"),
            ) { Text("Save to Gallery", color = palette.accent) }
            Box {
                var menu by remember { mutableStateOf(false) }
                OutlinedButton(enabled = canExport && !busy, onClick = { menu = true }, modifier = Modifier.testTag("draft-share")) {
                    Icon(Icons.Filled.Share, null, tint = palette.accent, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Share", color = palette.accent)
                }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(text = { Text("Share video") }, onClick = {
                        menu = false
                        export { share.share(it.file, it.mimeType) }
                    }, modifier = Modifier.testTag("draft-share-video"))
                    DropdownMenuItem(text = { Text("Share audio (M4A)") }, onClick = {
                        menu = false
                        export(audioOnly = true) { share.share(it.file, it.mimeType) }
                    }, modifier = Modifier.testTag("draft-share-audio"))
                }
            }
            Spacer(Modifier.weight(1f))
            if (onRetake != null) TextButton(onClick = onRetake, enabled = !busy) { Text("Retake", color = palette.accent) }
        }
        val trim = pendingTrim ?: savedTrim ?: DraftTrimSelection.of(duration)
        if (trim != null) {
            TrimControls(
                trim = trim, savedTrim = savedTrim, outputScale = draft.outputScale, frames = frames,
                scrubPosition = scrubPosition, busy = busy, fineTrimExpanded = fineTrimExpanded,
                onToggleFineTrim = { fineTrimExpanded = !fineTrimExpanded },
                onScrub = { if (!busy) seek(it) },
                onEdit = ::editTrim,
                onReset = { DraftTrimSelection.of(duration)?.let { editTrim(it, 0.0, true) } },
                onPlaySelection = {
                    seek(trim.start)
                    player.play()
                    playUntil = trim.end
                },
            )
        }
        TextButton(onClick = { confirmDelete = true }, enabled = !busy, modifier = Modifier.padding(top = 6.dp).testTag("draft-delete")) {
            Text("Delete draft", color = palette.recording)
        }
    }

    if (showNameEditor) {
        DraftNameEditor(initial = draft.title ?: "", onDismiss = { showNameEditor = false }) { name ->
            controller.drafts.rename(draft.id, name)
        }
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete this private draft?") },
            text = { Text("Copies you’ve already saved or shared will stay where you put them.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    try {
                        controller.drafts.delete(draft)
                        onDeleted()
                    } catch (e: Exception) {
                        message = e.message
                    }
                }, modifier = Modifier.testTag("draft-delete-confirm")) { Text("Delete draft", color = palette.recording) }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Cancel") } },
        )
    }
    if (signIn) {
        SocialEntryPoints.SignInSheet(onDismiss = {
            signIn = false
            val copy = pendingPost
            pendingPost = null
            if (copy != null) {
                if (controller.isSignedInForPosting) posting = copy else copy.remove()
            }
        })
    }
    posting?.let { copy ->
        PostComposerSheet(
            controller = controller,
            draft = draft,
            clip = copy,
            onDismiss = {
                posting = null
                copy.remove()
            },
        )
    }
}

private suspend fun refreshPostStatus(
    controller: CaptureControllerImpl,
    uploader: VideoUploader,
    draftId: UUID,
    accountId: UUID,
    waitForResult: Boolean,
    onMessage: (String) -> Unit,
) {
    val posted = uploader.resume(draftId, accountId, controller.drafts, waitForResult)
    if (controller.auth.userId.value != accountId) return
    if (posted) {
        onMessage("Posted. The original is still in Private drafts.")
        controller.recordSuccessfulTake(draftId)
    } else when (val phase = uploader.phase.value) {
        is VideoUploader.Phase.Failed -> onMessage(phase.message)
        is VideoUploader.Phase.Pending ->
            if (controller.drafts.postSubmission(draftId, accountId)?.isPending == true) onMessage(phase.message)
        else -> Unit
    }
}

@Composable
private fun PostAction(
    submission: DraftPostSubmission?,
    checking: Boolean,
    canExport: Boolean,
    onCheck: () -> Unit,
    onView: (UUID) -> Unit,
    onPost: () -> Unit,
) {
    val palette = LocalStudioPalette.current
    val colors = ButtonDefaults.buttonColors(containerColor = palette.accent, contentColor = palette.onAccent)
    val modifier = Modifier.fillMaxWidth().heightIn(min = 50.dp).testTag("draft-post-action")
    when (submission) {
        is DraftPostSubmission.Pending ->
            Button(onClick = onCheck, enabled = !checking, colors = colors, modifier = modifier) {
                Text(if (checking) "Checking post…" else "Check post status", fontWeight = FontWeight.SemiBold)
            }
        is DraftPostSubmission.Published ->
            Button(onClick = { onView(submission.id) }, colors = colors, modifier = modifier) {
                Icon(Icons.Filled.PlayArrow, null)
                Spacer(Modifier.width(6.dp))
                Text("View post", fontWeight = FontWeight.SemiBold)
            }
        null ->
            Button(onClick = onPost, enabled = canExport, colors = colors, modifier = modifier) {
                Text("Post to HandStrudel", fontWeight = FontWeight.SemiBold)
            }
    }
}

@Composable
private fun TrimControls(
    trim: DraftTrimSelection,
    savedTrim: DraftTrimSelection?,
    outputScale: Double,
    frames: Map<Int, Bitmap>,
    scrubPosition: Double?,
    busy: Boolean,
    fineTrimExpanded: Boolean,
    onToggleFineTrim: () -> Unit,
    onScrub: (Double) -> Unit,
    onEdit: (DraftTrimSelection, Double, Boolean) -> Unit,
    onReset: () -> Unit,
    onPlaySelection: () -> Unit,
) {
    val palette = LocalStudioPalette.current
    fun label(captured: Double) = String.format(Locale.US, "%.2f s", captured * outputScale)
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Trim", fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = palette.ink, modifier = Modifier.weight(1f))
            TextButton(onClick = onReset, enabled = !busy && !(trim.isFullLength && savedTrim != null),
                modifier = Modifier.testTag("draft-trim-reset")) { Text("Reset", color = palette.accent) }
        }
        Text("Drag the handles to trim. Tap a frame to preview it.", fontSize = 12.sp, color = palette.muted)
        DraftTrimFilmstrip(trim, frames, scrubPosition, outputScale, onScrub, onEdit)
        Row {
            Text("${label(trim.start)} to ${label(trim.end)}", fontSize = 12.sp, color = palette.muted,
                modifier = Modifier.weight(1f).testTag("draft-trim-range"))
            Text("${label(trim.end - trim.start)} selected", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = palette.ink)
        }
        OutlinedButton(onClick = onPlaySelection, enabled = !busy, modifier = Modifier.testTag("draft-play-selection")) {
            Icon(Icons.Filled.PlayArrow, null, tint = palette.accent, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text("Play selection", color = palette.accent)
        }
        Row(
            Modifier.fillMaxWidth().clickable(onClick = onToggleFineTrim).padding(vertical = 6.dp).testTag("draft-fine-trim"),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Fine trim", fontSize = 15.sp, color = palette.ink, modifier = Modifier.weight(1f))
            Text(if (fineTrimExpanded) "▾" else "▸", color = palette.accent)
        }
        if (fineTrimExpanded) {
            Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                TrimNudges(trim, Edge.START, outputScale, busy, onEdit)
                TrimNudges(trim, Edge.END, outputScale, busy, onEdit)
            }
        }
    }
}

@Composable
private fun TrimNudges(trim: DraftTrimSelection, edge: Edge, outputScale: Double, busy: Boolean, onEdit: (DraftTrimSelection, Double, Boolean) -> Unit) {
    val palette = LocalStudioPalette.current
    val name = if (edge == Edge.START) "Start" else "End"
    val position = if (edge == Edge.START) trim.start else trim.end
    val step = 0.1 / outputScale
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(name, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = palette.ink, modifier = Modifier.weight(1f))
        listOf(-1, 1).forEach { direction ->
            val next = trim.moving(edge, position + direction * step)
            OutlinedButton(
                onClick = { onEdit(next, if (edge == Edge.START) next.start else next.end, true) },
                enabled = !busy && next != trim,
                modifier = Modifier.padding(start = 6.dp).semantics {
                    contentDescription = "$name 0.1 seconds ${if (direction < 0) "earlier" else "later"}"
                },
            ) { Icon(if (direction < 0) Icons.Filled.Remove else Icons.Filled.Add, null, tint = palette.accent) }
        }
    }
}

/** iOS `DraftTrimFilmstrip`: 7 frames, a dimmed outside, an accent selection and two drag handles. */
@Composable
private fun DraftTrimFilmstrip(
    trim: DraftTrimSelection,
    frames: Map<Int, Bitmap>,
    scrubPosition: Double?,
    outputScale: Double,
    onScrub: (Double) -> Unit,
    onEdit: (DraftTrimSelection, Double, Boolean) -> Unit,
) {
    val palette = LocalStudioPalette.current
    val density = LocalDensity.current
    BoxWithConstraints(Modifier.fillMaxWidth().height(65.dp).testTag("draft-filmstrip")) {
        val gutter = minOf(22.dp, maxWidth / 4)
        val width = maxOf(1.dp, maxWidth - gutter * 2)
        val widthPx = with(density) { width.toPx() }
        val startX = gutter + width * (trim.start / trim.duration).toFloat()
        val endX = gutter + width * (trim.end / trim.duration).toFloat()
        Row(
            Modifier.offset(x = gutter).width(width).fillMaxHeight().clip(RoundedCornerShape(6.dp))
                .pointerScrub { x -> onScrub(trim.duration * (x / widthPx).coerceIn(0f, 1f)) },
        ) {
            for (i in 0 until FRAME_COUNT) {
                Box(
                    Modifier.weight(1f).fillMaxHeight().background(palette.muted.copy(alpha = 0.19f)),
                    contentAlignment = Alignment.Center,
                ) {
                    val frame = frames[i]
                    if (frame != null) Image(frame.asImageBitmap(), null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                    else Icon(Icons.Filled.Movie, null, tint = palette.muted, modifier = Modifier.size(14.dp))
                }
            }
        }
        // Selection overlay.
        Box(Modifier.offset(x = gutter).width(maxOf(0.dp, startX - gutter)).fillMaxHeight().background(Color.Black.copy(alpha = 0.63f)))
        Box(Modifier.offset(x = endX).width(maxOf(0.dp, gutter + width - endX)).fillMaxHeight().background(Color.Black.copy(alpha = 0.63f)))
        Box(Modifier.offset(x = startX).width(maxOf(1.dp, endX - startX)).fillMaxHeight()
            .border(2.5.dp, palette.accent, RoundedCornerShape(5.dp)))
        scrubPosition?.let { position ->
            val x = gutter + width * (position / trim.duration).coerceIn(0.0, 1.0).toFloat() - 1.dp
            Box(Modifier.offset(x = x, y = 4.dp).width(2.dp).height(57.dp).shadow(2.dp).background(Color.White))
        }
        TrimHandle(Edge.START, trim, startX - 9.dp - 13.dp, widthPx, outputScale, onEdit)
        TrimHandle(Edge.END, trim, endX + 9.dp + 13.dp, widthPx, outputScale, onEdit)
    }
}

@Composable
private fun TrimHandle(
    edge: Edge,
    trim: DraftTrimSelection,
    center: androidx.compose.ui.unit.Dp,
    widthPx: Float,
    outputScale: Double,
    onEdit: (DraftTrimSelection, Double, Boolean) -> Unit,
) {
    val palette = LocalStudioPalette.current
    val isStart = edge == Edge.START
    val value = if (isStart) trim.start else trim.end
    var origin by remember { mutableStateOf<DraftTrimSelection?>(null) }
    var dragX by remember { mutableStateOf(0f) }
    val latestTrim by androidx.compose.runtime.rememberUpdatedState(trim)
    val latestOnEdit by androidx.compose.runtime.rememberUpdatedState(onEdit)
    Box(
        Modifier.offset(x = center - 22.dp).width(44.dp).fillMaxHeight()
            .semantics {
                contentDescription = if (isStart) "Trim start" else "Trim end"
                stateDescription = String.format(Locale.US, "%.2f seconds", value * outputScale)
            }
            .testTag(if (isStart) "draft-trim-start" else "draft-trim-end")
            .pointerInputDrag(
                onStart = { origin = latestTrim; dragX = 0f },
                onDrag = { dx ->
                    dragX += dx
                    val o = origin ?: latestTrim
                    val base = if (isStart) o.start else o.end
                    val next = o.moving(edge, base + o.duration * dragX / widthPx)
                    latestOnEdit(next, if (isStart) next.start else next.end, false)
                },
                onEnd = {
                    val o = origin ?: latestTrim
                    val base = if (isStart) o.start else o.end
                    val next = o.moving(edge, base + o.duration * dragX / widthPx)
                    latestOnEdit(next, if (isStart) next.start else next.end, true)
                    origin = null
                },
            ),
        contentAlignment = if (isStart) Alignment.CenterEnd else Alignment.CenterStart,
    ) {
        Box(
            Modifier.width(18.dp).fillMaxHeight().clip(RoundedCornerShape(6.dp)).background(palette.accent),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                if (isStart) Icons.AutoMirrored.Filled.KeyboardArrowLeft else Icons.AutoMirrored.Filled.KeyboardArrowRight,
                null, tint = palette.onAccent, modifier = Modifier.size(16.dp),
            )
        }
    }
}

private fun Modifier.pointerScrub(onScrub: (Float) -> Unit): Modifier = this
    .pointerInput(Unit) { detectTapGestures { onScrub(it.x) } }
    .pointerInput("drag") { detectDragGestures { change, _ -> onScrub(change.position.x) } }

private fun Modifier.pointerInputDrag(onStart: () -> Unit, onDrag: (Float) -> Unit, onEnd: () -> Unit): Modifier =
    pointerInput(Unit) {
        detectDragGestures(
            onDragStart = { onStart() },
            onDragEnd = onEnd,
            onDragCancel = onEnd,
        ) { change, amount ->
            change.consume()
            onDrag(amount.x)
        }
    }

/** iOS `PrivateDraftNameEditor`. */
@Composable
private fun DraftNameEditor(initial: String, onDismiss: () -> Unit, onSave: (String) -> Unit) {
    var name by remember { mutableStateOf(initial) }
    var error by remember { mutableStateOf<String?>(null) }
    fun save() {
        try {
            onSave(name)
            onDismiss()
        } catch (e: Exception) {
            error = e.message
        }
    }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Private draft name") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(name, { name = it }, label = { Text("Draft name") }, singleLine = true,
                    modifier = Modifier.testTag("private-draft-name"))
                error?.let { Text(it, color = Color.Red) }
                Text("This name stays on this device and isn't shared or posted. Leave it blank to remove it. " +
                    "Only the first ${RecordingDraft.TITLE_LIMIT} characters are saved.", fontSize = 12.sp)
            }
        },
        confirmButton = { TextButton(onClick = ::save, modifier = Modifier.testTag("private-draft-name-save")) { Text("Save") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}
