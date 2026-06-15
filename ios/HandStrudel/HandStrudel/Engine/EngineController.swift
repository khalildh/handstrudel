import SwiftUI
import QuartzCore

struct Waveform: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let isPremium: Bool
    let packId: String?
}

let WAVEFORMS: [Waveform] = [
    // Built-in oscillators — synthesized at runtime, no audio data needed.
    Waveform(id: "sawtooth", name: "Saw",      emoji: "🪚", isPremium: false, packId: nil),
    Waveform(id: "square",   name: "Square",   emoji: "⬜", isPremium: false, packId: nil),
    Waveform(id: "triangle", name: "Triangle", emoji: "🔺", isPremium: false, packId: nil),
    Waveform(id: "sine",     name: "Sine",     emoji: "🔮", isPremium: false, packId: nil),

    // Multi-oscillator / custom-shape synths — implemented in strudel-entry.mjs.
    Waveform(id: "pluck",    name: "Pluck",    emoji: "🪕", isPremium: false, packId: nil),
    Waveform(id: "supersaw", name: "Supersaw", emoji: "🌊", isPremium: false, packId: nil),
    Waveform(id: "pulse",    name: "Pulse",    emoji: "👾", isPremium: false, packId: nil),
    Waveform(id: "fm",       name: "FM Bell",  emoji: "🔔", isPremium: false, packId: nil),

    // Bundled GM-style sampled instruments — MP3 audio ships in the app
    // bundle under Resources/instrument-samples. IDs must match
    // `bundled-instruments.json` exactly.
    Waveform(id: "piano",            name: "Piano",       emoji: "🎹", isPremium: false, packId: nil),
    Waveform(id: "epiano",           name: "E.Piano",     emoji: "🎛️", isPremium: false, packId: nil),
    Waveform(id: "organ",            name: "Organ",       emoji: "🎚️", isPremium: false, packId: nil),
    Waveform(id: "pipeorgan",        name: "Pipe Organ",  emoji: "⛪️", isPremium: false, packId: nil),
    Waveform(id: "strings",          name: "Strings",     emoji: "🎻", isPremium: false, packId: nil),
    Waveform(id: "sax",              name: "Sax",         emoji: "🎷", isPremium: false, packId: nil),
    Waveform(id: "marimba",          name: "Marimba",     emoji: "🪘", isPremium: false, packId: nil),
    Waveform(id: "kalimba",          name: "Kalimba",     emoji: "🎼", isPremium: false, packId: nil),
    Waveform(id: "flute",            name: "Flute",       emoji: "🎶", isPremium: false, packId: nil),
    Waveform(id: "bells",            name: "Bells",       emoji: "🔔", isPremium: false, packId: nil),
    Waveform(id: "steinway",         name: "Steinway",    emoji: "🎹", isPremium: false, packId: nil),
    Waveform(id: "folkharp",         name: "Folk Harp",   emoji: "🪕", isPremium: false, packId: nil),
    Waveform(id: "clavisynth",       name: "Clavinet",    emoji: "⚡️", isPremium: false, packId: nil),
    Waveform(id: "organ8",           name: "Organ 8'",    emoji: "🎹", isPremium: false, packId: nil),
    Waveform(id: "pipeorgan_loud",   name: "Pipe Loud",   emoji: "⛪️", isPremium: false, packId: nil),
    Waveform(id: "harmonica",        name: "Harmonica",   emoji: "🪗", isPremium: false, packId: nil),
    Waveform(id: "vibraphone",       name: "Vibraphone",  emoji: "🔔", isPremium: false, packId: nil),
    Waveform(id: "tubularbells",     name: "Tubular",     emoji: "🛎️", isPremium: false, packId: nil),
    Waveform(id: "xylophone",        name: "Xylophone",   emoji: "🪵", isPremium: false, packId: nil),
    Waveform(id: "balafon",          name: "Balafon",     emoji: "🪘", isPremium: false, packId: nil),
    Waveform(id: "handchimes",       name: "Handchimes",  emoji: "🔔", isPremium: false, packId: nil),
    Waveform(id: "dantranh",         name: "Đàn Tranh",   emoji: "🪕", isPremium: false, packId: nil),
    Waveform(id: "ocarina",          name: "Ocarina",     emoji: "🪈", isPremium: false, packId: nil),
    Waveform(id: "recorder_soprano", name: "Recorder S",  emoji: "🪈", isPremium: false, packId: nil),
    Waveform(id: "recorder_tenor",   name: "Recorder T",  emoji: "🪈", isPremium: false, packId: nil),
    Waveform(id: "recorder_bass",    name: "Recorder B",  emoji: "🪈", isPremium: false, packId: nil),
    Waveform(id: "saxello",          name: "Saxello",     emoji: "🎷", isPremium: false, packId: nil),
    Waveform(id: "sax_vib",          name: "Sax Vibrato", emoji: "🎷", isPremium: false, packId: nil),
    Waveform(id: "psaltery",         name: "Psaltery",    emoji: "🪕", isPremium: false, packId: nil),
    Waveform(id: "kalimba2",         name: "Kalimba 2",   emoji: "🎼", isPremium: false, packId: nil),
]

private func debugLog(_ msg: String) {
    #if DEBUG
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("debug.log")
    let line = "\(Date()): \(msg)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: url)
        }
    }
    #endif
}

@MainActor
final class EngineController: ObservableObject {
    let handTracker = HandTrackingManager()
    let strudelBridge = StrudelBridge()
    let soundFontEngine = SoundFontEngine()
    let haptics = HapticManager()
    private let saveDetector = SaveGestureDetector()

    // Configuration
    @Published var config = DEFAULT_MAPPING
    @Published var advanced = false
    @Published var isRunning = false
    @Published var isPaused = false  // true when control sheet is open
    @Published var status = "tap start"

