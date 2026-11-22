package com.handstrudel.ui.studio.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.QueueMusic
import androidx.compose.material.icons.filled.ArrowOutward
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Piano
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.outlined.Layers
import androidx.compose.material.icons.outlined.Movie
import androidx.compose.material.icons.outlined.Palette
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.semantics.stateDescription
import kotlin.math.roundToInt
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.handstrudel.app.LocalAppServices
import com.handstrudel.models.SOUNDFONT_INSTRUMENTS
import com.handstrudel.ui.capture.CaptureEntryPoints
import com.handstrudel.ui.nav.LocalAppNavigator
import com.handstrudel.ui.studio.common.StudioActionButton
import com.handstrudel.ui.studio.common.StudioMusic
import com.handstrudel.ui.studio.common.StudioSettingRow
import com.handstrudel.ui.studio.common.StudioSettingsDivider
import com.handstrudel.ui.studio.common.StudioSettingsPanel
import com.handstrudel.ui.studio.common.StudioSheet
import com.handstrudel.ui.studio.common.isAccessibilityTextSize
import com.handstrudel.ui.studio.common.studioContentWidth
import com.handstrudel.ui.studio.pickers.InstrumentPickerSheet
import com.handstrudel.ui.studio.pickers.ProgressionPickerSheet
import com.handstrudel.ui.studio.pickers.ScalePickerSheet
import com.handstrudel.ui.studio.presets.SoundSetupsSheet
import com.handstrudel.ui.studio.sheet.StudioKeyMenu
import com.handstrudel.ui.theme.LocalStudioPalette
import com.handstrudel.ui.theme.StudioThemePickerSheet
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch

