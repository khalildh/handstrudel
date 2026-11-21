# Android parity with iOS 1.0.1: spec and build plan

Status: plan. Branch `claude/android-parity-1.0.1` (from `origin/main` 0a77df3e, the iOS 1.0.1 build 42 code).
Audience: the implementation agents. Each workstream section is a complete brief.

Path shorthands used below:

| Shorthand | Path |
| --- | --- |
| `iOS/` | `ios/HandStrudel/HandStrudel/` |
| `A/` | `android/app/src/main/java/com/handstrudel/` |
| `AT/` | `android/app/src/test/java/com/handstrudel/` (JVM unit tests; directory does not exist yet) |
| `core/` | Rust crate `core/handstrudel-core/` (exposed to Android as Gradle module `:core`, see `android/core/README.md`) |

**Scope rule: iOS 1.0.1 only.** The 1.0.2 work in flight (Learn to Play rework, Pro sound unlocks, chord voicing setting, Pro/+ store restructure, push, sound pages, streaks, invites) and the 1.0.3 instrument format are **not** part of this parity target. When the iOS code on this branch and an idea disagree, the iOS code wins.

---

## 0. Where things stand

### iOS reference (≈25.6k Swift lines)

* **App shell:** `App/ContentView.swift` (2.6k lines) holds three destinations: **Feed**, **Music** and **Account**. When a session starts, a full-screen performance view takes over. It also routes deep links and runs the recording/loop/play-along orchestration. `App/ControlSheetView.swift` (1.6k) is the in-session settings sheet, plus `LoopShelfView` and `SoundSetupsView` (presets).
* **Audio has two engines:**
  * `Engine/SoundFontEngine.swift` is native (AVAudioUnitSampler + `Resources/soundfonts/GeneralUser-GS.sf2`). It voices the chord+melody family when "Voice through SoundFont" is on, which is the default for Split and Scale.
  * `Engine/StrudelBridge.swift` is a hidden WKWebView running `Resources/strudel-engine.html` + `strudel-bundle.js`, built from `ios/strudel-entry.mjs` by `ios/bundle-strudel.mjs`. It voices the Melodic/Flow/Hybrid/Lead patterns, 37 `WAVEFORMS` (8 oscillator synths + 29 bundled sampled instruments in `Resources/instrument-samples/`), Grid, Drums, both drum-loop tracks, and chord+melody with SoundFont off.
* **Per-mode logic** sits behind `Engine/ModeController.swift` (`tick(engine)`): Melodic (also Flow/Hybrid/Lead), Grid, Drum, ChordMelody, SoundFont, Learn.
* **Social:** `Social/*.swift` uses supabase-swift: Auth, Postgrest, Functions.
* **Payments:** RevenueCat (`Models/StoreManager.swift`, `Views/StoreView.swift`, `Views/PaywallOverlay.swift`).
* **The Rust core is not used by iOS.** It is Android-only today.

### Android today (≈3.4k Kotlin lines)

| Area | Files | State |
| --- | --- | --- |
| Shell | `A/ui/MainActivity.kt`, `A/ui/HandStrudelApp.kt` | Immersive single activity. Asks for camera+mic permissions. `StartScreen` is a legacy "PICK A VIBE" mapping-preset grid that iOS 1.0.1 does not have. `PerformanceScreen` has a camera, the Split overlay, beat dots and a settings gear. No tabs, no feed, no account. |
| Engine | `A/engine/EngineController.kt` | Booleans for grid/drum/chordMelody (Split only). Melodic tick drives a native oscillator. No Radial/Scale/ChordMelody-zones/SoundFont mode/Flow/Hybrid/Lead/Learn. No persistence. No quantize/auto-strum/pad volume. Touch handlers exist for Split. |
| Audio | `A/engine/synth/*` (Kotlin AudioTrack synth: oscillators, biquad, effects, step sequencer, drum synth), `A/engine/synth/SoundFontEngine.kt` + `android/app/src/main/cpp/tsf_jni.cpp` (TinySoundFont JNI, same GeneralUser-GS.sf2 committed under `android/app/src/main/assets/soundfonts/`) | SoundFont voices work. Native synth is a rough stand-in for Strudel. No sampled instruments, no Strudel drum-loop patterns. |
| Hand tracking | `A/engine/HandTrackingManager.kt`, `A/ui/CameraPreview.kt` | MediaPipe tasks-vision `hand_landmarker.task` (asset), CameraX front camera at 480x640. `HandData` has x/y/spread/pinch/pinchX/pinchY/fist/fingersUp. It lacks `rotation` and the five finger curls that iOS computes. No camera-issue states, no touch fallback. |
| Shared core | `core/src/{music,pinch,smoother,hands,grid_mode,chord_melody_mode}.rs` via UniFFI | `Layout` = Grid/Radial/Split. **No `Scale` layout** (iOS `ChordMelodyModeManager.Layout.scale`). `Scale` enum has 15 scales: missing the 8 iOS scales from Minor Pentatonic onward, and custom scales. `tick(hands, tables, quantize, autoStrum)`: Android always passes `false,false`. |
| Models | `A/models/{MusicTheory,ChordProgressions,Instruments,ParamDefs,Presets}.kt` | 15 scales, 10 progressions (iOS has 145), 20 GM instruments (iOS has 128 with a free subset), no waveforms catalog, no learn songs, no filters/themes. |
| UI | `A/ui/SplitChordMelodyOverlay.kt` (wheel + multitouch), `A/ui/SplitSettingsSheet.kt`, `A/ui/HandOverlay.kt` | Split only. |
| Haptics | `A/engine/HapticManager.kt` | Only `noteTrigger` and `chordTrigger`. |
| Tests | — | None. |

---

## 1. Feature inventory (iOS 1.0.1 → Android)

Status key: **done**, **partial**, **missing**. The "WS" column names the owning workstream from section 3.

### 1.1 App shell and platform

| Feature | iOS files | Android | WS | Parity notes |
| --- | --- | --- | --- | --- |
| Three destinations, studio takeover | `App/ContentView.swift` (`Destination`, `destinations`, `destinationTabs`) | missing | shell | Tabs are **Feed / Music / Account**. Music is the default and gets the filled accent capsule. While a session is running, tabs and the feed are hidden and the performance view is full-screen black. The Feed tab's tab bar is drawn over video (white ink) by the feed itself (`navigation:` closure). If social is unconfigured, the Feed and Account tabs show a "not available" placeholder. |
| Studio themes (4 palettes) | `Views/StudioTheme.swift` (`StudioTheme` volt/tide/afterglow/paper, `StudioPalette`, `StudioThemePicker`), `App/HandStrudelApp.swift` | missing | shell | Stored under key `studioTheme`, default `volt`. Paper is a light scheme, the others dark. Palette fields: background, surface, ink, muted, accent, onAccent, mediaAccent, mediaOnAccent, glow, overtone, recording. Copy the hex values exactly. The picker is reachable from the Music home (appearance button) and Account settings → Appearance. |
| Keep screen on, hide system bars | `HandStrudelApp.swift` | done | shell | Already in `MainActivity`. |
| Portrait only | Info.plist | done | shell | |
| Audio session: playback mixes with others | `restoreInstrumentAudio()` | n/a | engine | On Android, use `AudioAttributes.USAGE_MEDIA`/`CONTENT_TYPE_MUSIC`. Don't take audio focus exclusively, so other audio can mix. |
| Deep links | `ContentView.openSocialLink`, `Social/SocialModels.swift` `PerformanceLink`, entitlements `applinks:handstrudel.com` | missing | shell (routing) + social (parsing/targets) | `https://handstrudel.com/watch?v=<uuid>` (exactly one `v`) → open the performance. Custom scheme `handstrudel://watch|comments|sound|play/<uuid>`. Use an Android App Link with `autoVerify`. That needs `public/.well-known/assetlinks.json` (see Risks). |
| In-app review prompt | `ContentView` `CreatorReviewMilestones` (lines 14–38), `.task(id: canShowReview)` | missing | shell | Ask after 3 new successful takes, at most once per app version and once per 90 days. Only on the Music tab when idle and no sheet is open, after a 2 s delay. Android: Play In-App Review API. |
| Usage analytics (opt-in) | `App/AppAnalytics.swift` | missing | shell | Default **off**. Events: `active_day`, `return_day`, `first_note` (once per install), `recording_started`, `recording_saved`, `recording_posted`. POST to `rest/v1/rpc/record_app_usage_event` with `{p_event}` and the anon `apikey`. No auth header, no retry, 8 s timeout. `active_day` at most once per UTC day (`floor(epoch/86400)`). `return_day` when a previous day exists. Settings screen copy is in `UsageAnalyticsSettings`. |
| Shake to randomize | `App/UIKitBridges.swift` `ShakeDetectorView`, `ContentView.randomizeSettings` | missing | studio-ui | Picks a random key, an entitled scale, a random waveform and BPM 80–160, then shows a "randomized" toast for 1.2 s. Android: accelerometer shake detector. |
| Camera permission / touch fallback | `Engine/HandTrackingManager.swift` `CameraIssue`, `EngineController.fallBackToTouch`, `ContentView` `CameraRecoveryBanner`, `StudioInputPicker` | missing | engine (state) + studio-ui (banner/picker) | Issues: permissionDenied / restricted / unavailable / interrupted, each with a message ("…You can still play by touch."). Denial switches play input to touch. The picker offers "Open Camera Settings". Android must not block the app when the camera is denied. Today it asks at launch: ask lazily at session start instead. |

### 1.2 Music home (start screen) and onboarding

| Feature | iOS files | Android | WS | Notes |
| --- | --- | --- | --- | --- |
| Studio home | `Views/StartOverlayView.swift` (`StartOverlayView`, `StudioSettingsHero`, `SoundArtwork`, `StudioKeyMenu`, `StudioSettingsPanel/Row/Divider`, `StudioActionStyle`) | partial (wrong design) | studio-ui | Headline "Play the air.", subhead "Play music with a gesture or a touch.", appearance button. Hero card shows the current sound and opens the **Sound setup** sheet: instrument, key, scale and progression chips. Instrument preview plays a short phrase and stops when the app backgrounds. Library shortcuts: **Private drafts**, **Presets**, **Loops**. A **Start playing** button shows the error status above it. Delete the legacy `PRESETS` "PICK A VIBE" grid. |
| Start always opens Scale mode | `ContentView.startSession` | missing | engine + studio-ui | "Start playing" switches to `scaleChordMelody` unless a sound setup was applied (shared sound / preset / play-along). First it clamps the scale to the user's entitlement (`limitScaleToEntitlement`: an unentitled scale becomes Pentatonic). Uses `DEFAULT_MAPPING` and the saved play input (`studioPlayInput`, `air` = "Air + touch" or `touch` = "Touch only"). |
| Instrument picker (128 GM, 16 categories) | `Models/SoundFontInstrument.swift`, `StartOverlayView.InstrumentPickerSheet` | partial (20 instruments, chip row) | engine (catalog) + studio-ui (sheet) | Category tabs per `GMCategory`. Free set is `FREE_SOUNDFONT_INSTRUMENT_IDS`. Everything else has `packId "pro"` and shows a PRO badge and the paywall. |
| Progression picker (145 incl. "free") | `Models/ChordProgression.swift`, `ProgressionPickerSheet` | partial (10) | engine + studio-ui | 14 categories. Premium means `category != .essentials && !isCustom` (`packId "pro"`). Custom progressions are parsed from text ("1 4 5 1", degrees 1–7, 1–64 chords) in the control sheet (`customProgressionEditor`). |
| Scale picker + custom scales | `Models/MusicTheory.swift` (`BuiltInScale` 23, `CustomScale`, `Scale` enum), `ScalePickerSheet`, `CustomScaleEditor`, `PersistenceManager` custom scales | partial (15, no custom) | engine + studio-ui | Free: Major, Minor, Dorian, Pentatonic, Blues. Others are `pro`. Custom scales require `pro`. At most 64 custom scales. Editor: the root is fixed; select at least two more notes; "Save & Use"; edit/delete in the list. Custom scales encode as an object in `SoundSetup` JSON (see 1.6). |
| Onboarding overlay | `Views/OnboardingView.swift`, `ContentView` overlay | missing | studio-ui | Shown once (`hasSeenOnboarding`) over the running **Scale** mode. Steps: "Play your first note" → "Now try a pinch" (camera) / "Tap or slide to play" (touch). Uses the middle scale note. Honours swap hands. |

### 1.3 Performance view (stage)

