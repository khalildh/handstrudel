import Foundation

/// Default mode: hands drive synth parameters via the mapping config. Re-evals
/// the Strudel pattern only when the structural key (struct/waveform/harmony/
/// drums) changes; otherwise just pushes smoothed param values through.
@MainActor
final class MelodicModeController: ModeController {
    private var lastSnapshotTime: Double = 0

    func tick(_ engine: EngineController) {
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
        let structKey = "melodic|\(engine.structIdx)|\(engine.drumStateKey)|\(engine.selectedWaveform)|\(harmonyKey)"
        if structKey != engine.lastStructKey {
            engine.lastStructKey = structKey
            engine.recomputeScaleNotes()
            let synthCode = engine.chordMode
                ? buildChordSignalCode(structIdx: engine.structIdx, config: engine.config, waveform: engine.selectedWaveform)
                : buildSignalCode(structIdx: engine.structIdx, config: engine.config, waveform: engine.selectedWaveform)

            var parts = [synthCode]
            parts.append(contentsOf: engine.buildDrumCodeParts())
            let code = parts.count == 1 ? parts[0] : "stack(\(parts.joined(separator: ", ")))"
            strudelBridge.evaluate(code)
        }
    }
}