    // UI state (updated at ~15fps)
    @Published var handsState = HandsState()
    @Published var smoothedParams = MusicParams()
    @Published var codeDisplay = ""
    @Published var noteDisplay = ""
    @Published var bpm: Double = 120
    @Published var currentBeat = 0

    // Saved snippets
    @Published var savedSnippets = [SavedSnippet]()
    @Published var playingSet = Set<Int>()
    @Published var track = (slots: [Int](), speed: 1.0)
    @Published var trackPlaying = false

    // Drum mode
    @Published var drumModeEnabled = false
    let drumModeManager = DrumModeManager()
    @Published var lastDrumHit: String = ""

    // Camera filter
    @Published var selectedFilter: CameraFilter = CAMERA_FILTERS[0]

    // Hand skeleton theme
    @Published var selectedHandTheme: HandTheme = HAND_THEMES[0]

    // Jam session (SharePlay)
    let jamSession = JamSessionManager()

    // Loop recording & playback
    let loopRecorder = LoopRecorder()
    @Published var isLoopRecording = false
    @Published var loopRecordingProgress: Double = 0
    @Published var savedLoops = [RecordedLoop]()
    @Published var playingLoopIds = Set<UUID>()

    // Learn mode (Guitar Hero-style guided play)
    @Published var learnModeEnabled = false
    let learnModeManager = LearnModeManager()
    @Published var learnScore = LearnScore()
    @Published var learnVisibleNotes: [LearnModeManager.VisibleNote] = []
    @Published var learnHitEffects: [LearnModeManager.HitEffect] = []
    @Published var learnSongComplete = false
    @Published var currentLearnSong: LearnSong? = nil

    // Grid mode (pinch-to-play)
    @Published var gridModeEnabled = false
    @Published var gridOctaveRange: Int = 2  // 1, 2, or 3 octaves
    @Published var gridBaseOctave: Int = 3   // starting octave
    let gridModeManager = GridModeManager()
    @Published var lastGridNote: String = ""
    @Published var gridLeftLane: Int? = nil
    @Published var gridRightLane: Int? = nil

    // Grid quantize ("sync to beat"): snap note timing to a rhythmic grid that
    // is phase-locked to the audible/haptic beat. See the quantize clock below.
    @Published var quantizeEnabled = false {
        didSet { quantizeLastGridStep = -1 }   // re-sync the clock on toggle
    }
    @Published var quantizeDiv: Double = 8 {  // subdivisions per cycle: 4=¼, 8=⅛, 16=1/16
        didSet { quantizeLastGridStep = -1 }   // re-sync when the grid resolution changes
    }

    // Quantize clock — learned empirically from the onBeat callbacks so the
    // grid tracks the beat the player actually hears/feels without us having to
    // know the tempo. `quantizeBeatIndex` counts quarter notes; the wall-clock
    // gap between beats gives the quarter period, which we subdivide.
    private var quantizeBeatIndex = 0
    private var quantizeBeatWallTime: CFTimeInterval = 0
    private var quantizeQuarterPeriod: Double = 0.5
    private var quantizeLastGridStep = -1

    // Chord+Melody mode (two-hand harmony)
    @Published var chordMelodyModeEnabled = false
    /// Radial variant of chord+melody: the chord/melody hands select by *angle*
    /// around a centered wheel with a rest zone in the middle, rather than
    /// sweeping a linear strip. Shares all chordMelody* state and the
    /// ChordMelodyModeController; only the manager's `layout` differs.
    @Published var radialChordMelodyModeEnabled = false
    /// Split variant of chord+melody: same single wheel as radial, but the
    /// chord hand owns one semicircle and the melody hand owns the other.
    /// Shares all chordMelody* state; only the manager's `layout` differs.
    @Published var splitChordMelodyModeEnabled = false
    /// Route radial mode through the native SoundFont sampler instead of the
    /// WebView synth. Only consulted when `radialChordMelodyModeEnabled` is on.
    @Published var radialUseSoundFont: Bool = false
    /// Route split mode through the native SoundFont sampler. Only consulted
    /// when `splitChordMelodyModeEnabled` is on.
    @Published var splitUseSoundFont: Bool = true
    @Published var chordMelodySwapHands = false  // left=chords by default; toggle for lefties
    @Published var chordMelodyPadVolume: Double = 0.6   // sustained chord pad gain (100% of the 0…0.6 slider range)
    let chordMelodyModeManager = ChordMelodyModeManager()
    @Published var chordMelodyCurrentDegree: Int? = nil
    @Published var chordMelodyCurrentChordName: String = ""
    @Published var chordMelodyChordHandLane: Int? = nil   // for UI highlight on the zone strip
    @Published var chordMelodyMelodyLane: Int? = nil
    @Published var chordMelodyOctaveShift: Int = 0        // -1, 0, +1 from chord hand Y
    @Published var chordMelodyAutoStrum: Bool = false     // re-articulate chord on each beat

    /// Currently selected chord progression (subset of diatonic degrees the
    /// chord hand cycles through). Defaults to "Free" — all 7 diatonic chords.
    @Published var chordMelodyProgression: ChordProgression =
        (CHORD_PROGRESSIONS.first(where: { $0.id == "pop" })
         ?? CHORD_PROGRESSIONS.first(where: { $0.isFree })
         ?? CHORD_PROGRESSIONS[0]) {
        didSet { chordMelodyModeManager.zoneDegrees = chordMelodyProgression.degrees }
    }

    // SoundFont mode (chord+melody interaction played through a native .sf2
    // sampler instead of the WebView synth). Reuses chordMelodyModeManager and
    // the chordMelody* published UI state since the two modes are mutually
    // exclusive and share the same two-hand interaction.
    @Published var soundFontModeEnabled = false
    @Published var selectedSoundFontInstrument: SoundFontInstrument = DEFAULT_SOUNDFONT_INSTRUMENT {
        didSet { soundFontEngine.setInstrument(program: selectedSoundFontInstrument.program) }
    }

