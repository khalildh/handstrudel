package com.handstrudel.ui.studio.stage

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.VideocamOff
import androidx.compose.material.icons.outlined.Layers
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.currentStateAsState
import com.handstrudel.app.LocalAppServices
import com.handstrudel.engine.CameraIssue
import com.handstrudel.engine.PlayInput
import com.handstrudel.engine.StudioMode
import com.handstrudel.models.PARAM_DEFS
import com.handstrudel.ui.capture.CaptureEntryPoints
import com.handstrudel.ui.studio.CameraPreview
import com.handstrudel.ui.studio.common.StudioMusic
import com.handstrudel.ui.studio.onboarding.OnboardingOverlay
import com.handstrudel.ui.studio.overlays.ChordMelodyZonesOverlay
import com.handstrudel.ui.studio.overlays.DrumLanesOverlay
import com.handstrudel.ui.studio.overlays.DrumXYPad
import com.handstrudel.ui.studio.overlays.GridLanesOverlay
import com.handstrudel.ui.studio.overlays.GridQuickBar
import com.handstrudel.ui.studio.overlays.LearnOverlay
import com.handstrudel.ui.studio.overlays.LearnSongPicker
import com.handstrudel.ui.studio.overlays.RadialWheelOverlay
import com.handstrudel.ui.studio.overlays.SplitScaleWheelOverlay
import com.handstrudel.ui.studio.overlays.WeaveView
import com.handstrudel.ui.studio.presets.SoundSetupsSheet
import com.handstrudel.ui.studio.sheet.ControlSheet
import com.handstrudel.ui.studio.visual.CAMERA_FILTERS
import com.handstrudel.ui.studio.visual.CameraFilterOverlay
import com.handstrudel.ui.studio.visual.HandOverlay
import com.handstrudel.ui.studio.visual.cameraFilter
import com.handstrudel.ui.studio.visual.cameraFilterEffect
import com.handstrudel.ui.studio.visual.handTheme
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.abs

