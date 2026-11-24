package com.handstrudel.ui.studio.presets

import androidx.compose.foundation.layout.statusBarsPadding
import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.FileUpload
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.engine.PresetPackException
import com.handstrudel.models.NamedSoundSetup
import com.handstrudel.models.SoundSetup
import com.handstrudel.ui.studio.common.SheetTextButton
import com.handstrudel.ui.studio.sheet.ControlSheetLogic
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

/** iOS `SoundPresetPack` size limit; anything bigger is refused by the codec anyway. */
private const val MAX_PACK_BYTES = 256 * 1024

private const val UNAVAILABLE = "This setup is unavailable or requires a sound pack you don't own."

/**
 * iOS `SoundSetupsView` (+ `SoundPresetFile`): save the current sound as a named
 * preset, apply, delete, and import / export a `.json` preset pack through the
 * system file picker. [onApply] receives an unlocked, valid setup; the host
 * applies it (and closes this sheet).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SoundSetupsSheet(onApply: (SoundSetup) -> Unit, onDismiss: () -> Unit) {
    val services = LocalAppServices.current
    val engine = services.engine
    val store = services.store
    val palette = LocalStudioPalette.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    store.state.collectAsState().value
    val setups by engine.presets.collectAsState()
    val current = remember { engine.soundSetupForSaving }

    var name by remember { mutableStateOf("") }
    var message by remember { mutableStateOf<String?>(null) }
    var transferMenu by remember { mutableStateOf(false) }
    var pendingImport by remember { mutableStateOf<PendingImport?>(null) }
    var pendingExport by remember { mutableStateOf<ByteArray?>(null) }

    fun errorText(error: Throwable): String = (error as? PresetPackException)?.message
        ?: error.localizedMessage ?: "This isn't a compatible HandStrudel preset file."

    fun importNow(bytes: ByteArray, total: Int?) {
        engine.importPresetPack(bytes)
            .onSuccess { count -> message = ControlSheetLogic.importResultMessage(count, total ?: count) }
            .onFailure { message = errorText(it) }
    }

    val importer = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            val bytes = runCatching { withContext(Dispatchers.IO) { readCapped(context, uri) } }
                .getOrElse { message = errorText(it); return@launch }
            // iOS validates the pack and confirms the count before importing.
            engine.previewPresetPack(bytes)
                .onSuccess { presets -> pendingImport = PendingImport(bytes, presets.size) }
                .onFailure { message = errorText(it) }
        }
    }
    val exporter = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        val bytes = pendingExport
        pendingExport = null
        if (uri == null || bytes == null) return@rememberLauncherForActivityResult
        scope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    context.contentResolver.openOutputStream(uri, "wt")?.use { it.write(bytes) }
                        ?: error("Couldn't save the preset file.")
                }
            }.onFailure { message = it.localizedMessage ?: "Couldn't save the preset file." }
        }
    }

    fun export(ids: List<UUID>) {
        engine.exportPresetPack(ids)
            .onSuccess { bytes ->
                pendingExport = bytes
                exporter.launch("HandStrudel Presets.json")
            }
            .onFailure { message = errorText(it) }
    }

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        modifier = Modifier.statusBarsPadding(),
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = palette.background,
        contentColor = palette.ink,
        dragHandle = null,
    ) {
        Column(Modifier.fillMaxWidth().fillMaxHeight().navigationBarsPadding()) {
            // Title bar: Done · Presets · transfer menu (iOS toolbar).
            Box(Modifier.fillMaxWidth().height(52.dp).padding(horizontal = 8.dp)) {
                SheetTextButton("Done", Modifier.align(Alignment.CenterStart), onClick = onDismiss)
                Text("Presets", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = palette.ink, modifier = Modifier.align(Alignment.Center))
                Box(Modifier.align(Alignment.CenterEnd)) {
                    Box(
                        Modifier.size(44.dp).clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { transferMenu = true }
                            .semantics {
                                contentDescription = "Move or back up presets. Preset files carry settings, not recordings or purchased sound packs."
                            }
                            .testTag("preset-transfer"),
                        contentAlignment = Alignment.Center,
                    ) { Icon(com.handstrudel.ui.theme.StudioIcons.ArrowUpArrowDown, null, tint = palette.accent, modifier = Modifier.size(26.dp)) }
                    DropdownMenu(expanded = transferMenu, onDismissRequest = { transferMenu = false }) {
                        DropdownMenuItem(
                            text = { Text("Import preset file") },
                            leadingIcon = { Icon(Icons.Filled.FileDownload, null) },
                            onClick = { transferMenu = false; importer.launch(arrayOf("application/json")) },
                            modifier = Modifier.testTag("preset-import"),
                        )
                        DropdownMenuItem(
                            text = { Text("Export all presets") },
                            leadingIcon = { Icon(Icons.Filled.FileUpload, null) },
                            enabled = setups.isNotEmpty(),
                            onClick = { transferMenu = false; export(setups.map { it.id }) },
                            modifier = Modifier.testTag("preset-export"),
                        )
                    }
                }
            }

            LazyColumn(Modifier.fillMaxWidth().weight(1f), contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 24.dp)) {
                if (current != null && current.isValid) {
                    item { ListSectionTitle("Current sound") }
                    item {
                        ListGroup {
                            // iOS `Form { TextField("Preset name") }`: a borderless 17 pt field in
                            // the row, placeholder in the tertiary label colour, inset divider below.
                            androidx.compose.foundation.text.BasicTextField(
                                value = name,
                                onValueChange = { name = it },
                                singleLine = true,
                                textStyle = androidx.compose.ui.text.TextStyle(fontSize = 17.sp, color = palette.ink),
                                cursorBrush = androidx.compose.ui.graphics.SolidColor(palette.accent),
                                modifier = Modifier.fillMaxWidth().heightIn(min = 44.dp).testTag("preset-name"),
                                decorationBox = { inner ->
                                    Box(Modifier.fillMaxWidth().heightIn(min = 44.dp).padding(horizontal = 20.dp), contentAlignment = Alignment.CenterStart) {
                                        if (name.isEmpty()) Text("Preset name", fontSize = 17.sp, color = palette.muted.copy(alpha = 0.6f))
                                        inner()
                                    }
                                },
                            )
                            Box(Modifier.padding(start = 20.dp).fillMaxWidth().height(0.5.dp).background(palette.border))
                            val canSave = ControlSheetLogic.canSavePreset(name, current, setups)
                            ListRow(enabled = canSave, modifier = Modifier.testTag("preset-save"), onClick = {
                                // iOS ignores a rejected save (duplicate / invalid) silently.
                                if (engine.addPreset(current, ControlSheetLogic.cleanPresetName(name))) name = ""
                            }) {
                                Text("Save current preset", fontSize = 17.sp, color = if (canSave) palette.accent else palette.muted.copy(alpha = 0.6f))
                            }
                        }
                    }
                }
                item { ListSectionTitle("Saved on this device") }
                item {
                    ListGroup {
                        if (setups.isEmpty()) {
                            Text(
                                "Save a sound from the studio or from a performance in the feed.",
                                fontSize = 17.sp, color = palette.muted, modifier = Modifier.padding(horizontal = 20.dp, vertical = 11.dp),
                            )
                        }
                        setups.forEach { setup ->
                            PresetRow(
                                setup = setup,
                                locked = !setup.sound.requiredPacks.all { store.isUnlocked(it) },
                                onUse = { locked ->
                                    if (locked) message = UNAVAILABLE else onApply(setup.sound)
                                },
                                onExport = { export(listOf(setup.id)) },
                                onDelete = { engine.deletePreset(setup.id) },
                            )
                        }
                    }
                }
            }
        }
    }

    pendingImport?.let { pending ->
        AlertDialog(
            onDismissRequest = { pendingImport = null },
            title = { Text("Import HandStrudel presets?") },
            text = { Text("This file contains ${pending.count} presets. Existing presets won't be replaced.") },
            confirmButton = {
                TextButton(onClick = { pendingImport = null; importNow(pending.bytes, pending.count) }, modifier = Modifier.testTag("preset-import-confirm")) {
                    Text("Import presets")
                }
            },
            dismissButton = { TextButton(onClick = { pendingImport = null }) { Text("Cancel") } },
        )
    }
    message?.let { text ->
        AlertDialog(
            onDismissRequest = { message = null },
            title = { Text("Presets") },
            text = { Text(text) },
            confirmButton = { TextButton(onClick = { message = null }) { Text("OK") } },
        )
    }
}

private class PendingImport(val bytes: ByteArray, val count: Int)

@Composable
private fun PresetRow(
    setup: NamedSoundSetup,
    locked: Boolean,
    onUse: (locked: Boolean) -> Unit,
    onExport: () -> Unit,
    onDelete: () -> Unit,
) {
    val palette = LocalStudioPalette.current
    val valid = setup.sound.isValid
    var menu by remember { mutableStateOf(false) }
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).testTag("preset-row"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            Modifier.weight(1f).heightIn(min = 56.dp).clickable(enabled = valid, role = Role.Button) { onUse(locked) }
                .alpha(if (locked || !valid) 0.5f else 1f).padding(start = 20.dp, top = 8.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(setup.name, fontSize = 17.sp, color = palette.ink)
                Text(ControlSheetLogic.presetSubtitle(setup.sound), fontSize = 12.sp, color = palette.muted)
            }
            if (locked) {
                Icon(
                    Icons.Outlined.Lock, "Requires a sound pack", tint = palette.muted,
                    modifier = Modifier.padding(start = 8.dp).size(18.dp),
                )
            }
        }
        Box {
            Box(
                Modifier.size(44.dp).clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { menu = true }
                    .semantics { contentDescription = "Actions for ${setup.name}" },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Filled.MoreVert, null, tint = palette.muted) }
            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                DropdownMenuItem(
                    text = { Text("Export this preset") },
                    leadingIcon = { Icon(Icons.Filled.FileUpload, null) },
                    enabled = valid,
                    onClick = { menu = false; onExport() },
                )
                DropdownMenuItem(
                    text = { Text("Delete") },
                    leadingIcon = { Icon(Icons.Filled.Delete, null) },
                    onClick = { menu = false; onDelete() },
                )
            }
        }
    }
}

@Composable
private fun ListSectionTitle(title: String) {
    val palette = LocalStudioPalette.current
    Text(
        title.uppercase(), fontSize = 13.sp, color = palette.muted,
        // iOS inset-grouped section header: 20 pt card inset + 20 pt text inset.
        modifier = Modifier.padding(start = 40.dp, end = 40.dp, top = 24.dp, bottom = 7.dp),
    )
}

@Composable
private fun ListGroup(content: @Composable () -> Unit) {
    val palette = LocalStudioPalette.current
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp).clip(RoundedCornerShape(10.dp)).background(palette.surface),
    ) { content() }
}

@Composable
private fun ListRow(enabled: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit, content: @Composable () -> Unit) {
    Row(
        modifier.fillMaxWidth().heightIn(min = 44.dp).clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .padding(horizontal = 20.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        content()
        Spacer(Modifier.weight(1f).widthIn(min = 0.dp))
    }
}

/** Reads at most [MAX_PACK_BYTES] + 1 bytes, so an oversized file still fails the codec's size check without loading it all. */
private fun readCapped(context: Context, uri: Uri): ByteArray {
    val input = context.contentResolver.openInputStream(uri) ?: error("This isn't a compatible HandStrudel preset file.")
    return input.use { stream ->
        val out = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        var total = 0
        while (total <= MAX_PACK_BYTES) {
            val n = stream.read(buffer)
            if (n < 0) break
            out.write(buffer, 0, n)
            total += n
        }
        out.toByteArray()
    }
}