/** iOS `StartOverlayView`: the Music tab before a session. */
@Composable
fun MusicHome() {
    val services = LocalAppServices.current
    val engine = services.engine
    val navigator = LocalAppNavigator.current
    val palette = LocalStudioPalette.current
    val scope = rememberCoroutineScope()

    val status by engine.status.collectAsState()
    val running by engine.isRunning.collectAsState()
    val instrument by engine.selectedSoundFontInstrument.collectAsState()
    val key by engine.selectedKey.collectAsState()
    val scale by engine.selectedScale.collectAsState()
    val progression by engine.chordMelodyProgression.collectAsState()
    // iOS `startingSession` (covers the camera permission dialog, not just engine prep).
    val starting by navigator.isStartingSession.collectAsState()

    var showSounds by remember { mutableStateOf(false) }
    var showAppearance by remember { mutableStateOf(false) }
    var showDrafts by remember { mutableStateOf(false) }
    var showSetups by remember { mutableStateOf(false) }
    var showLoops by remember { mutableStateOf(false) }
    var previewJob by remember { mutableStateOf<Job?>(null) }
    var isPreviewing by remember { mutableStateOf(false) }
    var previewFailed by remember { mutableStateOf(false) }

    fun stopPreview() {
        previewJob?.cancel()
        previewJob = null
        isPreviewing = false
        InstrumentPreview.stop(engine)
    }

    fun playPreview() {
        if (running || starting) return
        stopPreview()
        previewFailed = false
        val notes = StudioMusic.previewNotes(key, scale.intervals, progression.id, progression.degrees)
        isPreviewing = true
        previewJob = scope.launch {
            delay(120) // let another swipe cancel first
            if (!InstrumentPreview.start(engine, instrument)) {
                previewFailed = true
                stopPreview()
                return@launch
            }
            notes.forEachIndexed { i, note ->
                InstrumentPreview.noteOn(engine, note)
                delay(if (i == notes.size - 1) 570 else 250)
            }
            stopPreview()
        }
    }

    // Preview stops when the app backgrounds, a session starts, or the home leaves.
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val obs = LifecycleEventObserver { _, e -> if (e == Lifecycle.Event.ON_STOP || e == Lifecycle.Event.ON_PAUSE) stopPreview() }
        lifecycleOwner.lifecycle.addObserver(obs)
        onDispose { lifecycleOwner.lifecycle.removeObserver(obs); stopPreview() }
    }
    LaunchedEffect(starting, running) { if (starting || running) stopPreview() }

    Column(Modifier.fillMaxSize().background(palette.background).statusBarsPadding()) {
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState())
                .padding(horizontal = 22.dp).padding(top = 18.dp, bottom = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(Modifier.studioContentWidth(520), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                // Title.
                Column(verticalArrangement = Arrangement.spacedBy(17.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Filled.GraphicEq, null, tint = palette.accent, modifier = Modifier.size(16.dp))
                        Text("handstrudel", fontSize = 15.sp, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold, color = palette.ink)
                        Spacer(Modifier.weight(1f))
                        CircleIconButton(Icons.Outlined.Palette, "Appearance", "music-appearance", filled = true) {
                            stopPreview(); showAppearance = true
                        }
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Text("Play the air.", fontSize = 51.sp, lineHeight = 56.sp, fontFamily = FontFamily.Serif, letterSpacing = (-2).sp, color = palette.ink)
                        Text("Play music with a gesture or a touch.", fontSize = 15.sp, color = palette.muted)
                    }
                }

                // Hero card: instrument browser + current sound.
                val shape = RoundedCornerShape(23.dp)
                Column(Modifier.fillMaxWidth().clip(shape).background(palette.surface).border(1.dp, palette.border, shape)) {
                    InstrumentBrowser(
                        enabled = !starting,
                        isPreviewing = isPreviewing,
                        previewFailed = previewFailed,
                        onSelect = { inst -> if (inst.id != instrument.id) { stopPreview(); engine.setSoundFontInstrument(inst); playPreview() } },
                        onTogglePreview = { if (isPreviewing) stopPreview() else playPreview() },
                    )
                    Box(Modifier.fillMaxWidth().height(1.dp).background(palette.border))
                    Row(
                        Modifier.fillMaxWidth().clickable(enabled = !starting) { stopPreview(); showSounds = true }
                            .padding(16.dp).testTag("music-change-sound")
                            .semantics { contentDescription = "Change sound" },
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(14.dp),
                    ) {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(instrument.name, fontSize = 22.sp, fontWeight = FontWeight.SemiBold, color = palette.ink)
                            Text(
                                "${key.displayName} ${scale.displayName}  /  ${progression.name}",
                                fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = palette.muted,
                            )
                        }
                        Box(
                            Modifier.size(44.dp).clip(CircleShape).background(palette.accent.copy(alpha = 0.09f)),
                            contentAlignment = Alignment.Center,
                        ) { Icon(Icons.Filled.Tune, null, tint = palette.accent, modifier = Modifier.size(20.dp)) }
                    }
                }

                // Library shortcuts.
                // iOS: a row normally, a column at accessibility text sizes.
                if (isAccessibilityTextSize()) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        LibraryShortcut("Private drafts", Icons.Outlined.Movie, "private-drafts-button", Modifier.fillMaxWidth()) { showDrafts = true }
                        LibraryShortcut("Presets", Icons.Outlined.Layers, "music-presets-button", Modifier.fillMaxWidth()) { showSetups = true }
                        LibraryShortcut("Loops", Icons.Filled.Repeat, "music-loop-shelf", Modifier.fillMaxWidth()) { showLoops = true }
                    }
                } else {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        LibraryShortcut("Private drafts", Icons.Outlined.Movie, "private-drafts-button", Modifier.weight(1f)) { showDrafts = true }
                        LibraryShortcut("Presets", Icons.Outlined.Layers, "music-presets-button", Modifier.weight(1f)) { showSetups = true }
                        LibraryShortcut("Loops", Icons.Filled.Repeat, "music-loop-shelf", Modifier.weight(1f)) { showLoops = true }
                    }
                }
            }
        }

        // Start.
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 22.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(Modifier.studioContentWidth(520), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (status.startsWith("error")) Text(status, fontSize = 13.sp, color = androidx.compose.ui.graphics.Color(0xFFFF9500))
                if (starting) {
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = 54.dp),
                        horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
                    ) {
                        CircularProgressIndicator(color = palette.accent, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
                        Text("  $status", fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = palette.ink)
                    }
                } else {
                    StudioActionButton(Modifier.testTag("start-button"), onClick = { stopPreview(); navigator.startSession() }) {
                        Text("Start playing", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = palette.onAccent)
                        Spacer(Modifier.weight(1f))
                        Icon(Icons.Filled.ArrowOutward, null, tint = palette.onAccent)
                    }
                }
            }
        }
    }

    if (showAppearance) StudioThemePickerSheet(onDismiss = { showAppearance = false })
    if (showSounds) SoundSetupSheet(onDismiss = { showSounds = false })
    if (showDrafts) CaptureEntryPoints.DraftsSheet(onDismiss = { showDrafts = false })
    if (showLoops) CaptureEntryPoints.LoopShelfSheet(onDismiss = { showLoops = false })
    if (showSetups) {
        SoundSetupsSheet(
            onApply = { setup -> showSetups = false; navigator.startSession(setup) },
            onDismiss = { showSetups = false },
        )
    }
}

