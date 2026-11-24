## store (ed05ffc8, done)
- Integrator: AppServices.create: UnconfiguredStoreGate() -> StoreManager.create(app); keep store.bind(auth.userId).
- Studio-ui: hide Store button when !store.isConfigured; ProBadge()/ProBadge(CORNER); PaywallSheet("pro") for locked instruments/progressions/scales.
- Seam additions: StoreGate.refresh() default; StoreState new fields w/ defaults; types moved to StoreState.kt/RestoreOutcome.kt same package.
- Owner: RevenueCat Android key (-Phandstrudel.revenuecatApiKey), Play products. Pro doesn't unlock kits unless RC dashboard attaches kit_* to Pro.
## shell (a7a59460, 89f2bb5d, done)
- studio-ui: Stage close: only engine.stop() (shell calls capture.onSessionEnded). Drop MusicHome 72dp top /120dp bottom padding. Appearance via StudioThemePickerSheet.
- capture: onSessionEnded idempotent; mic via navigator.requestPermission(RECORD_AUDIO); reviewPrompt.recordSuccessfulTake(id); analytics RECORDING_*.
- social: Account->Appearance StudioThemePickerSheet; UsageAnalyticsScreen; openExternalLink; openPlayListing; feed reports onFullscreenChanged; fetchVideo may throw.
- engine: setSceneActive, startCameraIfRequested no-ops in legacy.
- Not verified: review card, real analytics POST, assetlinks, camera grant.
## capture (272c9d49 5c812cbb cff6711a, done)
- CONFLICT: shell set launchMode singleTask (deep link during camera prompt); capture says singleTask makes the MediaProjection single-app picker return RESULT_CANCELED; wants singleTop + process-scoped AppServices (shell did Application-scoped already). Must test both flows on emulator.
- AppServices.create: CaptureControllerImpl(app, prefs, engine, store, auth, analytics, reviewPrompt) (analytics, reviewPrompt local vals); call services.capture.attach(navigator) after navigator created.
- studio-ui: hide skeleton while recording && prefs.hideSkeletonWhenRecording; Music home "Private drafts" -> CaptureEntryPoints.DraftsSheet; CaptureEntryPoints.RecordingSettingsSection() in control sheet.
- engine: saveCapturedLoop + loop playback, setRecordingTempo/supportsHalfSpeedRecording, currentSoundSetup.
- social: fetchVideo, SignInSheet; PerformanceAudio.mediaUrl TODO(social).
- Posted clips: rotation flag (landscape + -90) — check web/iOS players; consider upright transcode.
## studio-ui (dbb62977 dbbeab19 16000e15 4df458a4, done)
- Engine seam requests sent to engine agent (preview, melodyOctaveShift, learn countdown, grid finger octave, harmony toggles, params mapped/manual/format, zones octave, progression category/parse, learn ids, grid lane convention, zoneDegrees, key/scale persistence, camera aspect).
- shell: root Modifier.semantics { testTagsAsResourceId = true }.
- capture: don't pad RecordingSettingsSection twice; loop audio export TODO(capture) in Mix->Loops.
- Unverified: engine-backed behaviour, hand themes visual, paywall with fake store, Paper theme, tablet.
## social (753d2748 a70b87cc, done)
- PROD BREACH to report: signed-out prod-config feed likely recorded ~1 anonymous view on a @handstrudel_demo clip (record_video_view).
- AppServices: auth = SocialServices.getOrNull(app)?.auth ?: SignedOutAuthSession()
- debug network security config cleartext 10.0.2.2/localhost.
- Usage analytics: social made temp screen TODO(shell) -> use shell's UsageAnalyticsScreen.
- engine: addPreset/presets; presetDetails TODO(engine).
- Unverified: real edge functions w/ R2, Google sign-in, audio download path, share chooser.
## engine (e1119d96..95548bcf, done) — merged last
- Real class HandStrudelEngine; EngineController is a thin facade; LegacyStudioEngine delegates. Studio-ui already dropped the legacy cast -> wire AppServices to HandStrudelEngine and delete LegacyStudioEngine + EngineController facade if nothing else uses them.
- studio-ui: CameraPreview should call handTracker.onCameraBindFailed(e) on bind failure and onCameraInUse() on CameraX ERROR_CAMERA_IN_USE. drumPad(x=intensity,y=complexity): iOS pad maps to drumPad(1 - padY, padX). Scale arc should use chordMelody.melodyLaneCount.
- studio-ui call sites to switch from local fallbacks to the new engine members: preview (home/InstrumentPreview.kt), melodyOctaveShift, learn countdown, finger octave, harmony toggles (Chords / Circle of 5ths rows in Sound tab), bpmIsMapped/mappedParamIds/manualValues, zones octave, ChordProgression.category (pickers/Pickers.kt pickerCategory) and .parse (ControlSheetLogic mirror), cameraAspect (StageMetrics.VIDEO_ASPECT).
- social: presetDetails TODO(engine) in PerformanceStart.kt.
- Counts: iOS wins (144 progressions, 23 filters, 8 songs + practice).
- Not verified: live instrument/key/progression change stuck notes; preset pack SAF import; loop record/playback with capture; real camera/speakers.

## Integration (claude/android-parity-1.0.1) — resolved
- engine: AppServices builds `HandStrudelEngine` directly; `EngineController` / `LegacyStudioEngine` deleted.
- studio-ui switched to engine members: previewStart/NoteOn/Stop, BUNDLED_SONGS/PRACTICE ids, learn countdown,
  melodyOctaveShift + melodyLaneCount (Scale), Zones octave rows by touch row, finger-octave dots/toggle,
  Chords / Circle of 5ths pills, bpmIsMapped / mappedParamIds / manualValues, ParamDef.format,
  ChordProgression.category (picker tabs) and .parse, previewPresetPack, cameraAspect.
- CameraPreview reports bind failures (`onCameraBindFailed`) and CameraX camera-in-use (`onCameraInUse`, cleared on reopen).
- drumPad: already correct (`drumPad(intensity = 1 - padY, complexity = padX)`); no change.
- One `SoundSetup.presetDetails` (engine's); social/capture copies removed. PerformanceAudio uses `SocialConfig.mediaUrl`.
- Mix > Loops has the iOS "Export WAV" button (capture's `exportLoop`). RecordingSettingsSection is padded once.
- Stage close still calls `capture.onSessionEnded()` before `engine.stop()` (idempotent; ends a take before the engine stops).
- Store button hidden when `!store.isConfigured`.
- launchMode: `singleTop`. A duplicate MainActivity (created when an intent lands while a system dialog is on top:
  camera prompt + deep link, or the MediaProjection "Share one app" relaunch) relays its intent to the live instance,
  moves that task forward if needed (REORDER_TASKS) and finishes in onCreate. Both flows verified on an API 36 emulator.
- Release: proguard-rules.pro keeps MediaPipe, JNA/UniFFI, @JavascriptInterface, serializers; dontwarn for AutoValue/Ktor.
