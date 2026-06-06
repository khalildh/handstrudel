import Foundation

/// Default mode: hands drive synth parameters via the mapping config.
///
/// This controller also owns the Flow / Hybrid / Lead variants of melodic
/// mode (selected via `engine.flowModeEnabled` etc.):
///
/// - **Melodic** — sparse `STRUCTS` rhythm, fully Strudel-driven.
/// - **Flow** — same pipeline as melodic, but a dense 16th-note struct so the
///   pitch signal is sampled ~6× more often (tighter pitch feedback).
/// - **Hybrid** — full Strudel melodic body plus an imperative `noteOn` lead
///   voice layered on top so pitch changes are heard instantly instead of
///   waiting for the next struct onset.
/// - **Lead** — imperative `noteOn` voice only (no Strudel pattern). Pitch
///   retunes instantly. Drum loops still play underneath via Strudel.
@MainActor
final class MelodicModeController: ModeController {
    private var lastSnapshotTime: Double = 0

    func tick(_ engine: EngineController) {
        if engine.leadModeEnabled {
            tickLead(engine)
        } else if engine.hybridModeEnabled {
            tickStrudelCore(engine, keyPrefix: "hybrid", structOverride: nil)
            driveLeadVoice(engine, velocity: 0.45)
        } else if engine.flowModeEnabled {
            tickStrudelCore(engine, keyPrefix: "flow", structOverride: FLOW_STRUCT)
        } else {
            tickStrudelCore(engine, keyPrefix: "melodic", structOverride: nil)
        }
    }

    /// Lead mode: just the imperative voice + drum loops; no Strudel melodic
    /// pattern. Pitch retunes instantly, so feedback feels as snappy as the
    /// chord-melody mode.
    private func tickLead(_ engine: EngineController) {
        driveLeadVoice(engine, velocity: 0.6)

        let structKey = "lead|\(engine.drumStateKey)"
        if structKey != engine.lastStructKey {
            engine.lastStructKey = structKey
            let parts = engine.buildDrumCodeParts()
            if parts.isEmpty {
                engine.strudelBridge.evaluate("silence")
            } else {
                let code = parts.count == 1 ? parts[0] : "stack(\(parts.joined(separator: ", ")))"
                engine.strudelBridge.evaluate(code)
            }
        }
    }

    /// Shared Strudel melodic pipeline for melodic / flow / hybrid modes.
    /// `keyPrefix` keeps each variant's re-eval cache distinct; `structOverride`
    /// lets flow swap in a denser rhythm without touching the others.
    private func tickStrudelCore(_ engine: EngineController, keyPrefix: String, structOverride: String?) {
        let strudelBridge = engine.strudelBridge
        let loopRecorder = engine.loopRecorder

        // Mute when no hands detected
        let hasHands = engine.currentHands.left != nil || engine.currentHands.right != nil
        if !hasHands {
            engine.smoothed["gain"] = 0
            strudelBridge.updateParams(engine.smoothed, config: engine.config)
            return
        }

        // Record code snapshots for loop recording in melodic mode (~10fps)
        if loopRecorder.isRecording {
            let elapsed = engine.startTime.map { Date().timeIntervalSince($0) } ?? 0
            if elapsed - lastSnapshotTime > 0.1 {
                lastSnapshotTime = elapsed
                // Build a static code string with current param values baked in
                let staticCode = buildCode(engine.smoothed, structIdx: engine.structIdx, config: engine.config, waveform: engine.selectedWaveform)
                loopRecorder.recordEvent(.codeSnapshot(code: staticCode), currentTime: elapsed)
            }
        }

        // Update signal params (key/scale aware)
        let notes = engine.cachedScaleNotes
        if engine.chordMode {
            let noteCount = engine.selectedScale.intervals.count
            let rawIdx: Double = engine.smoothed["noteIdx"] ?? 0
            let normalized: Double = rawIdx / Double(max(1, NOTES.count - 1))
            let degree: Int = max(0, min(noteCount - 1, Int(normalized * Double(noteCount - 1) + 0.5)))
            let chord = chordNotes(key: engine.selectedKey, scale: engine.selectedScale, degree: degree)
            strudelBridge.updateChordParams(engine.smoothed, config: engine.config, chordMidi: chord)
        } else if !notes.isEmpty {
            let rawIdx: Double = engine.smoothed["noteIdx"] ?? 10
            let normalized: Double = rawIdx / Double(max(1, NOTES.count - 1))
            let noteIdx: Int = max(0, min(notes.count - 1, Int(normalized * Double(notes.count - 1) + 0.5)))
            strudelBridge.updateScaleParams(engine.smoothed, config: engine.config, midi: notes[noteIdx])
        }

        // Re-evaluate when config changes
        let harmonyKey = "\(engine.selectedKey.rawValue)|\(engine.selectedScale.rawValue)|\(engine.chordMode)"
        let structKey = "\(keyPrefix)|\(engine.structIdx)|\(engine.drumStateKey)|\(engine.selectedWaveform)|\(harmonyKey)"
        if structKey != engine.lastStructKey {
            engine.lastStructKey = structKey
            engine.recomputeScaleNotes()
            let synthCode = engine.chordMode
                ? buildChordSignalCode(structIdx: engine.structIdx, config: engine.config, waveform: engine.selectedWaveform, structOverride: structOverride)
                : buildSignalCode(structIdx: engine.structIdx, config: engine.config, waveform: engine.selectedWaveform, structOverride: structOverride)

            var parts = [synthCode]
            parts.append(contentsOf: engine.buildDrumCodeParts())
            let code = parts.count == 1 ? parts[0] : "stack(\(parts.joined(separator: ", ")))"
            strudelBridge.evaluate(code)
        }
    }

    /// Current monophonic melodic note (scale-snapped) from the noteIdx param,
    /// or nil if no scale notes are available. Shared by lead + hybrid voices.
    private func melodicMidi(_ engine: EngineController) -> Int? {
        let notes = engine.cachedScaleNotes
        guard !notes.isEmpty else { return nil }
        let rawIdx = engine.smoothed["noteIdx"] ?? 10
        let normalized = rawIdx / Double(max(1, NOTES.count - 1))
        let idx = max(0, min(notes.count - 1, Int(normalized * Double(notes.count - 1) + 0.5)))
        return notes[idx]
    }

    /// Drive the imperative lead voice from the current melodic note: noteOn
    /// on first contact, noteSlide while a hand is present, noteOff when hands
    /// leave. Retunes instantly — no struct quantization.
    private func driveLeadVoice(_ engine: EngineController, velocity: Double) {
        let hasHands = engine.currentHands.left != nil || engine.currentHands.right != nil
        guard hasHands, let midi = melodicMidi(engine) else {
            if engine.leadVoiceMidi != nil {
                engine.strudelBridge.noteOff(hand: "lead")
                engine.leadVoiceMidi = nil
            }
            return
        }
        if engine.leadVoiceMidi == nil {
            engine.strudelBridge.noteOn(hand: "lead", midi: midi, waveform: engine.selectedWaveform, velocity: velocity)
            engine.leadVoiceMidi = midi
        } else if engine.leadVoiceMidi != midi {
            engine.strudelBridge.noteSlide(hand: "lead", midi: midi)
            engine.leadVoiceMidi = midi
        }
    }
}