/**
 * iOS `instrumentBrowser`: a paged, wrap-around strip of instrument artwork
 * (unlocked instruments plus the current one). Swiping selects and previews.
 */
@Composable
private fun InstrumentBrowser(
    enabled: Boolean,
    isPreviewing: Boolean,
    previewFailed: Boolean,
    onSelect: (com.handstrudel.models.SoundFontInstrument) -> Unit,
    onTogglePreview: () -> Unit,
) {
    val services = LocalAppServices.current
    val engine = services.engine
    val palette = LocalStudioPalette.current
    val selected by engine.selectedSoundFontInstrument.collectAsState()
    val key by engine.selectedKey.collectAsState()
    val scale by engine.selectedScale.collectAsState()
    val progression by engine.chordMelodyProgression.collectAsState()
    val instruments = SOUNDFONT_INSTRUMENTS.filter { it.id == selected.id || services.store.isUnlocked(it.packId) }
    val n = instruments.size.coerceAtLeast(1)
    val virtualCount = if (n > 1) n * 1000 else 1
    val startPage = if (n > 1) n * 500 + instruments.indexOfFirst { it.id == selected.id }.coerceAtLeast(0) else 0
    val pager = rememberPagerState(initialPage = startPage) { virtualCount }

    // Follow external changes (e.g. the picker) without a preview.
    LaunchedEffect(selected.id) {
        val idx = instruments.indexOfFirst { it.id == selected.id }
        if (idx >= 0 && pager.currentPage % n != idx) {
            pager.scrollToPage(pager.currentPage - pager.currentPage % n + idx)
        }
    }
    LaunchedEffect(pager, instruments) {
        snapshotFlow { pager.settledPage }.distinctUntilChanged().collect { page ->
            instruments.getOrNull(page % n)?.let(onSelect)
        }
    }

    Box(Modifier.fillMaxWidth().height(225.dp).testTag("sound-artwork")) {
        // iOS: one "Sound artwork" element whose value names the sound, adjustable to
        // the next/previous instrument (wrapping).
        val index = instruments.indexOfFirst { it.id == selected.id }.coerceAtLeast(0)
        fun step(by: Int): Boolean {
            if (!enabled || instruments.size < 2) return false
            onSelect(instruments[(index + by + instruments.size) % instruments.size])
            return true
        }
        HorizontalPager(
            pager,
            Modifier.fillMaxSize().clearAndSetSemantics {
                contentDescription = "Sound artwork"
                stateDescription = "${selected.name}, ${key.rawValue} ${scale.displayName}, ${progression.name}, ${index + 1} of ${instruments.size}"
                if (instruments.size > 1) {
                    progressBarRangeInfo = ProgressBarRangeInfo(index.toFloat(), 0f..(instruments.size - 1).toFloat(), steps = instruments.size - 2)
                    setProgress { target -> step(target.roundToInt().coerceIn(0, instruments.size - 1) - index) }
                    customActions = listOf(
                        CustomAccessibilityAction("Next instrument") { step(1) },
                        CustomAccessibilityAction("Previous instrument") { step(-1) },
                    )
                }
                if (!enabled) disabled()
            },
            userScrollEnabled = enabled && n > 1,
        ) { page ->
            instruments.getOrNull(page % n)?.let {
                SoundArtwork(it, key, scale, progression, Modifier.fillMaxSize())
            }
        }
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 10.dp).padding(top = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                if (previewFailed) "Preview unavailable" else "‹  Swipe instruments  ›",
                fontSize = 11.sp, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold, color = palette.ink,
                modifier = Modifier.clip(CircleShape).background(palette.background.copy(alpha = 0.9f))
                    .padding(horizontal = 10.dp, vertical = 6.dp),
            )
            Spacer(Modifier.weight(1f))
            CircleIconButton(
                if (isPreviewing) Icons.Filled.Stop else Icons.AutoMirrored.Filled.VolumeUp,
                if (isPreviewing) "Stop instrument preview" else "Preview instrument",
                "studio-instrument-preview", filled = false, enabled = enabled, onClick = onTogglePreview,
            )
        }
    }
}

