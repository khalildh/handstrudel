import SwiftUI
import ReplayKit
import GroupActivities
import Combine
import UIKit
import AVFAudio
import AVFoundation

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct ContentView: View {
    private enum Destination: String, CaseIterable {
        case feed = "Feed"
        case music = "Music"
        case account = "Account"

        var icon: String {
            switch self {
            case .feed: return "play.rectangle"
            case .music: return "waveform"
            case .account: return "person"
            }
        }
    }

    @StateObject private var engine = EngineController()
    @StateObject private var storeManager = StoreManager()
    @StateObject private var auth = AuthManager()
    @StateObject private var drafts = RecordingDrafts()
    @State private var recorderEvents = RecorderEvents()
    @Environment(\.scenePhase) private var scenePhase
    @State private var destination: Destination = .music
    @State private var hasOpenedFeed = false
    @State private var startingSession = false
    @State private var showDrafts = false
    @State private var showSetups = false
    @State private var soundError: String?
    @State private var sharedSoundLoad: Task<Void, Never>?
    @State private var linkedComments: Video?
    @State private var linkedPerformance: Video?
    @State private var backing: BackingTrack?
    @State private var backingLoad: Task<Void, Never>?
    @State private var backingPlaying = false
    @State private var showBackingMixer = false
    @AppStorage("playAlongBackingVolume") private var backingVolume = BackingTrackVolume.defaultValue
    @State private var reviewingDraft: RecordingDraft?
    @State private var retakeRequested = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showSheet = false
    @State private var isRecording = false
    @State private var recordingUsesMicrophone = false
    @State private var recorderBusy = false
    @State private var captureTask: Task<Void, Never>?
    @State private var activeDraft: RecordingDraft?
    @State private var activeAudioLoop: CapturedLoopFile?
    @State private var loopCaptureTask: Task<Void, Never>?
    @State private var recordingError: String?
    @State private var recordCountdown = 0
    @State private var countInClick: AVAudioPlayer?
    @State private var countingBeats = false
    @AppStorage("hideSkeletonWhenRecording") private var hideSkeletonWhenRecording = true
    @AppStorage("recordPerformanceMicrophone") private var recordPerformanceMicrophone = false
    @AppStorage("recordAtHalfSpeed") private var recordAtHalfSpeed = false
    @State private var filterName: String = ""
    @State private var showFilterName = false
    @State private var jamInvitation: JamInvitation?
    @State private var jamError: String?
    @State private var showLearnPicker = false
    @State private var watermarkView: UIView?
    @State private var showRandomizedToast = false
    /// In melodic mode, tapping the screen toggles the floating chrome (top
    /// bar, code pill, note badge, beat ring) off so the camera + Weave
    /// reads clean. Tap again to bring it back. Other modes always show
    /// their chrome since the controls are essential.
    @State private var chromeVisible = true
    /// Touch-driven highlights for Split mode (UIKit multitouch overlay).
    @State private var splitTouchChordZones: Set<ChordSubzone> = []
    @State private var splitTouchMelodyLanes: Set<Int> = []
    /// Stack of currently-held chord touches (parent voice ID + chord data).
    /// The last entry is the "live" touch chord — it overrides the camera so
    /// the melody snap follows whatever the player is touching.
    @State private var splitTouchChordStack: [SplitTouchChord] = []
    // Song mode removed

    var body: some View {
        ZStack {
            (engine.isRunning ? Color.black : StudioStyle.background).ignoresSafeArea()

            if !engine.isRunning || hasOpenedFeed {
                destinations
                    .opacity(engine.isRunning ? 0 : 1)
                    .allowsHitTesting(!engine.isRunning)
                    .accessibilityHidden(engine.isRunning)
            }

            if engine.isRunning {
                performanceView
                    .overlay {
                        if !hasSeenOnboarding && engine.scaleChordMelodyModeEnabled {
                            let notes = scaleNotesOneOctave(key: engine.selectedKey, scale: engine.selectedScale)
                            let midi = notes.isEmpty ? 60 : notes[notes.count / 2]
                            OnboardingView(hasSeenOnboarding: $hasSeenOnboarding,
                                           noteName: pitchClassName(midi), melodyLaneCount: notes.count,
                                           swapHands: engine.chordMelodySwapHands) {
                                playFirstNote(midi)
                            }
                                .transition(.opacity)
                        }
                    }
            }

            // Hidden WebView for audio (must be in view hierarchy)
            WebViewContainer(webView: engine.strudelBridge.view)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
        }
        .onAppear {
            recorderEvents.onInterruption = { error in
                if let activeAudioLoop {
                    if engine.isLoopRecording { resolveAudioLoop(activeAudioLoop, interruption: error) }
                    else { activeAudioLoop.fail(error) }
                    return
                }
                guard isRecording, !recorderBusy, let draft = activeDraft else { return }
                finishRecordingUI()
                if (try? drafts.complete(draft)) != nil {
                    recordingError = "Recording interrupted. Check Private drafts for the saved take."
                } else {
                    drafts.discardUnfinished(draft)
                    recordingError = "Recording stopped before the take could be saved. \(error.localizedDescription)"
                }
            }
            RPScreenRecorder.shared().delegate = recorderEvents
            if ProcessInfo.processInfo.arguments.contains("--reset-onboarding") {
                hasSeenOnboarding = false
            }
            #if DEBUG
            startDemoIfRequested()
            // Open a sample take in the simulator, which cannot record with ReplayKit.
            if let path = ProcessInfo.processInfo.environment["HANDSTRUDEL_TEST_CLIP"] {
                DispatchQueue.main.async { openSampleDraft(at: URL(fileURLWithPath: path)) }
            }
            #endif
        }
        .sheet(isPresented: $showDrafts) {
            RecordingDraftsView(store: drafts, auth: auth, openedDraft: nil, onRetake: nil)
        }
        .sheet(isPresented: $showSetups, onDismiss: {
            if engine.isRunning { engine.resume() }
        }) {
            SoundSetupsView(engine: engine, store: storeManager) { setup in
                showSetups = false
                if engine.isRunning {
                    engine.applySoundSetup(setup, store: storeManager)
                } else {
                    trySharedSound(setup)
                }
            }
            .onAppear {
                guard engine.isRunning else { return }
                engine.pause()
                backing?.player.pause()
                backingPlaying = false
            }
        }
        .onOpenURL(perform: openSocialLink)
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { openSocialLink(url) }
        }
        .sheet(item: $linkedPerformance) { video in
            CreatorVideoView(video: video, auth: auth, onPlayAlong: { source in
                linkedPerformance = nil
                prepareBacking(source)
            }, onTrySound: { sound in
                linkedPerformance = nil
                trySharedSound(sound)
            })
        }
        .sheet(item: $linkedComments) { video in
            CommentsView(video: video, auth: auth) { author in
                if author == video.userId { linkedComments = nil }
            }
        }
        .alert("HandStrudel", isPresented: Binding(
            get: { soundError != nil }, set: { if !$0 { soundError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(soundError ?? "") }
        .sheet(item: $reviewingDraft, onDismiss: {
            if engine.isRunning { engine.resume() }
            if retakeRequested {
                retakeRequested = false
                startRecordingCountdown()
            }
        }) { draft in
            RecordingDraftsView(store: drafts, auth: auth, openedDraft: draft, onRetake: engine.isRunning ? {
                retakeRequested = true
                reviewingDraft = nil
            } : nil)
                .onAppear { engine.pause() }
        }
        .alert("Recording", isPresented: Binding(
            get: { recordingError != nil }, set: { if !$0 { recordingError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(recordingError ?? "") }
        .sheet(item: $jamInvitation) { invitation in
            invitation
        }
        .alert("SharePlay", isPresented: Binding(
            get: { jamError != nil }, set: { if !$0 { jamError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(jamError ?? "")
        }
        .task { await engine.jamSession.listenForSessions() }
        .onReceive(engine.jamSession.$isActive.removeDuplicates()) { active in
            guard active else { return }
            if activeDraft?.recordedAtHalfSpeed == true { stopRecording() }
            jamInvitation = nil
            if !isRecording { restoreInstrumentAudio() }
            if !engine.isRunning { startSession() }
        }
        .onReceive(engine.jamSession.$errorMessage.compactMap { $0 }) { message in
            jamError = message
            engine.jamSession.errorMessage = nil
        }
        .statusBarHidden(engine.isRunning)
        .onChange(of: engine.isRunning) { running in
            if running { startingSession = false }
            else { cancelCountdown(); stopBacking() }
        }
        .onChange(of: backingVolume) { volume in
            backing?.player.volume = Float(BackingTrackVolume.clamped(volume))
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                backing?.player.pause()
                backingPlaying = false
                if isRecording { stopRecording() }
                else if engine.isLoopRecording, activeAudioLoop != nil { finishAudioLoop() }
                else if !recorderBusy { cancelCountdown() }
            }
            if phase == .active, engine.isRunning, engine.handTracker.cameraIssue != nil {
                engine.handTracker.startSession()
            }
        }
        .onChange(of: engine.status) { status in
            if status.hasPrefix("error:") { startingSession = false; stopBacking() }
        }
        .onChange(of: destination) { tab in
            if tab == .feed { hasOpenedFeed = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .siriStartPreset)) { notification in
            guard !engine.isRunning, let presetId = notification.object as? String else { return }
            if let preset = PRESETS.first(where: { $0.id == presetId }) {
                engine.start(config: preset.mapping, advanced: false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .siriStartMode)) { notification in
            guard let mode = notification.object as? String else { return }
            if !engine.isRunning {
                // Start with default preset first
                engine.start(config: DEFAULT_MAPPING, advanced: false)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                switch mode {
                case "grid": engine.switchMode(grid: true, drums: false, learn: false)
                case "drums": engine.switchMode(grid: false, drums: true, learn: false)
                default: break
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleLoopRecording)) { _ in
            guard engine.isRunning else { return }
            toggleAudioLoop()
        }
    }

    private var destinations: some View {
        VStack(spacing: 0) {
            ZStack {
                if hasOpenedFeed && SocialConfig.isConfigured {
                    FeedView(auth: auth, isActive: destination == .feed && !engine.isRunning,
                             onMakeMusic: { destination = .music }, onTrySound: trySharedSound,
                             onPlayAlong: prepareBacking)
                        .opacity(destination == .feed ? 1 : 0)
                        .allowsHitTesting(destination == .feed)
                        .accessibilityHidden(destination != .feed)
                }

                switch destination {
                case .feed:
                    if !SocialConfig.isConfigured {
                        socialUnavailable("Feed", icon: "play.rectangle")
                    }
                case .music:
                    StartOverlayView(
                        status: engine.status,
                        engine: engine,
                        storeManager: storeManager,
                        starting: startingSession,
                        onStart: { startSession() },
                        onDrafts: { showDrafts = true },
                        onSetups: { showSetups = true }
                    )
                case .account:
                    if SocialConfig.isConfigured {
                        ProfileView(auth: auth)
                    } else {
                        socialUnavailable("Account", icon: "person.crop.circle")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            HStack(spacing: 0) {
                ForEach(Destination.allCases, id: \.self) { tab in
                    let selected = destination == tab
                    Button {
                        destination = tab
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 19, weight: .semibold))
                                .frame(width: 56, height: 31)
                                .background {
                                    if tab == .music {
                                        Capsule().fill(selected ? StudioStyle.accent : StudioStyle.accent.opacity(0.12))
                                    }
                                }
                                .foregroundStyle(tab == .music && selected ? StudioStyle.background
                                                 : selected || tab == .music ? StudioStyle.accent : StudioStyle.muted)
                            Text(tab.rawValue)
                                .font(.caption2.weight(selected ? .semibold : .medium))
                                .foregroundStyle(selected ? StudioStyle.ink : StudioStyle.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("tab-\(tab.rawValue.lowercased())")
                }
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background {
                StudioStyle.background.ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .top) { Rectangle().fill(StudioStyle.border).frame(height: 1) }
            .disabled(startingSession)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Main navigation")
        }
        .tint(StudioStyle.accent)
    }

    private func socialUnavailable(_ title: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Label(title, systemImage: icon).font(.title2.bold())
            Text("This section is unavailable in this build.").foregroundStyle(.secondary)
        }
    }

    private func startSession(setup: SoundSetup? = nil) {
        guard !engine.isRunning, !startingSession else { return }
        if let setup, !engine.applySoundSetup(setup, store: storeManager) {
            soundError = "This setup is unavailable or requires a sound pack you don't own."
            return
        }
        startingSession = true
        destination = .music
        engine.start(config: DEFAULT_MAPPING, advanced: false)
        if setup == nil { engine.switchMode(grid: false, drums: false, learn: false, scaleChordMelody: true) }
    }

    private func trySharedSound(_ setup: SoundSetup) {
        guard !engine.isRunning, !startingSession else {
            soundError = "Close your current session, then open this sound again."
            return
        }
        startSession(setup: setup)
    }

    private func prepareBacking(_ video: Video) {
        guard !engine.isRunning, !startingSession else { return }
        backingLoad?.cancel()
        backingLoad = Task {
            do {
                guard let source = try await FeedService.video(id: video.id),
                      source.backingEnabled == true, let username = source.username else {
                    throw SocialError.message("The creator no longer allows play-along on this performance.")
                }
                let track = try await BackingTrack.load(video: source, username: username)
                guard !Task.isCancelled, !engine.isRunning, !startingSession else { track.remove(); return }
                stopBacking()
                track.player.volume = Float(BackingTrackVolume.clamped(backingVolume))
                backing = track
                let setup = source.soundSetup.flatMap { sound in
                    sound.requiredPacks.allSatisfy { storeManager.isUnlocked($0) } ? sound : nil
                }
                startSession(setup: setup)
            } catch {
                if !Task.isCancelled {
                    soundError = (error as? SocialError)?.localizedDescription ?? "Couldn't load the backing audio. Try again."
                }
            }
        }
    }

    private func stopBacking() {
        backing?.remove()
        backing = nil
        backingPlaying = false
        showBackingMixer = false
    }

    private func openSocialLink(_ url: URL) {
        guard let link = PerformanceLink(url: url), SocialConfig.isConfigured else { return }
        sharedSoundLoad?.cancel()
        sharedSoundLoad = Task {
            do {
                let video = try await FeedService.video(id: link.videoID)
                guard !Task.isCancelled else { return }
                switch link {
                case .watch:
                    if let video { linkedPerformance = video }
                    else { soundError = "This performance is no longer available." }
                case .comments:
                    if let video, video.commentsEnabled != nil { linkedComments = video }
                    else { soundError = "Comments are not available for this performance." }
                case .playAlong:
                    if let video { prepareBacking(video) }
                    else { soundError = "This backing track is no longer available." }
                case .sound:
                    if let sound = video?.soundSetup { trySharedSound(sound) }
                    else { soundError = "The creator hasn't shared a sound setup for this clip, or it is no longer available." }
                }
            } catch {
                if !Task.isCancelled { soundError = "Couldn't open this link. Check your connection and try again." }
            }
        }
    }

    private func playFirstNote(_ midi: Int) {
        if ProcessInfo.processInfo.arguments.contains("--uitesting") { return }
        if engine.scaleUseSoundFont,
           engine.soundFontEngine.startIfNeeded(program: engine.selectedSoundFontInstrument.program) {
            engine.soundFontEngine.oneShot(midi: midi, velocity: 0.75, duration: 0.48)
        } else {
            engine.strudelBridge.playNote(midi: midi, waveform: engine.selectedWaveform,
                                          velocity: 0.75, duration: 0.48)
        }
        engine.haptics.noteTrigger()
    }

    #if DEBUG
    // MARK: - Promo demo mode

    /// When launched with a demo script (see `DemoDirector`), skip the start
    /// screen + onboarding, apply the script's setup, and boot Scale mode with
    /// scripted hands. Used by `promo/` to produce App Store promo videos.
    private func startDemoIfRequested() {
        guard let demo = DemoDirector.shared, !engine.isRunning else { return }
        hasSeenOnboarding = true
        let s = demo.script
        if let id = s.instrument {
            engine.selectedSoundFontInstrument = soundFontInstrument(id: id)
        }
        if let k = s.key, let key = MusicKey(rawValue: k) { engine.selectedKey = key }
        if let sc = s.scale, let scale = Scale(rawValue: sc) { engine.selectedScale = scale }
        let progId = s.progression ?? "free"
        if let prog = CHORD_PROGRESSIONS.first(where: { $0.id == progId }) {
            engine.chordMelodyProgression = prog
        }
        demo.onBeginCapture = { [engine] url in engine.soundFontEngine.startCapture(to: url) }
        demo.onEndCapture = { [engine] in engine.soundFontEngine.stopCapture() }
        engine.start(config: DEFAULT_MAPPING, advanced: false)
        engine.switchMode(grid: false, drums: false, learn: false, scaleChordMelody: true)
    }
    #endif

    // MARK: - Weave inputs & melodic-active probe

    /// Music-reactive accent color, derived from the existing `strudelHue`.
    /// Saturation/brightness fixed so the color stays legible on black at any
    /// hue.
    private var accentColor: Color {
        let h = strudelHue
        return Color(hue: h < 0 ? h + 1 : h, saturation: 0.68, brightness: 1.0)
    }

    /// Normalize a live musical parameter to 0…1 using its `PARAM_DEFS` range.
    /// Falls back to 0.5 when the param isn't registered (Weave keeps moving).
    private func normalizedParam(_ id: String) -> Double {
        guard let def = PARAM_DEFS.first(where: { $0.id == id }) else { return 0.5 }
        let v = engine.smoothedParams[id] ?? def.defaultValue
        let range = def.max - def.min
        guard range > 0 else { return 0.5 }
        return max(0, min(1, (v - def.min) / range))
    }

    /// True when the active mode is a "melodic-family" mode (vanilla Melodic,
    /// Flow, Hybrid, Lead). These share the Weave + center-note display and
    /// support tap-to-hide HUD. All other modes have their own spatial UI.
    private var melodicActive: Bool {
        !engine.gridModeEnabled && !engine.drumModeEnabled
            && !engine.learnModeEnabled && !engine.chordMelodyModeEnabled
            && !engine.radialChordMelodyModeEnabled && !engine.splitChordMelodyModeEnabled && !engine.scaleChordMelodyModeEnabled
            && !engine.soundFontModeEnabled
    }

    // MARK: - Split / Scale overlay data helpers

    /// Lettered chord names per zone, with a "⁷" suffix in Scale mode to
    /// signal the 7th-chord voicing.
    private func splitChordNames(zoneDegrees: [Int], scaleMode: Bool) -> [String] {
        zoneDegrees.map {
            chordDisplayName(key: engine.selectedKey, scale: engine.selectedScale, degree: $0)
                + (scaleMode ? "⁷" : "")
        }
    }

    /// MIDI notes the melody side maps to. Split: triad × 3 octaves (9 notes,
    /// chord-tone snap). Scale: one octave of the full diatonic scale (7).
    private func splitMelodyMidis(melodyDegree: Int, scaleMode: Bool) -> [Int] {
        if scaleMode {
            return scaleNotesOneOctave(key: engine.selectedKey, scale: engine.selectedScale)
        }
        let triad = chordNotes(key: engine.selectedKey, scale: engine.selectedScale, degree: melodyDegree)
        return (0..<3).flatMap { oct in triad.map { $0 + oct * 12 } }.sorted()
    }

    /// Lane indices that are chord tones of the active chord (Scale mode only).
    /// The overlay colors these with the chord accent so the player can see
    /// safe targets — Split returns an empty set since every lane is already
    /// a chord tone.
    private func splitChordToneLanes(melodyMidis: [Int], melodyDegree: Int, scaleMode: Bool) -> Set<Int> {
        guard scaleMode else { return [] }
        let triad7 = chordNotesWithSeventh(key: engine.selectedKey, scale: engine.selectedScale, degree: melodyDegree)
        let toneClasses = Set(triad7.map { $0 % 12 })
        return Set(melodyMidis.enumerated().compactMap { idx, midi in
            toneClasses.contains(midi % 12) ? idx : nil
        })
    }

    // MARK: - Split mode touch handlers

    /// Sustained voice IDs spawned per touch zone, so we can `noteOff` exactly
    /// what we started when the touch lifts or moves to a new zone. Each entry
    /// is the list of underlying voice strings (one per chord note for chord
    /// touches; one entry for melody touches).
    @State private var splitVoiceSubvoices: [String: [String]] = [:]

    /// Snapshot of a single live chord touch, kept on `splitTouchChordStack`
    /// so the melody-snap math can read whichever chord is currently held.
    private struct SplitTouchChord {
        let parentVoice: String
        let degree: Int
        let octave: Int
        let tones: [Int]   // absolute MIDI notes including octave shift
    }

    /// Push the touch chord state into the manager so the camera-side melody
    /// snap (and the engine's published `chordMelodyCurrentDegree`) follow
    /// whichever chord the player is touching. `clearWhenEmpty` lets exit
    /// callers wipe the override when the stack drains.
    private func syncSplitTouchChordToManager() {
        if let top = splitTouchChordStack.last {
            engine.chordMelodyModeManager.touchChordDegree = top.degree
            engine.chordMelodyModeManager.touchChordOctave = top.octave
            engine.chordMelodyModeManager.touchChordMidi = top.tones
        } else {
            engine.chordMelodyModeManager.touchChordDegree = nil
            engine.chordMelodyModeManager.touchChordOctave = 0
            engine.chordMelodyModeManager.touchChordMidi = []
        }
    }

    /// The chord degree the melody-touch handler should snap to: the most
    /// recent touched chord if any, else whatever the camera last set.
    private var splitMelodySnapDegree: Int {
        splitTouchChordStack.last?.degree
            ?? engine.chordMelodyCurrentDegree
            ?? engine.chordMelodyModeManager.zoneDegrees.first
            ?? 0
    }

    /// Start a sustained voice for one MIDI note. Routes to the SoundFont
    /// sampler or the WebView synth depending on `splitUseSoundFont`.
    private func splitNoteOn(voice: String, midi: Int, velocity: Double = 0.7) {
        if splitUsesSoundFont {
            engine.soundFontEngine.noteOn(voice: voice, midi: midi, velocity: velocity)
        } else {
            engine.strudelBridge.noteOn(hand: voice, midi: midi,
                                        waveform: engine.selectedWaveform, velocity: velocity)
        }
    }

    /// Stop a sustained voice started by `splitNoteOn`.
    private func splitNoteOff(voice: String) {
        if splitUsesSoundFont {
            engine.soundFontEngine.noteOff(voice: voice)
        } else {
            engine.strudelBridge.noteOff(hand: voice)
        }
    }

    private var splitUsesSoundFont: Bool {
        engine.scaleChordMelodyModeEnabled ? engine.scaleUseSoundFont : engine.splitUseSoundFont
    }

    /// Touch entered a Split-mode zone — spawn sustained voices and remember
    /// them under `parentVoice` so the matching `splitTouchExit` can stop them.
    private func splitTouchEnter(parentVoice: String, zone: SplitTouchZone) {
        let scaleMode = engine.scaleChordMelodyModeEnabled
        let native = splitUsesSoundFont
        switch zone {
        case .chord(let sub):
            let degree = engine.chordMelodyModeManager.degreeForZone(sub.wedge)
            // Scale mode voices the chord as a 7th — root / 3rd / 5th / 7th.
            let voicing = scaleMode
                ? chordNotesWithSeventh(key: engine.selectedKey, scale: engine.selectedScale, degree: degree)
                : chordNotes(key: engine.selectedKey, scale: engine.selectedScale, degree: degree)
            let absoluteTones = voicing.map { $0 + sub.octave * 12 }
            engine.holdJamVoice(parentVoice, pitches: absoluteTones, velocity: 0.7, native: native)
            var subs: [String] = []
            for (i, note) in absoluteTones.enumerated() {
                let sv = "\(parentVoice)-c\(i)"
                splitNoteOn(voice: sv, midi: note, velocity: 0.7)
                subs.append(sv)
            }
            splitVoiceSubvoices[parentVoice] = subs
            // Tell the manager about the touched chord so the melody hand —
            // and the live `chordMelodyCurrentDegree` published var — follow
            // it the same way they follow the camera-driven chord.
            splitTouchChordStack.append(
                SplitTouchChord(parentVoice: parentVoice, degree: degree,
                                octave: sub.octave, tones: absoluteTones)
            )
            syncSplitTouchChordToManager()
        case .melody(let lane):
            let lanes: [Int]
            if scaleMode {
                // Scale mode: one octave of the diatonic scale.
                lanes = scaleNotesOneOctave(key: engine.selectedKey, scale: engine.selectedScale)
            } else {
                let degree = splitMelodySnapDegree
                let triad = chordNotes(key: engine.selectedKey, scale: engine.selectedScale, degree: degree)
                lanes = (0..<3).flatMap { oct in triad.map { $0 + oct * 12 } }.sorted()
            }
            guard !lanes.isEmpty else { return }
            let safe = max(0, min(lanes.count - 1, lane))
            // The touch UIView doesn't track the outer-band octave shift on
            // the melody side yet — for now, a touch lands at base octave.
            // The hand-tracked path still gets the ±1 octave from the radial
            // band; touch is an explicit-tap experience.
            let sv = "\(parentVoice)-m"
            splitNoteOn(voice: sv, midi: lanes[safe], velocity: 0.75)
            engine.holdJamVoice(parentVoice, pitches: [lanes[safe]], velocity: 0.75, native: native)
            splitVoiceSubvoices[parentVoice] = [sv]
        }
        engine.haptics.noteTrigger()
    }

    /// Touch left a Split-mode zone — release all voices spawned for it.
    private func splitTouchExit(parentVoice: String) {
        engine.releaseJamVoice(parentVoice)
        if let subs = splitVoiceSubvoices[parentVoice] {
            for sv in subs { splitNoteOff(voice: sv) }
            splitVoiceSubvoices.removeValue(forKey: parentVoice)
        }
        // Drop this chord touch from the stack (if it was one) and resync.
        if splitTouchChordStack.contains(where: { $0.parentVoice == parentVoice }) {
            splitTouchChordStack.removeAll { $0.parentVoice == parentVoice }
            syncSplitTouchChordToManager()
        }
    }

    // MARK: - Performance View

    private func randomizeSettings() {
        let allKeys = MusicKey.allCases
        let allScales = Scale.allCases
        let waveformIds = WAVEFORMS.map(\.id)

        engine.selectedKey = allKeys.randomElement() ?? .C
        engine.selectedScale = allScales.randomElement() ?? .pentatonic
        engine.selectedWaveform = waveformIds.randomElement() ?? "sawtooth"
        engine.manualBPM = Double(Int.random(in: 80...160))
        engine.recomputeScaleNotes()

        withAnimation(.easeOut(duration: 0.2)) { showRandomizedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) { showRandomizedToast = false }
        }
    }

    private var performanceView: some View {
        ZStack {
            // Shake-to-randomize detector
            ShakeDetectorView { randomizeSettings() }
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)

            // Full-screen camera with filter
            ZStack {
                CameraView(handTracker: engine.handTracker)

                // Filter overlay
                if let color = engine.selectedFilter.overlayColor {
                    color.opacity(engine.selectedFilter.overlayOpacity)
                        .blendMode(engine.selectedFilter.blendMode)
                }
            }
            .saturation(engine.selectedFilter.saturation)
            .contrast(engine.selectedFilter.contrast)
            .brightness(engine.selectedFilter.brightness)
            .hueRotation(.degrees(engine.selectedFilter.hueRotation))
            .ignoresSafeArea()

            // The Weave — the music made visible. Lives under the hand
            // skeleton so your hands stay the clear instrument. Melodic-family
            // modes only; the other modes have their own spatial UI.
            if melodicActive {
                WeaveView(
                    hue: strudelHue,
                    energy: normalizedParam("gain"),
                    space: normalizedParam("reverb"),
                    brightness: normalizedParam("lpf"),
                    speed: max(0, min(1, (engine.bpm - 50) / 155)),
                    complexity: max(normalizedParam("crush"), normalizedParam("shape"))
                )
                .ignoresSafeArea()
            }

            // Current note at the heart of the weave. Stays visible when the
            // HUD is hidden — it's content, not chrome.
            if melodicActive {
                Text(engine.noteDisplay)
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundColor(.white.opacity(0.92))
                    .shadow(color: accentColor.opacity(0.6), radius: 24)
                    .scaleEffect(engine.currentBeat == 0 ? 1.06 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: engine.currentBeat)
                    .allowsHitTesting(false)
            }

            // Hand skeleton overlay with glow (aspect-corrected)
            HandOverlayView(
                handsState: engine.handsState,
                videoAspect: engine.handTracker.videoWidth / engine.handTracker.videoHeight,
                theme: engine.selectedHandTheme
            )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(isRecording && hideSkeletonWhenRecording ? 0 : 1)

            // Grid mode note lanes overlay (tappable for one-hand play)
            if engine.gridModeEnabled {
                noteGridOverlay
                    .ignoresSafeArea()
            }

            // Drum zone overlay (tappable pads)
            if engine.drumModeEnabled {
                drumZoneOverlay
                    .ignoresSafeArea()
            }

            // Chord+Melody / SoundFont mode overlay (chord zones + melody lanes).
            // Both modes share the same two-hand interaction and chordMelody*
            // UI state, so they render the same overlay.
            if engine.chordMelodyModeEnabled || engine.soundFontModeEnabled {
                ChordMelodyOverlayView(
                    zoneDegrees: engine.chordMelodyModeManager.zoneDegrees,
                    currentChordZone: engine.chordMelodyChordHandLane,
                    chordHandPinching: engine.chordMelodyModeManager.isChordHandPinching,
                    currentOctaveShift: engine.chordMelodyOctaveShift,
                    currentChordName: engine.chordMelodyCurrentChordName,
                    melodyLane: engine.chordMelodyMelodyLane,
                    melodyHandPinching: engine.chordMelodyModeManager.isMelodyHandPinching,
                    melodyLaneCount: 9,
                    swapHands: engine.chordMelodySwapHands
                )
                .ignoresSafeArea()
            }

            // Radial chord+melody overlay (one centered wheel: chords on the
            // outer ring, melody on the inner ring, rest in the middle).
            if engine.radialChordMelodyModeEnabled {
                let zoneDegrees = engine.chordMelodyModeManager.zoneDegrees
                let chordNames = zoneDegrees.map {
                    chordDisplayName(key: engine.selectedKey, scale: engine.selectedScale, degree: $0)
                }
                let melodyDegree = engine.chordMelodyCurrentDegree ?? zoneDegrees.first ?? 0
                let melodyTriad = chordNotes(key: engine.selectedKey, scale: engine.selectedScale, degree: melodyDegree)
                let melodyMidis = (0..<3).flatMap { oct in melodyTriad.map { $0 + oct * 12 } }.sorted()
                let melodyNames = melodyMidis.map { pitchClassName($0) }
                RadialChordMelodyOverlayView(
                    zoneDegrees: zoneDegrees,
                    chordNames: chordNames,
                    currentChordZone: engine.chordMelodyChordHandLane,
                    chordHandPinching: engine.chordMelodyModeManager.isChordHandPinching,
                    chordResting: engine.chordMelodyModeManager.chordResting,
                    currentChordName: engine.chordMelodyCurrentChordName,
                    melodyNames: melodyNames,
                    melodyLane: engine.chordMelodyMelodyLane,
                    melodyHandPinching: engine.chordMelodyModeManager.isMelodyHandPinching,
                    melodyResting: engine.chordMelodyModeManager.melodyResting
                )
                .ignoresSafeArea()
            }

            // Split / Scale chord+melody overlay (single circle cut in half).
            // Scale mode has 7 melody wedges = one octave of the scale; Split
            // has 9 melody wedges = 3 octaves of chord tones. The overlay
            // takes the same shape either way; what differs is the melody
            // labels + the count.
            if engine.splitChordMelodyModeEnabled || engine.scaleChordMelodyModeEnabled {
                let scaleMode = engine.scaleChordMelodyModeEnabled
                let zoneDegrees = engine.chordMelodyModeManager.zoneDegrees
                let chordNames = splitChordNames(zoneDegrees: zoneDegrees, scaleMode: scaleMode)
                let melodyDegree = engine.chordMelodyCurrentDegree ?? zoneDegrees.first ?? 0
                let melodyMidis = splitMelodyMidis(melodyDegree: melodyDegree, scaleMode: scaleMode)
                let melodyNames = melodyMidis.map { pitchClassName($0) }
                let melodyCount = melodyMidis.count
                let chordToneLanes = splitChordToneLanes(melodyMidis: melodyMidis, melodyDegree: melodyDegree, scaleMode: scaleMode)
                SplitChordMelodyOverlayView(
                    zoneDegrees: zoneDegrees,
                    chordNames: chordNames,
                    currentChordZone: engine.chordMelodyChordHandLane,
                    chordHandPinching: engine.chordMelodyModeManager.isChordHandPinching,
                    chordResting: engine.chordMelodyModeManager.chordResting,
                    currentChordName: engine.chordMelodyCurrentChordName,
                    chordOctaveShift: engine.chordMelodyOctaveShift,
                    melodyNames: melodyNames,
                    melodyLane: engine.chordMelodyMelodyLane,
                    melodyHandPinching: engine.chordMelodyModeManager.isMelodyHandPinching,
                    melodyResting: engine.chordMelodyModeManager.melodyResting,
                    swapHands: engine.chordMelodySwapHands,
                    touchedChordSubzones: splitTouchChordZones,
                    touchedMelodyLanes: splitTouchMelodyLanes,
                    chordToneLanes: chordToneLanes,
                    melodyOctaveShift: engine.chordMelodyModeManager.currentMelodyOctaveShift
                )
                .ignoresSafeArea()

                // Multitouch / drag layer on top of the visualization. Each
                // finger lights up its zone and re-fires when it crosses into
                // a new one — same feel as the grid mode multitouch.
                SplitTouchOverlay(
                    zoneCount: max(1, zoneDegrees.count),
                    melodyCount: melodyCount,
                    degreeForZone: { engine.chordMelodyModeManager.degreeForZone($0) },
                    swapHands: engine.chordMelodySwapHands,
                    onZoneEnter: { voice, zone in splitTouchEnter(parentVoice: voice, zone: zone) },
                    onZoneExit: { voice in splitTouchExit(parentVoice: voice) },
                    touchedChordSubzones: $splitTouchChordZones,
                    touchedMelodyLanes: $splitTouchMelodyLanes
                )
                .ignoresSafeArea()
            }

            // Learn mode overlay (Guitar Hero scrolling notes)
            if engine.learnModeEnabled {
                let gridNotes = scaleNotes(key: engine.selectedKey, scale: engine.selectedScale,
                                          baseOctave: engine.gridBaseOctave, octaveRange: engine.gridOctaveRange)
                LearnOverlayView(
                    noteCount: gridNotes.count,
                    scaleNotes: gridNotes,
                    visibleNotes: engine.learnVisibleNotes,
                    hitEffects: engine.learnHitEffects,
                    score: engine.learnScore,
                    songComplete: engine.learnSongComplete,
                    songName: engine.currentLearnSong?.name ?? "",
                    leftPinchX: engine.handsState.left?.pinchX,
                    leftPinchY: engine.handsState.left?.pinchY,
                    rightPinchX: engine.handsState.right?.pinchX,
                    rightPinchY: engine.handsState.right?.pinchY,
                    leftPinching: (engine.handsState.left?.pinch ?? 0) > 0.8,
                    rightPinching: (engine.handsState.right?.pinch ?? 0) > 0.8,
                    videoAspect: engine.handTracker.videoWidth / engine.handTracker.videoHeight,
                    countdownValue: engine.learnModeManager.countdownValue,
                    isCountingDown: engine.learnModeManager.isCountingDown,
                    onPlayAgain: {
                        if let song = engine.currentLearnSong { engine.loadLearnSong(song) }
                    },
                    onPickSong: { showLearnPicker = true }
                )
                .ignoresSafeArea()
            }

            // Tap an empty area (melodic mode only) to hide/show the HUD for a
            // clean view of the camera + Weave. Sits below the floating UI so
            // buttons still receive their own taps; when the HUD is hidden it
            // captures the next tap to bring it back.
            if melodicActive {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) { chromeVisible.toggle() }
                    }
            }

            // Floating UI overlays
            VStack {
                // Top bar: close button + beat dots
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Jam session indicator
                JamStatus(jam: engine.jamSession)
                if let backing, !isRecording, !recorderBusy, recordCountdown == 0 {
                    backingControls(backing)
                        .padding(.horizontal, 16)
                }
                if hasSeenOnboarding || !engine.scaleChordMelodyModeEnabled {
                    CameraRecoveryBanner(tracker: engine.handTracker)
                }

                // Floating code pill — hide in grid/drum/learn/chord/soundfont mode
                if !engine.gridModeEnabled && !engine.drumModeEnabled && !engine.learnModeEnabled && !engine.chordMelodyModeEnabled && !engine.radialChordMelodyModeEnabled && !engine.splitChordMelodyModeEnabled && !engine.scaleChordMelodyModeEnabled && !engine.soundFontModeEnabled {
                    codePill
                        .padding(.horizontal, 20)
                        .padding(.top, 2)
                }

                Spacer()

                // Note badge — hide in grid/drum/learn/chord/soundfont mode
                if !engine.gridModeEnabled && !engine.drumModeEnabled && !engine.learnModeEnabled && !engine.chordMelodyModeEnabled && !engine.radialChordMelodyModeEnabled && !engine.splitChordMelodyModeEnabled && !engine.scaleChordMelodyModeEnabled && !engine.soundFontModeEnabled {
                    noteBadge

                    beatRing
                        .padding(.bottom, 8)
                }

                // Grid quick controls (range + octave)
                if engine.gridModeEnabled {
                    gridQuickBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }

                // Drum XY pad (bottom area, below drum lanes)
                if engine.drumModeEnabled {
                    drumXYPad
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }

                // Bottom controls
                bottomControls
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                // Filter name toast
                if showFilterName {
                    Text(engine.selectedFilter.emoji + " " + engine.selectedFilter.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                        .transition(.opacity)
                }

                // Shake-to-randomize toast
                if showRandomizedToast {
                    Text("\u{1F3B2} Randomized!")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.purple.opacity(0.6)))
                        .transition(.opacity)
                }
            }
            .opacity(melodicActive && !chromeVisible ? 0 : 1)
            .allowsHitTesting(chromeVisible || !melodicActive)
            .simultaneousGesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        // Don't swipe filters while using drum XY pad or grid
                        guard !engine.drumModeEnabled && !engine.gridModeEnabled && !showBackingMixer else { return }
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        let filters = CAMERA_FILTERS.filter { !$0.isPremium || storeManager.isUnlocked($0.packId ?? "") }
                        guard let currentIdx = filters.firstIndex(where: { $0.id == engine.selectedFilter.id }) else { return }

                        let newIdx: Int
                        if value.translation.width < 0 {
                            // Swipe left → next filter
                            newIdx = (currentIdx + 1) % filters.count
                        } else {
                            // Swipe right → previous filter
                            newIdx = (currentIdx - 1 + filters.count) % filters.count
                        }
                        engine.selectedFilter = filters[newIdx]

                        // Show filter name briefly
                        withAnimation(.easeOut(duration: 0.2)) { showFilterName = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation(.easeOut(duration: 0.3)) { showFilterName = false }
                        }
                    }
            )
        }
        .sheet(isPresented: $showLearnPicker) {
            LearnSongPicker { song in
                engine.loadLearnSong(song)
                showLearnPicker = false
            }
        }
        .sheet(isPresented: $showSheet) {
            ControlSheet(engine: engine, storeManager: storeManager, hideSkeletonWhenRecording: $hideSkeletonWhenRecording,
                         recordPerformanceMicrophone: $recordPerformanceMicrophone)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .onAppear { engine.pause() }
                .onDisappear { engine.resume() }
        }
    }

    /// Short label for the play mode a clip was recorded in (shown on posts).
    private var currentModeName: String {
        if engine.scaleChordMelodyModeEnabled { return "scale" }
        if engine.splitChordMelodyModeEnabled { return "split" }
        if engine.radialChordMelodyModeEnabled { return "radial" }
        if engine.chordMelodyModeEnabled { return "chord-melody" }
        if engine.gridModeEnabled { return "grid" }
        if engine.drumModeEnabled { return "drums" }
        if engine.learnModeEnabled { return "learn" }
        return "melodic"
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Beat dots
            HStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i == engine.currentBeat
                              ? StudioStyle.accent
                              : Color.white.opacity(0.15))
                        .frame(width: 7, height: 7)
                        .scaleEffect(i == engine.currentBeat ? 1.5 : 1.0)
                        .animation(.easeOut(duration: 0.1), value: engine.currentBeat)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: "waveform").foregroundStyle(StudioStyle.accent)
                Text("handstrudel").foregroundStyle(StudioStyle.ink)
                    .lineLimit(1)
            }
            .font(.caption.monospaced().weight(.semibold))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(.black.opacity(0.55), in: Capsule())
            .accessibilityHidden(true)

            Spacer(minLength: 8)

            Button { showSetups = true } label: {
                Image(systemName: "square.stack")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .accessibilityLabel("Presets")
            .accessibilityIdentifier("studio-presets-button")
            .disabled(isRecording || recorderBusy || recordCountdown > 0 || activeAudioLoop != nil)

            JamButton(jam: engine.jamSession, action: toggleJam)
                .disabled(activeDraft?.recordedAtHalfSpeed == true || recordCountdown > 0)

            // Close button
            Button(action: { cancelCountdown(); stopBacking(); engine.stop() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .accessibilityLabel("End session")
            .disabled(isRecording || recorderBusy || activeAudioLoop != nil)
            .accessibilityIdentifier("close-button")
        }
    }

    private func toggleJam() {
        let jam = engine.jamSession
        if jam.isActive {
            jam.leaveSession()
        } else if jam.canActivate {
            jam.startSession()
        } else {
            do {
                jamInvitation = JamInvitation(controller: try GroupActivitySharingController(HandStrudelActivity()))
            } catch {
                jamError = "SharePlay is unavailable. Start a FaceTime call, then try again."
            }
        }
    }

    // MARK: - Music-reactive color

    private var strudelHue: Double {
        // Map note index (0-17) to hue (0-1), shift with beat for extra life
        let ni = engine.smoothedParams["noteIdx"] ?? 10
        let base = ni / 17.0
        let beatShift = Double(engine.currentBeat) * 0.03
        return (base + beatShift).truncatingRemainder(dividingBy: 1.0)
    }

    // MARK: - Code Pill

    private var codePill: some View {
        Group {
            if !engine.codeDisplay.isEmpty {
                Text(engine.codeDisplay.components(separatedBy: "\n").prefix(3).joined(separator: "\n"))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.green.opacity(0.8))
                    .lineLimit(3)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.green.opacity(0.12), lineWidth: 0.5)
                            )
                    )
                    .shadow(color: Color.green.opacity(0.25), radius: 8, x: 0, y: 0)
            }
        }
    }

    // MARK: - Note Badge

    private var noteBadge: some View {
        Text(engine.noteDisplay)
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(hue: strudelHue, saturation: 0.6, brightness: 0.3).opacity(0.5))
                    .overlay(
                        Capsule()
                            .stroke(Color(hue: strudelHue, saturation: 0.8, brightness: 1.0).opacity(0.6), lineWidth: 2)
                    )
            )
            .shadow(color: Color(hue: strudelHue, saturation: 0.8, brightness: 1.0).opacity(0.5), radius: 12, x: 0, y: 0)
            .scaleEffect(engine.currentBeat == 0 ? 1.1 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.5), value: engine.currentBeat)
    }

    // MARK: - Beat Ring

    private var beatRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.04), lineWidth: 1.5)
                .frame(width: 50, height: 50)

            Circle()
                .stroke(
                    engine.currentBeat % 2 == 0 ? Color.green.opacity(0.6) : Color.pink.opacity(0.6),
                    lineWidth: 1.5
                )
                .frame(width: 50, height: 50)
                .scaleEffect(engine.currentBeat == 0 ? 1.15 : 1.0)
                .opacity(engine.currentBeat == 0 ? 0.4 : 0.8)
                .animation(.easeOut(duration: 0.3), value: engine.currentBeat)

            Text("\(Int(engine.bpm.rounded()))")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Drum XY Pad

    private var drumXYPad: some View {
        GeometryReader { geo in
            let dotX = engine.drumComplexity * geo.size.width
            let dotY = (1 - engine.drumIntensity) * geo.size.height

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                // Quadrant labels
                VStack {
                    HStack {
                        Text("SOFT")
                            .foregroundColor(.white.opacity(0.15))
                        Spacer()
                        Text("LOUD")
                            .foregroundColor(.white.opacity(0.15))
                    }
                    Spacer()
                    HStack {
                        Text("SIMPLE")
                            .foregroundColor(.white.opacity(0.15))
                        Spacer()
                        Text("COMPLEX")
                            .foregroundColor(.white.opacity(0.15))
                    }
                }
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .padding(8)

                // Crosshair lines
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)

                // Position dot
                Circle()
                    .fill(Color.green)
                    .frame(width: 20, height: 20)
                    .shadow(color: .green.opacity(0.5), radius: 8)
                    .position(x: dotX, y: dotY)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let cx: Double = value.location.x / geo.size.width
                        let cy: Double = 1.0 - value.location.y / geo.size.height
                        engine.drumComplexity = max(0, min(1, cx))
                        engine.drumIntensity = max(0, min(1, cy))
                    }
            )
        }
        .frame(height: 80)
    }

    // MARK: - Grid Quick Bar

    private var gridQuickBar: some View {
        HStack(spacing: 10) {
            // Finger count indicator (when finger octave is enabled)
            if engine.fingerOctaveEnabled {
                HStack(spacing: 3) {
                    // Show finger count visually
                    ForEach(1...5, id: \.self) { i in
                        Circle()
                            .fill(i <= engine.currentFingerCount ? Color.green : Color.white.opacity(0.15))
                            .frame(width: 8, height: 8)
                    }
                }
            }

            // Octave display
            Text("Oct \(engine.gridBaseOctave)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.green)

            // Manual octave controls (when finger control is off)
            if !engine.fingerOctaveEnabled {
                Button(action: { if engine.gridBaseOctave > 1 { engine.gridBaseOctave -= 1 } }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                Button(action: { if engine.gridBaseOctave < 6 { engine.gridBaseOctave += 1 } }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }

            Spacer()

            // Sync-to-beat (quantize) toggle
            Button(action: { engine.quantizeEnabled.toggle() }) {
                Image(systemName: engine.quantizeEnabled ? "metronome.fill" : "metronome")
                    .font(.system(size: 12))
                    .foregroundColor(engine.quantizeEnabled ? .green : .white.opacity(0.5))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(engine.quantizeEnabled ? Color.green.opacity(0.15) : Color.white.opacity(0.1)))
            }

            // Finger octave toggle
            Button(action: { engine.fingerOctaveEnabled.toggle() }) {
                Image(systemName: engine.fingerOctaveEnabled ? "hand.raised.fingers.spread" : "hand.raised.slash")
                    .font(.system(size: 12))
                    .foregroundColor(engine.fingerOctaveEnabled ? .green : .white.opacity(0.5))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(engine.fingerOctaveEnabled ? Color.green.opacity(0.15) : Color.white.opacity(0.1)))
            }

            // Range pills
            ForEach([1, 2, 3], id: \.self) { range in
                Button(action: { engine.gridOctaveRange = range }) {
                    Text("\(range)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(engine.gridOctaveRange == range ? .black : .white.opacity(0.6))
                        .frame(width: 26, height: 26)
                        .background(
                            Circle().fill(engine.gridOctaveRange == range ? Color.green : Color.white.opacity(0.1))
                        )
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.black.opacity(0.5))
        )
    }

    // MARK: - Note Grid Overlay

    @State private var touchedLane: Int? = nil  // legacy, kept for compat
    @State private var touchActiveLanes: Set<Int> = []

    private var noteGridOverlay: some View {
        GeometryReader { geo in
            let notes = scaleNotes(key: engine.selectedKey, scale: engine.selectedScale, baseOctave: engine.gridBaseOctave, octaveRange: engine.gridOctaveRange)
            let count = notes.count
            // Pad top/bottom 15% to avoid dead zones where camera can't see hands
            let topPad = geo.size.height * 0.15
            let bottomPad = geo.size.height * 0.2  // more bottom padding for UI controls
            let usableHeight = geo.size.height - topPad - bottomPad
            let laneHeight = usableHeight / CGFloat(max(1, count))

            // Apply same aspect fill correction as HandOverlayView
            let vidAspect = engine.handTracker.videoWidth / engine.handTracker.videoHeight
            let scrAspect = geo.size.width / geo.size.height

            let correctedY: (Double) -> CGFloat = { vy in
                if vidAspect > scrAspect {
                    return CGFloat(vy) * geo.size.height
                } else {
                    let vis = vidAspect / scrAspect
                    let off = (1 - vis) / 2
                    return (CGFloat(vy) - off) / vis * geo.size.height
                }
            }

            let leftVisualLane: Int? = engine.handsState.left.map { hand in
                let screenY = correctedY(hand.pinchY) - topPad
                return max(0, min(count - 1, Int(screenY / laneHeight)))
            }
            let rightVisualLane: Int? = engine.handsState.right.map { hand in
                let screenY = correctedY(hand.pinchY) - topPad
                return max(0, min(count - 1, Int(screenY / laneHeight)))
            }

            VStack(spacing: 0) {
                Spacer().frame(height: topPad)
                ForEach(0..<count, id: \.self) { i in
                    let noteIdx = count - 1 - i
                    let midi = notes[noteIdx]
                    let name = midiNoteName(midi)
                    let leftActive = leftVisualLane == i
                    let rightActive = rightVisualLane == i
                    let isEven = i % 2 == 0
                    let isTouchActive = touchActiveLanes.contains(i)

                    ZStack {
                        // Lane background — split left/right + touch highlight
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(isTouchActive ? Color.cyan.opacity(0.3)
                                      : leftActive ? Color.green.opacity(engine.gridModeManager.isLeftPinching ? 0.25 : 0.1)
                                      : Color.white.opacity(isEven ? 0.03 : 0.0))
                            Rectangle()
                                .fill(isTouchActive ? Color.cyan.opacity(0.3)
                                      : rightActive ? Color.pink.opacity(engine.gridModeManager.isRightPinching ? 0.25 : 0.1)
                                      : Color.white.opacity(isEven ? 0.03 : 0.0))
                        }

                        // Left label
                        HStack {
                            Text(name)
                                .font(.system(size: (leftActive || isTouchActive) ? 14 : 11, weight: (leftActive || isTouchActive) ? .black : .medium, design: .monospaced))
                                .foregroundColor(isTouchActive ? .cyan : leftActive ? .green : .white.opacity(0.5))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill((leftActive || isTouchActive) ? Color.green.opacity(0.2) : Color.black.opacity(0.3)))
                            Spacer()
                            // Right label
                            Text(name)
                                .font(.system(size: (rightActive || isTouchActive) ? 14 : 11, weight: (rightActive || isTouchActive) ? .black : .medium, design: .monospaced))
                                .foregroundColor(isTouchActive ? .cyan : rightActive ? .pink : .white.opacity(0.3))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill((rightActive || isTouchActive) ? Color.pink.opacity(0.2) : Color.black.opacity(0.2)))
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(height: laneHeight)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(leftActive || rightActive || isTouchActive ? 0.2 : 0.06))
                            .frame(height: 1)
                    }
                }
                Spacer()
            }

            // Multitouch layer on top for two-finger play
            GridTouchOverlay(
                noteCount: count,
                topPad: topPad,
                bottomPad: bottomPad,
                notes: notes,
                waveform: engine.selectedWaveform,
                onNoteOn: { voice, midi, name in
                    engine.strudelBridge.noteOn(hand: voice, midi: midi, waveform: engine.selectedWaveform, velocity: 0.7)
                    engine.holdJamVoice(voice, pitches: [midi], velocity: 0.7)
                    engine.haptics.noteTrigger()
                    engine.lastGridNote = name
                    let elapsed = engine.startTime.map { Date().timeIntervalSince($0) } ?? 0
                    engine.loopRecorder.recordEvent(.noteOn(midi: midi, waveform: engine.selectedWaveform, velocity: 0.7), currentTime: elapsed)
                },
                onNoteOff: { voice in
                    engine.strudelBridge.noteOff(hand: voice)
                    engine.releaseJamVoice(voice)
                },
                onNoteSlide: { voice, midi, name in
                    engine.strudelBridge.noteSlide(hand: voice, midi: midi)
                    engine.slideJamVoice(voice, pitches: [midi])
                    engine.lastGridNote = name
                    engine.haptics.lightTap()
                },
                onHaptic: { },
                activeLanes: $touchActiveLanes
            )

        }
    }

    // MARK: - Drum Lane Overlay

    @State private var activeDrumLanes = Set<String>()

    private struct DrumLane: Identifiable {
        let id: String
        let name: String
        let hitType: String
        let emoji: String
        let color: Color
    }

    private let drumLanes: [DrumLane] = [
        DrumLane(id: "crash", name: "CRASH", hitType: "crash", emoji: "💥", color: .yellow),
        DrumLane(id: "hihat", name: "HI-HAT", hitType: "hihat", emoji: "🔔", color: .cyan),
        DrumLane(id: "snare", name: "SNARE", hitType: "snare", emoji: "🥁", color: .orange),
        DrumLane(id: "ride", name: "RIDE", hitType: "ride", emoji: "🛎️", color: .pink),
        DrumLane(id: "tom", name: "TOM", hitType: "tom", emoji: "🪘", color: .purple),
        DrumLane(id: "kick", name: "KICK", hitType: "kick", emoji: "🦶", color: .red),
    ]

    private var drumZoneOverlay: some View {
        GeometryReader { geo in
            let topPad = geo.size.height * 0.15
            let bottomPad = geo.size.height * 0.20
            let usableHeight = geo.size.height - topPad - bottomPad
            let laneHeight = usableHeight / CGFloat(drumLanes.count)

        VStack(spacing: 0) {
            Spacer().frame(height: topPad)

            ForEach(Array(drumLanes.enumerated()), id: \.element.id) { idx, lane in
                let leftTouched = activeDrumLanes.contains("L_\(lane.id)")
                let rightTouched = activeDrumLanes.contains("R_\(lane.id)")
                let leftHand = engine.drumLeftLane == idx
                let rightHand = engine.drumRightLane == idx
                let leftPinch = leftHand && engine.drumModeManager.isLeftPinching
                let rightPinch = rightHand && engine.drumModeManager.isRightPinching
                let leftActive = leftTouched || leftPinch
                let rightActive = rightTouched || rightPinch

                HStack(spacing: 0) {
                    // Left hand pad
                    ZStack {
                        Rectangle()
                            .fill(leftActive ? lane.color.opacity(0.35)
                                  : leftHand ? lane.color.opacity(0.1)
                                  : Color.white.opacity(0.03))

                        HStack(spacing: 6) {
                            Text(lane.emoji)
                                .font(.system(size: 20))
                            Text(lane.name)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(leftActive ? lane.color : .white.opacity(0.4))
                        }
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                let key = "L_\(lane.id)"
                                if !activeDrumLanes.contains(key) {
                                    activeDrumLanes.insert(key)
                                    engine.strudelBridge.playHit(lane.hitType)
                                    engine.jamSession.sendEvent(.drumHit(hitType: lane.hitType))
                                    engine.haptics.drumHit()
                                }
                            }
                            .onEnded { _ in
                                activeDrumLanes.remove("L_\(lane.id)")
                            }
                    )

                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1)

                    // Right hand pad
                    ZStack {
                        Rectangle()
                            .fill(rightActive ? lane.color.opacity(0.35)
                                  : rightHand ? lane.color.opacity(0.1)
                                  : Color.white.opacity(0.0))

                        HStack(spacing: 6) {
                            Text(lane.name)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(rightActive ? lane.color : .white.opacity(0.4))
                            Text(lane.emoji)
                                .font(.system(size: 20))
                        }
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                let key = "R_\(lane.id)"
                                if !activeDrumLanes.contains(key) {
                                    activeDrumLanes.insert(key)
                                    engine.strudelBridge.playHit(lane.hitType)
                                    engine.jamSession.sendEvent(.drumHit(hitType: lane.hitType))
                                    engine.haptics.drumHit()
                                }
                            }
                            .onEnded { _ in
                                activeDrumLanes.remove("R_\(lane.id)")
                            }
                    )
                }
                .frame(height: laneHeight)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(leftActive || rightActive ? 0.15 : 0.04))
                        .frame(height: 1)
                }
                .animation(.easeOut(duration: 0.08), value: leftActive)
                .animation(.easeOut(duration: 0.08), value: rightActive)
            }

            Spacer()
        }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 16) {
            // Loop record button
            loopRecordButton

            Spacer()

            // Video record button
            VStack(spacing: 4) {
                if !isRecording, !recorderBusy, recordCountdown == 0 {
                    Button {
                        recordAtHalfSpeed.toggle()
                    } label: {
                        Label("½×", systemImage: "tortoise")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(recordAtHalfSpeed ? StudioStyle.background : .white)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 32)
                            .background(recordAtHalfSpeed ? StudioStyle.accent : .black.opacity(0.55), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Half-speed recording")
                    .accessibilityValue(recordAtHalfSpeed ? "On" : "Off")
                    .accessibilityIdentifier("half-speed-recording")
                }
                recordButton
            }

            Spacer()

            // Settings button
            Button(action: { showSheet = true }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .accessibilityLabel("Music settings")
            .accessibilityIdentifier("settings-button")
            .disabled(activeAudioLoop != nil || isRecording || recorderBusy || recordCountdown > 0)
        }
    }

    @State private var showLoopSaved = false
    @State private var loopMessage = ""

    private var loopRecordButton: some View {
        Button(action: toggleAudioLoop) {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.55))
                    .frame(width: 44, height: 44)

                if engine.isLoopRecording {
                    Circle()
                        .trim(from: 0, to: engine.loopRecordingProgress)
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "stop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(StudioStyle.recording)
                } else {
                    Image(systemName: "repeat")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }

                // Loop count badge
                if !engine.savedLoops.isEmpty && !engine.isLoopRecording {
                    Text("\(engine.savedLoops.count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(StudioStyle.background)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(StudioStyle.accent))
                        .offset(x: 16, y: -16)
                }
            }
        }
        .disabled(engine.loopCaptureBusy || isRecording || recorderBusy || recordCountdown > 0)
        .accessibilityLabel(engine.isLoopRecording ? "Stop loop recording" : "Record audio loop")
        .overlay(alignment: .top) {
            if showLoopSaved {
                HStack(spacing: 6) {
                    Image(systemName: loopMessage.contains("saved") ? "checkmark.circle.fill" : loopMessage.contains("Recording") ? "record.circle" : "info.circle.fill")
                        .font(.system(size: 12))
                    Text(loopMessage)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundColor(loopMessage.contains("saved") ? .green : loopMessage.contains("Recording") ? .red : .orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            Capsule().stroke(
                                loopMessage.contains("saved") ? Color.green.opacity(0.3) : Color.orange.opacity(0.3),
                                lineWidth: 1
                            )
                        )
                )
                .offset(y: -40)
                .transition(.opacity)
            }
        }
    }

    private func backingControls(_ track: BackingTrack) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Button {
                    if track.player.isPlaying { track.player.pause(); backingPlaying = false }
                    else { backingPlaying = track.player.play() }
                } label: {
                    Label("Play along with @\(track.credit.username)", systemImage: backingPlaying ? "pause.fill" : "play.fill")
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                }
                .accessibilityLabel(backingPlaying ? "Pause backing track" : "Play backing track")
                .accessibilityHint("Performance by @\(track.credit.username)")

                Button {
                    showBackingMixer.toggle()
                } label: {
                    Image(systemName: backingVolume == 0 ? "speaker.slash.fill" : "slider.horizontal.3")
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(showBackingMixer ? 0.12 : 0), in: Circle())
                }
                .accessibilityLabel(showBackingMixer ? "Hide backing mixer" : "Show backing mixer")
            }

            if showBackingMixer {
                VStack(spacing: 0) {
                    HStack {
                        Text("Backing volume")
                        Spacer()
                        Text(BackingTrackVolume.clamped(backingVolume), format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
                    Slider(value: $backingVolume, in: 0...1, step: 0.05) {
                        Text("Backing volume")
                    }
                    .tint(StudioStyle.accent)
                    .frame(minHeight: 44)
                }
                .frame(maxWidth: 228)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.plain)
        .foregroundStyle(StudioStyle.accent)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 22))
    }

    private var recordButton: some View {
        Button {
            if isRecording { stopRecording() }
            else if recordCountdown > 0 { cancelCountdown() }
            else { startRecordingCountdown() }
        } label: {
            ZStack {
                Circle().fill(.black.opacity(0.55))
                Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5)
                if recorderBusy {
                    ProgressView().tint(.white)
                } else if isRecording {
                    RoundedRectangle(cornerRadius: 6).fill(StudioStyle.recording).frame(width: 27, height: 27)
                } else if recordCountdown > 0 {
                    VStack(spacing: 0) {
                        Text("\(recordCountdown)")
                            .font(.title3.monospacedDigit().weight(.semibold))
                        if countingBeats {
                            Text("\(recordCountdown == 1 ? "Beat" : "Beats")")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                } else {
                    Circle().fill(StudioStyle.recording).padding(7)
                }
            }
            .frame(width: 62, height: 62)
        }
        .buttonStyle(.plain)
        .disabled(recorderBusy || activeAudioLoop != nil)
        .accessibilityLabel(isRecording ? "Stop recording" : recordCountdown > 0 ? "Cancel countdown" : "Record video")
        .accessibilityValue(recordCountdown == 0 ? "" : countingBeats ? "\(recordCountdown) beats remaining" : "\(recordCountdown) seconds remaining")
        .accessibilityIdentifier("record-button")
    }

    // MARK: - Recording

    private func toggleAudioLoop() {
        if activeAudioLoop != nil { finishAudioLoop(); return }
        guard engine.isRunning, !isRecording, !recorderBusy, recordCountdown == 0 else { return }
        guard engine.savedLoops.count < EngineController.maxLoops else {
            showLoopNotice("Delete a saved loop before recording another.")
            return
        }
        let recorder = RPScreenRecorder.shared()
        guard recorder.isAvailable else {
            recordingError = "Audio capture isn't available right now."
            return
        }
        let capture = CapturedLoopFile()
        activeAudioLoop = capture
        engine.loopCaptureBusy = true
        recorder.isMicrophoneEnabled = false
        let bpm = engine.manualBPM
        let duration = min(90, max(1, engine.loopRecorder.loopDuration(bpm: bpm)))
        recorder.startCapture(handler: { sample, type, error in
            if let error { capture.fail(error) }
            if type == .audioApp { capture.append(sample) }
        }, completionHandler: { error in
            DispatchQueue.main.async {
                guard activeAudioLoop?.id == capture.id else { return }
                engine.loopCaptureBusy = false
                if let error {
                    capture.discard()
                    activeAudioLoop = nil
                    recordingError = "Couldn't start loop recording. \(error.localizedDescription)"
                    return
                }
                engine.isLoopRecording = true
                if scenePhase == .background { finishAudioLoop(); return }
                showLoopNotice("Recording app audio. Tap again to stop.")
                loopCaptureTask = Task {
                    let start = Date()
                    while !Task.isCancelled {
                        let elapsed = Date().timeIntervalSince(start)
                        engine.loopRecordingProgress = min(1, elapsed / duration)
                        if elapsed >= duration { finishAudioLoop(); return }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                }
            }
        })
    }

    private func finishAudioLoop() {
        guard let capture = activeAudioLoop, !engine.loopCaptureBusy else { return }
        engine.loopCaptureBusy = true
        loopCaptureTask?.cancel()
        loopCaptureTask = nil
        RPScreenRecorder.shared().stopCapture { error in
            DispatchQueue.main.async {
                resolveAudioLoop(capture, interruption: error)
            }
        }
    }

    private func resolveAudioLoop(_ capture: CapturedLoopFile, interruption: Error?) {
        guard activeAudioLoop?.id == capture.id else { return }
        loopCaptureTask?.cancel()
        loopCaptureTask = nil
        activeAudioLoop = nil
        engine.loopCaptureBusy = false
        engine.isLoopRecording = false
        engine.loopRecordingProgress = 0
        do {
            let duration = try capture.finish()
            engine.saveCapturedLoop(id: capture.id, duration: duration, bpm: engine.manualBPM,
                                    mode: engine.currentModeString, autoplay: scenePhase == .active && interruption == nil)
            showLoopNotice(interruption == nil ? "Loop saved as WAV." : "Recording interrupted. Partial loop saved as WAV.")
        } catch {
            capture.discard()
            recordingError = "Couldn't save the loop. \((interruption ?? error).localizedDescription)"
        }
    }

    private func showLoopNotice(_ message: String) {
        loopMessage = message
        withAnimation { showLoopSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if loopMessage == message { withAnimation { showLoopSaved = false } }
        }
    }

    private func startRecordingCountdown() {
        let recorder = RPScreenRecorder.shared()
        guard engine.isRunning, !isRecording, !recorderBusy, activeAudioLoop == nil, recordCountdown == 0 else { return }
        guard !recordAtHalfSpeed || engine.supportsHalfSpeedRecording else {
            recordingError = "Half speed is available in solo play. End the jam, guided lesson, or saved sequence first."
            return
        }
        guard recorder.isAvailable else {
            recordingError = "Screen recording isn’t available right now."
            return
        }
        let countIn = RecordingCountIn(sourceBPM: backing?.savedBPM, halfSpeed: recordAtHalfSpeed)
        backing?.player.pause()
        backingPlaying = false
        showBackingMixer = false
        countingBeats = countIn.usesBeats
        recordCountdown = countIn.steps
        countInClick = countIn.clickTrack().flatMap { try? AVAudioPlayer(data: $0) }
        countInClick?.prepareToPlay()
        captureTask = Task {
            guard !Task.isCancelled else { return }
            let clock = ContinuousClock()
            let start = clock.now
            countInClick?.play()
            for elapsedSteps in 1...countIn.steps {
                try? await clock.sleep(until: start.advanced(by: .seconds(Double(elapsedSteps) * countIn.secondsPerStep)))
                guard !Task.isCancelled else { return }
                recordCountdown = countIn.steps - elapsedSteps
            }
            clearCountdown()
            if engine.isRunning, scenePhase != .background { startRecording() }
        }
    }

    private func cancelCountdown() {
        guard recordCountdown > 0 else { return }
        captureTask?.cancel()
        clearCountdown()
    }

    private func clearCountdown() {
        countInClick?.stop()
        countInClick = nil
        captureTask = nil
        recordCountdown = 0
        countingBeats = false
    }

    private func startRecording() {
        let recorder = RPScreenRecorder.shared()
        guard !recordAtHalfSpeed || engine.supportsHalfSpeedRecording else {
            recordingError = "Half-speed recording is unavailable in this session."
            return
        }
        let draft: RecordingDraft
        do {
            let sound = engine.currentSoundSetup
            draft = try drafts.begin(instrument: sound?.instrumentName, mode: currentModeName, soundSetup: sound,
                                     backingCredit: backing?.credit, halfSpeed: recordAtHalfSpeed)
        } catch {
            recordingError = "Couldn’t create a private draft. \(error.localizedDescription)"
            return
        }
        activeDraft = draft
        recorderBusy = true
        engine.setRecordingTempo(halfSpeed: draft.recordedAtHalfSpeed == true)
        backing?.player.rate = Float(engine.recordingTempoScale)
        backing?.player.pause()
        backingPlaying = false

        recordingUsesMicrophone = false
        if recordPerformanceMicrophone, !engine.jamSession.isActive, !engine.jamSession.canActivate {
            let audio = AVAudioSession.sharedInstance()
            do {
                try audio.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
                try audio.setActive(true)
                recordingUsesMicrophone = true
            } catch {
                restoreInstrumentAudio()
            }
        }
        recorder.isMicrophoneEnabled = recordingUsesMicrophone

        // Add watermark overlay for branding in recording
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first?.windows.first {
            let wm = WatermarkManager.createWatermarkView(frame: window.bounds, credit: draft.backingCredit)
            window.addSubview(wm)
            watermarkView = wm
        }

        recorder.startRecording { error in
            DispatchQueue.main.async {
                if let error {
                    drafts.discardUnfinished(draft)
                    finishRecordingUI()
                    recordingError = "Couldn’t start recording. \(error.localizedDescription)"
                } else {
                    recorderBusy = false
                    isRecording = true
                    if scenePhase == .background { stopRecording(); return }
                    if draft.recordedAtHalfSpeed == true && !engine.supportsHalfSpeedRecording {
                        stopRecording()
                        return
                    }
                    if let backing {
                        backing.player.currentTime = 0
                        backingPlaying = backing.player.play()
                        if !backingPlaying {
                            recordingError = "The backing track couldn't start. Check the take before sharing."
                            stopRecording()
                            return
                        }
                    }
                    captureTask = Task {
                        let captureLimit = Double(RecordingDrafts.recordingLimit) / draft.outputScale
                        try? await Task.sleep(nanoseconds: UInt64(captureLimit * 1_000_000_000))
                        if !Task.isCancelled { stopRecording() }
                    }
                }
            }
        }
    }

    private func stopRecording() {
        guard isRecording, !recorderBusy, let draft = activeDraft else { return }
        recorderBusy = true
        captureTask?.cancel()
        engine.setRecordingTempo(halfSpeed: false)
        let recorder = RPScreenRecorder.shared()
        let outputURL = drafts.videoURL(for: draft.id)

        recorder.stopRecording(withOutput: outputURL) { error in
            DispatchQueue.main.async {
                finishRecordingUI()
                do {
                    if let error { throw error }
                    try drafts.complete(draft)
                    if scenePhase != .background { reviewingDraft = draft }
                } catch {
                    if (try? drafts.complete(draft)) != nil {
                        recordingError = "Recording was interrupted. Check Private drafts for the saved take."
                    } else {
                        drafts.discardUnfinished(draft)
                        recordingError = "Couldn’t save this take. \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func finishRecordingUI() {
        captureTask?.cancel()
        backing?.player.pause()
        backing?.player.rate = 1
        engine.setRecordingTempo(halfSpeed: false)
        backingPlaying = false
        if recordingUsesMicrophone {
            RPScreenRecorder.shared().isMicrophoneEnabled = false
            restoreInstrumentAudio()
            recordingUsesMicrophone = false
        }
        isRecording = false
        recorderBusy = false
        captureTask = nil
        activeDraft = nil
        watermarkView?.removeFromSuperview()
        watermarkView = nil
    }

    #if DEBUG
    private func openSampleDraft(at url: URL) {
        do {
            let draft = try drafts.begin(instrument: engine.selectedSoundFontInstrument.name, mode: currentModeName)
            do {
                try FileManager.default.copyItem(at: url, to: drafts.videoURL(for: draft.id))
                try drafts.complete(draft)
                reviewingDraft = draft
            } catch {
                drafts.discardUnfinished(draft)
                throw error
            }
        } catch {
            recordingError = error.localizedDescription
        }
    }
    #endif
}

enum BackingTrackVolume {
    static let defaultValue = 0.55

    static func clamped(_ value: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : defaultValue
    }
}

struct RecordingCountIn {
    let steps: Int
    let secondsPerStep: Double
    var usesBeats: Bool { steps == 4 }

    init(sourceBPM: Double?, halfSpeed: Bool) {
        if let sourceBPM, (20...400).contains(sourceBPM) {
            steps = 4
            secondsPerStep = 60 / sourceBPM * (halfSpeed ? 2 : 1)
        } else {
            steps = 3
            secondsPerStep = 1
        }
    }

    func clickTrack() -> Data? {
        guard usesBeats else { return nil }
        let sampleRate = 22_050
        let sampleCount = Int((Double(steps) * secondsPerStep * Double(sampleRate)).rounded())
        let clickLength = sampleRate / 25
        var samples = [Int16](repeating: 0, count: sampleCount)
        // One PCM buffer puts all four clicks on the same audio clock.
        for beat in 0..<steps {
            let onset = Int((Double(beat) * secondsPerStep * Double(sampleRate)).rounded())
            let frequency = beat == 0 ? 1_480.0 : 990.0
            for sample in 0..<clickLength {
                let phase = Double(sample) / Double(clickLength)
                let envelope = min(1, phase * 25) * (1 - phase) * (1 - phase)
                let wave = sin(2 * .pi * frequency * Double(sample) / Double(sampleRate))
                samples[onset + sample] = Int16(wave * envelope * 13_000).littleEndian
            }
        }

        let dataSize = sampleCount * MemoryLayout<Int16>.size
        var wav = Data(capacity: 44 + dataSize)
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { wav.append(contentsOf: $0) }
        }
        wav.append(contentsOf: "RIFF".utf8)
        append(UInt32(36 + dataSize))
        wav.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16))
        append(UInt16(1)) // Mono, signed 16-bit PCM.
        append(UInt16(1))
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))
        append(UInt16(2))
        append(UInt16(16))
        wav.append(contentsOf: "data".utf8)
        append(UInt32(dataSize))
        samples.withUnsafeBytes { wav.append(contentsOf: $0) }
        return wav
    }
}