/** iOS `ContentView.performanceView`: the full-screen session stage. */
@Composable
fun Stage() {
    val services = LocalAppServices.current
    val engine = services.engine
    val palette = LocalStudioPalette.current
    val scope = rememberCoroutineScope()

    val mode by engine.mode.collectAsState()
    val playInput by engine.playInput.collectAsState()
    val cameraIssue by engine.cameraIssue.collectAsState()
    val hands by engine.handsState.collectAsState()
    val filterId by engine.selectedFilter.collectAsState()
    val themeId by engine.selectedHandTheme.collectAsState()
    val isPaused by engine.isPaused.collectAsState()
    val auxIssue by engine.auxiliaryAudioIssue.collectAsState()
    val beat by engine.currentBeat.collectAsState()
    val bpm by engine.bpm.collectAsState()
    val noteDisplay by engine.noteDisplay.collectAsState()
    val codeDisplay by engine.codeDisplay.collectAsState()
    val params by engine.smoothedParams.collectAsState()
    val capture by services.capture.state.collectAsState()
    val locked by services.capture.isRecordingLocked.collectAsState()
    val hideSkeleton by services.prefs.hideSkeletonWhenRecording.collectAsState()
    val hasSeenOnboarding by services.prefs.hasSeenOnboarding.collectAsState()
    val lifecycle by LocalLifecycleOwner.current.lifecycle.currentStateAsState()
    val active = lifecycle.isAtLeast(Lifecycle.State.RESUMED)

    var showSheet by remember { mutableStateOf(false) }
    var showSetups by remember { mutableStateOf(false) }
    var showLearnPicker by remember { mutableStateOf(false) }
    var chromeVisible by remember { mutableStateOf(true) }
    var filterToast by remember { mutableIntStateOf(0) }
    var randomToast by remember { mutableIntStateOf(0) }

    val filter = cameraFilter(filterId)
    val melodicActive = mode.isMelodicFamily
    // iOS hides the melodic HUD with `.opacity(0)` and `.allowsHitTesting(false)`.
    val chromeHidden = melodicActive && !chromeVisible
    val swipeEnabled = FilterSwipe.isEnabled(mode, playInput, mixerOpen = CaptureEntryPoints.isBackingMixerOpen())
    val cycleFilter = remember {
        { swipeLeft: Boolean ->
            // iOS: swipe left → next unlocked filter, right → previous; then the name toast.
            val ids = CAMERA_FILTERS.filter { services.store.isUnlocked(it.packId) }.map { it.id }
            FilterSwipe.next(ids, engine.selectedFilter.value, swipeLeft)?.let { id ->
                engine.setFilter(id)
                filterToast++
            }
            Unit
        }
    }
    val swipe = Modifier.filterSwipe(swipeEnabled, cycleFilter)
    val touchEnabled = !isPaused && active
    val busy = capture.isRecording || capture.isBusy || capture.countdown != null
    val strudelHue = run {
        val ni = params["noteIdx"] ?: 10.0
        (ni / 17.0 + beat * 0.03) % 1.0
    }
    fun normalized(id: String): Double {
        val def = PARAM_DEFS.firstOrNull { it.id == id } ?: return 0.5
        val v = params[id] ?: def.defaultValue
        val range = def.max - def.min
        return if (range <= 0) 0.5 else ((v - def.min) / range).coerceIn(0.0, 1.0)
    }

    ShakeDetector {
        RandomSettings.pick(services.store).apply(engine)
        randomToast++
    }
    LaunchedEffect(mode) {
        // iOS: choosing Learn with no song loaded opens the picker.
        if (mode == StudioMode.LEARN && engine.learn.value.currentSongId == null) showLearnPicker = true
    }

    Box(Modifier.fillMaxSize().background(Color.Black).testTag("stage")) {
        // ---- Backdrop ----
        if (playInput == PlayInput.AIR && cameraIssue == null) {
            // iOS filters the ZStack of camera + colour overlay, so the matrix tints the overlay too.
            Box(Modifier.fillMaxSize().cameraFilterEffect(filter)) {
                CameraPreview(modifier = Modifier.fillMaxSize(), handTracker = engine.handTracker)
                CameraFilterOverlay(filter, Modifier.fillMaxSize())
            }
        } else {
            Box(
                Modifier.fillMaxSize().background(
                    Brush.radialGradient(listOf(palette.mediaAccent.copy(alpha = 0.11f), Color.Black), radius = 1050f),
                ),
            )
        }

        // ---- Weave + centre note (melodic family) ----
        if (melodicActive) {
            WeaveView(
                hue = strudelHue, energy = normalized("gain"), space = normalized("reverb"),
                brightness = normalized("lpf"), speed = ((bpm - 50) / 155).coerceIn(0.0, 1.0),
                complexity = maxOf(normalized("crush"), normalized("shape")),
                modifier = Modifier.fillMaxSize(),
            )
            val pulse by animateFloatAsState(if (beat == 0) 1.06f else 1f, spring(dampingRatio = 0.6f), label = "note")
            Text(
                noteDisplay,
                fontSize = 72.sp, fontWeight = FontWeight.ExtraLight, color = Color.White.copy(alpha = 0.92f),
                style = TextStyle(shadow = Shadow(hueColor(strudelHue, 0.68f, 1f).copy(alpha = 0.6f), blurRadius = 48f)),
                modifier = Modifier.align(Alignment.Center).scale(pulse),
            )
        }

        HandOverlay(
            hands, handTheme(themeId),
            Modifier.fillMaxSize().alpha(if (capture.isRecording && hideSkeleton) 0f else 1f),
            videoAspect = com.handstrudel.ui.studio.common.StageMetrics.videoAspect(engine),
        )

        // ---- Mode overlays ----
        when (mode) {
            StudioMode.GRID -> GridLanesOverlay(touchEnabled, Modifier.fillMaxSize())
            StudioMode.DRUM -> DrumLanesOverlay(touchEnabled, Modifier.fillMaxSize())
            StudioMode.CHORD_MELODY, StudioMode.SOUNDFONT -> ChordMelodyZonesOverlay(touchEnabled, Modifier.fillMaxSize())
            StudioMode.RADIAL -> RadialWheelOverlay(touchEnabled, Modifier.fillMaxSize())
            StudioMode.SPLIT -> SplitScaleWheelOverlay(scaleMode = false, touchEnabled = touchEnabled, modifier = Modifier.fillMaxSize())
            StudioMode.SCALE -> SplitScaleWheelOverlay(scaleMode = true, touchEnabled = touchEnabled, modifier = Modifier.fillMaxSize())
            StudioMode.LEARN -> LearnOverlay(touchEnabled, onPickSong = { showLearnPicker = true }, modifier = Modifier.fillMaxSize())
            else -> Unit
        }

        // Tap empty space to hide/show the HUD (melodic family only). It sits under the
        // chrome so buttons get their taps; while the HUD is hidden it moves above it and
        // takes the next tap, so the invisible buttons can't be pressed (iOS).
        val melodicSurface = @Composable {
            Box(
                Modifier.fillMaxSize()
                    .clickable(remember { MutableInteractionSource() }, indication = null) { chromeVisible = !chromeVisible }
                    .pointerInput(playInput) {
                        if (playInput != PlayInput.AIR) return@pointerInput
                        // iOS: horizontal swipe (≥ 50 pt) cycles the unlocked camera filters.
                        var total = 0f
                        detectHorizontalDragGestures(
                            onDragStart = { total = 0f },
                            onDragEnd = { if (abs(total) >= FilterSwipe.MIN_DISTANCE.toPx()) cycleFilter(total < 0) },
                            onHorizontalDrag = { _, d -> total += d },
                        )
                    }
                    .testTag("stage-melodic-surface"),
            )
        }
        if (melodicActive && !chromeHidden) melodicSurface()

        // ---- Floating chrome ----
        val chromeAlpha by animateFloatAsState(if (chromeHidden) 0f else 1f, tween(250), label = "chrome")
        Column(
            Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().alpha(chromeAlpha)
                .then(if (chromeHidden) Modifier.clearAndSetSemantics {} else Modifier)
        ) {
            TopBar(
                beat = beat,
                locked = locked,
                // iOS keeps ✕ enabled during the count-in; it cancels the countdown.
                closeEnabled = !(capture.isRecording || capture.isBusy || capture.isLoopCapturing),
                swipe = swipe,
                onPresets = { showSetups = true },
                onClose = {
                    services.capture.onSessionEnded()
                    engine.stop()
                },
                modifier = Modifier.padding(horizontal = 16.dp).padding(top = 8.dp),
            )
            if (!busy && (hasSeenOnboarding || mode != StudioMode.SCALE)) {
                CameraInputStatus(
                    playInput, cameraIssue, swipe,
                    onTouch = { services.prefs.setStudioPlayInput(PlayInput.TOUCH); engine.setPlayInput(PlayInput.TOUCH) },
                    onRetry = { engine.reportCameraIssue(null); engine.startCameraIfRequested() },
                )
            }
            auxIssue?.let { issue ->
                if (!capture.isRecording && capture.countdown == null) {
                    Text(
                        issue, fontSize = 12.sp, color = Color.White, textAlign = TextAlign.Center,
                        modifier = Modifier.align(Alignment.CenterHorizontally).padding(horizontal = 16.dp, vertical = 4.dp)
                            .clip(RoundedCornerShape(12.dp)).background(Color.Black.copy(alpha = 0.75f))
                            .padding(horizontal = 12.dp, vertical = 7.dp),
                    )
                }
            }
            if (melodicActive) CodePill(codeDisplay, Modifier.padding(horizontal = 20.dp).padding(top = 2.dp).then(swipe))
            Spacer(Modifier.weight(1f))
            if (melodicActive) {
                NoteBadge(noteDisplay, beat, strudelHue, Modifier.align(Alignment.CenterHorizontally).then(swipe))
                BeatRing(beat, bpm, Modifier.align(Alignment.CenterHorizontally).padding(top = 8.dp, bottom = 8.dp).then(swipe))
            }
            if (mode == StudioMode.GRID) GridQuickBar(Modifier.padding(horizontal = 16.dp).padding(bottom = 4.dp))
            if (mode == StudioMode.DRUM) DrumXYPad(Modifier.padding(horizontal = 16.dp).padding(bottom = 4.dp))
            Box(Modifier.fillMaxWidth()) {
                CaptureEntryPoints.StageBottomControls(onOpenSettings = { if (!locked) showSheet = true }, itemModifier = swipe)
            }
            AnimatedVisibility(filterToast > 0, Modifier.align(Alignment.CenterHorizontally), enter = fadeIn(), exit = fadeOut()) {
                Toast("${filter.emoji} ${filter.name}", Color.Black.copy(alpha = 0.5f))
            }
            AnimatedVisibility(randomToast > 0, Modifier.align(Alignment.CenterHorizontally), enter = fadeIn(), exit = fadeOut()) {
                Toast("🎲 Randomized!", Color(0xFFAF52DE).copy(alpha = 0.6f), Modifier.testTag("randomized-toast"))
            }
        }

        if (chromeHidden) melodicSurface()

        CaptureEntryPoints.StageOverlays()

        // ---- Onboarding (once, over the Scale wheel) ----
        if (!hasSeenOnboarding && mode == StudioMode.SCALE) {
            val key by engine.selectedKey.collectAsState()
            val scale by engine.selectedScale.collectAsState()
            val swap by engine.chordMelodySwapHands.collectAsState()
            val notes = StudioMusic.scaleNotesOneOctave(key, scale.intervals)
            val lane = notes.size / 2
            val midi = notes.getOrElse(lane) { 60 }
            OnboardingOverlay(
                noteName = StudioMusic.pitchClassName(midi),
                melodyLaneCount = notes.size,
                swapHands = swap,
                canSuggestPinching = playInput == PlayInput.AIR && cameraIssue == null,
                playFirstNote = {
                    // iOS plays a 0.48 s one-shot of the middle scale note.
                    val id = "onboarding-first-note"
                    engine.scaleTouchEnterMelody(id, lane)
                    scope.launch { delay(480); engine.scaleTouchExit(id) }
                },
                onDone = { services.prefs.setHasSeenOnboarding(true) },
            )
        }
    }

    LaunchedEffect(filterToast) { if (filterToast > 0) { delay(1200); filterToast = 0 } }
    LaunchedEffect(randomToast) { if (randomToast > 0) { delay(1200); randomToast = 0 } }

    if (showSheet) {
        LaunchedEffect(Unit) { engine.pause() }
        ControlSheet(
            onDismiss = { showSheet = false; engine.resume() },
            onOpenLearnPicker = { showLearnPicker = true },
        )
    }
    if (showSetups) {
        // iOS: the engine and the backing track pause while Presets is open; closing it
        // resumes the engine (the backing stays paused until the user plays it again).
        LaunchedEffect(Unit) {
            engine.pause()
            CaptureEntryPoints.pauseBacking(services.capture)
        }
        SoundSetupsSheet(
            onApply = { setup ->
                engine.applySoundSetup(setup, services.store)
                showSetups = false
                engine.resume()
            },
            onDismiss = { showSetups = false; engine.resume() },
        )
    }
    if (showLearnPicker) {
        LearnSongPicker(
            onPick = {
                engine.loadLearnSong(it)
                showLearnPicker = false
                // iOS: picking a lesson from the control sheet also closes the sheet.
                if (showSheet) { showSheet = false; engine.resume() }
            },
            onDismiss = { showLearnPicker = false },
        )
    }
}