@Composable
private fun CircleIconButton(icon: ImageVector, label: String, tag: String, filled: Boolean, enabled: Boolean = true, onClick: () -> Unit) {
    val palette = LocalStudioPalette.current
    Box(
        Modifier.size(44.dp).clip(CircleShape)
            .background(if (filled) palette.surface else palette.background.copy(alpha = 0.92f))
            .border(1.dp, palette.border, CircleShape)
            .clickable(enabled = enabled, onClick = onClick)
            .testTag(tag).semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) { Icon(icon, null, tint = palette.accent, modifier = Modifier.size(18.dp)) }
}

@Composable
private fun LibraryShortcut(title: String, icon: ImageVector, tag: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val palette = LocalStudioPalette.current
    Row(
        modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp)).clickable(onClick = onClick).testTag(tag).padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, tint = palette.muted, modifier = Modifier.size(16.dp))
        Text(" $title", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = palette.muted, maxLines = 2)
    }
}

/** iOS `soundsSheet` ("Sound setup"): hero + instrument, key, scale and chords chips. */
@Composable
fun SoundSetupSheet(onDismiss: () -> Unit) {
    val engine = LocalAppServices.current.engine
    val instrument by engine.selectedSoundFontInstrument.collectAsState()
    val key by engine.selectedKey.collectAsState()
    val scale by engine.selectedScale.collectAsState()
    val progression by engine.chordMelodyProgression.collectAsState()
    var picker by remember { mutableStateOf<String?>(null) }

    StudioSheet(title = "Sound setup", onDismiss = onDismiss) {
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 14.dp)
                .widthIn(max = 620.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            StudioSettingsHero(instrument.name, key, scale, progression, instrument)
            StudioSettingsPanel {
                StudioSettingRow("Instrument", Icons.Filled.GraphicEq, instrument.name, Modifier.testTag("sounds-instrument")) { picker = "instrument" }
                StudioSettingsDivider()
                StudioKeyMenu(key) { engine.setKey(it) }
                StudioSettingsDivider()
                StudioSettingRow("Scale", Icons.Filled.Piano, scale.displayName, Modifier.testTag("scale-picker")) { picker = "scale" }
                StudioSettingsDivider()
                StudioSettingRow("Chords", Icons.AutoMirrored.Filled.QueueMusic, progression.name, Modifier.testTag("sounds-progression")) { picker = "progression" }
            }
        }
    }
    when (picker) {
        "instrument" -> InstrumentPickerSheet(instrument, { engine.setSoundFontInstrument(it) }, { picker = null })
        "progression" -> ProgressionPickerSheet(progression, { engine.setProgression(it) }, { picker = null })
        "scale" -> ScalePickerSheet(onDismiss = { picker = null })
    }
}

