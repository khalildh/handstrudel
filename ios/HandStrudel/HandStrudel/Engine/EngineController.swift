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

    // Chord+Melody mode (two-hand harmony)
    @Published var chordMelodyModeEnabled = false
    @Published var chordMelodySwapHands = false  // left=chords by default; toggle for lefties
    @Published var chordMelodyPadVolume: Double = 0.22  // sustained chord pad gain
    let chordMelodyModeManager = ChordMelodyModeManager()
    @Published var chordMelodyCurrentDegree: Int? = nil
    @Published var chordMelodyCurrentChordName: String = ""
    @Published var chordMelodyChordHandLane: Int? = nil   // for UI highlight on the zone strip
    @Published var chordMelodyMelodyLane: Int? = nil
    @Published var chordMelodyOctaveShift: Int = 0        // -1, 0, +1 from chord hand Y
    @Published var chordMelodyAutoStrum: Bool = false     // re-articulate chord on each beat
    private var lastChordMelodyBeat: Int = -1             // edge detection for auto-strum

    /// Currently selected chord progression (subset of diatonic degrees the
    /// chord hand cycles through). Defaults to "Free" — all 7 diatonic chords.
    @Published var chordMelodyProgression: ChordProgression = CHORD_PROGRESSIONS.first(where: { $0.isFree }) ?? CHORD_PROGRESSIONS[0] {
        didSet { chordMelodyModeManager.zoneDegrees = chordMelodyProgression.degrees }
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

    /// MIDI note currently held by the imperative lead voice (lead + hybrid
    /// modes), or nil when the voice is off. Drives noteOn vs. noteSlide.
    private var leadVoiceMidi: Int? = nil

    // EDM mode — a live, gesture-driven performance mode built on the hybrid
    // approach (Strudel four-on-floor + pumped pad/bass + master filter, with
    // the instant imperative lead on top). See tickEDMMode.
    @Published var edmModeEnabled = false
    /// True while a build-up/riser is running (kick drops out, filter sweeps up).
    @Published var edmBuilding = false
    /// Length of the build-up in bars (4 beats each) before it drops.
    @Published var edmBuildBars = 2
    private var edmBuildStart: Date?
    /// Edge-trigger guard for the two-fist build gesture (re-arms on release).
    private var edmGestureArmed = true

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
    @Published var selectedScale: Scale = .pentatonic
    @Published var chordMode: Bool = false
    @Published var circleOfFifthsEnabled: Bool = false
    @Published var chordDisplay: String = ""

    // Cached scale notes (recomputed when key/scale changes)
    private var cachedScaleNotes: [Int] = scaleNotes(key: .C, scale: .pentatonic)
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

        // Restore mode
        switch pm.lastMode {
        case "grid": gridModeEnabled = true
        case "drum": drumModeEnabled = true
        case "lead": leadModeEnabled = true
        case "hybrid": hybridModeEnabled = true
        case "flow": flowModeEnabled = true
        case "edm": edmModeEnabled = true
        default: break // melodic is the default
        }

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

    // Hot-path state (not Published — updated at 60fps)
    private var rawParams = MusicParams()
    private var smoothed = MusicParams()
    private var currentHands = HandsState()
    private var structIdx = 0
    private var lastStructKey = ""
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

    private func tick() {
        updateManualOverrides()
        ParamSmoother.smooth(target: rawParams, smoothed: &smoothed)

        let isLive = playingSet.isEmpty && !trackPlaying
        guard isLive, !isPaused else { return }

        if learnModeEnabled {
            tickLearnMode()
        } else if chordMelodyModeEnabled {
            tickChordMelodyMode()
        } else if gridModeEnabled {
            tickGridMode()
        } else if drumModeEnabled {
            tickDrumMode()
        } else if edmModeEnabled {
            tickEDMMode()
        } else if leadModeEnabled {
            tickLeadMode()
        } else if hybridModeEnabled {
            tickHybridMode()
        } else if flowModeEnabled {
            tickFlowMode()
        } else {
            tickMelodicMode()
        }


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

    private func tickGridMode() {
        gridModeManager.videoAspect = handTracker.videoWidth / handTracker.videoHeight
        let screenBounds = UIScreen.main.bounds
        gridModeManager.screenAspect = screenBounds.width / screenBounds.height

        // Finger count octave: non-pinching hand's fingers set the octave
        if fingerOctaveEnabled {
            // Check which hand is NOT pinching and use its finger count
            let leftPinching = gridModeManager.isLeftPinching
            let rightPinching = gridModeManager.isRightPinching

            let fingerHand: HandData?
            if leftPinching && !rightPinching {
                fingerHand = currentHands.right // right hand controls octave
            } else if rightPinching && !leftPinching {
                fingerHand = currentHands.left  // left hand controls octave
            } else if !leftPinching && !rightPinching {
                // Neither pinching — use whichever hand has more fingers up
                let leftFingers = currentHands.left?.fingersUp ?? 0
                let rightFingers = currentHands.right?.fingersUp ?? 0
                fingerHand = leftFingers >= rightFingers ? currentHands.left : currentHands.right
            } else {
                fingerHand = nil // both pinching, don't change
            }

            if let hand = fingerHand {
                let fingers = hand.fingersUp
                currentFingerCount = fingers
                if fingers >= 1 && fingers <= 5 {
                    let newOctave = fingers + 1 // 1 finger = octave 2, 5 fingers = octave 6
                    if newOctave != gridBaseOctave {
                        gridBaseOctave = newOctave
                    }
                }
            }
        }

        let gridNotes = scaleNotes(key: selectedKey, scale: selectedScale, baseOctave: gridBaseOctave, octaveRange: gridOctaveRange)
        let actions = gridModeManager.checkNotes(hands: currentHands, scaleNotes: gridNotes, currentBeat: 0)
        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
        for action in actions {
            switch action {
            case .noteOn(let hand, let midi, let name, let vel):
                strudelBridge.noteOn(hand: hand, midi: midi, waveform: selectedWaveform, velocity: vel)
                haptics.noteTrigger()
                lastGridNote = name
                loopRecorder.recordEvent(.noteOn(midi: midi, waveform: selectedWaveform, velocity: vel), currentTime: elapsed)
                jamSession.sendEvent(.noteOn(midi: midi, waveform: selectedWaveform, velocity: vel))
            case .noteOff(let hand):
                strudelBridge.noteOff(hand: hand)
                loopRecorder.recordEvent(.noteOff(hand: hand), currentTime: elapsed)
                jamSession.sendEvent(.noteOff(hand: hand))
            case .slide(let hand, let midi, let name):
                strudelBridge.noteSlide(hand: hand, midi: midi)
                lastGridNote = name
            }
        }

        let lanes = gridModeManager.currentLanes(hands: currentHands, scaleNotes: gridNotes)
        gridLeftLane = lanes.left
        gridRightLane = lanes.right

        // Only drum loops (no continuous synth)
        evaluateDrumLoopsIfChanged(modePrefix: "grid")
    }

    // MARK: - Chord+Melody mode

    private func tickChordMelodyMode() {
        chordMelodyModeManager.swapHands = chordMelodySwapHands
        chordMelodyModeManager.videoAspect = handTracker.videoWidth / handTracker.videoHeight
        let bounds = UIScreen.main.bounds
        chordMelodyModeManager.screenAspect = bounds.width / bounds.height

        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0

        // Closure that returns the triad MIDI notes for a given scale degree —
        // used to play the chord on the chord hand.
        let chordTones: (Int) -> [Int] = { [weak self] degree in
            guard let self else { return [] }
            return chordNotes(key: self.selectedKey, scale: self.selectedScale, degree: degree)
        }

        // Closure that returns the melody hand's snap targets: the chord tones
        // expanded across ~2 octaves so the melody hand has 6-9 lanes to choose
        // from. This is the "cheap version" of chord-aware snap from the
        // implementation notes: melody can only pick chord tones, period.
        let melodyTones: (Int) -> [Int] = { [weak self] degree in
            guard let self else { return [] }
            let triad = chordNotes(key: self.selectedKey, scale: self.selectedScale, degree: degree)
            // Expand triad up across octaves so the melody hand has multiple lanes.
            // Each octave above the base contributes another root/third/fifth.
            var lanes: [Int] = []
            for octave in 0..<3 {
                for note in triad {
                    lanes.append(note + octave * 12)
                }
            }
            return lanes.sorted()
        }

        let actions = chordMelodyModeManager.tick(
            hands: currentHands,
            chordTones: chordTones,
            melodyTones: melodyTones
        )

        for action in actions {
            switch action {
            case .padOn(let notes, let degree):
                let name = chordDisplayName(key: selectedKey, scale: selectedScale, degree: degree)
                chordMelodyCurrentChordName = name
                chordMelodyCurrentDegree = degree
                chordMelodyOctaveShift = chordMelodyModeManager.currentOctaveShift
                // Bring up 3 sustained pad voices at low volume — the chord
                // sits quietly under the melody so the player always hears the
                // harmony without the right hand having to play.
                for (i, midi) in notes.enumerated() {
                    strudelBridge.noteOn(hand: "pad\(i)", midi: midi, waveform: "triangle", velocity: chordMelodyPadVolume)
                }
            case .padSlide(let notes, let degree):
                let name = chordDisplayName(key: selectedKey, scale: selectedScale, degree: degree)
                chordMelodyCurrentChordName = name
                chordMelodyCurrentDegree = degree
                chordMelodyOctaveShift = chordMelodyModeManager.currentOctaveShift
                // Glide each pad voice to the new chord tone — Strudel's
                // noteSlide ramps pitch without re-attacking the envelope, so
                // chord changes blend instead of clicking.
                for (i, midi) in notes.enumerated() {
                    strudelBridge.noteSlide(hand: "pad\(i)", midi: midi)
                }
            case .padOff:
                for i in 0..<3 {
                    strudelBridge.noteOff(hand: "pad\(i)")
                }
            case .chordAccent(let notes, _, let vel):
                // Pinch on the chord hand is an additive accent — a brief
                // chord stab on top of the existing pad. Quiet enough that
                // it doesn't dominate the melody.
                for midi in notes {
                    strudelBridge.playNote(midi: midi, waveform: selectedWaveform, velocity: vel * 0.5, duration: 0.5)
                    loopRecorder.recordEvent(.noteOn(midi: midi, waveform: selectedWaveform, velocity: vel * 0.5), currentTime: elapsed)
                }
                haptics.noteTrigger()
            case .melodyOn(let hand, let midi, let name, let vel):
                strudelBridge.noteOn(hand: hand, midi: midi, waveform: selectedWaveform, velocity: vel)
                haptics.noteTrigger()
                lastGridNote = name
                loopRecorder.recordEvent(.noteOn(midi: midi, waveform: selectedWaveform, velocity: vel), currentTime: elapsed)
            case .melodyOff(let hand):
                strudelBridge.noteOff(hand: hand)
                loopRecorder.recordEvent(.noteOff(hand: hand), currentTime: elapsed)
            case .melodySlide(let hand, let midi, let name):
                strudelBridge.noteSlide(hand: hand, midi: midi)
                lastGridNote = name
            }
        }

        // Publish UI state.
        let zones = chordMelodyModeManager.currentZones(hands: currentHands)
        chordMelodyChordHandLane = zones.chordDegree
        chordMelodyMelodyLane = zones.melodyLane
        chordMelodyOctaveShift = chordMelodyModeManager.currentOctaveShift
        if let deg = zones.chordDegree, chordMelodyCurrentDegree == nil {
            // Preview chord name even before the user pinches.
            chordMelodyCurrentChordName = chordDisplayName(key: selectedKey, scale: selectedScale, degree: deg)
        }

        // Right-hand X → low-pass filter cutoff (timbre modulation).
        // Hand left = dark/muffled, hand right = bright/open. Affects pad +
        // melody voices since Strudel's voices read the global __hp.lpf.
        let melodyHandData = chordMelodySwapHands ? currentHands.left : currentHands.right
        if let mh = melodyHandData, let lpfDef = PARAM_MAP["lpf"] {
            let mapped = lpfDef.min + max(0, min(1, mh.pinchX)) * (lpfDef.max - lpfDef.min)
            smoothed["lpf"] = mapped
            strudelBridge.setSynthParam("lpf", value: mapped)
        }

        // Auto-strum: re-articulate the held chord on each beat so the player
        // doesn't have to pulse-pinch. Only fires while the chord hand is in
        // frame and a chord is voiced.
        if chordMelodyAutoStrum,
           chordMelodyModeManager.currentChordMidi.isEmpty == false,
           currentBeat != lastChordMelodyBeat {
            lastChordMelodyBeat = currentBeat
            for midi in chordMelodyModeManager.currentChordMidi {
                strudelBridge.playNote(midi: midi, waveform: selectedWaveform, velocity: 0.25, duration: 0.4)
            }
        }

        evaluateDrumLoopsIfChanged(modePrefix: "chordmelody")
    }

    // Drum hand lane tracking for UI
    @Published var drumLeftLane: Int? = nil
    @Published var drumRightLane: Int? = nil

    private func tickDrumMode() {
        strudelBridge.updateDrumParams(intensity: drumIntensity, complexity: drumComplexity)
        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
        let hits = drumModeManager.checkHits(hands: currentHands, currentTime: elapsed)
        for hit in hits {
            strudelBridge.playHit(hit.hitType)
            haptics.drumHit()
            lastDrumHit = hit.hitType
            loopRecorder.recordEvent(.drumHit(hitType: hit.hitType), currentTime: elapsed)
            jamSession.sendEvent(.drumHit(hitType: hit.hitType))
        }

        // Update lane display for UI
        drumLeftLane = drumModeManager.leftLane
        drumRightLane = drumModeManager.rightLane

        evaluateDrumLoopsIfChanged(modePrefix: "drum")
    }

    // MARK: - Learn Mode

    private func tickLearnMode() {
        // Use same grid infrastructure for lane detection
        let gridNotes = scaleNotes(key: selectedKey, scale: selectedScale,
                                   baseOctave: gridBaseOctave, octaveRange: gridOctaveRange)
        guard !gridNotes.isEmpty else { return }

        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0

        // Get current pinch/lane state from grid manager
        let leftHand = currentHands.left
        let rightHand = currentHands.right
        let leftLane = leftHand.map { gridModeManager.yToNoteIndex(y: $0.pinchY, noteCount: gridNotes.count) }
        let rightLane = rightHand.map { gridModeManager.yToNoteIndex(y: $0.pinchY, noteCount: gridNotes.count) }
        let leftPinching = (leftHand?.pinch ?? 0) > 0.8
        let rightPinching = (rightHand?.pinch ?? 0) > 0.8

        gridLeftLane = leftLane
        gridRightLane = rightLane

        let hitNotes = learnModeManager.tick(
            elapsed: elapsed,
            leftLane: leftLane,
            rightLane: rightLane,
            leftPinching: leftPinching,
            rightPinching: rightPinching
        )

        // Play sound for hit notes
        for hit in hitNotes {
            strudelBridge.playNote(midi: hit.midi, waveform: selectedWaveform, velocity: 0.7, duration: 0.3)
            haptics.learnPerfectHit()
        }

        // Sync visual state to published properties (at UI timer rate)
        learnScore = learnModeManager.score
        learnVisibleNotes = learnModeManager.visibleNotes
        learnHitEffects = learnModeManager.hitEffects
        learnSongComplete = learnModeManager.songComplete
    }

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

    // MARK: - Melodic Mode

    private var lastMelodicSnapshotTime: Double = 0

    private func tickMelodicMode() {
        tickMelodicCore(keyPrefix: "melodic", structOverride: nil)
    }

    /// Flow mode: identical Strudel pipeline to melodic, but a dense rest-free
    /// 16th-note struct so the pitch signal is sampled far more often. Stays
    /// 100% Strudel — code snapshots, effects and stack() all still work.
    private func tickFlowMode() {
        tickMelodicCore(keyPrefix: "flow", structOverride: FLOW_STRUCT)
    }

    /// Hybrid mode: the full Strudel melodic body (effects + rhythm + code
    /// snapshots) plus an imperative lead voice layered on top so pitch changes
    /// are heard instantly instead of waiting for the next struct onset.
    private func tickHybridMode() {
        tickMelodicCore(keyPrefix: "hybrid", structOverride: nil)
        driveLeadVoice(velocity: 0.45)
    }

    /// Lead mode: the melodic voice routed entirely through the imperative
    /// noteOn/noteSlide synth (no Strudel pattern). Pitch snaps to scale notes
    /// but retunes instantly, so feedback is as snappy as chord-melody mode.
    /// Drum loops still play underneath via Strudel.
    private func tickLeadMode() {
        driveLeadVoice(velocity: 0.6)

        // Keep Strudel drum loops playing underneath the imperative lead.
        let structKey = "lead|\(drumStateKey)"
        if structKey != lastStructKey {
            lastStructKey = structKey
            let parts = buildDrumCodeParts()
            if parts.isEmpty {
                strudelBridge.evaluate("silence")
            } else {
                let code = parts.count == 1 ? parts[0] : "stack(\(parts.joined(separator: ", ")))"
                strudelBridge.evaluate(code)
            }
        }
    }

    /// Shared Strudel melodic pipeline for melodic / flow / hybrid modes.
    /// `keyPrefix` keeps each variant's re-eval cache distinct; `structOverride`
    /// lets flow swap in a denser rhythm without touching the others.
    private func tickMelodicCore(keyPrefix: String, structOverride: String?) {
        // Mute when no hands detected
        let hasHands = currentHands.left != nil || currentHands.right != nil
        if !hasHands {
            smoothed["gain"] = 0
            strudelBridge.updateParams(smoothed, config: config)
            return
        }

        // Record code snapshots for loop recording in melodic mode (~10fps)
        if loopRecorder.isRecording {
            let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
            if elapsed - lastMelodicSnapshotTime > 0.1 {
                lastMelodicSnapshotTime = elapsed
                // Build a static code string with current param values baked in
                let staticCode = buildCode(smoothed, structIdx: structIdx, config: config, waveform: selectedWaveform)
                loopRecorder.recordEvent(.codeSnapshot(code: staticCode), currentTime: elapsed)
            }
        }

        // Update signal params (key/scale aware)
        let notes = cachedScaleNotes
        if chordMode {
            let noteCount = selectedScale.intervals.count
            let rawIdx: Double = smoothed["noteIdx"] ?? 0
            let normalized: Double = rawIdx / Double(max(1, NOTES.count - 1))
            let degree: Int = max(0, min(noteCount - 1, Int(normalized * Double(noteCount - 1) + 0.5)))
            let chord = chordNotes(key: selectedKey, scale: selectedScale, degree: degree)
            strudelBridge.updateChordParams(smoothed, config: config, chordMidi: chord)
        } else if !notes.isEmpty {
            let rawIdx: Double = smoothed["noteIdx"] ?? 10
            let normalized: Double = rawIdx / Double(max(1, NOTES.count - 1))
            let noteIdx: Int = max(0, min(notes.count - 1, Int(normalized * Double(notes.count - 1) + 0.5)))
            strudelBridge.updateScaleParams(smoothed, config: config, midi: notes[noteIdx])
        }

        // Re-evaluate when config changes
        let harmonyKey = "\(selectedKey.rawValue)|\(selectedScale.rawValue)|\(chordMode)"
        let structKey = "\(keyPrefix)|\(structIdx)|\(drumStateKey)|\(selectedWaveform)|\(harmonyKey)"
        if structKey != lastStructKey {
            lastStructKey = structKey
            recomputeScaleNotes()
            let synthCode = chordMode
                ? buildChordSignalCode(structIdx: structIdx, config: config, waveform: selectedWaveform, structOverride: structOverride)
                : buildSignalCode(structIdx: structIdx, config: config, waveform: selectedWaveform, structOverride: structOverride)

            var parts = [synthCode]
            parts.append(contentsOf: buildDrumCodeParts())
            let code = parts.count == 1 ? parts[0] : "stack(\(parts.joined(separator: ", ")))"
            strudelBridge.evaluate(code)
        }
    }

    /// Current monophonic melodic note (scale-snapped) from the noteIdx param,
    /// or nil if no scale notes are available. Shared by lead + hybrid voices.
    private func melodicMidi() -> Int? {
        let notes = cachedScaleNotes
        guard !notes.isEmpty else { return nil }
        let rawIdx = smoothed["noteIdx"] ?? 10
        let normalized = rawIdx / Double(max(1, NOTES.count - 1))
        let idx = max(0, min(notes.count - 1, Int(normalized * Double(notes.count - 1) + 0.5)))
        return notes[idx]
    }

    /// Drive the imperative lead voice from the current melodic note: noteOn on
    /// first contact, noteSlide while a hand is present, noteOff when hands
    /// leave. Retunes instantly — no struct quantization.
    private func driveLeadVoice(velocity: Double) {
        let hasHands = currentHands.left != nil || currentHands.right != nil
        guard hasHands, let midi = melodicMidi() else {
            if leadVoiceMidi != nil {
                strudelBridge.noteOff(hand: "lead")
                leadVoiceMidi = nil
            }
            return
        }
        if leadVoiceMidi == nil {
            strudelBridge.noteOn(hand: "lead", midi: midi, waveform: selectedWaveform, velocity: velocity)
            leadVoiceMidi = midi
        } else if leadVoiceMidi != midi {
            strudelBridge.noteSlide(hand: "lead", midi: midi)
            leadVoiceMidi = midi
        }
    }

    // MARK: - EDM Mode

    /// Duration in seconds of the current build-up setting (bars × 4 beats).
    private var edmBuildDuration: Double {
        let beatDur = 60.0 / max(40, manualBPM)
        return beatDur * Double(max(1, edmBuildBars)) * 4.0
    }

    /// Start a build-up, or — if one is already running — drop immediately.
    /// Wired to the on-screen BUILD-UP / DROP button and the two-fist gesture.
    func triggerEDMBuild() {
        if edmBuilding {
            dropEDM()
        } else {
            edmBuilding = true
            edmBuildStart = Date()
        }
    }

    private func dropEDM() {
        edmBuilding = false
        edmBuildStart = nil
        strudelBridge.playHit("crash") // impact on the drop
    }

    /// EDM mode: a self-running four-on-floor groove + sidechained pad/bass
    /// (Strudel) with the instant imperative lead on top (the hybrid idea).
    /// Hands open the master filter (energy); the BUILD-UP button or a two-fist
    /// gesture fires a riser that drops back into the groove. The beat keeps
    /// playing even with no hands so you can actually run a set.
    private func tickEDMMode() {
        // Instant topline lead (hybrid voice).
        driveLeadVoice(velocity: 0.5)

        let now = Date()

        // Auto-drop when the build-up timer elapses.
        if edmBuilding, let start = edmBuildStart, now.timeIntervalSince(start) >= edmBuildDuration {
            dropEDM()
        }

        // Two-fist gesture → build-up (edge-triggered, re-arms when released).
        let bothFists = (currentHands.left?.fist ?? 0) > 0.7 && (currentHands.right?.fist ?? 0) > 0.7
        if bothFists {
            if edmGestureArmed && !edmBuilding {
                triggerEDMBuild()
            }
            edmGestureArmed = false
        } else {
            edmGestureArmed = true
        }

        // Master low-pass cutoff: a riser sweep while building, otherwise driven
        // by hand height (raise hands = brighter = more energy).
        let cutoff: Double
        if edmBuilding, let start = edmBuildStart {
            let p = min(1, now.timeIntervalSince(start) / edmBuildDuration)
            cutoff = 600 * pow(16000.0 / 600.0, p) // exponential 600 → 16 kHz
        } else {
            let hasHands = currentHands.left != nil || currentHands.right != nil
            let energy = max(currentHands.left?.y ?? 0, currentHands.right?.y ?? 0)
            cutoff = hasHands ? 300 * pow(2.0, energy * 6.0) : 2200 // ~300 .. ~19 kHz
        }
        strudelBridge.setSynthParam("_edmLpf", value: cutoff)

        // Keep the pad/bass tracking the current scale note (slow, sustained).
        if let midi = melodicMidi() {
            strudelBridge.updateScaleParams(smoothed, config: config, midi: midi)
        }

        // Re-evaluate the Strudel body only when the phase or sound changes —
        // the filter sweep rides the live signal, no re-eval needed.
        let harmonyKey = "\(selectedKey.rawValue)|\(selectedScale.rawValue)"
        let structKey = "edm|\(edmBuilding)|\(harmonyKey)"
        if structKey != lastStructKey {
            lastStructKey = structKey
            recomputeScaleNotes()
            strudelBridge.evaluate(buildEDMCode(building: edmBuilding))
        }
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

    private var drumStateKey: String {
        let ids = (selectedDrumLoop.id, selectedDrumLoop2.id)
        let vals = (drumVolume, drumBPM, drumVolume2, drumBPM2, drumComplexity, drumIntensity)
        if ids != _lastDrumIds || vals != _lastDrumVals {
            _lastDrumIds = ids
            _lastDrumVals = vals
            _cachedDrumKey = "\(ids.0)|\(vals.0)|\(vals.1)|\(ids.1)|\(vals.2)|\(vals.3)|\(vals.4)|\(vals.5)"
        }
        return _cachedDrumKey
    }

    private func buildDrumCodeParts() -> [String] {
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

    private func evaluateDrumLoopsIfChanged(modePrefix: String) {
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
        edmBuilding = false
        edmBuildStart = nil
        edmGestureArmed = true
        strudelBridge.stop()
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
                    lead: Bool = false, hybrid: Bool = false, flow: Bool = false, edm: Bool = false) {
        silenceAll()
        gridModeEnabled = grid
        drumModeEnabled = drums
        learnModeEnabled = learn
        chordMelodyModeEnabled = chordMelody
        leadModeEnabled = lead
        hybridModeEnabled = hybrid
        flowModeEnabled = flow
        edmModeEnabled = edm
    }

    /// Persisted/loop-record label for the current mode.
    var currentModeString: String {
        if gridModeEnabled { return "grid" }
        if drumModeEnabled { return "drum" }
        if leadModeEnabled { return "lead" }
        if hybridModeEnabled { return "hybrid" }
        if flowModeEnabled { return "flow" }
        if edmModeEnabled { return "edm" }
        return "melodic"
    }

    func stop() {
        // Persist state before teardown
        let mode = currentModeString
        PersistenceManager.shared.saveEngineState(
            presetId: nil,
            mode: mode,
            key: selectedKey.rawValue,
            scale: selectedScale.rawValue,
            waveform: selectedWaveform,
            bpm: manualBPM,
            filterId: selectedFilter.id,
            gridBaseOctave: gridBaseOctave,
            gridOctaveRange: gridOctaveRange
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
        leadModeEnabled = false
        hybridModeEnabled = false
        flowModeEnabled = false
        edmModeEnabled = false
        edmBuilding = false
        edmBuildStart = nil
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