internal fun hueColor(h: Double, s: Float, v: Float): Color {
    val hue = ((h % 1.0) + 1.0) % 1.0
    return Color.hsv((hue * 360).toFloat(), s, v)
}

@Composable
private fun TopBar(
    beat: Int, locked: Boolean, closeEnabled: Boolean, swipe: Modifier,
    onPresets: () -> Unit, onClose: () -> Unit, modifier: Modifier = Modifier,
) {
    val palette = LocalStudioPalette.current
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        BeatDots(beat, swipe)
        Spacer(Modifier.weight(1f).widthIn(min = 8.dp))
        Row(
            swipe.clip(CircleShape).background(Color.Black.copy(alpha = 0.55f)).padding(horizontal = 11.dp, vertical = 7.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Icon(Icons.Filled.GraphicEq, null, tint = palette.mediaAccent, modifier = Modifier.size(14.dp))
            Text("handstrudel", fontSize = 12.sp, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold, color = Color.White, maxLines = 1)
        }
        Spacer(Modifier.weight(1f).widthIn(min = 8.dp))
        RoundButton(Icons.Outlined.Layers, "Presets", "studio-presets-button", enabled = !locked, swipe = swipe, onClick = onPresets)
        Spacer(Modifier.size(8.dp))
        RoundButton(Icons.Filled.Close, "End session", "close-button", enabled = closeEnabled, swipe = swipe, onClick = onClose)
    }
}