@MainActor
private final class BackingTrack {
    let credit: BackingCredit
    let savedBPM: Double?
    let player: AVAudioPlayer
    private let url: URL

    private init(credit: BackingCredit, savedBPM: Double?, url: URL) throws {
        self.credit = credit
        self.savedBPM = savedBPM
        self.url = url
        player = try AVAudioPlayer(contentsOf: url)
        player.numberOfLoops = -1
        player.enableRate = true
        guard player.prepareToPlay() else { throw SocialError.message("The backing audio couldn't be prepared.") }
    }

    static func load(video: Video, username: String) async throws -> BackingTrack {
        let asset = AVURLAsset(url: video.videoURL)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, (0.1...61).contains(duration),
              !(try await asset.loadTracks(withMediaType: .audio)).isEmpty,
              let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
        else { throw SocialError.message("This performance doesn't have playable backing audio.") }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Backing-\(UUID()).m4a")
        do {
            exporter.outputURL = url
            exporter.outputFileType = .m4a
            await exporter.export()
            try Task.checkCancellation()
            guard exporter.status == .completed else { throw exporter.error ?? SocialError.message("Backing audio couldn't be downloaded.") }
            return try BackingTrack(credit: BackingCredit(videoId: video.id, username: username),
                                    savedBPM: video.soundSetup?.bpm, url: url)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    func remove() {
        player.stop()
        try? FileManager.default.removeItem(at: url)
    }
}

private final class RecorderEvents: NSObject, RPScreenRecorderDelegate {
    var onInterruption: ((Error) -> Void)?

    func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWith previewViewController: RPPreviewViewController?, error: Error?) {
        guard let error else { return }
        DispatchQueue.main.async { [weak self] in self?.onInterruption?(error) }
    }
}

private struct JamInvitation: UIViewControllerRepresentable, Identifiable {
    let id = UUID()
    let controller: GroupActivitySharingController

