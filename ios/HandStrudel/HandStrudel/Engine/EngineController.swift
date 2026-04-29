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
    Waveform(id: "sawtooth", name: "Saw", emoji: "🪚", isPremium: false, packId: nil),
    Waveform(id: "square", name: "Square", emoji: "⬜", isPremium: false, packId: nil),
    Waveform(id: "triangle", name: "Triangle", emoji: "🔺", isPremium: false, packId: nil),
    Waveform(id: "sine", name: "Sine", emoji: "🔮", isPremium: false, packId: nil),
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
    @Published var hydraConfig = DEFAULT_HYDRA_MAPPING
    @Published var advanced = false
    @Published var isRunning = false
    @Published var status = "tap start"

    // UI state (updated at ~15fps)
    @Published var handsState = HandsState()
    @Published var smoothedParams = MusicParams()
    @Published var codeDisplay = ""
    @Published var hydraCodeDisplay = ""
    @Published var noteDisplay = ""
    @Published var bpm: Double = 120
    @Published var currentBeat = 0

    // Saved snippets
    @Published var savedSnippets = [SavedSnippet]()
    @Published var playingSet = Set<Int>()
    @Published var track = (slots: [Int](), speed: 1.0)
    @Published var trackPlaying = false
    @Published var hydraEnabled = false

    // Drum mode
    @Published var drumModeEnabled = false
    private let drumModeManager = DrumModeManager()
    @Published var lastDrumHit: String = ""

    // Camera filter
    @Published var selectedFilter: CameraFilter = CAMERA_FILTERS[0]

    // Jam session (SharePlay)
    let jamSession = JamSessionManager()

    // Loop recording & playback
    let loopRecorder = LoopRecorder()
    @Published var isLoopRecording = false
    @Published var loopRecordingProgress: Double = 0
    @Published var savedLoops = [RecordedLoop]()
    @Published var playingLoopIds = Set<UUID>()

    // Grid mode (pinch-to-play)
    @Published var gridModeEnabled = false
    @Published var gridOctaveRange: Int = 2  // 1, 2, or 3 octaves
    @Published var gridBaseOctave: Int = 3   // starting octave
    let gridModeManager = GridModeManager()
    @Published var lastGridNote: String = ""
    @Published var gridLeftLane: Int? = nil
    @Published var gridRightLane: Int? = nil

    // Manual controls
    @Published var manualBPM: Double = 120
    @Published var currentStructIdx = 0
    @Published var autoRotateStructs = true
    @Published var lockedParams = Set<String>()
    @Published var manualValues = MusicParams()
    @Published var selectedWaveform: String = "sawtooth"
    @Published var selectedDrumLoop: DrumLoop = DRUM_LOOPS[0]
    @Published var drumVolume: Double = 1.0
    @Published var drumSpeed: Double = 1.0
    @Published var selectedDrumLoop2: DrumLoop = DRUM_LOOPS[0]
    @Published var drumVolume2: Double = 1.0
    @Published var drumComplexity: Double = 0.5  // 0 = simple, 1 = complex
    @Published var drumIntensity: Double = 0.5   // 0 = soft, 1 = loud
    @Published var drumSpeed2: Double = 1.0

    // Harmony
    @Published var selectedKey: MusicKey = .C
    @Published var selectedScale: Scale = .pentatonic
    @Published var chordMode: Bool = false
    @Published var circleOfFifthsEnabled: Bool = false
    @Published var chordDisplay: String = ""

    // Cached scale notes (recomputed when key/scale changes)
    private var cachedScaleNotes: [Int] = scaleNotes(key: .C, scale: .pentatonic)
    private var lastHarmonyKey = ""

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
    private var lastHydraCode = ""
    private var displayLink: CADisplayLink?
    private var uiTimer: Timer?
    private var structTimer: Timer?
    private(set) var startTime: Date?

    func start(config: MappingConfig, hydraConfig: MappingConfig, advanced: Bool) {
        debugLog("start() called")
        self.config = config
        self.hydraConfig = hydraConfig
        self.advanced = advanced

        // Build default params
        let musicDefs = buildDefaultParams(config)
        let hydraDefs = buildDefaultParams(hydraConfig)
        let defs = musicDefs.merging(hydraDefs) { _, new in new }
        rawParams = defs
        smoothed = defs

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
                HandMapper.mapHandsToParams(hands, params: &self.rawParams, config: self.hydraConfig)
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
        guard isLive else { return }

        if gridModeEnabled {
            tickGridMode()
        } else if drumModeEnabled {
            tickDrumMode()
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

    private func tickGridMode() {
        gridModeManager.videoAspect = handTracker.videoWidth / handTracker.videoHeight
        let screenBounds = UIScreen.main.bounds
        gridModeManager.screenAspect = screenBounds.width / screenBounds.height

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

    private func tickDrumMode() {
        // Sync XY pad values to Web Audio
        strudelBridge.updateDrumParams(intensity: drumIntensity, complexity: drumComplexity)
        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
        let hits = drumModeManager.checkHits(hands: currentHands, currentTime: elapsed)
        for hitType in hits {
            strudelBridge.playHit(hitType)
            haptics.drumHit()
            lastDrumHit = hitType
            loopRecorder.recordEvent(.drumHit(hitType: hitType), currentTime: elapsed)
            jamSession.sendEvent(.drumHit(hitType: hitType))
        }
        evaluateDrumLoopsIfChanged(modePrefix: "drum")
    }

    private func tickMelodicMode() {
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
        let structKey = "melodic|\(structIdx)|\(drumStateKey)|\(selectedWaveform)|\(harmonyKey)"
        if structKey != lastStructKey {
            lastStructKey = structKey
            recomputeScaleNotes()
            let synthCode = chordMode
                ? buildChordSignalCode(structIdx: structIdx, config: config, waveform: selectedWaveform)
                : buildSignalCode(structIdx: structIdx, config: config, waveform: selectedWaveform)

            var parts = [synthCode]
            parts.append(contentsOf: buildDrumCodeParts())
            let code = parts.count == 1 ? parts[0] : "stack(\(parts.joined(separator: ", ")))"
            strudelBridge.evaluate(code)
        }

        if hydraEnabled {
            let hydraCode = buildHydraCode(smoothed)
            if hydraCode != lastHydraCode {
                lastHydraCode = hydraCode
                strudelBridge.evalHydra(hydraCode)
            }
        }
    }

    private func tickSaveGesture() {
        guard !gridModeEnabled && !drumModeEnabled else { return }
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
        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
        let mode = gridModeEnabled ? "grid" : (drumModeEnabled ? "drum" : "melodic")
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

    private var drumStateKey: String {
        let k1 = "\(selectedDrumLoop.id)|\(String(format: "%.1f|%.1f", drumVolume, drumSpeed))"
        let k2 = "\(selectedDrumLoop2.id)|\(String(format: "%.1f|%.1f", drumVolume2, drumSpeed2))"
        let ci = String(format: "%.1f|%.1f", drumComplexity, drumIntensity)
        return "\(k1)|\(k2)|\(ci)"
    }

    private func buildDrumCodeParts() -> [String] {
        // Complexity affects speed multiplier (simple=1x, complex=2-4x for hats)
        // Intensity affects gain
        let intensityGain = 0.3 + drumIntensity * 1.2  // 0.3 to 1.5
        let complexitySpeed = 1.0 + drumComplexity * 2.0  // 1x to 3x

        var parts: [String] = []
        var code1 = selectedDrumLoop.code
        if !code1.isEmpty {
            let vol = drumVolume * intensityGain
            code1 = "(\(code1)).gain(\(String(format: "%.2f", vol)))"
            let spd = drumSpeed * complexitySpeed
            if spd != 1.0 { code1 = "(\(code1)).fast(\(String(format: "%.1f", spd)))" }
            parts.append(code1)
        }
        var code2 = selectedDrumLoop2.code
        if !code2.isEmpty {
            let vol = drumVolume2 * intensityGain
            code2 = "(\(code2)).gain(\(String(format: "%.2f", vol)))"
            let spd = drumSpeed2 * complexitySpeed
            if spd != 1.0 { code2 = "(\(code2)).fast(\(String(format: "%.1f", spd)))" }
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
        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.066, repeats: true) { [weak self] _ in
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
                if self.hydraEnabled {
                    self.hydraCodeDisplay = self.buildHydraDisplayCode(s)
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

    private func buildHydraDisplayCode(_ p: MusicParams) -> String {
        let freq = p["hFreq"] ?? 10
        let sync = p["hSync"] ?? 0.1
        let kaleid = Int((p["hKaleid"] ?? 3).rounded())
        let rot = p["hRotate"] ?? 0
        let colorama = p["hColorama"] ?? 0.05
        let bright = p["hBright"] ?? 1
        let pixel = Int((p["hPixel"] ?? 200).rounded())
        let mod = p["hModulate"] ?? 0.02
        let scale = p["hScale"] ?? 1
        let sat = p["hSaturate"] ?? 1

        var lines = ["osc(\(String(format: "%.1f", freq)),\(String(format: "%.2f", sync)),1.5)"]
        if kaleid > 1 { lines.append("  .kaleid(\(kaleid))") }
        if rot > 0.01 { lines.append("  .rotate(\(String(format: "%.3f", rot)))") }
        if scale != 1 { lines.append("  .scale(\(String(format: "%.2f", scale)))") }
        if pixel < 190 { lines.append("  .pixelate(\(pixel),\(pixel))") }
        lines.append("  .color(1,1,1)")
        if bright != 1 { lines.append("  .brightness(\(String(format: "%.2f", bright)))") }
        if sat != 1 { lines.append("  .saturate(\(String(format: "%.2f", sat)))") }
        if colorama > 0.01 { lines.append("  .colorama(\(String(format: "%.3f", colorama)))") }
        if mod > 0.005 { lines.append("  .modulate(noise(3),\(String(format: "%.3f", mod)))") }
        lines.append("  .out()")
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

    func toggleHydra() {
        hydraEnabled.toggle()
        strudelBridge.setHydraEnabled(hydraEnabled)
        if !hydraEnabled {
            lastHydraCode = ""
        }
    }

    func stop() {
        // Timers
        displayLink?.invalidate()
        displayLink = nil
        uiTimer?.invalidate()
        uiTimer = nil
        structTimer?.invalidate()
        structTimer = nil

        // Audio/camera — kill all voices immediately
        strudelBridge.noteOff(hand: "left")
        strudelBridge.noteOff(hand: "right")
        strudelBridge.noteOff(hand: "touch1")
        strudelBridge.noteOff(hand: "touch2")
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