@Composable
private fun RoundButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, tag: String, enabled: Boolean,
    swipe: Modifier, onClick: () -> Unit,
) {
    Box(
        swipe.size(44.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.4f))
            .clickable(enabled = enabled, onClick = onClick).testTag(tag).semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) { Icon(icon, null, tint = Color.White.copy(alpha = if (enabled) 0.85f else 0.35f), modifier = Modifier.size(18.dp)) }
}

/** iOS top-bar beat dots: 7 pt, current one ×1.5 in the media accent. */
@Composable
fun BeatDots(beat: Int, modifier: Modifier = Modifier) {
    val palette = LocalStudioPalette.current
    Row(modifier.testTag("beat-dots"), horizontalArrangement = Arrangement.spacedBy(5.dp), verticalAlignment = Alignment.CenterVertically) {
        for (i in 0 until 4) {
            val s by animateFloatAsState(if (i == beat) 1.5f else 1f, tween(100), label = "dot$i")
            Box(
                Modifier.size(7.dp).scale(s).clip(CircleShape)
                    .background(if (i == beat) palette.mediaAccent else Color.White.copy(alpha = 0.15f)),
            )
        }
    }
}

/** iOS `cameraInputStatus` + `CameraRecoveryBanner`. */
@Composable
private fun CameraInputStatus(input: PlayInput, issue: CameraIssue?, swipe: Modifier, onTouch: () -> Unit, onRetry: () -> Unit) {
    val palette = LocalStudioPalette.current
    Box(Modifier.fillMaxWidth().padding(top = 6.dp), contentAlignment = Alignment.Center) {
        if (input == PlayInput.AIR) {
            if (issue != null) {
                Column(
                    swipe.padding(horizontal = 20.dp).clip(RoundedCornerShape(12.dp)).background(Color.Black.copy(alpha = 0.72f))
                        .padding(10.dp).testTag("camera-recovery-banner"),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(issue.message, fontSize = 12.sp, color = Color.White)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        BannerButton("Use touch only", palette.mediaAccent, Modifier.testTag("camera-recovery-touch"), onTouch)
                        if (issue == CameraIssue.UNAVAILABLE) BannerButton("Try camera again", palette.mediaAccent, onClick = onRetry)
                    }
                }
            }
        } else {
            Row(
                swipe.clip(CircleShape).background(Color.Black.copy(alpha = 0.6f)).padding(horizontal = 10.dp, vertical = 6.dp)
                    .testTag("touch-camera-off"),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Icon(Icons.Filled.VideocamOff, null, tint = Color.White, modifier = Modifier.size(14.dp))
                Text("Camera off", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
            }
        }
    }
}