    func makeUIViewController(context: Context) -> GroupActivitySharingController { controller }
    func updateUIViewController(_ controller: GroupActivitySharingController, context: Context) {}
}

private struct CameraRecoveryBanner: View {
    @ObservedObject var tracker: HandTrackingManager
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let issue = tracker.cameraIssue {
            HStack {
                Text(issue).font(.caption)
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .font(.caption.weight(.semibold))
                .tint(StudioStyle.accent)
            }
            .padding(10)
            .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
        }
    }
}

private struct JamButton: View {
    @ObservedObject var jam: JamSessionManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if jam.isConnecting {
                ProgressView().tint(.white)
                    .frame(width: 44, height: 44)
            } else {
                Image(systemName: "shareplay")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(jam.isActive ? StudioStyle.accent : .white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55), in: Circle())
            }
        }
        .disabled(jam.isConnecting)
        .accessibilityLabel(jam.isActive ? "Leave SharePlay jam" : "Start SharePlay jam")
        .accessibilityIdentifier("shareplay-jam-button")
    }
}

private struct JamStatus: View {
    @ObservedObject var jam: JamSessionManager

    var body: some View {
        if jam.isActive {
            Text(jam.participantCount > 1 ? "\(jam.participantCount) people jamming" : "Waiting for friends")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StudioStyle.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.65), in: Capsule())
                .allowsHitTesting(false)
        }
    }
}
