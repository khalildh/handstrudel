package com.handstrudel.ui.capture

import com.handstrudel.ui.theme.StudioIcons
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.Movie
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.ui.theme.LocalStudioPalette
import java.text.DateFormat
import java.util.Date
import java.util.UUID

/**
 * iOS `RecordingDraftsView`: the private drafts list, or one draft's editor when
 * [openedDraftId] is set (the review right after a take, with Retake).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun DraftsSheetView(openedDraftId: UUID?, onRetake: (() -> Unit)?, onDismiss: () -> Unit) {
    val palette = LocalStudioPalette.current
    val controller = captureController()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var selected by rememberSaveable { mutableStateOf<String?>(null) }
    var editorBusy by remember { mutableStateOf(false) }
    val startToken = remember { controller?.ui?.value?.closeDraftsToken }
    val ui = controller?.ui?.collectAsState()
    LaunchedEffect(ui?.value?.closeDraftsToken) {
        if (startToken != null && ui?.value?.closeDraftsToken != startToken) onDismiss()
    }

    ModalBottomSheet(
        onDismissRequest = { if (!editorBusy) onDismiss() },
        sheetState = sheetState,
        containerColor = palette.background,
        dragHandle = null,
    ) {
        Column(Modifier.fillMaxWidth().fillMaxHeight().testTag("drafts-sheet")) {
            val editing = openedDraftId ?: selected?.let(UUID::fromString)
            Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.weight(1f)) {
                    if (openedDraftId == null && selected != null && !editorBusy) {
                        Row(
                            Modifier.clickable { selected = null }.padding(8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, null, tint = palette.accent)
                            Text("Drafts", color = palette.accent)
                        }
                    }
                }
                Text(
                    if (openedDraftId == null) "Private drafts" else "Review take",
                    fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = palette.ink,
                )
                Box(Modifier.weight(1f), contentAlignment = Alignment.CenterEnd) {
                    TextButton(onClick = onDismiss, enabled = !editorBusy, modifier = Modifier.testTag("drafts-done")) {
                        Text("Done", fontWeight = FontWeight.SemiBold, color = palette.accent)
                    }
                }
            }
            when {
                controller == null -> EmptyDrafts("Drafts aren't available yet.", "")
                editing != null -> DraftEditor(
                    controller = controller,
                    draftId = editing,
                    onRetake = onRetake,
                    onBusyChanged = { editorBusy = it },
                    onDeleted = { if (openedDraftId != null) onDismiss() else selected = null },
                )
                else -> DraftList(onOpen = { selected = it.toString() })
            }
        }
    }
}

@Composable
private fun DraftList(onOpen: (UUID) -> Unit) {
    val controller = captureController() ?: return
    val palette = LocalStudioPalette.current
    val drafts by controller.drafts.drafts.collectAsState()
    val loadError by controller.drafts.loadError.collectAsState()
    if (drafts.isEmpty()) {
        EmptyDrafts(
            if (loadError == null) "No drafts yet" else "Drafts couldn’t load",
            loadError ?: "Your recordings stay here until you delete them.",
        )
        return
    }
    val format = remember { DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT) }
    LazyColumn(Modifier.fillMaxSize().testTag("drafts-list")) {
        items(drafts, key = { it.id }) { draft ->
            Column(
                Modifier.fillMaxWidth().clickable { onOpen(draft.id) }.padding(horizontal = 20.dp, vertical = 12.dp)
                    .testTag("draft-row"),
                verticalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Text(draft.displayTitle, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = palette.ink, maxLines = 2)
                if (draft.title != null && draft.instrument != null) Text(draft.instrument, fontSize = 15.sp, color = palette.muted)
                Text(format.format(Date(draft.createdAt)), fontSize = 15.sp, color = palette.muted)
            }
            HorizontalDivider(color = palette.border)
        }
    }
}

@Composable
private fun EmptyDrafts(title: String, detail: String) {
    val palette = LocalStudioPalette.current
    Column(
        Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
    ) {
        Icon(StudioIcons.FilmStack, null, tint = palette.accent, modifier = Modifier.size(40.dp))
        Text(title, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = palette.ink, textAlign = TextAlign.Center)
        if (detail.isNotEmpty()) Text(detail, color = palette.muted, textAlign = TextAlign.Center)
    }
}