| Feature | iOS files | Android | WS | Notes |
| --- | --- | --- | --- | --- |
| Top bar | `ContentView.topBar` | partial | studio-ui | 4 beat dots (current one larger, media accent), "handstrudel" pill, Presets button, (SharePlay button: out of scope), close (✕) button that ends the session. Disabled while recording, during the countdown or during loop capture. |
| Bottom controls | `ContentView.bottomControls`, `loopRecordButton`, `recordButton` | missing | capture (buttons) + studio-ui (layout slot) | Left: loop record button with progress ring and count badge, plus "Loops". Centre: "½×" half-speed toggle above the record button. Right: settings (sliders) button. |
| Hand skeleton + themes | `Views/HandOverlayView.swift` (trail points, glow), `Models/HandTheme.swift` (7 themes; 5 premium with `visual_pack` → `plus_features`) | partial (no themes/trail) | studio-ui | Aspect-corrected to the video. Hidden while recording when `hideSkeletonWhenRecording` is on (default true). |
| Camera filters (26) | `Models/CameraFilter.swift`, `Views/CameraView.swift` | missing | studio-ui | Each filter is saturation, contrast, brightness, hue rotation, plus an optional colour overlay with blend mode. Premium filters use `plus_features`. Selected filter persists (`lastFilterId`). Android: `ColorMatrix` → `RenderEffect` on the `PreviewView` (COMPATIBLE/TextureView mode, API 31+). Below 31, apply only the overlay. |
| Weave visual (melodic family) | `Views/WeaveView.swift`, `ContentView` (`melodicActive`, `strudelHue`) | missing | studio-ui | Inputs: hue, energy=gain, space=reverb, brightness=lpf, speed from BPM, complexity=max(crush,shape). Large note name (72 pt ultralight) pulses on the downbeat. |
| Split wheel | `Views/SplitChordMelodyOverlayView.swift`, `Views/SplitTouchOverlay.swift` | done (mostly) | studio-ui | Already ported. Check: octave band labels, accessibility notes, latest-touch-wins chord stack. |
| Scale wheel | same overlay family, `ChordMelodyModeManager.Layout.scale` | missing | engine (core layout) + studio-ui | Melody side plays the full scale; the outer ring shifts octave ±1. `promo/lib/choreo.mjs` `GEOM` mirrors the iOS geometry. Use it as a cross-check. |
| Radial wheel | `Views/RadialChordMelodyOverlayView.swift` | missing | studio-ui | Chords on the outer ring, melody on the inner ring, rest in the centre. |
| Chord+Melody zones | `Views/ChordMelodyOverlayView.swift` | missing | studio-ui | Also used by SoundFont mode. 9 melody lanes. |
| Grid lanes (touchable) | `ContentView.noteGridOverlay`, `Views/GridTouchView.swift`, `ContentView.gridQuickBar` | missing | studio-ui | |
| Drum lanes + XY pad | `ContentView.drumZoneOverlay`, `drumXYPad` | missing | studio-ui | |
| Learn overlay | `Views/LearnOverlayView.swift`, `Views/LearnSongPicker.swift` | missing | studio-ui | Falling notes, hit effects, score, song complete card. Picker opens when Learn is chosen with no song loaded. |
| Note badge / code pill / beat ring | `ContentView` MARK sections | missing | studio-ui | |
| Toasts/notices | `draftPostNotice` (4 s), loop notices, randomized toast | missing | shell (global host) | |

### 1.4 Modes and sound engine

| Mode | iOS files | Android | Notes |
| --- | --- | --- | --- |
| Melodic / Flow / Hybrid / Lead | `Engine/MelodicModeController.swift`, `Engine/HandMapper.swift`, `Engine/ParamSmoother.swift`, `Models/ParamDefs.swift`, `Models/MusicConfig.generated.swift`, `Engine/StrudelBridge.swift` | partial (native approximation of Melodic only) | Strudel pattern driven by mapped params (`DEFAULT_MAPPING`: left y=noteIdx, x=lpf, spread=reverb; right y=gain, x=bpm, spread=delay). Smoothing EMA α=0.1. Struct rotates every 8 s (`STRUCTS`). Flow uses a dense 16th struct. Hybrid adds an imperative lead voice. Lead is the imperative voice only. Drum loops play under all of them. |
| Grid | `GridModeController/Manager.swift` | partial | Core `GridModeManager` exists. Settings: range 1/2/3 octaves, base octave 1–6, quantize. |
| Drums | `DrumModeController/Manager.swift` | partial | Lanes with pinch hits. intensity/complexity. |
| Chord+Melody (zones) | `ChordMelodyModeController.swift`, `ChordMelodyModeManager.swift` | missing | Grid layout in the core. |
| Radial / Split / Scale | same + `SoundFontModeController.swift` | Split only | Per-layout "Voice through SoundFont" toggle. Defaults: radial **false**, split **true**, scale **true**. SoundFont routing goes through `tickSoundFontMode`. Non-SF routing goes through Strudel `noteOn`. |
| SoundFont mode | `SoundFontModeController.swift`, `SoundFontEngine.swift` | partial | |
| Learn | `LearnModeController/Manager.swift`, `Models/LearnSong.swift` (14 songs) | missing | Pauses when the app is not active (`setLearnSceneActive`). |
| Quantize | `EngineController.quantizeEnabled/quantizeDiv` (¼, ⅛, 1/16), `quantizeBoundaryCrossed` | missing | Applies to the chord+melody family and Grid. Beat timing comes from Strudel `onBeat`. |
| Auto-strum, pad volume (0–0.6, default 0.6), swap hands | `EngineController`, `ControlSheetView.modeSection` | swap only | |
| Two drum-loop tracks | `ParamDefs.swift` `DRUM_LOOPS`, `EngineController.buildDrumCodeParts`, `ControlSheetView.drumTrackSection` | missing | Each track: loop, volume, BPM. Premium loops use `kit_808` / `kit_electronic` (also granted by Pro). |
| BPM + params (lock / manual value) | `ControlSheetView.bpmSection/paramsSection`, `EngineController.setManualValue/toggleLock` | missing | Hidden for the chord+melody family. |
| Waveform/sample picker (37) | `EngineController.swift` `WAVEFORMS`, `ControlSheetView.soundSection` | missing | Hidden when the active path uses SoundFont. |
| Haptics | `Engine/HapticManager.swift` | partial | beatPulse (downbeat stronger), noteTrigger, drumHit, learnPerfect/Good/Miss, lightTap. |
| First-note analytics hook | `EngineController.init` (`onNoteStarted`) | missing | Only while running and not paused. |
| Persistence of engine state | `Engine/PersistenceManager.swift` | missing | Keys and defaults: lastMode `splitchordmelody`, lastKey `C`, lastScale `Pentatonic` (or `lastCustomScale` JSON), lastWaveform `sawtooth`, lastSoundFont = default instrument, lastBPM 120, lastFilterId `none`, grid octave 3, range 2, quantize off/8, loop bars. |
| Mapping presets (Dreamy, Gritty, …) | `Models/MappingConfig.swift` `PRESETS` | Android shows them on its start screen | Only reachable through Siri in iOS 1.0.1. **Remove from the Android UI.** Keep the data if the engine needs it. |
| Save gesture → snippets → track sequencer | `SaveGestureDetector.swift`, `Models/Snippet.swift`, `ControlSheetView.snippetsSection/trackSection` | missing | **Unreachable in 1.0.1**: `DEFAULT_MAPPING` maps no axis to `"save"` and there is no mapping editor. Out of scope. |

### 1.5 Control sheet (in-session settings)

`App/ControlSheetView.swift`. Four tabs: **Sound / Play / Mix / Capture**. Opening the sheet pauses the engine (`engine.pause()`). Android today has `SplitSettingsSheet.kt` (key, scale, instrument, progression, swap). **Partial.** Owner: studio-ui. Capture-tab content comes from capture.

* **Sound:**
  * `StudioSettingsHero` with the current instrument (SF name or waveform name), key, scale and progression.
  * Harmony section: key, scale, progression, custom progression editor.
  * Waveform grid when not on the SoundFont path.
  * "Presets" row.
* **Play:**
  * Play input picker.
  * "Other modes" disclosure with buttons Split, Scale, Radial, Chord+Melody, SoundFont, Melodic, Flow, Hybrid, Lead, Grid, Drums, Learn. Collapsed by default when in Split or Scale.
  * Performance section per mode:
    * Chord-family: quantize, description text, custom progression, swap hands, auto-strum, Voice through SoundFont (radial/split/scale), pad volume.
    * Grid: quantize, range, base octave.
* **Mix:**
  * BPM and params (not chord-family).
  * Drums 1 and Drums 2 tracks.
  * Loops (when any are saved).
* **Capture:** recording settings (`recordingSection`), filters, hand themes.
* Header actions include a **Store** button. Locked items open `PaywallOverlay` for that pack.

### 1.6 Presets (sound setups)

| Feature | iOS files | Android | WS | Notes |
| --- | --- | --- | --- | --- |
| Named presets: save, apply, delete | `PersistenceManager.swift` (`NamedSoundSetup`, `SoundSetup`, `addPreset`), `ControlSheetView.SoundSetupsView` | missing | engine (model/store) + studio-ui (sheet) | Name: trimmed, ≤40 chars, unique by (sound, name). Applying while running pauses, then resumes. Applying from home starts a session. Locked packs block applying ("This setup is unavailable or requires a sound pack you don't own."). |
| Import/export preset pack (`.json`) | `SoundPresetPack`, `SoundPresetFile` | missing | engine (codec) + studio-ui (SAF picker) | Format `{format:"handstrudel-presets", version:1, presets:[{name, sound}]}`, pretty-printed with sorted keys. 1–128 presets, ≤256 KB. All-or-nothing validation, with the exact error strings from `PackError`. |
| `SoundSetup` JSON | `PersistenceManager.swift` lines ~280–335 | missing | engine | **Wire format shared with iOS and the server** (`videos.sound_setup` jsonb ≤4096 bytes). Fields: `version`(1), `instrument`, `waveform`, `key` (raw string, e.g. `"Db"`), `scale` (built-in raw name such as `"Harmonic Minor"`, **or** a custom-scale object), `progression` (id or `"custom"`), `customDegrees` (0-based, optional), `mode` (`melodic, flow, hybrid, lead, grid, drum, chordmelody, radialchordmelody, splitchordmelody, scalechordmelody, soundfont`), `bpm` (20–400), `useSoundFont`, `autoStrum`, `padVolume` (0–0.6), `gridOctave` (1–6), `gridRange` (1–3). Port `isValid` and `requiredPacks` exactly. |

### 1.7 Recording, drafts, export, loops, play-along

| Feature | iOS files | Android | WS | Notes |
| --- | --- | --- | --- | --- |
| Video recording of the stage | `ContentView` MARK Recording (≈2053–2340), ReplayKit `RPScreenRecorder` | missing | capture | Captures the app screen and app audio, plus the mic only if `recordPerformanceMicrophone` is on (default off). 60 s limit (`RecordingDrafts.recordingLimit`). Count-in (`RecordingCountIn`): with a backing BPM, 4 beats with a click (1480 Hz downbeat, 990 Hz others). Without one, 3 × 1 s. `recording_started`/`recording_saved` analytics. Interruption saves the partial take with a message. Backgrounding stops recording. |
| Half-speed recording | `ContentView` `recordAtHalfSpeed`, `EngineController.setRecordingTempo`, `supportsHalfSpeedRecording`, `RecordingDrafts.scaledAsset` | missing | capture + engine | Engine tempo ×0.5 while recording. The draft is time-scaled ×2 on export/post. Not allowed in Learn, while snippets/track play, or with loops that are not audio loops. |
| Watermark | `Engine/WatermarkManager.swift` | missing | capture | 140×50 (178 with credit) black 50 % rounded box, right side at 30 % height. QR to `https://handstrudel.com` or `…/watch?v=<source id>` when playing along. Visible only while recording. |
| Private drafts library | `Views/RecordingDraftsView.swift` (`RecordingDrafts` store, `RecordingDraft`, `RecordingDraftEditor`, `DraftTrimFilmstrip`, `PrivateDraftNameEditor`) | missing | capture | Per-draft folder with video and metadata. Title ≤60 chars, kept on device only. Trim with a 7-frame filmstrip, nudges and "Play selection". Rename, delete (confirmation: "Copies you've already saved or shared will stay where you put them."), Retake (when opened right after a take). Post status is persisted per account (`DraftPostSubmission` pending/published). |
| Export | `RecordingDraftsView` (`Save to Photos`, `Share video`, `Share audio (M4A)`), `RecordingDraftExport` | missing | capture | Android: MediaStore `Movies/HandStrudel`, share via FileProvider, M4A audio-only remux. Temp copies are deleted after sharing. |
| Audio loops | `ContentView.toggleAudioLoop/finishAudioLoop/resolveAudioLoop`, `Engine/AudioExporter.swift` (`CapturedLoopFile`), `Engine/EngineController` loop API, `App/ControlSheetView.LoopShelfView` | missing | capture (capture + shelf UI) + engine (storage/playback) | Captures **app audio** for `bars × 4 × 60/BPM` seconds (capped at 90 s), from the bar options in `LoopRecorder.barOptions`. Max 20 loops. Shelf: play/stop layered, rename, mute, gain, delete, export audio. |
| Play-along (backing track) | `ContentView.prepareBacking/playBacking/backingControls`, `BackingTrack`, `PerformanceAudio`, `BackingTrackVolume` | missing | capture | Re-fetches the video and requires `backing_enabled`. Downloads the audio, loops it with an adjustable volume (`playAlongBackingVolume`), and auto-plays when the session starts. Applies the source's `sound_setup` if entitled. Credit `@user` is carried into the post (`BackingCredit`, `source_video_id`) and the watermark QR. |