    // Melodic-family alternative voices (all keep the other modes intact):
    //  - lead:   single hand-tracked voice routed through the imperative
    //            noteOn/noteSlide synth (no Strudel) — instant, theremin-like.
    //  - hybrid: full Strudel melodic body (effects + rhythm + code snapshots)
    //            with an imperative lead layered on top for instant pitch feel.
    //  - flow:   100% Strudel melodic, but a dense 16th-note struct so the
    //            pitch signal is sampled far more often (much tighter feedback).
    @Published var leadModeEnabled = false
    @Published var hybridModeEnabled = false
    @Published var flowModeEnabled = false

    /// Hand-tracked imperative lead voice MIDI (used by Hybrid + Lead modes).
    /// Internal — `MelodicModeController` reads/writes; engine clears on
    /// stop/pause so dangling notes don't hang.
    var leadVoiceMidi: Int? = nil

    /// Last `currentBeat` value the chord-melody / SoundFont auto-strum fired
    /// on, so we only re-articulate once per beat instead of every tick.
    private var lastChordMelodyBeat: Int = -1

    // Manual controls
    @Published var manualBPM: Double = 120
    @Published var currentStructIdx = 0
    @Published var autoRotateStructs = true
    @Published var lockedParams = Set<String>()
    @Published var manualValues = MusicParams()
    @Published var selectedWaveform: String = "sawtooth"
    @Published var selectedDrumLoop: DrumLoop = DRUM_LOOPS[0]
    @Published var drumVolume: Double = 1.0
    @Published var drumBPM: Double = 120
    @Published var selectedDrumLoop2: DrumLoop = DRUM_LOOPS[0]
    @Published var drumVolume2: Double = 1.0
    @Published var drumBPM2: Double = 120
    @Published var drumComplexity: Double = 0.5
    @Published var drumIntensity: Double = 0.5

    // Harmony
    @Published var selectedKey: MusicKey = .C
    @Published var selectedScale: Scale = .major
    @Published var chordMode: Bool = false
    @Published var circleOfFifthsEnabled: Bool = false
    @Published var chordDisplay: String = ""

    // Cached scale notes (recomputed when key/scale changes).
    // `internal` so the mode controllers can read it each tick.
    var cachedScaleNotes: [Int] = scaleNotes(key: .C, scale: .pentatonic)
    private var lastHarmonyKey = ""

    // MARK: - Persistence

    init() {
        loadPersistedState()
    }

    private func loadPersistedState() {
        let pm = PersistenceManager.shared

        // Restore settings
        if let key = MusicKey(rawValue: pm.lastKey) {
            selectedKey = key
        }
        if let scale = Scale(rawValue: pm.lastScale) {
            selectedScale = scale
        }
        selectedWaveform = pm.lastWaveform
        manualBPM = pm.lastBPM
        gridBaseOctave = pm.lastGridBaseOctave
        gridOctaveRange = pm.lastGridOctaveRange
        quantizeEnabled = pm.lastQuantizeEnabled
        quantizeDiv = pm.lastQuantizeDiv

        // Restore mode
        switch pm.lastMode {
        case "grid": gridModeEnabled = true
        case "drum": drumModeEnabled = true
        case "chordmelody": chordMelodyModeEnabled = true
        case "radialchordmelody": radialChordMelodyModeEnabled = true
        case "splitchordmelody": splitChordMelodyModeEnabled = true
        case "soundfont": soundFontModeEnabled = true
        case "lead": leadModeEnabled = true
        case "hybrid": hybridModeEnabled = true
        case "flow": flowModeEnabled = true
        default: break // melodic is the default
        }
        selectedSoundFontInstrument = soundFontInstrument(id: pm.lastSoundFont)

        // Restore camera filter
        if let filter = CAMERA_FILTERS.first(where: { $0.id == pm.lastFilterId }) {
            selectedFilter = filter
        }

        // Restore saved data
        savedLoops = pm.loadLoops()
        savedSnippets = pm.loadSnippets()

        // Recompute cached scale notes for restored key/scale
        recomputeScaleNotes()
    }

    func recomputeScaleNotes() {
        cachedScaleNotes = scaleNotes(key: selectedKey, scale: selectedScale)
    }

    var bpmIsMapped: Bool {
        config.left.values.contains("bpm") || config.right.values.contains("bpm")
    }

    func setManualValue(_ paramId: String, value: Double) {
        manualValues[paramId] = value
        if lockedParams.contains(paramId) {
            rawParams[paramId] = value
        }
    }

    func toggleLock(_ paramId: String) {
        if lockedParams.contains(paramId) {
            lockedParams.remove(paramId)
        } else {
            lockedParams.insert(paramId)
            manualValues[paramId] = smoothedParams[paramId] ?? PARAM_MAP[paramId]?.defaultValue ?? 0
        }
    }

    // Hot-path state (not Published — updated at 60fps). The mode controllers
    // read/write `smoothed`, `currentHands`, `structIdx` and `lastStructKey`
    // each tick, so those are `internal` rather than `private`.
    private var rawParams = MusicParams()
    var smoothed = MusicParams()
    var currentHands = HandsState()
    var structIdx = 0
    var lastStructKey = ""
    private var displayLink: CADisplayLink?
    private var uiTimer: Timer?
    private var structTimer: Timer?
    private(set) var startTime: Date?

    func start(config: MappingConfig, advanced: Bool) {
        debugLog("start() called")
        self.config = config
        self.advanced = advanced

        // Always start in melodic mode
        learnModeEnabled = false

        // Build default params
        let defs = buildDefaultParams(config)
        rawParams = defs
        smoothed = defs

        // UITesting bypass: skip audio/camera, just show the UI
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            isRunning = true
            return
        }

