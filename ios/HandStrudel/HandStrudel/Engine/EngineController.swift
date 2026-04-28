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
    Waveform(id: "sawtooth", name: "Saw", emoji: "\u{1FAB5}", isPremium: false, packId: nil),
    Waveform(id: "square", name: "Square", emoji: "\u{25A0}", isPremium: false, packId: nil),
    Waveform(id: "triangle", name: "Triangle", emoji: "\u{25B3}", isPremium: false, packId: nil),
    Waveform(id: "sine", name: "Sine", emoji: "\u{223F}", isPremium: false, packId: nil),

    // Premium waveforms
    Waveform(id: "sawtooth", name: "Supersaw", emoji: "🎸", isPremium: true, packId: "analog"),
    Waveform(id: "sine", name: "FM", emoji: "📡", isPremium: true, packId: "analog"),
    Waveform(id: "triangle", name: "Pluck", emoji: "🪕", isPremium: true, packId: "texture"),
    Waveform(id: "sine", name: "Pad", emoji: "☁️", isPremium: true, packId: "texture"),
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

    // Grid mode (pinch-to-play)
    @Published var gridModeEnabled = false
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
    @Published var drumSpeed2: Double = 1.0
    private var lastDrumLoopId = ""

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
    private var startTime: Date?

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

                // Beat callback
                strudelBridge.onBeat = { [weak self] beat in
                    DispatchQueue.main.async {
                        self?.currentBeat = beat
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
            HandMapper.mapHandsToParams(hands, params: &self.rawParams, config: self.config)
            HandMapper.mapHandsToParams(hands, params: &self.rawParams, config: self.hydraConfig)
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

    private func tick() {
        // Apply manual BPM if not hand-mapped
        if !bpmIsMapped {
            rawParams["bpm"] = manualBPM
        }

        // Apply locked param overrides (manual values override hand tracking)
        for paramId in lockedParams {
            if let val = manualValues[paramId] {
                rawParams[paramId] = val
            }
        }

        // Circle of fifths: left hand X position maps to key
        if circleOfFifthsEnabled, let leftHand = currentHands.left {
            let cofIdx = max(0, min(11, Int(leftHand.x * 12)))
            let newKey = CIRCLE_OF_FIFTHS[cofIdx]
            if newKey != selectedKey {
                selectedKey = newKey
                recomputeScaleNotes()
            }
        }

        // Apply manual struct index
        structIdx = currentStructIdx

        // EMA smoothing
        ParamSmoother.smooth(target: rawParams, smoothed: &smoothed)

        let isLive = playingSet.isEmpty && !trackPlaying

        if isLive && gridModeEnabled {
            // Grid mode: pinch-to-play with quantized pitch
            let notes = cachedScaleNotes
            let events = gridModeManager.checkNotes(hands: currentHands, scaleNotes: notes, currentBeat: 0)
            for event in events {
                strudelBridge.playNote(midi: event.midi, waveform: selectedWaveform, velocity: event.velocity)
                lastGridNote = event.noteName
            }

            // Update lane display
            let lanes = gridModeManager.currentLanes(hands: currentHands, scaleNotes: notes)
            gridLeftLane = lanes.left
            gridRightLane = lanes.right

            // Still handle drum loop tracks
            let drumKey1 = "\(selectedDrumLoop.id)|\(String(format: "%.1f|%.1f", drumVolume, drumSpeed))"
            let drumKey2 = "\(selectedDrumLoop2.id)|\(String(format: "%.1f|%.1f", drumVolume2, drumSpeed2))"
            let gridStructKey = "grid|\(drumKey1)|\(drumKey2)"
            if gridStructKey != lastStructKey {
                lastStructKey = gridStructKey
                var parts: [String] = []
                var drumCode1 = selectedDrumLoop.code
                if !drumCode1.isEmpty {
                    if drumVolume != 1.0 { drumCode1 = "(\(drumCode1)).gain(\(String(format: "%.2f", drumVolume)))" }
                    if drumSpeed != 1.0 { drumCode1 = "(\(drumCode1)).fast(\(String(format: "%.1f", drumSpeed)))" }
                    parts.append(drumCode1)
                }
                var drumCode2 = selectedDrumLoop2.code
                if !drumCode2.isEmpty {
                    if drumVolume2 != 1.0 { drumCode2 = "(\(drumCode2)).gain(\(String(format: "%.2f", drumVolume2)))" }
                    if drumSpeed2 != 1.0 { drumCode2 = "(\(drumCode2)).fast(\(String(format: "%.1f", drumSpeed2)))" }
                    parts.append(drumCode2)
                }
                if !parts.isEmpty {
                    let code = parts.count == 1 ? parts[0] : "stack(\(parts.joined(separator: ", ")))"
                    strudelBridge.evaluate(code)
                }
            }
        } else if isLive && drumModeEnabled {
            // Drum mode: detect hand velocity and trigger one-shot drum hits
            let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
            let hits = drumModeManager.checkHits(hands: currentHands, currentTime: elapsed)
            for hitType in hits {
                strudelBridge.playHit(hitType)
                lastDrumHit = hitType
            }

            // Still handle drum loop tracks alongside drum mode
            let drumKey1 = "\(selectedDrumLoop.id)|\(String(format: "%.1f|%.1f", drumVolume, drumSpeed))"
            let drumKey2 = "\(selectedDrumLoop2.id)|\(String(format: "%.1f|%.1f", drumVolume2, drumSpeed2))"
            let drumStructKey = "drum|\(drumKey1)|\(drumKey2)"
            if drumStructKey != lastStructKey {
                lastStructKey = drumStructKey
                var parts: [String] = []

                var drumCode1 = selectedDrumLoop.code
                if !drumCode1.isEmpty {
                    if drumVolume != 1.0 { drumCode1 = "(\(drumCode1)).gain(\(String(format: "%.2f", drumVolume)))" }
                    if drumSpeed != 1.0 { drumCode1 = "(\(drumCode1)).fast(\(String(format: "%.1f", drumSpeed)))" }
                    parts.append(drumCode1)
                }

                var drumCode2 = selectedDrumLoop2.code
                if !drumCode2.isEmpty {
                    if drumVolume2 != 1.0 { drumCode2 = "(\(drumCode2)).gain(\(String(format: "%.2f", drumVolume2)))" }
                    if drumSpeed2 != 1.0 { drumCode2 = "(\(drumCode2)).fast(\(String(format: "%.1f", drumSpeed2)))" }
                    parts.append(drumCode2)
                }

                if !parts.isEmpty {
                    let code = parts.count == 1 ? parts[0] : "stack(\(parts.joined(separator: ", ")))"
                    strudelBridge.evaluate(code)
                }
            }
        } else if isLive {
            // Update signal params in WebView (key/scale aware)
            let notes = cachedScaleNotes
            if chordMode {
                let noteCount = selectedScale.intervals.count
                let degree = max(0, min(noteCount - 1, Int((smoothed["noteIdx"] ?? 0) / Double(NOTES.count - 1) * Double(noteCount - 1) + 0.5)))
                let chord = chordNotes(key: selectedKey, scale: selectedScale, degree: degree)
                strudelBridge.updateChordParams(smoothed, config: config, chordMidi: chord)
            } else {
                let noteIdx = max(0, min(notes.count - 1, Int((smoothed["noteIdx"] ?? 10) / Double(NOTES.count - 1) * Double(notes.count - 1) + 0.5)))
                let midi = notes[noteIdx]
                strudelBridge.updateScaleParams(smoothed, config: config, midi: midi)
            }

            // Harmony key for re-eval: includes key, scale, chord mode
            let harmonyKey = "\(selectedKey.rawValue)|\(selectedScale.rawValue)|\(chordMode)"

            // Re-evaluate when struct, drum loops, waveform, or harmony changes
            let drumKey1 = "\(selectedDrumLoop.id)|\(String(format: "%.1f|%.1f", drumVolume, drumSpeed))"
            let drumKey2 = "\(selectedDrumLoop2.id)|\(String(format: "%.1f|%.1f", drumVolume2, drumSpeed2))"
            let structKey = "\(structIdx)|\(drumKey1)|\(drumKey2)|\(selectedWaveform)|\(harmonyKey)"
            if structKey != lastStructKey {
                lastStructKey = structKey
                recomputeScaleNotes()
                let synthCode: String
                if chordMode {
                    synthCode = buildChordSignalCode(structIdx: structIdx, config: config, waveform: selectedWaveform)
                } else {
                    synthCode = buildSignalCode(structIdx: structIdx, config: config, waveform: selectedWaveform)
                }

                // Build drum codes
                var parts = [synthCode]

                var drumCode1 = selectedDrumLoop.code
                if !drumCode1.isEmpty {
                    if drumVolume != 1.0 { drumCode1 = "(\(drumCode1)).gain(\(String(format: "%.2f", drumVolume)))" }
                    if drumSpeed != 1.0 { drumCode1 = "(\(drumCode1)).fast(\(String(format: "%.1f", drumSpeed)))" }
                    parts.append(drumCode1)
                }

                var drumCode2 = selectedDrumLoop2.code
                if !drumCode2.isEmpty {
                    if drumVolume2 != 1.0 { drumCode2 = "(\(drumCode2)).gain(\(String(format: "%.2f", drumVolume2)))" }
                    if drumSpeed2 != 1.0 { drumCode2 = "(\(drumCode2)).fast(\(String(format: "%.1f", drumSpeed2)))" }
                    parts.append(drumCode2)
                }

                let code = parts.count == 1 ? parts[0] : "stack(\(parts.joined(separator: ", ")))"
                strudelBridge.evaluate(code)
            }

            // Hydra visuals
            if hydraEnabled {
                let hydraCode = buildHydraCode(smoothed)
                if hydraCode != lastHydraCode {
                    lastHydraCode = hydraCode
                    strudelBridge.evalHydra(hydraCode)
                }
            }
        }

        // Save gesture detection
        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
        if saveDetector.check(hands: currentHands, config: config, currentTime: elapsed) {
            let snippet = SavedSnippet(
                code: buildCode(smoothed, structIdx: structIdx, config: config, waveform: selectedWaveform),
                bpm: Int((smoothed["bpm"] ?? 120).rounded())
            )
            DispatchQueue.main.async { [weak self] in
                self?.savedSnippets.append(snippet)
            }
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

                if self.chordMode {
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

                self.codeDisplay = self.buildDisplayCode(s)
                if self.hydraEnabled {
                    self.hydraCodeDisplay = self.buildHydraDisplayCode(s)
                }
            }
        }
    }

    // MARK: - Display code (simplified, no HTML needed)

    private func buildDisplayCode(_ p: MusicParams) -> String {
        let cpm = String(format: "%.1f", (p["bpm"] ?? 120) / 4)
        let st = STRUCTS[structIdx]
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
        displayLink?.invalidate()
        displayLink = nil
        uiTimer?.invalidate()
        uiTimer = nil
        structTimer?.invalidate()
        structTimer = nil
        handTracker.stopSession()
        strudelBridge.stop()
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