### 1.8 Store, paywall and Pro gating

| Feature | iOS files | Android | WS | Notes |
| --- | --- | --- | --- | --- |
| Entitlements | `Models/StoreManager.swift` | missing | store | Entitlements: `pro`, `plus_features`, `studio_pack`, `party_pack`, `kit_808`, `kit_electronic`. `isUnlocked(packId)` maps packId → entitlement via `entitlementId(for:)`. Unknown packs and `filter_pack`/`visual_pack`/`theme_pack`/`scale_pack` map to `plus_features`. `hasProAccess`, `hasPlusFeatures`, `hasSubscription`. |
| Restore | `StoreManager.restorePurchases`, `StoreView.RestorePurchasesButton` | missing | store | Outcomes: accessAvailable / noActivePurchases / requestedItemUnavailable / cancelled / failed. Only active entitlements count. |
| Store screen | `Views/StoreView.swift` | missing | store | Sections: Drum kits (808, Electronic), Pro, HandStrudel+ (RevenueCat paywall), Restore, Privacy + Terms links. iOS links Apple's standard EULA. **Android must link `https://handstrudel.com/terms`**. |
| Pack paywall sheet | `Views/PaywallOverlay.swift` | missing | store | Name, description, "INCLUDES" list, price, buy button, error. |
| Account-linked purchases | `AuthManager.apply` → `Purchases.logIn(userId)`. `signOut` → `logOut` | missing | store (listener) | Lets Pro bought on iOS unlock on Android for the same signed-in account, if both apps use the same RevenueCat project. |
| Gated content | instruments, progressions, scales, custom scales (pro). Filters, hand themes, premium scales (plus). Drum kits (kit_*) | missing | consumers call the store seam | |

### 1.9 Social

All iOS `Social/*` files map to Android **missing**. Owner: social, unless noted.

* **Backend client:**
  * `SocialConfig.swift`: Supabase URL and publishable key, media bases (`media.handstrudel.com` legacy, `clips.handstrudel.com` for `videos|thumbs/<x>/screened/<y>` keys), terms/guidelines/watch/support URLs, `isConfigured`, `emailSignInEnabled = true`, `creatorURL`.
  * Android has no review URL equivalent of `reviewURL`. Use the Play listing.
* **Auth:**
  * `AuthManager.swift`: session listener, profile load, email OTP (`signInWithOTP` + `verifyOTP(type: email)`, 6-digit code, Resend SMTP), username completion, display name (≤40), avatar via `profile-avatar` function, sign out, delete account (`delete-account` function; a lost response is reported as unconfirmed and does not sign out).
  * `SignInView.swift`: "Your music. Your stage.", Apple button, "Email me a code", "Make music as a guest".
  * `ProfileSetupView`: "Choose a username", 3–20 chars `[a-z0-9_]`, terms and community guidelines links. Saving sets `accepted_terms_at`; this is the EULA acceptance that posting requires (`needsProfileSetup`).
* **Models:** `SocialModels.swift`: `Profile`, `Video` (lenient decoding; an invalid `sound_setup` becomes nil), `VideoPostFields`, `VideoComment` (max 300 unicode scalars), `CreatorActivity`, `PublicCreator`, `PostSearch` (escaping), `BackingCredit`, `WeeklyChallenge`, `PerformanceLink`, `CommentReportReason`, upload request/response types.
* **Service:** `FeedService.swift`.
  * Tables/views used: `feed_videos`, `following_videos`, `following_activity_videos`, `my_reposted_videos`, `saved_videos`, `videos`, `likes`, `follows`, `blocks`, `reports`, `comments`, `video_comments`, `comment_likes`, `comment_reports`, `profiles`, `public_creators`, `video_bookmarks`, `video_audio_downloads`, `weekly_challenges`.
  * RPCs: `record_video_view` (with a per-video watch receipt), `record_video_share`, `set_video_bookmark`, `set_video_repost`, `delete_video_comment`, `record_app_usage_event`.
  * Functions: `sign-upload`, `publish-upload`, `delete-video`, `delete-account`, `profile-avatar`.
  * Has fallbacks for missing views/functions (`isMissingView`, `isMissingFunction`, `Unavailable` messages).
* **Feed:** `FeedView.swift` (3.5k lines).
  * Modes **Discover / Latest / Following**. Discover uses client re-ranking (`DiscoveryFeedRanking`: freshness `3/(1+h/72)` + `min(log1p(likes),4)*0.65/(1+h/168)`, never the same creator twice in a row).
  * Full-screen vertical paging (`PagedFeed`, `FeedNavigation.destination`: past either edge it picks a random different clip). Preloading of the next clips' frames (`FeedVideoPreloader`), warm first clip.
  * Playback controls: tap to pause, seek slider, progress strip, retry. A qualified view counts after `min(2 s, duration/2)` of watching (`QualifiedClipWatch`).
  * Action rail: like, comments, share (`VideoShareSheet`, records share), repost, save/bookmark, "Play this sound", "Play along", more menu (report, block, delete own post, allow audio downloads, stop allowing play-along, download audio).
  * Search (`PostSearchView`, `@handle` search, "Broaden search").
  * Activity inbox (`ActivityInboxView`, unread badge, mark read).
  * Weekly play-along challenge.
  * Remixes list ("Inspired by @x").
  * Saved performances library (`PerformanceLibraryView`), `CreatorVideoView`, `PublicCreatorView`, empty state "Make the first one".
* **Comments:** `CommentsView.swift`. Threaded replies (load more, hide replies), like, delete own (also removes replies), report with reasons, block author, owner can close comments ("Manage comments"/"Close comments"), "Sign in to comment".
* **Profile:** `ProfileView.swift`, `ProfileImageStore.swift`.
  * Own profile: portfolio tabs (posts, reposts), edit profile (display name, photo choose/remove), share profile (`creatorURL`).
  * Account settings: Appearance, Usage Analytics, Get help (support URL), Write a review, Terms of Use, Community Guidelines, Blocked users (unblock), Sign out, "Delete account…" with a "Delete forever" confirmation.
  * Also shows other creators' profiles with follow.
* **Post composer:** `PostComposerView.swift` (owner: capture, see the WS notes). Caption ≤150, toggles "Allow comments", "Allow others to play along", "Share playable preset" (attaches `sound_setup`), "Inspired by @x" credit, "Uploading…" progress, `DraftPostUpdate` notices ("Video submitted for checking.", "Video posted.", failure detail).
* **Upload pipeline:** `VideoUploader.swift` (owner: capture).
  1. Transcode to 720 px wide H.264, even height, 30 fps, bitrate `min(2.5 Mbps, (12 MiB·8)/duration − 128 kbps)`, AAC 128 kbps, ≤15 MiB, ≤60 s.
  2. Thumbnail JPEG q0.75 at `min(1 s, duration/2)`.
  3. `sign-upload` `{videoBytes, thumbBytes, moderationVersion: 2}`, then PUT both to the presigned R2 URLs.
  4. Persist `pending` **before** submit.
  5. `publish-upload` `{action:"submit", id, fields}`, then poll `{action:"status"}` every 2 s for up to 120 s.
  6. Status `published` / `held` / `failed` / `checking` / `reserved`, with the exact user-facing strings in `track()`.
  7. A 404 "Upload not found." or 409 expiry clears the submission.
  8. Requests are pinned to the account that started the post.

### 1.10 Out-of-scope iOS features present in code (see section 2)

SharePlay jam (`Engine/JamSession.swift`, `JamButton`, `JamInvitation`), Siri shortcuts (`Engine/SiriShortcuts.swift`), Sign in with Apple. Also present but **dead code** (not referenced outside their own file, and their targets are not in `project.yml`): `LiveActivityManager`, `WatchSessionManager`, `SpatialAudioManager`, `MotionManager`, `iMessageManager`, `LoopSharingManager`, the `HandStrudelWatch`/`HandStrudelLiveActivity` folders.

---

## 2. Out of scope for Android 1.0.1 parity

| iOS feature | Why it's out |
| --- | --- |
| **SharePlay jam** (`JamSession.swift`, top-bar Jam button) | Built on Apple GroupActivities and FaceTime, which have no Android equivalent. A cross-platform jam would need a new realtime backend: new product work, not parity. Hide the button. |
| **Siri shortcuts** (`SiriShortcuts.swift`: start Dreamy/Gritty, grid, drums, toggle loop recording) | Apple App Intents. The closest Android equivalent (static launcher shortcuts or Assistant App Actions) targets the legacy mapping presets, which 1.0.1 exposes nowhere else. Optional later: launcher shortcuts for "Start playing" and "Private drafts". |
| **Sign in with Apple** | Native only on Apple platforms. The repo's `supabase/config.toml` has `[auth.external.apple] enabled = false` and no Google provider; it is local-dev config, so the production dashboard state is unknown. Android uses **email OTP** (enabled: `otp_length = 6`, custom template `supabase/templates/otp.html`) plus **Google** only if the owner enables the Google provider (see Risks). Apple-only iOS users with private-relay emails can't reach the same account on Android without Apple OAuth via browser. Track that as a fast-follow (Risk R5). |
| **Apple Watch, Live Activities, iMessage, spatial audio (head tracking), device-motion, `.handstrudel` loop file sharing** | Apple platform APIs, and dead code in 1.0.1 (never referenced, no build targets). Nothing user-facing to match. |
| **App Store review deep link** (`SocialConfig.reviewURL`) | Replaced by the Play In-App Review API and a Play listing link. |
| **Mapping presets UI, save gesture, snippets, track sequencer** | Unreachable in iOS 1.0.1 (see 1.4). |
| **`Weave` on non-melodic modes, promo `DemoDirector`** | iOS shows Weave only for the melodic family. DemoDirector is DEBUG-only promo tooling. |
| **Legacy Studio/Party pack purchases** | iOS still lists drum kits and Pro. The studio/party pack entitlements only gate legacy mapping presets, which are unreachable. Android sells nothing it can't show (see store WS). |

---

## 3. Workstreams

Six workstreams run in parallel, one git worktree each, branched from the Phase 0 scaffold commit:

| WS | Name | One-line goal |
| --- | --- | --- |
| 1 | `shell` | App shell, navigation, theme, prefs, deep links, analytics, review, global notices |
| 2 | `engine` | All audio and mode logic, Rust core, catalogs, persistence, Strudel WebView bridge |
| 3 | `studio-ui` | Everything drawn on the Music tab: home, stage, overlays, control sheet, pickers, onboarding |
| 4 | `capture` | Recording, drafts, export, audio loops, play-along, watermark, post composer + upload |
| 5 | `social` | Supabase auth, feed, comments, profile/account, moderation actions |
| 6 | `store` | RevenueCat, entitlements, store screen, paywall sheet |

If only five agents are available, fold **store** into **shell**.

If seven are available, split **social** into:
* **social-feed:** owns `social/data/**`, `ui/social/feed/**`, `ui/social/comments/**`.
* **social-account:** owns `social/auth/**`, `ui/social/account/**`, and codes against `FeedService` signatures, which are a 1:1 port of `FeedService.swift`.

### 3.0 Phase 0: seams scaffold (integrator, before fan-out, about 1–2 h)

Do this as **one commit** on `claude/android-parity-1.0.1` so every worktree starts from the same seams. It contains only build config, manifest, package skeletons and the interfaces below, with `TODO()` bodies. Each interface has exactly one owning WS that implements it. Everyone else codes against it, and uses a fake in their own tests.

**Build (`android/build.gradle.kts`, `android/app/build.gradle.kts`, `android/settings.gradle.kts`), owned by the integrator:**

* `minSdk = 29`, raised from 26. Reasons:
  * `AudioPlaybackCaptureConfiguration` is needed for app-audio recording and loops.
  * Scoped MediaStore writes need no storage permission.
  * About 95 % of active devices.
