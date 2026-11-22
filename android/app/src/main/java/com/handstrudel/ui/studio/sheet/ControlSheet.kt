package com.handstrudel.ui.studio.sheet

import androidx.compose.foundation.layout.statusBarsPadding
import com.handstrudel.ui.studio.common.SheetGrabber
import com.handstrudel.ui.theme.StudioFonts
import com.handstrudel.ui.studio.common.isAccessibilityTextSize
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material.icons.outlined.ShoppingBag
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.ui.store.StoreScreen
import com.handstrudel.ui.studio.common.rememberPaywallHost
import com.handstrudel.ui.studio.common.studioContentWidth
import com.handstrudel.ui.studio.presets.SoundSetupsSheet
import com.handstrudel.ui.theme.LocalStudioPalette

/** iOS `ControlSheet.SettingsSection`. */
internal enum class SettingsSection(val title: String, val icon: ImageVector) {
    SOUND("Sound", Icons.Filled.GraphicEq),
    PLAY("Play", Icons.Filled.TouchApp),
    MIX("Mix", Icons.Filled.Tune),
    CAPTURE("Capture", Icons.Filled.Videocam);

    val tag: String get() = "music-settings-${name.lowercase()}"
}

/**
 * The in-session control sheet (iOS `ControlSheet` in `App/ControlSheetView.swift`):
 * "Music settings" header with Store and Done, then four tabs (Sound / Play /
 * Mix / Capture). The Stage shows it and pauses/resumes the engine around it.
 * Choosing Learn with no song loaded calls [onOpenLearnPicker]; the Stage hosts
 * `LearnSongPicker`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ControlSheet(onDismiss: () -> Unit, onOpenLearnPicker: () -> Unit) {
    val services = LocalAppServices.current
    val engine = services.engine
    val palette = LocalStudioPalette.current
    val paywall = rememberPaywallHost()
    // Recompose locks when entitlements change.
    services.store.state.collectAsState().value

    var section by rememberSaveable { mutableStateOf(SettingsSection.SOUND) }
    var showStore by remember { mutableStateOf(false) }
    var showSetups by remember { mutableStateOf(false) }
    var setupError by remember { mutableStateOf<String?>(null) }

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        modifier = Modifier.statusBarsPadding(),
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = palette.background,
        contentColor = palette.ink,
        dragHandle = { SheetGrabber() },
    ) {
        Column(Modifier.fillMaxWidth().fillMaxHeight().navigationBarsPadding()) {
            SettingsHeader(
                section = section,
                onSection = { section = it },
                onStore = { showStore = true },
                onDone = onDismiss,
            )
            key(section) {
                Column(
                    Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState()).testTag("music-settings-scroll"),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Column(
                        Modifier.studioContentWidth().padding(start = 18.dp, end = 18.dp, top = 15.dp, bottom = 28.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        when (section) {
                            SettingsSection.SOUND -> SoundTab(paywall, onOpenPresets = { showSetups = true })
                            SettingsSection.PLAY -> PlayTab(onOpenLearnPicker)
                            SettingsSection.MIX -> MixTab(paywall)
                            SettingsSection.CAPTURE -> CaptureTab(paywall)
                        }
                    }
                }
            }
        }
    }

    if (showStore) StoreScreen(onDismiss = { showStore = false })
    if (showSetups) {
        SoundSetupsSheet(
            onApply = { setup ->
                // iOS: `engine.applySoundSetup(setup, store:)`, then close the presets sheet.
                if (!engine.applySoundSetup(setup, services.store)) {
                    setupError = "This setup is unavailable or requires a sound pack you don't own."
                }
                showSetups = false
            },
            onDismiss = { showSetups = false },
        )
    }
    setupError?.let { message ->
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { setupError = null },
            confirmButton = { androidx.compose.material3.TextButton(onClick = { setupError = null }) { Text("OK") } },
            title = { Text("Presets") },
            text = { Text(message) },
        )
    }
}

@Composable
private fun SettingsHeader(
    section: SettingsSection,
    onSection: (SettingsSection) -> Unit,
    onStore: () -> Unit,
    onDone: () -> Unit,
) {
    val palette = LocalStudioPalette.current
    Column(Modifier.fillMaxWidth().background(palette.background), horizontalAlignment = Alignment.CenterHorizontally) {
        Column(
            Modifier.studioContentWidth().padding(start = 20.dp, end = 20.dp, top = 11.dp, bottom = 10.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "Music settings",
                    fontFamily = StudioFonts.Serif,
                    fontSize = 28.sp,
                    color = palette.ink,
                    modifier = Modifier.semantics { heading() },
                )
                Spacer(Modifier.weight(1f).widthIn(min = 4.dp))
                // No RevenueCat key in this build: nothing to sell, so no Store entry.
                if (com.handstrudel.app.LocalAppServices.current.store.isConfigured) Box(
                    Modifier.size(44.dp).clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button, onClick = onStore)
                        .semantics { contentDescription = "Store" }.testTag("music-settings-store"),
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Outlined.ShoppingBag, null, tint = palette.accent) }
                Box(
                    Modifier.heightIn(min = 44.dp).widthIn(min = 44.dp).clip(RoundedCornerShape(10.dp))
                        .clickable(role = Role.Button, onClick = onDone).testTag("music-settings-done"),
                    contentAlignment = Alignment.Center,
                ) { Text("Done", fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = palette.accent) }
            }
            SettingsTabs(section, onSection)
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(palette.ink.copy(alpha = 0.06f)))
    }
}

@Composable
private fun SettingsTabs(section: SettingsSection, onSection: (SettingsSection) -> Unit) {
    val palette = LocalStudioPalette.current
    val shape = RoundedCornerShape(16.dp)
    val box = Modifier.fillMaxWidth().clip(shape).background(palette.surface).border(1.dp, palette.border, shape).padding(4.dp)
    @Composable
    fun tabButton(tab: SettingsSection, modifier: Modifier) {
        val selected = tab == section
        Column(
            modifier.heightIn(min = 46.dp).clip(RoundedCornerShape(12.dp))
                .background(if (selected) palette.accent else androidx.compose.ui.graphics.Color.Transparent)
                .clickable(role = Role.Tab) { onSection(tab) }
                .semantics { this.selected = selected }
                .testTag(tab.tag)
                .padding(vertical = 6.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically),
        ) {
            val tint = if (selected) palette.onAccent else palette.muted
            Icon(tab.icon, null, tint = tint, modifier = Modifier.size(18.dp))
            Text(tab.title, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = tint)
        }
    }
    // iOS stacks the tabs vertically at accessibility text sizes.
    if (isAccessibilityTextSize()) {
        Column(box, verticalArrangement = Arrangement.spacedBy(3.dp)) {
            SettingsSection.entries.forEach { tabButton(it, Modifier.fillMaxWidth()) }
        }
    } else {
        Row(box, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            SettingsSection.entries.forEach { tabButton(it, Modifier.weight(1f)) }
        }
    }
}