        status = "initialising strudel..."
        debugLog("status set to initialising")

        // Start Strudel in WebView
        Task {
            do {
                strudelBridge.onLog = { [weak self] msg in
                    debugLog("JS: \(msg)")
                    DispatchQueue.main.async {
                        self?.status = msg
                    }
                }
                debugLog("calling strudelBridge.initialize()")
                try await strudelBridge.initialize()
                debugLog("strudelBridge.initialize() returned")

                // Evaluate initial signal-based code
                debugLog("evaluating initial code...")
                let code = buildSignalCode(structIdx: structIdx, config: config, waveform: selectedWaveform)
                strudelBridge.evaluate(code)
                lastStructKey = String(structIdx)

                debugLog("requesting camera...")
                status = "requesting camera..."

                // Start camera + hand tracking
                handTracker.onHandsUpdate = { [weak self] hands in
                    self?.handleHandsUpdate(hands)
                }
                handTracker.startSession()
                debugLog("camera started")

                // Jam session: play remote events
                jamSession.onRemoteEvent = { [weak self] event in
                    guard let self else { return }
                    switch event {
                    case .noteOn(let midi, let waveform, let vel):
                        self.strudelBridge.playNote(midi: midi, waveform: waveform, velocity: vel * 0.7, duration: 0.2)
                    case .drumHit(let hitType):
                        self.strudelBridge.playHit(hitType)
                    case .noteOff:
                        break
                    case .bpmChange:
                        break
                    }
                }

                // Beat callback
                strudelBridge.onBeat = { [weak self] beat in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        let oldBeat = self.currentBeat
                        self.currentBeat = beat
                        if beat != oldBeat {
                            self.haptics.beatPulse(isDownbeat: beat == 0)
                            // Advance the quantize clock by one quarter note and
                            // learn the tempo from the gap between beats.
                            let now = CACurrentMediaTime()
                            if self.quantizeBeatWallTime > 0 {
                                let delta = now - self.quantizeBeatWallTime
                                if delta > 0.05 && delta < 2.0 { self.quantizeQuarterPeriod = delta }
                            }
                            self.quantizeBeatWallTime = now
                            self.quantizeBeatIndex += 1
                        }
                    }
                }

                debugLog("starting display link and timers...")
                startTime = Date()
                startDisplayLink()
                startTimers()

                debugLog("all started, setting isRunning=true")
                status = "running -- wave your hands"
                isRunning = true
            } catch {
                debugLog("start error: \(error.localizedDescription)")
                status = "error: \(error.localizedDescription)"
            }
        }
    }

    private nonisolated func handleHandsUpdate(_ hands: HandsState) {
        // Called from background processingQueue — dispatch to main for @MainActor state
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentHands = hands
            // Skip param mapping in grid/drum mode — hands control notes/hits, not synth params
            if !self.gridModeEnabled && !self.drumModeEnabled {
                HandMapper.mapHandsToParams(hands, params: &self.rawParams, config: self.config)
            }
        }
    }

    private func startDisplayLink() {
        let link = CADisplayLink(target: DisplayLinkTarget { [weak self] in
            self?.tick()
        }, selector: #selector(DisplayLinkTarget.handleDisplayLink))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    // MARK: - Tick (60fps main loop)

    // One controller per playable mode; `activeMode` selects which runs each
    // frame. The per-mode logic lives in these types (see *ModeController.swift)
    // rather than in this class.
    private let melodicMode = MelodicModeController()
    private let gridMode = GridModeController()
    private let drumMode = DrumModeController()
    private let chordMelodyMode = ChordMelodyModeController()
    private let learnMode = LearnModeController()
    private let soundFontMode = SoundFontModeController()

    private var activeMode: ModeController {
        if learnModeEnabled { return learnMode }
        if soundFontModeEnabled { return soundFontMode }
        // Radial mode normally goes through the WebView-synth chord-melody
        // controller, but flipping the per-mode toggle routes it through the
        // native SoundFont sampler instead. `tickSoundFontMode` honours the
        // radial layout flag, so the same controller works for both layouts.
        if radialChordMelodyModeEnabled && radialUseSoundFont { return soundFontMode }
        if splitChordMelodyModeEnabled && splitUseSoundFont { return soundFontMode }
        if chordMelodyModeEnabled || radialChordMelodyModeEnabled || splitChordMelodyModeEnabled { return chordMelodyMode }
        if gridModeEnabled { return gridMode }
        if drumModeEnabled { return drumMode }
        return melodicMode
    }

    private func tick() {
        updateManualOverrides()
        ParamSmoother.smooth(target: rawParams, smoothed: &smoothed)

        let isLive = playingSet.isEmpty && !trackPlaying
        guard isLive, !isPaused else { return }

        activeMode.tick(self)

        tickLoopPlayback()
        tickLoopRecordingProgress()
        tickSaveGesture()
    }

    private func updateManualOverrides() {
        if !bpmIsMapped { rawParams["bpm"] = manualBPM }
        for paramId in lockedParams {
            if let val = manualValues[paramId] { rawParams[paramId] = val }
        }
        if circleOfFifthsEnabled, let leftHand = currentHands.left {
            let cofIdx = max(0, min(11, Int(leftHand.x * 12)))
            let newKey = CIRCLE_OF_FIFTHS[cofIdx]
            if newKey != selectedKey {
                selectedKey = newKey
                recomputeScaleNotes()
            }
        }
        structIdx = currentStructIdx
    }

    @Published var fingerOctaveEnabled = false
    @Published var currentFingerCount: Int = 0


    // MARK: - SoundFont mode

    /// Same two-hand chord+melody interaction as `tickChordMelodyMode`, but the
    /// notes are voiced by the native `AVAudioUnitSampler` (`soundFontEngine`)
    /// using a real General MIDI SoundFont instead of the WebView synth. Reuses
    /// `chordMelodyModeManager` and the `chordMelody*` published UI state.
    func tickSoundFontMode() {
        // Lazily bring up the native audio graph the first time the mode runs —
        // idempotent, so this covers both the mode-switch and restore paths.
        soundFontEngine.startIfNeeded(program: selectedSoundFontInstrument.program)

        chordMelodyModeManager.layout = splitChordMelodyModeEnabled ? .split
            : radialChordMelodyModeEnabled ? .radial
            : .grid
        chordMelodyModeManager.swapHands = chordMelodySwapHands
        chordMelodyModeManager.videoAspect = handTracker.videoWidth / handTracker.videoHeight
        let bounds = UIScreen.main.bounds
        chordMelodyModeManager.screenAspect = bounds.width / bounds.height

        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0

        let chordTones: (Int) -> [Int] = { [weak self] degree in
            guard let self else { return [] }
            return chordNotes(key: self.selectedKey, scale: self.selectedScale, degree: degree)
        }
        let melodyTones: (Int) -> [Int] = { [weak self] degree in
            guard let self else { return [] }
            let triad = chordNotes(key: self.selectedKey, scale: self.selectedScale, degree: degree)
            var lanes: [Int] = []
            for octave in 0..<3 {
                for note in triad { lanes.append(note + octave * 12) }
            }
            return lanes.sorted()
        }

        // SoundFont mode intentionally runs free-time — passing quantize here
        // makes the pad/melody/accent strikes wait for grid boundaries, which
        // feels stiff and laggy with the native sampler.
        let actions = chordMelodyModeManager.tick(
            hands: currentHands,
            chordTones: chordTones,
            melodyTones: melodyTones
        )

        for action in actions {
            switch action {
            case .padOn(let notes, let degree):
                chordMelodyCurrentChordName = chordDisplayName(key: selectedKey, scale: selectedScale, degree: degree)
                chordMelodyCurrentDegree = degree
                chordMelodyOctaveShift = chordMelodyModeManager.currentOctaveShift
                for (i, midi) in notes.enumerated() {
                    soundFontEngine.noteOn(voice: "pad\(i)", midi: midi, velocity: chordMelodyPadVolume)
                }
            case .padSlide(let notes, let degree):
                chordMelodyCurrentChordName = chordDisplayName(key: selectedKey, scale: selectedScale, degree: degree)
                chordMelodyCurrentDegree = degree
                chordMelodyOctaveShift = chordMelodyModeManager.currentOctaveShift
                for (i, midi) in notes.enumerated() {
                    soundFontEngine.slide(voice: "pad\(i)", midi: midi)
                }
            case .padOff:
                for i in 0..<3 { soundFontEngine.noteOff(voice: "pad\(i)") }
            case .chordAccent(let notes, _, let vel):
                for midi in notes {
                    soundFontEngine.oneShot(midi: midi, velocity: vel * 0.6, duration: 0.5)
                    loopRecorder.recordEvent(.noteOn(midi: midi, waveform: selectedWaveform, velocity: vel * 0.5), currentTime: elapsed)
                }
                haptics.noteTrigger()
            case .melodyOn(let hand, let midi, let name, let vel):
                soundFontEngine.noteOn(voice: hand, midi: midi, velocity: vel)
                haptics.noteTrigger()
                lastGridNote = name
                loopRecorder.recordEvent(.noteOn(midi: midi, waveform: selectedWaveform, velocity: vel), currentTime: elapsed)
            case .melodyOff(let hand):
                soundFontEngine.noteOff(voice: hand)
                loopRecorder.recordEvent(.noteOff(hand: hand), currentTime: elapsed)
            case .melodySlide(let hand, let midi, let name):
                soundFontEngine.slide(voice: hand, midi: midi)
                lastGridNote = name
            }
        }

        // Publish UI state (shared with the chord+melody overlay).
        let zones = chordMelodyModeManager.currentZones(hands: currentHands)
        chordMelodyChordHandLane = zones.chordDegree
        chordMelodyMelodyLane = zones.melodyLane
        chordMelodyOctaveShift = chordMelodyModeManager.currentOctaveShift
        // Sync from the manager every frame so touch-driven chord changes
        // (which mutate manager state without emitting an action) still push
        // the new degree + name to the engine — that's what re-letters the
        // wheel's inner melody ring.
        if let deg = chordMelodyModeManager.currentChordDegree {
            chordMelodyCurrentDegree = deg
            chordMelodyCurrentChordName = chordDisplayName(key: selectedKey, scale: selectedScale, degree: deg)
        } else if let deg = zones.chordDegree, chordMelodyCurrentDegree == nil {
            chordMelodyCurrentChordName = chordDisplayName(key: selectedKey, scale: selectedScale, degree: deg)
        }

        // Auto-strum: re-articulate the held chord on each beat.
        if chordMelodyAutoStrum,
           chordMelodyModeManager.currentChordMidi.isEmpty == false,
           currentBeat != lastChordMelodyBeat {
            lastChordMelodyBeat = currentBeat
            for midi in chordMelodyModeManager.currentChordMidi {
                soundFontEngine.oneShot(midi: midi, velocity: 0.3, duration: 0.4)
            }
        }

        evaluateDrumLoopsIfChanged(modePrefix: "soundfont")
    }

    /// Has the quantize grid advanced to a new subdivision since the last tick?
    /// Returns true at most once per grid step. The grid is anchored to the
    /// onBeat clock so steps land on (and evenly between) the felt beats.
    /// `quantizeDiv` is the number of subdivisions per cycle (4 quarters), so
    /// e.g. 8 → two steps per quarter (eighth notes).
    func quantizeBoundaryCrossed() -> Bool {
        guard quantizeEnabled, quantizeBeatWallTime > 0, quantizeQuarterPeriod > 0 else { return false }
        let subsPerQuarter = max(1.0, quantizeDiv / 4.0)
        let now = CACurrentMediaTime()
        let frac = min(2.0, max(0, (now - quantizeBeatWallTime) / quantizeQuarterPeriod))
        let subPos = (Double(quantizeBeatIndex) + frac) * subsPerQuarter
        let step = Int(floor(subPos))
        if quantizeLastGridStep == -1 {
            quantizeLastGridStep = step   // first observation: sync, don't fire
            return false
        }
        if step != quantizeLastGridStep {
            quantizeLastGridStep = step
            return true
        }
        return false
    }

    // Drum hand lane tracking for UI
    @Published var drumLeftLane: Int? = nil
    @Published var drumRightLane: Int? = nil

    // MARK: - Learn Mode

    func loadLearnSong(_ song: LearnSong) {
        // Auto-set key and scale to match the song
        selectedKey = song.suggestedKey
        selectedScale = song.suggestedScale
        recomputeScaleNotes()

        let gridNotes = scaleNotes(key: selectedKey, scale: selectedScale,
                                   baseOctave: gridBaseOctave, octaveRange: gridOctaveRange)
        learnModeManager.loadSong(song, scaleNotes: gridNotes, bpm: song.bpm)
        manualBPM = song.bpm
        currentLearnSong = song
        learnSongComplete = false
    }

    private static let maxSnippets = 50
    private static let maxLoops = 20

    private func tickSaveGesture() {
        guard !gridModeEnabled && !drumModeEnabled else { return }
        guard savedSnippets.count < Self.maxSnippets else { return }
        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
        if saveDetector.check(hands: currentHands, config: config, currentTime: elapsed) {
            let snippet = SavedSnippet(
                code: buildCode(smoothed, structIdx: structIdx, config: config, waveform: selectedWaveform),
                bpm: Int((smoothed["bpm"] ?? 120).rounded())
            )
            savedSnippets.append(snippet)
        }
    }

    // MARK: - Loop Recording & Playback

    private func tickLoopPlayback() {
        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
        let events = loopRecorder.getPlaybackEvents(currentTime: elapsed)
        for (event, volume) in events {
            switch event {
            case .noteOn(let midi, let waveform, let vel):
                strudelBridge.playNote(midi: midi, waveform: waveform, velocity: vel * volume, duration: 0.2)
            case .drumHit(let hitType):
                strudelBridge.playHit(hitType)
            case .noteOff:
                break // one-shot playback, no sustained notes in loops
            case .codeSnapshot(let code):
                strudelBridge.evaluate(code)
            }
        }
    }

    private func tickLoopRecordingProgress() {
        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
        let currentBpm = smoothed["bpm"] ?? manualBPM

        // Auto-stop recording when loop duration reached
        if loopRecorder.isRecording && loopRecorder.checkAutoStop(currentTime: elapsed, bpm: currentBpm) {
            if let loop = loopRecorder.stopRecording(bpm: currentBpm) {
                savedLoops.append(loop)
                // Auto-play the just-recorded loop
                loopRecorder.addLoop(loop, startTime: elapsed)
                playingLoopIds.insert(loop.id)
            }
            isLoopRecording = false
        }

        loopRecordingProgress = loopRecorder.recordingProgress(currentTime: elapsed, bpm: currentBpm)
    }

    func startLoopRecording() {
        guard savedLoops.count < Self.maxLoops else { return }
        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
        let mode = currentModeString
        loopRecorder.startRecording(currentTime: elapsed, mode: mode)
        isLoopRecording = true
    }

    @discardableResult
    func stopLoopRecording() -> Bool {
        let currentBpm = smoothed["bpm"] ?? manualBPM
        if let loop = loopRecorder.stopRecording(bpm: currentBpm) {
            savedLoops.append(loop)
            let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
            loopRecorder.addLoop(loop, startTime: elapsed)
            playingLoopIds.insert(loop.id)
            isLoopRecording = false
            return true
        }
        isLoopRecording = false
        return false
    }

    func toggleLoopPlayback(_ loopId: UUID) {
        if playingLoopIds.contains(loopId) {
            loopRecorder.removeLoop(loopId)
            playingLoopIds.remove(loopId)
        } else if let loop = savedLoops.first(where: { $0.id == loopId }) {
            let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
            loopRecorder.addLoop(loop, startTime: elapsed)
            playingLoopIds.insert(loopId)
        }
    }

    func deleteLoop(_ loopId: UUID) {
        loopRecorder.removeLoop(loopId)
        playingLoopIds.remove(loopId)
        savedLoops.removeAll { $0.id == loopId }
    }

    func stopAllLoops() {
        loopRecorder.stopPlayback()
        playingLoopIds.removeAll()
    }

    // MARK: - Drum Code Helpers (shared by all modes)

    // Cached to avoid 60fps string allocation
    private var _cachedDrumKey = ""
    private var _lastDrumIds = ("", "")
    private var _lastDrumVals = (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

    // `internal` so mode controllers can fold drum state into their struct keys.
    var drumStateKey: String {
        let ids = (selectedDrumLoop.id, selectedDrumLoop2.id)
        let vals = (drumVolume, drumBPM, drumVolume2, drumBPM2, drumComplexity, drumIntensity)
        if ids != _lastDrumIds || vals != _lastDrumVals {
            _lastDrumIds = ids
            _lastDrumVals = vals
            _cachedDrumKey = "\(ids.0)|\(vals.0)|\(vals.1)|\(ids.1)|\(vals.2)|\(vals.3)|\(vals.4)|\(vals.5)"
        }
        return _cachedDrumKey
    }

    func buildDrumCodeParts() -> [String] {
        let intensityGain = 0.3 + drumIntensity * 1.2
        let complexitySpeed = 1.0 + drumComplexity * 2.0

        var parts: [String] = []
        var code1 = selectedDrumLoop.code
        if !code1.isEmpty {
            let vol = drumVolume * intensityGain
            code1 = "(\(code1)).gain(\(String(format: "%.2f", vol)))"
            // BPM via cpm (cycles per minute = BPM / 4)
            let cpm1 = drumBPM / 4.0 * complexitySpeed
            code1 = "(\(code1)).cpm(\(String(format: "%.1f", cpm1)))"
            parts.append(code1)
        }
        var code2 = selectedDrumLoop2.code
        if !code2.isEmpty {
            let vol = drumVolume2 * intensityGain
            code2 = "(\(code2)).gain(\(String(format: "%.2f", vol)))"
            let cpm2 = drumBPM2 / 4.0 * complexitySpeed
            code2 = "(\(code2)).cpm(\(String(format: "%.1f", cpm2)))"
            parts.append(code2)
        }
        return parts
    }

    func evaluateDrumLoopsIfChanged(modePrefix: String) {
        let key = "\(modePrefix)|\(drumStateKey)"
        guard key != lastStructKey else { return }
        lastStructKey = key
        let parts = buildDrumCodeParts()
        if parts.isEmpty {
            strudelBridge.evaluate("silence")
        } else {
            let code = parts.count == 1 ? parts[0] : "stack(\(parts.joined(separator: ", ")))"
            strudelBridge.evaluate(code)
        }
    }

    private func startTimers() {
        // Struct rotation every 8s (only when auto-rotate is on)
        structTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            guard let self, self.autoRotateStructs else { return }
            self.currentStructIdx = (self.currentStructIdx + 1) % STRUCTS.count
        }

        // UI sync at ~15fps
        // UI sync at ~8fps (enough for visual meters, reduces SwiftUI rebuilds)
        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.125, repeats: true) { [weak self] _ in
            guard let self else { return }
            let s = self.smoothed
            let notes = self.cachedScaleNotes

            DispatchQueue.main.async {
                self.smoothedParams = s
                self.handsState = self.currentHands
                self.bpm = s["bpm"] ?? 120

                if self.gridModeEnabled {
                    // Grid mode: show last triggered note
                    self.noteDisplay = self.lastGridNote.isEmpty ? "pinch to play" : self.lastGridNote
                    self.chordDisplay = ""
                    self.codeDisplay = "grid mode — \(self.selectedKey.rawValue) \(self.selectedScale.rawValue)"
                } else if self.chordMode {
                    let noteCount: Int = self.selectedScale.intervals.count
                    let rawIdx: Double = s["noteIdx"] ?? 0
                    let normalized: Double = rawIdx / Double(NOTES.count - 1)
                    let degree: Int = max(0, min(noteCount - 1, Int(normalized * Double(noteCount - 1) + 0.5)))
                    self.noteDisplay = chordDisplayName(key: self.selectedKey, scale: self.selectedScale, degree: degree)
                    self.chordDisplay = self.noteDisplay
                } else if !notes.isEmpty {
                    let rawIdx: Double = s["noteIdx"] ?? 10
                    let normalized: Double = rawIdx / Double(NOTES.count - 1)
                    let idx: Int = max(0, min(notes.count - 1, Int(normalized * Double(notes.count - 1) + 0.5)))
                    let midi: Int = notes[idx]
                    self.noteDisplay = midiNoteName(midi)
                    self.chordDisplay = ""
                } else {
                    let ni: Int = max(0, min(NOTES.count - 1, Int((s["noteIdx"] ?? 10).rounded())))
                    self.noteDisplay = NOTE_DISPLAY[ni]
                    self.chordDisplay = ""
                }

                if !self.gridModeEnabled {
                    self.codeDisplay = self.buildDisplayCode(s)
                }
            }
        }
    }

    // MARK: - Display code (simplified, no HTML needed)

    private func buildDisplayCode(_ p: MusicParams) -> String {
        let cpm = String(format: "%.1f", (p["bpm"] ?? 120) / 4)
        let st = STRUCTS[max(0, min(STRUCTS.count - 1, structIdx))]
        let notes = cachedScaleNotes

        let noteStr: String
        if chordMode {
            let noteCount = selectedScale.intervals.count
            let degree = max(0, min(noteCount - 1, Int((p["noteIdx"] ?? 0) / Double(NOTES.count - 1) * Double(noteCount - 1) + 0.5)))
            let chord = chordNotes(key: selectedKey, scale: selectedScale, degree: degree)
            noteStr = chord.map { midiToStrudelNote($0) }.joined(separator: ",")
        } else if !notes.isEmpty {
            let noteIdx = max(0, min(notes.count - 1, Int((p["noteIdx"] ?? 10) / Double(NOTES.count - 1) * Double(notes.count - 1) + 0.5)))
            noteStr = midiToStrudelNote(notes[noteIdx])
        } else {
            let ni = max(0, min(NOTES.count - 1, Int((p["noteIdx"] ?? 10).rounded())))
            noteStr = NOTES[ni]
        }

        var lines = [
            "note(\"\(noteStr)\")",
            "  .s(\"\(selectedWaveform)\")",
            "  .struct(\"\(st)\")",
            "  .cpm(\(cpm))",
        ]

        for id in extraParamIds(config) {
            guard let def = PARAM_MAP[id] else { continue }
            lines.append("  .\(def.strudelKey)(\(def.toCode(p[id] ?? def.defaultValue)))")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Snippet Playback

    func toggleSnippet(_ idx: Int) {
        // Stop track
        if trackPlaying {
            trackPlaying = false
        }

        var set = playingSet
        if set.contains(idx) {
            set.remove(idx)
        } else {
            set.insert(idx)
        }
        playingSet = set

        if set.isEmpty {
            lastStructKey = "" // force re-eval
        } else {
            let codes = set.sorted().compactMap { savedSnippets[safe: $0]?.code }
            let code = codes.count == 1 ? codes[0] : "stack(\(codes.joined(separator: ", ")))"
            strudelBridge.evaluate(code)
        }
    }

    func addToTrack(_ idx: Int) {
        track.slots.append(idx)
        if trackPlaying {
            if let code = buildTrackCode(slots: track.slots, speed: track.speed, snippets: savedSnippets) {
                strudelBridge.evaluate(code)
            }
        }
    }

    func removeFromTrack(_ slotIdx: Int) {
        track.slots.remove(at: slotIdx)
        if track.slots.isEmpty && trackPlaying {
            trackPlaying = false
            lastStructKey = ""
        } else if trackPlaying {
            if let code = buildTrackCode(slots: track.slots, speed: track.speed, snippets: savedSnippets) {
                strudelBridge.evaluate(code)
            }
        }
    }

    func setTrackSpeed(_ speed: Double) {
        track.speed = speed
        if trackPlaying {
            if let code = buildTrackCode(slots: track.slots, speed: speed, snippets: savedSnippets) {
                strudelBridge.evaluate(code)
            }
        }
    }

    func toggleTrackPlay() {
        if trackPlaying {
            trackPlaying = false
            lastStructKey = ""
        } else {
            guard !track.slots.isEmpty else { return }
            playingSet.removeAll()
            trackPlaying = true
            if let code = buildTrackCode(slots: track.slots, speed: track.speed, snippets: savedSnippets) {
                strudelBridge.evaluate(code)
            }
        }
    }

    /// Kill all active sounds without stopping the engine
    func silenceAll() {
        strudelBridge.noteOff(hand: "left")
        strudelBridge.noteOff(hand: "right")
        strudelBridge.noteOff(hand: "touch1")
        strudelBridge.noteOff(hand: "touch2")
        strudelBridge.noteOff(hand: "lead")
        leadVoiceMidi = nil
        strudelBridge.stop()
        soundFontEngine.allNotesOff()
        lastStructKey = "" // force re-eval when resuming
    }

    /// Pause audio (control sheet open)
    func pause() {
        isPaused = true
        silenceAll()
    }

    /// Resume audio (control sheet closed)
    func resume() {
        isPaused = false
    }

    /// Call when switching modes to stop lingering sounds
    func switchMode(grid: Bool, drums: Bool, learn: Bool, chordMelody: Bool = false,
                    lead: Bool = false, hybrid: Bool = false, flow: Bool = false,
                    soundFont: Bool = false, radialChordMelody: Bool = false,
                    splitChordMelody: Bool = false) {
        silenceAll()
        gridModeEnabled = grid
        drumModeEnabled = drums
        learnModeEnabled = learn
        chordMelodyModeEnabled = chordMelody
        radialChordMelodyModeEnabled = radialChordMelody
        splitChordMelodyModeEnabled = splitChordMelody
        leadModeEnabled = lead
        hybridModeEnabled = hybrid
        flowModeEnabled = flow
        soundFontModeEnabled = soundFont
        if soundFont {
            soundFontEngine.startIfNeeded(program: selectedSoundFontInstrument.program)
        }
    }

    /// Persisted/loop-record label for the current mode.
    var currentModeString: String {
        if gridModeEnabled { return "grid" }
        if drumModeEnabled { return "drum" }
        if soundFontModeEnabled { return "soundfont" }
        if radialChordMelodyModeEnabled { return "radialchordmelody" }
        if splitChordMelodyModeEnabled { return "splitchordmelody" }
        if chordMelodyModeEnabled { return "chordmelody" }
        if leadModeEnabled { return "lead" }
        if hybridModeEnabled { return "hybrid" }
        if flowModeEnabled { return "flow" }
        return "melodic"
    }

    func stop() {
        // Persist state before teardown
        let mode = currentModeString
        PersistenceManager.shared.lastSoundFont = selectedSoundFontInstrument.id
        PersistenceManager.shared.saveEngineState(
            presetId: nil,
            mode: mode,
            key: selectedKey.rawValue,
            scale: selectedScale.rawValue,
            waveform: selectedWaveform,
            bpm: manualBPM,
            filterId: selectedFilter.id,
            gridBaseOctave: gridBaseOctave,
            gridOctaveRange: gridOctaveRange,
            quantizeEnabled: quantizeEnabled,
            quantizeDiv: quantizeDiv
        )
        PersistenceManager.shared.saveLoops(savedLoops)
        PersistenceManager.shared.saveSnippets(savedSnippets)

        // Timers
        displayLink?.invalidate()
        displayLink = nil
        uiTimer?.invalidate()
        uiTimer = nil
        structTimer?.invalidate()
        structTimer = nil

        // Audio/camera — kill all voices immediately
        silenceAll()
        strudelBridge.stop()
        handTracker.stopSession()
        handTracker.onHandsUpdate = nil
        strudelBridge.onBeat = nil
        strudelBridge.onLog = nil

        // Reset all state
        saveDetector.reset()
        loopRecorder.reset()
        jamSession.leaveSession()
        gridModeEnabled = false
        drumModeEnabled = false
        soundFontModeEnabled = false
        chordMelodyModeEnabled = false
        radialChordMelodyModeEnabled = false
        splitChordMelodyModeEnabled = false
        leadModeEnabled = false
        hybridModeEnabled = false
        flowModeEnabled = false
        leadVoiceMidi = nil
        gridLeftLane = nil
        gridRightLane = nil
        lastGridNote = ""
        lastDrumHit = ""
        lastStructKey = ""

        isRunning = false
        status = "tap start"
    }

    deinit {
        displayLink?.invalidate()
        uiTimer?.invalidate()
        structTimer?.invalidate()
    }
}

// Helper to use CADisplayLink with a closure
private class DisplayLinkTarget: NSObject {
    let callback: () -> Void
    init(callback: @escaping () -> Void) { self.callback = callback }
    @objc func handleDisplayLink() { callback() }
}