* Turn on `buildFeatures.buildConfig = true`.
* Add plugin `org.jetbrains.kotlin.plugin.serialization` (same Kotlin version) and `org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3`, `org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0`.
* Tests:
  * `testImplementation("junit:junit:4.13.2")`, `kotlinx-coroutines-test`, `org.json:json` (for JVM tests).
  * `testOptions.unitTests.isReturnDefaultValues = true`.
  * JVM tests must not load the `:core` .so. Keep pure-Kotlin logic separate from UniFFI calls, or guard them.
* **BuildConfig fields:**
  * `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `MEDIA_BASE_URL`, `CLIP_MEDIA_BASE_URL`:
    * Default: parsed at configuration time from `ios/HandStrudel/HandStrudel/Social/SocialConfig.swift` (`productionURL`, `productionAnonKey`, `productionMediaBase`, `productionClipMediaBase`) with a regex. That gives one source of truth, so nobody copies the key by hand.
    * Override with Gradle properties `handstrudel.supabaseUrl` etc. (local stacks).
    * Never log or print the key in build output.
  * `REVENUECAT_API_KEY`: Gradle property `handstrudel.revenuecatApiKey` or env `REVENUECAT_ANDROID_API_KEY`. Default `""`.
  * `GOOGLE_WEB_CLIENT_ID`: property `handstrudel.googleWebClientId`. Default `""`.
* Kotlin/AGP: the project is on Kotlin 2.0.21 / AGP 8.7.0 / compileSdk 35. Before fan-out, pick dependency versions in each WS that compile against Kotlin 2.0.21. If supabase-kt or Coil require Kotlin 2.1, bump Kotlin in Phase 0, not in a WS.
* Each WS adds **only** its own `implementation(...)` lines (listed per WS), in a block headed `// --- <ws> ---`, so merges are line-additive.

**Manifest (`android/app/src/main/AndroidManifest.xml`), finalised in Phase 0 and owned by shell afterwards:**

* Permissions:
  * Existing: `INTERNET`, `CAMERA`, `RECORD_AUDIO`, `VIBRATE`.
  * Add: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PROJECTION`, `POST_NOTIFICATIONS` (FGS notification on 33+). RevenueCat merges `BILLING` itself.
* `uses-feature android.hardware.camera` and `.front` → `required="false"`. The app is playable by touch, matching the iOS fallback.
* `MainActivity` (singleTop) intent filters:
  * `handstrudel://` hosts `watch`, `comments`, `sound`, `play`.
  * `https://handstrudel.com/watch` with `android:autoVerify="true"`.
* `<provider androidx.core.content.FileProvider android:authorities="${applicationId}.fileprovider">` with `res/xml/file_paths.xml` (`cache-path exports/`, `files-path drafts/`).
* `<service android:name=".capture.CaptureService" android:foregroundServiceType="mediaProjection" android:exported="false"/>`.

**Seam files (package skeleton with interfaces):**

```kotlin
// A/app/AppServices.kt                          — owner: shell
// Created once in MainActivity, provided via CompositionLocal LocalAppServices.
class AppServices(
    val prefs: AppPrefs,                 // shell
    val analytics: AppAnalytics,         // shell
    val engine: StudioEngine,            // engine  (EngineController implements it)
    val store: StoreGate,                // store
    val auth: AuthSession,               // social
    val capture: CaptureController,      // capture
)

// A/ui/nav/AppNavigator.kt                      — owner: shell
enum class Destination { Feed, Music, Account }
interface AppNavigator {
    val destination: StateFlow<Destination>
    fun select(d: Destination)
    fun startSession(setup: SoundSetup? = null, useCurrentSoundAsFallback: Boolean = false) // iOS startSession
    fun trySharedSound(setup: SoundSetup)        // errors if a session is running
    fun prepareBacking(video: Video)             // delegates to capture.prepareBacking, switches to Music
    fun openPerformance(link: PerformanceLink)   // deep links & "view post"
    fun showNotice(text: String, millis: Long = 4000)
    fun showError(title: String, message: String)
}

// A/ui/theme/StudioTheme.kt                     — owner: shell
enum class StudioTheme { VOLT, TIDE, AFTERGLOW, PAPER }; data class StudioPalette(...)
val LocalStudioPalette: ProvidableCompositionLocal<StudioPalette>
@Composable fun StudioThemePickerSheet(onDismiss: () -> Unit)   // used by studio-ui home & social account settings

// A/engine/StudioEngine.kt                      — owner: engine (see WS2 for the full member list)
// A/store/StoreGate.kt                          — owner: store
interface StoreGate {
    val isConfigured: Boolean                    // false when REVENUECAT_API_KEY is blank
    val state: StateFlow<StoreState>             // products, loading, restoring, customer info
    fun isUnlocked(packId: String): Boolean
    val hasProAccess: Boolean; val hasPlusFeatures: Boolean; val hasSubscription: Boolean
    suspend fun purchase(activity: Activity, productId: String): PurchaseResult
    suspend fun restore(packId: String? = null): RestoreOutcome?
    suspend fun logIn(appUserId: String); suspend fun logOut()
}
@Composable fun PaywallSheet(packId: String, onDismiss: () -> Unit)   // store
@Composable fun StoreScreen(onDismiss: () -> Unit)                    // store

// A/social/AuthSession.kt                       — owner: social
interface AuthSession {
    val isConfigured: Boolean
    val userId: StateFlow<UUID?>; val profile: StateFlow<Profile?>
    val needsProfileSetup: Boolean
    suspend fun accessToken(): String?           // current session JWT (capture pins uploads to it)
    suspend fun functionsFor(accountId: UUID): SupabaseFunctionsInvoker  // throws if session user ≠ accountId
}
// A/social/SocialEntryPoints.kt                 — owner: social
object SocialEntryPoints {
    @Composable fun FeedTab(isActive: Boolean, onFullscreenChanged: (Boolean) -> Unit, tabBar: @Composable (overVideo: Boolean) -> Unit)
    @Composable fun AccountTab()
    @Composable fun CreatorVideoSheet(video: Video, onDismiss: () -> Unit)
    @Composable fun CommentsSheet(video: Video, onDismiss: () -> Unit)
    @Composable fun SignInSheet(onDismiss: () -> Unit)   // capture shows it from the composer
    suspend fun fetchVideo(id: UUID): Video?              // FeedService.video
}
// A/social/model/*                              — owner: social. Video, Profile, BackingCredit, PerformanceLink (+ parser)

// A/capture/CaptureController.kt                — owner: capture
interface CaptureController {
    val state: StateFlow<CaptureState>           // isRecording, busy, countdown, loopCapturing, loopProgress, backing (credit, playing, volume)
    fun prepareBacking(video: Video)             // iOS prepareBacking
    fun onSessionEnded(); fun onAppBackgrounded()
}
object CaptureEntryPoints {
    @Composable fun StageBottomControls(onOpenSettings: () -> Unit)   // loop button+Loops, ½×, record button
    @Composable fun StageOverlays()                                    // countdown, watermark, backing controls, recording toasts
    @Composable fun RecordingSettingsSection()                        // control sheet → Capture tab
    @Composable fun DraftsSheet(onDismiss: () -> Unit)
    @Composable fun LoopShelfSheet(onDismiss: () -> Unit)
    val isRecordingLocked: StateFlow<Boolean>    // studio-ui disables presets/close/settings while true
}

// A/ui/studio/StudioEntryPoints.kt              — owner: studio-ui
object StudioEntryPoints {
    @Composable fun MusicHome()                  // StartOverlayView equivalent
    @Composable fun Stage()                      // full performance view
}
```

`SoundSetup` and the catalogs live in `A/models/` (owner: engine). `Video` and `PerformanceLink` live in `A/social/model/` (owner: social). Phase 0 creates their data classes **with all fields**, so other workstreams can compile against them. The field lists are in 1.6 and 1.9, copied from `PersistenceManager.swift` and `SocialModels.swift`.

**Moves in Phase 0, so WS file sets are disjoint:**
* `A/ui/SplitChordMelodyOverlay.kt`, `A/ui/SplitSettingsSheet.kt`, `A/ui/HandOverlay.kt` and `A/ui/CameraPreview.kt` → `A/ui/studio/`.

#### 3.0.1 Phase 0 as built (decisions; these override the sketch above where they differ)

The scaffold commit compiles, runs `:app:testDebugUnitTest`, and keeps the app playable (Music home → Start playing → the old Split stage) through stubs. Where the sketch above was ambiguous, this is what was built. Code against the files, not the sketch.

**Seam files and their Phase 0 stub implementations** (replace the stub in `AppServices.create` at integration; keep the interface):

| File | Types | Owner | Phase 0 implementation |
| --- | --- | --- | --- |
| `A/app/AppServices.kt` | `AppServices` (+ `reviewPrompt`), `LocalAppServices`, `AppServices.create(context)` | shell | wires the stubs below |
| `A/app/AppPrefs.kt` | `AppPrefs` (typed StateFlow + setter per iOS key, plus `feedMuted` for social), `PrefsStore`, `SharedPrefsStore`, `InMemoryPrefsStore` (use in tests), `StoreBackedAppPrefs` | shell | real (SharedPreferences `app`); shell may swap to DataStore behind the same interface |
| `A/app/AppAnalytics.kt` | `AppAnalytics`, `AppAnalyticsEvent` | shell | `NoopAppAnalytics` |
| `A/app/ReviewPrompt.kt` | `ReviewPrompt.recordSuccessfulTake(draftId)` (capture calls it) | shell | `NoopReviewPrompt` |
| `A/app/Share.kt` | `shareFile(context, uri, mime)`, `shareText(...)` | shell | real |
| `A/ui/nav/AppNavigator.kt` | `Destination`, `AppNavigator`, `LocalAppNavigator` | shell | `DefaultAppNavigator.kt` (lazy camera permission, notices, errors, deep-link sheets) |
| `A/ui/theme/StudioTheme.kt` | `StudioTheme` (hex values ported), `StudioPalette`, `LocalStudioPalette`, `StudioThemePickerSheet` | shell | real palettes, plain picker |
| `A/ui/HandStrudelApp.kt`, `A/ui/MainActivity.kt` | root composable, `DestinationTabs`, `SocialUnavailable` | shell | minimal tabs + Stage takeover + WebView host |
| `A/engine/StudioEngine.kt`, `A/engine/StudioEngineModels.kt` | `StudioEngine`, `PresetPackException`; `PlayInput`, `CameraIssue`, `StudioMode`, `DrumTrackState`, `ChordMelodyDisplay`, `LaneDisplay`, `Learn*`, `SavedLoop`, `AppAudioTap` | engine | `LegacyStudioEngine.kt` (adapter over the old `EngineController`) |
| `A/models/SoundSetup.kt`, `A/models/Scales.kt`, `A/models/Waveforms.kt` | `SoundSetup`, `SoundSetupMode`, `NamedSoundSetup`, `SoundSetupJson`; `CustomScale`, `ScaleSelection`; `Waveform`, `WAVEFORMS` | engine | real wire codec + `isValid`/`requiredPacks` |
| `A/store/StoreGate.kt` | `StoreGate`, `StoreState`, `StoreProduct`, `PurchaseResult`, `RestoreOutcome` | store | `UnconfiguredStoreGate` (= no-key behaviour) |
| `A/ui/store/StoreSheets.kt` | `PaywallSheet`, `StoreScreen`, `ProBadge` | store | stubs |
| `A/social/AuthSession.kt` | `AuthSession`, `SupabaseFunctionsInvoker`, `FunctionResponse`, `AccountChangedException` | social | `SignedOutAuthSession` (`isConfigured = false`) |
| `A/social/SocialEntryPoints.kt` | `SocialEntryPoints` | social | placeholders; `fetchVideo` returns null |
| `A/social/model/{Profile,Video,BackingCredit,PerformanceLink}.kt` | all fields from `SocialModels.swift`; `PerformanceLink.parse` implemented | social | real |
| `A/capture/CaptureController.kt`, `A/capture/CaptureService.kt` | `CaptureController`, `CaptureState`, `BackingState`; FGS stub | capture | `NoopCaptureController` |
| `A/ui/capture/CaptureEntryPoints.kt` | `CaptureEntryPoints` | capture | settings button only |
| `A/ui/studio/StudioEntryPoints.kt` | `StudioEntryPoints.MusicHome/Stage` | studio-ui | minimal home + the old Split performance screen |
| `A/common/Serializers.kt` | `UuidSerializer` (lowercase), `SwiftUuidSerializer` (uppercase), `SwiftDoubleSerializer` | integrator (frozen; coordinate changes) | real |