@Composable
private fun BannerButton(label: String, tint: Color, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Text(
        label, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = tint,
        modifier = modifier.clip(RoundedCornerShape(8.dp)).background(tint.copy(alpha = 0.15f)).clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 6.dp),
    )
}

/** iOS `codePill`: first 3 lines of the Strudel code, green mono on black. */
@Composable
private fun CodePill(code: String, modifier: Modifier = Modifier) {
    if (code.isEmpty()) return
    val green = Color(0xFF30D158)
    Text(
        code.lines().take(3).joinToString("\n"),
        fontSize = 8.sp, fontFamily = FontFamily.Monospace, color = green.copy(alpha = 0.8f), maxLines = 3,
        modifier = modifier.shadow(8.dp, RoundedCornerShape(14.dp), ambientColor = green.copy(alpha = 0.25f), spotColor = green.copy(alpha = 0.25f))
            .clip(RoundedCornerShape(14.dp)).background(Color.Black.copy(alpha = 0.5f))
            .border(0.5.dp, green.copy(alpha = 0.12f), RoundedCornerShape(14.dp))
            .padding(horizontal = 10.dp, vertical = 6.dp),
    )
}

/** iOS `noteBadge`. */
@Composable
private fun NoteBadge(note: String, beat: Int, hue: Double, modifier: Modifier = Modifier) {
    val s by animateFloatAsState(if (beat == 0) 1.1f else 1f, spring(dampingRatio = 0.5f), label = "badge")
    Text(
        note, fontSize = 28.sp, fontWeight = FontWeight.Black, color = Color.White,
        modifier = modifier.scale(s).clip(CircleShape).background(hueColor(hue, 0.6f, 0.3f).copy(alpha = 0.5f))
            .border(2.dp, hueColor(hue, 0.8f, 1f).copy(alpha = 0.6f), CircleShape)
            .padding(horizontal = 20.dp, vertical = 10.dp),
    )
}

/** iOS `beatRing`: 50 pt ring + BPM. */
@Composable
private fun BeatRing(beat: Int, bpm: Double, modifier: Modifier = Modifier) {
    val s by animateFloatAsState(if (beat == 0) 1.15f else 1f, tween(300), label = "ring")
    val a by animateFloatAsState(if (beat == 0) 0.4f else 0.8f, tween(300), label = "ringA")
    Box(modifier.size(50.dp), contentAlignment = Alignment.Center) {
        Box(Modifier.size(50.dp).border(1.5.dp, Color.White.copy(alpha = 0.04f), CircleShape))
        Box(
            Modifier.size(50.dp).scale(s).alpha(a)
                .border(1.5.dp, if (beat % 2 == 0) Color(0xFF30D158).copy(alpha = 0.6f) else Color(0xFFFF375F).copy(alpha = 0.6f), CircleShape),
        )
        Text("${Math.round(bpm)}", fontSize = 13.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace, color = Color.White.copy(alpha = 0.5f))
    }
}

@Composable
private fun Toast(text: String, bg: Color, modifier: Modifier = Modifier) {
    Text(
        text, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.White,
        modifier = modifier.padding(bottom = 8.dp).clip(CircleShape).background(bg).padding(horizontal = 20.dp, vertical = 10.dp),
    )
}