**Decisions:**
1. **Dependencies are pre-pinned.** Every WS dependency from sections WS1–WS6 is already in its `// --- <ws> ---` block of `android/app/build.gradle.kts`, resolved and compiled together on Kotlin 2.0.21 / AGP 8.7.0. Kotlin is **not** bumped: supabase-kt **3.0.2** (+ Ktor 3.0.1) is the newest release built with Kotlin 2.0.21 (3.0.3+ needs 2.1). Coil 3.0.4, Media3 1.4.1, RevenueCat 8.10.8, credentials 1.3.0 all resolve. A WS that needs another dependency adds it inside its own block only. Engine's asset copy task goes in the `// --- engine (assets) ---` block above `dependencies`.
2. **BuildConfig.** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `MEDIA_BASE_URL`, `CLIP_MEDIA_BASE_URL` are parsed from `SocialConfig.swift` (`static let <name> = "…"`). Override with `-Phandstrudel.supabaseUrl`, `handstrudel.supabaseAnonKey`, `handstrudel.mediaBaseUrl`, `handstrudel.clipMediaBaseUrl`. `REVENUECAT_API_KEY` from `handstrudel.revenuecatApiKey` or env `REVENUECAT_ANDROID_API_KEY`; `GOOGLE_WEB_CLIENT_ID` from `handstrudel.googleWebClientId`. The key ends up only in the gitignored generated `BuildConfig.java`; never log it.
3. **`SoundSetup` lives in `A/models/SoundSetup.kt`** (not `engine/persistence/`), because social and capture import it. `SoundPresetPack`, `EnginePersistence` and `CustomScaleStore` still go in `A/engine/persistence/`. Encode/decode **only** through `SoundSetupJson` / `SoundSetup.encode()` / `SoundSetup.decode()`: it ignores unknown keys, writes `version`, omits a null `customDegrees`, prints whole doubles as `120` (Swift style) and custom-scale UUIDs uppercase, so Android output equals iOS output modulo key order. `ScaleSelection` = `BuiltIn(Scale)` | `Custom(CustomScale)` with a string-or-object serializer. `Scale.rawValue` is the wire name (iOS `BuiltInScale.rawValue`); engine adds the 8 missing scales and changes `displayName` to the iOS display names ("Major Pentatonic", "Minor Blues") without touching `rawValue`.
4. **`isValid` / `requiredPacks` are ported exactly**, but resolve against today's short catalogs. `SoundFontInstrument.packId` and `ChordProgression.packId` are `null` stubs (TODO(engine)); engine ports the 128 instruments (note iOS ids such as `electric_piano_1` differ from today's Android `rhodes`), the 145 progressions with categories and `ChordProgression.parse`. `WAVEFORMS` is fully ported into `models/Waveforms.kt` (the old 4-entry list in `ParamDefs.kt` was removed): **iOS has 38 entries** (8 synths + 30 samples), not 37; the iOS list wins.
5. **`StudioEngine` shape.** Observables are `StateFlow`s with a `setX(...)` per settable value. Related display state is bundled: `chordMelody: StateFlow<ChordMelodyDisplay>`, `lanes: StateFlow<LaneDisplay>`, `learn: StateFlow<LearnDisplay>`; drum tracks are `drumTrack1/drumTrack2: StateFlow<DrumTrackState>` with `setDrumLoop/Volume/BPM(track, …)`. Learn songs are referenced by a stable `songId: String` (engine's catalog), not iOS's random UUID. Touch: `split*/scale*/radial*/zones*` enter/exit, `gridLaneTouchOn/Slide/Off`, `drumLaneTap`, `drumPad(x, y)`. Shell reports camera permission denial with `reportCameraIssue(PERMISSION_DENIED)` (which falls back to TOUCH). Capture publishes loop-capture progress with `updateLoopCapture(...)` and hands finished files to `saveCapturedLoop(file, …)`. `strudelWebView` is a `StateFlow<WebView?>` that shell hosts once it is non-null.
6. **`isRecordingLocked` is on `CaptureController`**, not on the `CaptureEntryPoints` object, so it is backed by the controller instance. `CaptureEntryPoints` lives in `A/ui/capture/CaptureEntryPoints.kt` (capture's UI package). Its composables, and `StudioEntryPoints`/`SocialEntryPoints`, read services from `LocalAppServices.current` / `LocalAppNavigator.current`.
7. **`StoreGate.isUnlocked(packId: String?)`** takes a nullable id (free content passes `null`), and `StoreGate.bind(userId)` is how store follows sign-in (called once in `AppServices.create`). Store UI composables live in `A/ui/store/StoreSheets.kt`; WS6 may split the file, keeping the signatures.
8. **`AuthSession.functionsFor(accountId)`** returns a `SupabaseFunctionsInvoker` whose `invoke(function, JsonElement)` returns `FunctionResponse(status, body)` for every HTTP status (callers map 404/409 like iOS) and throws only on transport failure or `AccountChangedException`.
9. **`Video` keeps timestamps as the raw server strings** (`createdAt` is also the feed cursor, iOS `rawCreatedAt`); use `createdAtInstant` / `savedAtInstant`. `sound_setup` decodes leniently (invalid → null) via `LenientSoundSetupSerializer`. Media URLs (`videoURL`/`thumbURL`) are social's to add with `SocialConfig.mediaURL`.
10. **Engine adapter.** `LegacyStudioEngine` drives the old `EngineController`, so the Split stage, overlay and settings sheet keep working. `StudioEntryPoints.Stage` still reaches the legacy controller for the Split overlay and `SplitSettingsSheet`; studio-ui removes that cast when it ports them to `StudioEngine`, and engine deletes `LegacyStudioEngine` when `EngineController` implements `StudioEngine`.
11. **Permissions.** Launch no longer asks for anything. `DefaultAppNavigator.startSession` asks for CAMERA only when the play input is Air; denial reports `PERMISSION_DENIED` and starts in TOUCH. RECORD_AUDIO is not requested anywhere yet (capture asks when mic recording is turned on).
12. **Verified.** `./gradlew :app:assembleDebug :app:testDebugUnitTest` passes; on an API 36 emulator the app cold-starts on Music, Start playing opens the Split stage, the settings sheet and ✕ work, Feed/Account show placeholders, and `handstrudel://watch/<uuid>` routes to `openPerformance` ("This performance isn't available." with the stub social). The debug APK is ~175 MB with all pre-pinned deps and four ABIs; small emulators may need more data space.
13. **Tests.** `AT/models/SoundSetupJsonTest.kt` (iOS payloads with a built-in and a custom scale, round trip, `isValid` bounds) and `AT/social/SocialModelSeamTest.kt` (`Video` lenient decode, `PerformanceLink` parsing). Each WS extends the tests for the code it owns. The legacy `models/Presets.kt` grid is gone from the UI but the data stays (engine decides).

---

### WS1 — `shell`: app shell and platform

**Goal.** The iOS `ContentView` skeleton: three tabs, the studio takeover, theme, prefs, deep links, analytics, review prompt and global alerts/notices. Shell owns the activity and the composition root, and wires every other WS's entry points together.

**Owns:**

* Existing: `A/ui/MainActivity.kt`, `A/ui/HandStrudelApp.kt`, `AndroidManifest.xml` (after Phase 0), `res/values/themes.xml`, launcher resources, root `android/build.gradle.kts`.
* New:
  * `A/app/AppServices.kt`
  * `A/app/AppPrefs.kt`: DataStore Preferences wrapper. All keys are named as on iOS: `studioTheme`, `hasSeenOnboarding`, `studioPlayInput`, `appUsageAnalyticsEnabled`, `creatorReviewMilestones`, `hideSkeletonWhenRecording`, `recordPerformanceMicrophone`, `recordAtHalfSpeed`, `playAlongBackingVolume`. Other WSs read and write them through typed accessors added here in Phase 0.
  * `A/app/AppAnalytics.kt`
  * `A/app/ReviewPrompt.kt` (`CreatorReviewMilestones` + Play review)
  * `A/app/DeepLinkRouter.kt`
  * `A/ui/nav/AppNavigator.kt` + impl
  * `A/ui/nav/DestinationTabs.kt`
  * `A/ui/theme/StudioTheme.kt`
  * `A/ui/theme/StudioThemePickerSheet.kt`
  * `A/ui/settings/UsageAnalyticsScreen.kt`
  * `A/ui/common/NoticeHost.kt`
  * `A/ui/common/SocialUnavailable.kt`

**Port from:** `iOS/App/HandStrudelApp.swift`, `iOS/App/ContentView.swift` (body, `destinations`, `destinationTabs`, notices, review task, `onOpenURL`, scenePhase handling, `canShowReview`), `iOS/App/AppAnalytics.swift`, `iOS/Views/StudioTheme.swift`, `iOS/App/UIKitBridges.swift` (`ShareSheet` → a shared `shareFile(uri, mime)` helper here).

**Behaviour checklist:**
* The root `Box` layers the Feed (always composed when social is configured, so playback can preload). It is visible only on the Feed tab when no session runs.
* Below the feed: the destinations, the Stage when `engine.isRunning`, and the hidden 1×1 `AndroidView` hosting `engine.strudelWebView`. The WebView must stay attached, as iOS keeps it in the hierarchy.
* The status bar is hidden while running or while the feed is full-screen.
* Lifecycle (`ON_STOP`/`ON_START`) is forwarded to `engine.setSceneActive`, `capture.onAppBackgrounded()`, and the analytics active day.
* Deep link intents (`onCreate` + `onNewIntent`) go to `PerformanceLink.parse` (social) and then `navigator.openPerformance`. That opens `CreatorVideoSheet`, `CommentsSheet`, `trySharedSound(video.soundSetup)` or `prepareBacking`, per link kind, the same as `ContentView.openPerformance`.
* Runtime permissions: camera is requested only when a session starts with Air input. Denial feeds the engine's camera issue. Mic is requested only when the user turns on mic recording.

**Dependencies:** `androidx.datastore:datastore-preferences:1.1.1`, `com.google.android.play:review-ktx:2.0.2`, `androidx.browser:browser:1.8.0` (Custom Tabs for terms/guidelines/support links, also used by social).

**Acceptance (emulator):**
1. A cold start lands on **Music**. Tabs switch. Feed and Account show placeholders when `SUPABASE_ANON_KEY` is blank.
2. The theme picker switches all four palettes live. Paper renders light. The choice persists across restarts.
3. `adb shell am start -d "handstrudel://watch/<uuid>"` and `-d "https://handstrudel.com/watch?v=<uuid>"` route to `navigator.openPerformance`. Use a fake social in this WS.
4. Starting a session hides the tabs and shows the Stage. Closing returns to Music.
5. With analytics on, `active_day` fires at most once per day. Verify with a fake sender.

**Unit tests (`AT/app/`):**
* `CreatorReviewMilestonesTest`: port the logic. Duplicates are ignored, the 3-take threshold, the version gate, the 90-day gate.
* `AppAnalyticsTest`: opt-out sends nothing. `active_day`/`return_day` semantics. `first_note` once. Fake prefs and clock.
* `StudioPaletteTest`: hex values match iOS.

---

### WS2 — `engine`: audio, modes, core, catalogs, persistence

**Goal.** Make `EngineController` feature-equal to `iOS/Engine/EngineController.swift` for every reachable mode, with identical music behaviour. It exposes the `StudioEngine` interface that studio-ui and capture code against.

**Architecture decision: run Strudel in an Android WebView.** iOS voices Melodic, Flow, Hybrid, Lead, Grid, Drums, both drum-loop tracks, the 37 `WAVEFORMS` (29 are sampled instruments) and the non-SoundFont chord+melody path through Strudel. Re-implementing that in Kotlin would never match. Instead:
* Reuse `strudel-engine.html` + `strudel-bundle.js` + `instrument-samples/` in an `android.webkit.WebView`.
* Serve them with `androidx.webkit.WebViewAssetLoader` (`https://appassets.androidplatform.net/…`). This replaces iOS `SampleSchemeHandler` and its `fetch` override for Dirt-Samples.
* Set `mediaPlaybackRequiresUserGesture = false`.
* Bridge with `evaluateJavascript` (same JS API as iOS: `initStrudel`, `strudelEval`, `strudelStop`, `noteOn/noteOff/noteSlide/playNote/playHit`, `__hp.*`, `_drumIntensity/_drumComplexity`).
* Callbacks (`onBeat`, `onNoteStarted`, logs) go through `addJavascriptInterface`. The page currently posts to `window.webkit.messageHandlers.strudelBridge`. Add an Android shim in `strudel-engine.html` that forwards to the injected interface; keep the iOS behaviour unchanged.

The native SoundFont path (TinySoundFont) stays for SoundFont routing, which is the default for Split and Scale. Delete the Kotlin `synth/` oscillator stand-ins once Strudel works. Keep `DrumSynth` only if needed as an offline fallback; iOS has none.

Copy the assets at build time with a Gradle `Copy` task (`generateStrudelAssets`) from `ios/HandStrudel/HandStrudel/Resources/{strudel-engine.html,strudel-bundle.js,instrument-samples}` into `app/build/generated/assets/strudel`, registered as an assets srcDir. Do not commit duplicates. The task runs `node ios/bundle-strudel.mjs` only if the bundle is missing.

**Owns:**

* Existing:
  * `A/engine/**`: EngineController, HandTrackingManager, HapticManager, CoreBridge, GridModeManager, DrumModeManager, `synth/**`.
  * `A/models/**`
  * `core/**` (Rust), `android/core/**`
  * `android/app/src/main/cpp/**`
  * `android/app/src/main/assets/{soundfonts,hand_landmarker.task}`
* New:
  * `A/engine/StudioEngine.kt` (implementation side)
  * `A/engine/strudel/StrudelBridge.kt`
  * `A/engine/modes/{ModeController,MelodicModeController,GridModeController,DrumModeController,ChordMelodyModeController,SoundFontModeController,LearnModeController}.kt`
  * `A/engine/LearnModeManager.kt`
  * `A/engine/ParamSmoother.kt` (or core `ParamSmoother`)
  * `A/engine/HandMapper.kt`
  * `A/engine/loops/AudioLoopStore.kt`: saved loop files, metadata, layered playback, gain, mute, rename, delete, max 20.
  * `A/engine/AppAudioTap.kt`: optional PCM tap of the native mix, used by capture.
  * `A/engine/persistence/{EnginePersistence,SoundSetup,SoundPresetPack,CustomScaleStore}.kt`
  * `A/models/{Waveforms,SoundFontInstruments,ChordProgressions,Scales,LearnSongs,DrumLoops,CameraFilters,HandThemes}.kt`. The filter and theme *data* live here; drawing them is studio-ui's job.
  * `android/app/build.gradle.kts` asset copy task (its own block).

**`StudioEngine` interface (`A/engine/StudioEngine.kt`).** Mirror the iOS `@Published` names, as `StateFlow` for observables and functions for actions:

* **Lifecycle:** `isRunning`, `isPaused`, `status` ("tap start", "Preparing instrument…", "Playing", "error: …"), `auxiliaryAudioIssue`.
  * `start(input: PlayInput)`: SoundFont-routed modes open the session immediately; Strudel init continues in the background.
  * `stop()`, `pause()`, `resume()`, `setSceneActive(Boolean)`, `silenceAll()`.
* **Input:** `playInput: StateFlow<PlayInput>` (AIR/TOUCH), `setPlayInput`, `cameraIssue: StateFlow<CameraIssue?>`, `startCameraIfRequested()`, `handsState`, `handTracker` (for `CameraPreview` binding).
* **Mode:** `mode: StateFlow<StudioMode>`, an enum of the 11 `SoundSetup.Mode` values plus `LEARN`. `switchMode(StudioMode)`. `currentModeString`.
* **Sound:** `selectedKey`, `selectedScale` (`ScaleSelection` = builtIn | custom), `selectedSoundFontInstrument`, `selectedWaveform`, `chordMelodyProgression`, `manualBPM`, `quantizeEnabled`, `quantizeDiv`, `chordMelodySwapHands`, `chordMelodyAutoStrum`, `chordMelodyPadVolume`, `radialUseSoundFont`/`splitUseSoundFont`/`scaleUseSoundFont`, `gridBaseOctave`, `gridOctaveRange`.
  * Drum tracks 1/2 (`selectedDrumLoop`, `drumVolume`, `drumBPM`, `selectedDrumLoop2`, `drumVolume2`, `drumBPM2`), `drumIntensity`, `drumComplexity`.
  * `lockedParams`, `setManualValue`, `toggleLock`, `smoothedParams`.
  * `selectedFilter`, `selectedHandTheme` (persisted ids).
* **Display state:**
  * `currentBeat`, `bpm`, `noteDisplay`, `codeDisplay`.
  * Chord-melody: `chordMelodyCurrentDegree`, `chordMelodyCurrentChordName`, `chordMelodyChordHandLane`, `chordMelodyMelodyLane`, `chordMelodyOctaveShift`, `zoneDegrees`, chord/melody pinching and resting.
  * Grid and drum lanes and pinching, `lastDrumHit`.
  * Learn: `learnScore`, `learnVisibleNotes`, `learnHitEffects`, `learnSongComplete`, `currentLearnSong`, `loadLearnSong`, `updateLearnViewport`, `tapLearnLane`.
* **Touch:** `splitTouchEnterChord/EnterMelody/Exit` (exists), plus the equivalents for Radial, Scale, Grid lane and Drum lane taps.
* **Presets:** `currentSoundSetup`, `soundSetupForSaving`, `applySoundSetup(setup, store: StoreGate): Boolean`, `presets` CRUD, `importPresetPack(bytes)`/`exportPresetPack(ids)`, custom-scale CRUD.
* **Recording hooks:** `setRecordingTempo(halfSpeed)`, `supportsHalfSpeedRecording`, `isLoopRecording`, `loopCaptureBusy`, `loopRecordingProgress`, `loopRecordingBars`/`setLoopRecordingBars`, `loopDurationSeconds(bpm)`.
* **Loops:** `savedLoops`, `playingLoopIds`, `saveCapturedLoop(file, duration, bpm, mode, autoplay)`, `toggleLoopPlayback`, `renameLoop`, `setLoopGain`, `toggleLoopMute`, `deleteLoop`, `stopAllLoops`, `maxLoops = 20`.
* **Hooks:** `onFirstNote: (() -> Unit)?` (shell analytics). `audioSessionId` / `AppAudioTap` (capture).

**Rust core work (`core/`, mirrors Swift exactly; port the matching iOS tests):**
1. `Layout::Scale` with the `.scale` behaviour from `ChordMelodyModeManager.swift` (≈ lines 355, 370–395, 652, 689): the melody side covers the full scale, the outer band shifts melody ±1 octave, and `split_octave_shift` semantics apply.
2. Add the 8 missing `Scale` variants (Minor Pentatonic, Major Blues, Phrygian Dominant, Diminished (Half-Whole), Harmonic Major, Lydian Dominant, Altered, Dominant Bebop), with intervals from `MusicTheory.swift`.
3. Custom scales: add `scale_notes_for_intervals(root, intervals)` and `chord_notes_for_intervals(...)` (or make every API take `Vec<i32>` intervals), so custom scales work everywhere.
4. Wire `quantize`/`auto_strum` through `tick` from engine state. Check against `quantizeBoundaryCrossed` on iOS.

**Hand tracking:** add `rotation`, `thumbCurl`, `indexCurl`, `middleCurl`, `ringCurl`, `pinkyCurl`, computed as in `iOS/Engine/HandTrackingManager.swift`. Add `CameraIssue` reporting: CameraX bind failure means unavailable, `CameraState.ERROR_CAMERA_IN_USE` means interrupted, permission denied comes in from shell. On denial, fall back to touch, like iOS.

**Haptics:** port all `HapticManager.swift` patterns with `VibrationEffect.createOneShot` / `createWaveform` amplitudes. Respect `hasAmplitudeControl`.

**Persistence:** a DataStore or SharedPreferences namespace `engine`, holding the same keys and defaults as `PersistenceManager.swift`. Note that the persisted `lastMode` defaults to `splitchordmelody`, but **Start playing** switches to `scalechordmelody` (shell/studio-ui call `navigator.startSession()`, which calls `engine.switchMode(SCALE)` unless a setup applied).

**Dependencies:** `androidx.webkit:webkit:1.12.1`. Serialization comes from Phase 0. The Rust toolchain is already required (`android/core/README.md`).

**Acceptance (emulator; use `-camera-front webcam0` or touch input):**
1. Start playing → the Scale wheel sounds through the SoundFont instrument. Change instrument, key, scale and progression live; no stuck notes.
2. Every mode in "Other modes" makes sound:
   * Split, Scale, Radial (SF on/off), Chord+Melody, SoundFont: native.
   * Melodic, Flow, Hybrid, Lead, Grid, Drums: Strudel WebView.
   * Learn: a song plays and is scored by touch taps.
3. Both drum tracks play under melodic modes with independent volume and BPM.
4. All 37 waveforms are audible. Sampled instruments load offline (airplane mode).
5. Quantize ⅛ audibly snaps chord changes. Auto-strum re-articulates on the beat.
6. Kill and relaunch: key, scale (including a custom scale), instrument, waveform, BPM, filter, grid settings and mode restore.
7. Import an iOS-exported preset pack. Re-export it and diff: identical JSON, modulo key order.
8. Deny camera → `cameraIssue = permissionDenied`, input becomes TOUCH, and touch play still works.

**Unit tests:**
* `cargo test` in `core/`: Scale layout cases ported from `iOS/../HandStrudelTests/ChordMelodyModeManagerTests.swift`, new scales' intervals, custom-interval chord notes.
* `AT/engine/` and `AT/models/`:
  * `SoundSetupJsonTest`: round-trip; decode an iOS fixture with a built-in scale and one with a custom scale; `isValid` bounds; `requiredPacks`.
  * `SoundPresetPackTest`: 0/129 presets, >256 KB, bad name, wrong format → exact error strings.
  * `CatalogTest`: 128 instruments and the free id set, 145 progressions and the premium rule, 23 scales and the free set, 14 learn songs, 37 waveforms. Ids match the iOS files. Port `SoundFontInstrumentTests`, `ChordProgressionTests`, `MusicTheoryTests`, `LearnSongTests`, `ParamDefsTests`, `CameraFilterTests` (data part).
  * `ChordProgressionParseTest`.
  * `LearnModeManagerTest`: port `LearnModeManagerTests.swift`.
  * `EnginePersistenceTest`: defaults.

---

### WS3 — `studio-ui`: Music home, stage and control sheet

**Goal.** Every pixel of the Music tab, both before and during a session, matches iOS 1.0.1. studio-ui drives `StudioEngine`, gates premium content through `StoreGate`, and embeds capture's controls in slots.

**Owns:**

* Moved in Phase 0: `A/ui/studio/{SplitChordMelodyOverlay,SplitSettingsSheet→ControlSheet,HandOverlay,CameraPreview}.kt`.
* New under `A/ui/studio/`:
  * `StudioEntryPoints.kt`
  * `home/{MusicHome,SoundSetupSheet,StudioSettingsHero,SoundArtwork,StudioInputPicker,StudioKeyMenu}.kt`
  * `pickers/{InstrumentPickerSheet,ProgressionPickerSheet,ScalePickerSheet,CustomScaleEditor}.kt`
  * `stage/{Stage,TopBar,BeatDots,NoteBadge,CodePill,CameraRecoveryBanner,RandomizedToast,ShakeDetector}.kt`
  * `overlays/{ScaleWheelOverlay,RadialWheelOverlay,ChordMelodyZonesOverlay,GridLanesOverlay,DrumLanesOverlay,DrumXYPad,LearnOverlay,LearnSongPicker,WeaveView}.kt`
  * `visual/{CameraFilterEffect,HandThemeRenderer}.kt`
  * `sheet/{ControlSheet,SoundTab,PlayTab,MixTab,CaptureTab,OtherModesPicker,DrumTrackSection,ParamsSection,BpmSection,CustomProgressionEditor,FiltersSection,HandThemesSection}.kt`
  * `presets/SoundSetupsSheet.kt` (list, save current, apply, delete, import/export via the SAF `OpenDocument`/`CreateDocument`)
  * `onboarding/OnboardingOverlay.kt`

**Port from:**
* `iOS/Views/StartOverlayView.swift`, `OnboardingView.swift`, `HandOverlayView.swift`, `CameraView.swift`.
* `ChordMelodyOverlayView.swift`, `RadialChordMelodyOverlayView.swift`, `SplitChordMelodyOverlayView.swift`, `SplitTouchOverlay.swift`, `GridTouchView.swift`, `LearnOverlayView.swift`, `LearnSongPicker.swift`, `WeaveView.swift`.
* `iOS/App/ControlSheetView.swift`: everything except `LoopShelfView` (capture), `recordingSection` (capture), and the store/paywall views (store).
* `iOS/App/ContentView.swift` performance view sections: top bar, overlays, note badge, beat ring, drum XY pad, grid quick bar, note grid, drum lanes, randomize.

**Rules:**
* Locked content shows the PRO badge. Tapping it opens `PaywallSheet(packId)`. When `store.isConfigured == false`, locked items show "Not available yet" and do nothing.
* Opening the control sheet calls `engine.pause()`. Dismissing calls `resume()`.
* Presets, Close and Settings are disabled while `capture.isRecordingLocked`.
* The bottom row of the Stage is exactly `CaptureEntryPoints.StageBottomControls(onOpenSettings = { showSheet = true })`. Recording overlays come from `CaptureEntryPoints.StageOverlays()`.
* The Capture tab hosts `CaptureEntryPoints.RecordingSettingsSection()`, then filters, then hand themes.
* The "Store" header action opens `StoreScreen`. The Learn picker opens when Learn is selected with no song loaded.
* Skeleton opacity is 0 while recording when the `hideSkeletonWhenRecording` pref is on.
* Accessibility: keep iOS identifiers as `Modifier.testTag` (`start-button`, `settings-button`, `close-button`, `music-other-modes`, `studio-play-input`, `scale-picker`, `sounds-instrument`, `create-custom-scale`, `private-drafts-button`, `music-presets-button`, `music-loop-shelf`, …). That lets one test plan describe both apps.

**Dependencies:** `androidx.compose.material:material-icons-extended` (BOM-managed).

**Acceptance (emulator):**
1. Music home matches iOS: headline, hero, sound sheet with four chips, three library shortcuts, Start playing. The instrument preview stops when the app backgrounds.
2. First session shows onboarding on the Scale wheel. It never shows again.
3. All overlays render and are touch-playable at phone and tablet sizes. Split, Scale and Radial wedges align with the camera-tracked hand.
4. The control sheet has four tabs with the iOS sections per mode. Other-modes switching works. Pad volume shows a percentage of 0.6.
5. Each of the 26 filters is visibly distinct on API 31+. Hand themes change the skeleton colours.
6. Shaking randomizes and shows the toast.
7. Presets: save, apply, delete, and import/export a `.json` through the system file picker.
8. With a fake `StoreGate` that has nothing unlocked: PRO badges appear and the paywall opens. With everything unlocked: no badges.

**Unit tests (`AT/ui/studio/`):** pure geometry for wedges and zone hit-testing (`zoneForPoint`, wedge bounds for every layout), the custom-progression text parser binding, the filter → `ColorMatrix` builder (port `CameraFilterTests` numeric expectations), and onboarding step state.

---

### WS4 — `capture`: recording, drafts, loops, play-along, posting

**Goal.** Record performances and audio loops the way iOS does, manage private drafts (trim, rename, export, share), support play-along backing tracks, and post drafts to the feed through the screening upload pipeline.

**Android design:**

* **Stage capture: MediaProjection.**
  * `CaptureService` is a foreground service of type `mediaProjection`.
  * Video: a `VirtualDisplay` at the screen size (portrait) feeding a `MediaCodec` H.264 surface. On API 34+, use `MediaProjectionConfig.createConfigForUserChoice()` so the user can pick "this app only"; that matches ReplayKit's app-only capture.
  * Audio: `AudioRecord` with `AudioPlaybackCaptureConfiguration` (`addMatchingUid(myUid)`, `USAGE_MEDIA`/`USAGE_GAME`). This captures both the native SoundFont audio and the WebView's Strudel audio. Optional mic: mix the mic `AudioRecord` in when `recordPerformanceMicrophone` is on.
  * Mux to MP4 with `MediaMuxer`.
  * Consent: ask once per studio session, keep the projection alive until the session ends, and stop it on `capture.onSessionEnded()`. Android 14 tokens are single-use, so a new session re-prompts. Explain this in the UI on the first prompt.
* **Audio loops:** capture `bars × 4 × 60 / BPM` seconds (≤90 s) of app audio with the same playback-capture `AudioRecord`, then hand the WAV/M4A to `engine.saveCapturedLoop`. If no projection is active and the active mode is SoundFont-only, `engine.AppAudioTap` can supply the native mix with no consent prompt (an optimisation, not required).
* **Half speed:** `engine.setRecordingTempo(true)` while recording. The draft stores `recordedAtHalfSpeed`. Export and post apply a ×2 speed via Media3 Transformer (`SpeedChangeEffect` + `SpeedChangingAudioProcessor`). Compare the pitch behaviour with an iOS export of the same take and match it.
* **Watermark:** a Compose overlay shown only while recording (it is captured with the screen). Same geometry as iOS. QR via ZXing.
* **Drafts:** under `filesDir/drafts/<uuid>/` (`take.mp4`, `draft.json`). The metadata mirrors `RecordingDraft`: title, created, duration, instrument, mode, soundSetup, backingCredit, recordedAtHalfSpeed, trim, plus per-account `DraftPostSubmission`.
* **Trim:** filmstrip frames from `MediaMetadataRetriever`; preview with ExoPlayer clipping.
* **Export:**
  * Save: `MediaStore.Video` in `Movies/HandStrudel`.
  * Share video/audio: FileProvider + `ACTION_SEND`, from a temp copy under `cacheDir/exports` that is deleted afterwards.
  * M4A: `MediaExtractor` + `MediaMuxer` audio-only remux.
* **Upload:** port `VideoUploader.swift` exactly (section 1.9), with Media3 Transformer for 720-wide H.264 at the computed bitrate and AAC 128 k, and a JPEG thumbnail. Call `sign-upload` and `publish-upload` through `auth.functionsFor(accountId)`. PUT to the presigned URLs with OkHttp, with exact `Content-Type` and `Content-Length`. Persist `pending` before submitting. Poll.
* **Post composer:** port `PostComposerView.swift`. If the user isn't signed in or `needsProfileSetup`, show `SocialEntryPoints.SignInSheet`. After a successful post, call `navigator.showNotice(...)` and offer "View post" (`navigator.openPerformance(.watch(id))`).
* **Play-along:** port `prepareBacking`, `BackingTrack`, `PerformanceAudio.export`. Download the clip with the authenticated anon key, extract the audio, and loop it in ExoPlayer with `REPEAT_MODE_ONE` and volume from the `playAlongBackingVolume` pref. Re-check `backing_enabled` via `SocialEntryPoints.fetchVideo`. Apply the `soundSetup` if entitled (else fall back to the current sound). Count in with 4 clicks at the source BPM. Credit goes into the draft and the post.
* **Analytics:** `recording_started`, `recording_saved`, `recording_posted`. Successful takes call `ReviewPrompt.record(draftId)` (shell).

**Owns (new):**
* `A/capture/{CaptureController,CaptureControllerImpl,CaptureService,ScreenRecorder,AppAudioCapture,LoopCapture,RecordingCountIn,Watermark,BackingTrack,PerformanceAudio}.kt`
* `A/capture/drafts/{RecordingDraft,RecordingDrafts,DraftTrimSelection,DraftExport}.kt`
* `A/capture/upload/{VideoUploader,VideoTranscoder,UploadModels}.kt`
* `A/ui/capture/{StageBottomControls,RecordButton,LoopRecordButton,CountdownOverlay,BackingControls,RecordingSettingsSection,DraftsSheet,DraftEditor,DraftTrimFilmstrip,DraftNameEditor,LoopShelfSheet,PostComposerSheet}.kt`
* `res/xml/file_paths.xml` (Phase 0 creates it; capture may extend it).

**Port from:**
* `iOS/App/ContentView.swift`: Recording MARK, `toggleAudioLoop`/`finishAudioLoop`/`resolveAudioLoop`, `prepareBacking`/`playBacking`/`stopBacking`/`backingControls`, `RecordingCountIn`, `BackingTrackVolume`, `PerformanceAudio`, `RecorderEvents`.
* `iOS/Views/RecordingDraftsView.swift`, `iOS/Engine/WatermarkManager.swift`, `iOS/Engine/AudioExporter.swift`.
* `iOS/App/ControlSheetView.swift`: `LoopShelfView`, `recordingSection`.
* `iOS/Social/VideoUploader.swift`, `iOS/Social/PostComposerView.swift`.
* `iOS/Social/SocialModels.swift`: `VideoPostFields`, `DraftPostSubmission`, `SignUpload*`, `PublishUpload*`.

**Dependencies:** `androidx.media3:media3-transformer:1.4.1`, `media3-effect:1.4.1`, `media3-exoplayer:1.4.1`, `media3-ui:1.4.1`, `com.squareup.okhttp3:okhttp:4.12.0` (or reuse the Ktor engine from social), `com.google.zxing:core:3.5.3`, `androidx.lifecycle:lifecycle-service:2.8.7`.

**Acceptance (emulator API 34 + a physical device for audio capture):**
1. Record → 3-second countdown → stage recording with the watermark → stop. The draft opens with playback that has audio from both the SoundFont and Strudel paths. The skeleton is hidden in the video when the pref is on.
2. Half-speed take: the export plays at normal tempo.
3. Trim, rename and delete work. Save to Gallery shows the clip in Photos. Share video/audio opens the Android share sheet. Temp files are removed.
4. Loop: 4 bars at 120 BPM records 8 s and auto-plays layered. Shelf rename, mute, gain and delete work. A 21st loop is refused with the iOS message.
5. Play-along from a feed post (with a fake or real social): the backing loops, the count-in uses the source BPM, and the credit appears in the composer.
6. Posting against staging or production with a test account goes through the `checking` state to `published` (or `held`, with the iOS string). Killing the app mid-check and reopening Drafts resumes the status.
7. Backgrounding during recording saves the partial take and shows the iOS interruption message.

**Unit tests (`AT/capture/`):**
* `RecordingCountInTest`: steps, secondsPerStep, click-track sample count and onsets.
* `DraftTrimSelectionTest`: port `moving(edge, to:)` constraints.
* `RecordingDraftTitleTest`: `normalizedTitle`, 60-char limit.
* `VideoUploaderMathTest`: `renderSize` even height and 720 width; `targetVideoBitrate` for 1 s, 7 s and 60 s.
* `VideoUploaderStateTest`: fake publish returning checking→published / held / failed / 404 / 409 / timeout; the submission is persisted before submit; per-account isolation.
* `DraftStoreTest`: pending/published persistence round-trip.

---

### WS5 — `social`: auth, feed, comments, profile

**Goal.** Feed and Account tabs equivalent to iOS, against the shared Supabase backend, with email OTP sign-in (plus Google when configured), username/EULA setup, and all moderation actions Google Play's UGC policy requires (report, block, delete own content, account deletion).

**Owns (new):**
* `A/social/{SocialConfig,SupabaseProvider,AuthSession,AuthManager,SocialEntryPoints}.kt`
* `A/social/model/{Profile,Video,VideoEngagement,VideoComment,CreatorActivity,PublicCreator,PostSearch,BackingCredit,WeeklyChallenge,PerformanceLink,ReportReason,CommentReportReason}.kt`
* `A/social/data/{FeedService,ProfileImageStore,DiscoveryFeedRanking,FeedNavigation}.kt`
* `A/ui/social/auth/{SignInSheet,EmailCodeFlow,ProfileSetupSheet}.kt`
* `A/ui/social/feed/{FeedTab,FeedModel,FeedPager,FeedCell,FeedActionRail,FeedPlayerPool,FeedPreloader,FeedProgressStrip,FeedSeekSlider,FeedSoundSheet,VideoShareSheet,PostSearchScreen,ActivityInboxScreen,PerformanceLibraryScreen,CreatorVideoSheet,PublicCreatorScreen,WeeklyChallengeBanner}.kt`
* `A/ui/social/comments/CommentsSheet.kt`
* `A/ui/social/account/{AccountTab,ProfileScreen,CreatorProfileHeader,CreatorPortfolio,EditProfileSheet,BlockedUsersScreen,AccountSettings,DeleteAccountDialog}.kt`

**Port from:** every file in `iOS/Social/` except `VideoUploader.swift` and `PostComposerView.swift` (capture). Port `PerformanceLink` from `SocialModels.swift`.

**Details:**
* **Client:** supabase-kt with Auth (PKCE not needed for OTP; session persisted by the default `SettingsSessionManager`), Postgrest and Functions. Use the anon key from `BuildConfig`. `SocialConfig.isConfigured` is false when the key is blank or starts with `YOUR-`. Media URL routing must match `SocialConfig.mediaURL` exactly.
* **Sign-in sheet:**
  * Email field → "Email me a code" → 6-digit code → verify.
  * A "Continue with Google" button only when `BuildConfig.GOOGLE_WEB_CLIENT_ID` is non-blank. It uses Credential Manager `GetGoogleIdOption` → `auth.signInWith(IDToken) { provider = Google; idToken; nonce }`.
  * "Make music as a guest" dismisses.
  * Apple button: hidden (see Risk R5).
* **On session change:** load the profile and call `store.logIn(userId)` through a listener the store registers. Social must not depend on RevenueCat; it emits `userId` changes and store subscribes. Sign out → `store.logOut()`.
* **Profile setup (EULA):** username regex `^[a-z0-9_]{3,20}$`. Terms and community guidelines links open in Custom Tabs. Saving sets `username` and `accepted_terms_at`. A unique violation shows "taken". Posting, commenting, following and liking require `!needsProfileSetup`.
* **Feed:**
  * Compose `VerticalPager` with **one ExoPlayer per visible plus two adjacent pages** from a small pool (`FeedPlayerPool`). Preload via Media3 `DefaultPreloadManager` or prepared-but-paused players.
  * First-frame warm-up at launch, like iOS commit a09c0631: "Preload actual video frames and warm the first feed clip at launch".
  * At either edge, continue with a random different clip (`FeedNavigation.destination`).
  * A view counts after `min(2 s, dur/2)`, with a per-video receipt UUID persisted for the session.
  * Mode switcher Discover / Latest / Following. Pull or button refresh.
  * The feed is dark over video. The tab bar is drawn over video through the `tabBar(overVideo = true)` slot from shell.
  * Full-screen toggling notifies shell (`onFullscreenChanged`).
* **Action rail and menus:**
  * Like (optimistic), comments, share (`ACTION_SEND` of `watchURL`, plus `record_video_share`), repost, save, **Play this sound** → `navigator.trySharedSound(video.soundSetup)`, **Play along** → `navigator.prepareBacking(video)`.
  * Report: reasons per `ReportReason`. Block: removes the creator's posts from all lists immediately.
  * Owner-only: delete post (`delete-video`), toggle audio downloads, stop allowing play-along, manage comments.
  * Download audio (where allowed): MediaStore Audio or share.
* **Account tab:** signed-out state uses the iOS copy. Settings items are listed in 1.9.
  * Appearance opens shell's `StudioThemePickerSheet`.
  * Usage Analytics opens shell's `UsageAnalyticsScreen`.
  * "Write a review" opens the Play listing or the in-app review.
  * Delete account: a "Delete forever" confirmation calls `delete-account`. On success, sign out. On a lost response, show the "unconfirmed" message and keep the session.
* **Images:** Coil for thumbnails and avatars. Avatar upload: Photo Picker (`PickVisualMedia`) → downscale/JPEG → `profile-avatar` function (same body as `AuthManager.updateAvatar`).

**Dependencies:**
* `io.github.jan-tennert.supabase:bom:<3.0.x compatible with Kotlin 2.0.21>` with `auth-kt`, `postgrest-kt`, `functions-kt`
* `io.ktor:ktor-client-okhttp:<matching>`
* `androidx.media3:media3-exoplayer:1.4.1`, `media3-ui:1.4.1`, `media3-datasource-okhttp:1.4.1`
* `io.coil-kt.coil3:coil-compose:3.0.4`, `coil-network-okhttp:3.0.4`
* `androidx.credentials:credentials:1.3.0`, `androidx.credentials:credentials-play-services-auth:1.3.0`, `com.google.android.libraries.identity.googleid:googleid:1.1.1`

**Acceptance (emulator, production read-only + a test account):**
1. The Feed tab plays the Discover feed full-screen. Swipe up and down is instant on adjacent clips; tapping pauses; seeking works. Latest and Following switch.
2. Sign in with an email code from the test account. First sign-in shows username setup with terms links. After that, likes, comments (≤300 chars counter), replies, follow, repost and save work and persist across restarts.
3. Report and block a test post or account: it disappears from the feed. Unblock from Blocked users.
4. Search `@handle` and text. Activity inbox shows unread items and marks them read. The weekly challenge opens its list.
5. "Play this sound" starts a session with that setup. "Play along" goes to capture with the backing loaded.
6. Delete own post. Delete the account of a throwaway test user: signed out, and profile and videos gone.
7. Deep link to a post opens `CreatorVideoSheet`. Comments links open `CommentsSheet`.

**Unit tests (`AT/social/`):** port `HandStrudelTests/SocialTests.swift`:
* `PerformanceLink` parsing (valid/invalid hosts, duplicate `v`, credentials in URL).
* `Video` decoding with a bad `sound_setup` → null.
* Username validation.
* `PostSearch` escaping and column selection.
* `SocialConfig.mediaURL` screened routing.
* `DiscoveryFeedRanking` order and creator alternation.
* `FeedNavigation.destination` with an injected chooser.
* `VideoComment` length counted in unicode scalars.
* Account deletion result (`deleted`/`unconfirmed`).
* `CreatorActivity.title` pluralisation.

---

### WS6 — `store`: RevenueCat and gating

**Goal.** Same entitlement model as iOS on Google Play via RevenueCat, the store screen and pack paywall, restore, and account-linked purchases. The app must degrade cleanly with no key.

**Owns (new):** `A/store/{StoreGate,StoreManager,StoreState,Entitlements,ProductIds,RestoreOutcome}.kt`, `A/ui/store/{StoreScreen,PaywallSheet,RestorePurchasesButton,ProBadge}.kt`. `ProBadge` is shared, and studio-ui imports it.

**Port from:** `iOS/Models/StoreManager.swift`, `iOS/Views/StoreView.swift`, `iOS/Views/PaywallOverlay.swift`, and pack info in `ControlSheetView.packInfo(for:)`.

**Details:**
* `Purchases.configure(PurchasesConfiguration.Builder(context, BuildConfig.REVENUECAT_API_KEY).build())` in `StoreManager.init`, **only if the key is non-blank**. Otherwise `isConfigured = false`:
  * `isUnlocked()` returns true only for free content (`packId == null`).
  * `StoreScreen` shows "Purchases aren't available in this build".
  * Studio-ui hides the Store button.
* Entitlement mapping is a pure function `Entitlements.entitlementId(packId)`, identical to Swift, so it can be unit-tested.
* Listen to `UpdatedCustomerInfoListener`.
* Play product IDs (owner creates them in Play Console; see Risks): `com.handstrudel.pro` (one-time, non-consumable), subscription `com.handstrudel.plus` with base plans `monthly` and `yearly`. RevenueCat identifiers are `com.handstrudel.plus:monthly` / `:yearly`. Optionally `com.handstrudel.kit.808` and `com.handstrudel.kit.electronic`; Pro already grants the kit entitlements, so these can be skipped.
* Store screen sections: drum kits (hidden if the products don't load), Pro, HandStrudel+ (RevenueCat `purchases-ui` `PaywallDialog` if an offering exists, else plain package buttons), Restore, Privacy (`https://handstrudel.com/privacy`) and **Terms (`https://handstrudel.com/terms`)**.
* `logIn`/`logOut` run in response to `auth.userId` changes. store subscribes in `AppServices` wiring (shell calls `store.bind(auth.userId)`).

**Dependencies:** `com.revenuecat.purchases:purchases:8.10.x`, `com.revenuecat.purchases:purchases-ui:8.10.x`. Pick versions compatible with compileSdk 35 / Kotlin 2.0.21.

**Acceptance:**
1. With no key: the app runs, every PRO item shows locked with no crash, and the store says unavailable.
2. With a key, a Play internal-testing track and a license tester: the Pro purchase unlocks instruments, progressions, scales and custom scales immediately. Plus unlocks filters, hand themes and premium scales. Restore works after reinstall.
3. Signing in with an account that owns Pro on iOS (same RevenueCat project) unlocks Pro on Android.

**Unit tests (`AT/store/`):** `EntitlementsTest`, which ports `StoreManagerTests.swift` (every packId → entitlement, legacy product mapping). `RestoreOutcomeTest` with a fake customer-info source. `UnconfiguredStoreTest`.

---

### 3.7 Seam ownership summary

| Seam | Owner | Consumers |
| --- | --- | --- |
| `MainActivity`, `HandStrudelApp`, `AppServices`, `AppNavigator`, `Destination`, `AppPrefs`, theme (`LocalStudioPalette`, picker), manifest, root Gradle | shell | all |
| `StudioEngine`, `SoundSetup`, catalogs, `AudioLoopStore`, `AppAudioTap`, Strudel WebView instance | engine | studio-ui, capture, shell (WebView host), social (SoundSetup decode) |
| `StudioEntryPoints.MusicHome/Stage` | studio-ui | shell |
| `CaptureController`, `CaptureEntryPoints` (stage controls/overlays, recording settings, drafts, loop shelf) | capture | studio-ui, shell |
| `AuthSession`, `SocialEntryPoints`, `Video`, `PerformanceLink`, `FeedService` | social | shell, capture, store (userId) |
| `StoreGate`, `PaywallSheet`, `StoreScreen`, `ProBadge` | store | studio-ui, capture (composer: none), shell (binding) |

### 3.8 Integration order

1. Merge order: shell → engine → store → studio-ui → social → capture. Later branches rebase onto earlier ones; conflicts are limited to `// --- ws ---` dependency blocks.
2. Replace the fakes in `AppServices` with the real implementations.
3. Run `./gradlew :app:testDebugUnitTest :app:assembleDebug` and `cargo test` in `core/`.
4. Do an end-to-end pass on an emulator and on one physical device (camera + audio capture). Then close emulators started for the run.

---

## 4. Risks and owner inputs

| # | Needed from owner | Used by | Degradation without it |
| --- | --- | --- | --- |
| R1 | **Google Play Console app** `com.handstrudel.app`: upload key, internal testing track, license testers. Required for billing tests and for App Links verification. | store, shell | Debug builds run fine; billing can't be tested. |
| R2 | **RevenueCat Android app** in the *same* RevenueCat project as iOS: the Play service-account JSON linked, entitlements `pro`, `plus_features`, `kit_808`, `kit_electronic` attached to the Play products (above), and the **public Android SDK key** (`goog_…`) passed as `handstrudel.revenuecatApiKey`. | store | `StoreGate.isConfigured = false`: store hidden, all paid content locked, no crash. |
| R3 | **Play products:** `com.handstrudel.pro` (in-app), `com.handstrudel.plus` subscription with `monthly`/`yearly` base plans, prices matching iOS, and optionally the kit products. | store | The store shows only what loads. Missing products are hidden, not "---". |
| R4 | **Google sign-in:** enable the Google provider in the Supabase dashboard. Needs a Google Cloud Web OAuth client id + secret and an Android OAuth client (package + SHA-1 of the debug, upload and Play signing keys). Pass the Web client id as `handstrudel.googleWebClientId`. **Confirm whether production already has Google enabled**: the repo's `supabase/config.toml` is local-only and shows neither Google nor Apple enabled. | social | Google button hidden; email OTP only. |
| R5 | **Apple-account users on Android:** iOS users who signed up with Sign in with Apple (often private-relay emails) cannot reach that account via email OTP. Fix options: enable Apple OAuth (web flow) for Android (Apple Services ID, return URL `handstrudel://auth-callback`, Supabase redirect allow-list), or document "use the same email". Decide before public launch. | social | Those users get a new, separate account. |
| R6 | **App Links:** `public/.well-known/assetlinks.json` with the Play app-signing SHA-256 (served at `https://handstrudel.com/.well-known/assetlinks.json`), deployed with the website. | shell | `https://handstrudel.com/watch` links open the browser; the `handstrudel://` scheme still works. |
| R7 | **Supabase auth redirect/Email templates:** OTP codes work with no redirect. Only Google/Apple OAuth need redirect URLs added in the Supabase dashboard. | social | — |
| R8 | **Play policy items:** a Data safety form (camera frames processed on device and not uploaded; optional analytics; account, email, UGC videos and comments); an account-deletion web URL (Play requires one outside the app; `handstrudel.com/support` or a dedicated page); UGC policy (report, block, moderation exist: Sightengine screening + reports); target API 35; foreground-service declaration for `mediaProjection` with a demo video. | owner | Can't publish until done; no code impact. |
| R9 | **Video uploads gate:** the backend `VIDEO_UPLOADS_ENABLED` and smoke-test setup (`docs/video-upload-release.md`) applies to Android too. `moderationVersion: 2` is required by `sign-upload`. | capture | Posting returns the server's "disabled" message. Drafts stay private. |
| R10 | **APK size:** GeneralUser-GS.sf2 (32 MB) + instrument samples (30 MB) + Strudel bundle + MediaPipe model. Fine under the 200 MB AAB limit, but consider Play Asset Delivery (install-time pack) for the samples if the size hurts conversion. | engine | — |
| R11 | **Android WebView audio latency/throttling:** Strudel modes may lag more than on iOS on low-end devices. The default (Scale/Split) path is native SoundFont, so the first-run experience is unaffected. Measure; if Lead or Hybrid feel late, route their imperative lead voice through TinySoundFont/oscillator natively. | engine | — |
| R12 | **MediaProjection UX:** a consent dialog each studio session (Android 14+ tokens are single-use). On API <34, the whole screen is captured, but the stage is immersive so this is acceptable. Some OEMs restrict playback capture. Detect a silent capture and warn the user. | capture | Recording still works with mic-only audio if playback capture fails. Show a notice. |
| R13 | **Kotlin/AGP compatibility** of supabase-kt, Coil 3, RevenueCat and Media3 with Kotlin 2.0.21. Resolve in Phase 0 by bumping Kotlin/AGP once, not per WS. | integrator | — |
| R14 | **Secrets hygiene:** the Supabase publishable key is public by design (RLS), but agents must not echo it in logs, PR text or docs. Gradle reads it from `SocialConfig.swift`. The RevenueCat Android key is public-safe too, but keep it out of git (Gradle property / CI secret) so builds can choose. | all | — |
