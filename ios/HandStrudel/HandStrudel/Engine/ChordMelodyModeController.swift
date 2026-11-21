import UIKit

/// Two-hand harmony: one hand sustains a chord pad (zone by X, octave by Y),
/// the other plays a melody snapped to the current chord's tones. See
/// ChordMelodyModeManager for the gesture logic.
@MainActor
final class ChordMelodyModeController: ModeController {
    private var lastBeat: Int = -1  // edge detection for auto-strum

    func tick(_ engine: EngineController) {
        let chordMelodyModeManager = engine.chordMelodyModeManager
        let strudelBridge = engine.strudelBridge
        let haptics = engine.haptics
        let loopRecorder = engine.loopRecorder

        engine.configureWheelManager()

        let elapsed = engine.startTime.map { Date().timeIntervalSince($0) } ?? 0

        let tones = engine.chordMelodyTones(key: engine.selectedKey, scale: engine.selectedScale)
        let chordTones = tones.chord
        let melodyTones = tones.melody

        let actions = chordMelodyModeManager.tick(
            hands: engine.currentHands,
            chordTones: chordTones,
            melodyTones: melodyTones,
            quantize: engine.quantizeEnabled,
            gridBoundaryCrossed: engine.quantizeBoundaryCrossed()
        )

        for action in actions {
            switch action {
            case .padOn(let notes, let degree):
                let name = chordDisplayName(key: engine.selectedKey, scale: engine.selectedScale, degree: degree)
                engine.chordMelodyCurrentChordName = name
                engine.chordMelodyCurrentDegree = degree
                engine.chordMelodyOctaveShift = chordMelodyModeManager.currentOctaveShift
                for (i, midi) in notes.enumerated() {
                    strudelBridge.noteOn(hand: "pad\(i)", midi: midi, waveform: "triangle", velocity: engine.chordMelodyPadVolume)
                }
                engine.holdJamVoice("pad", pitches: notes, velocity: engine.chordMelodyPadVolume, waveform: "triangle")
            case .padSlide(let notes, let degree):
                let name = chordDisplayName(key: engine.selectedKey, scale: engine.selectedScale, degree: degree)
                engine.chordMelodyCurrentChordName = name
                engine.chordMelodyCurrentDegree = degree
                engine.chordMelodyOctaveShift = chordMelodyModeManager.currentOctaveShift
                for (i, midi) in notes.enumerated() {
                    strudelBridge.noteSlide(hand: "pad\(i)", midi: midi)
                }
                engine.slideJamVoice("pad", pitches: notes)
            case .padOff:
                for i in 0..<4 {
                    strudelBridge.noteOff(hand: "pad\(i)")
                }
                engine.releaseJamVoice("pad")
            case .chordAccent(let notes, _, let vel):
                for midi in notes {
                    strudelBridge.playNote(midi: midi, waveform: engine.selectedWaveform, velocity: vel * 0.5, duration: 0.5,
                                           capture: .chord)
                    loopRecorder.recordEvent(.noteOn(midi: midi, waveform: engine.selectedWaveform, velocity: vel * 0.5), currentTime: elapsed)
                }
                engine.shareJamNotes(notes, velocity: vel * 0.5, duration: 0.5)
                haptics.noteTrigger()
            case .melodyOn(let hand, let midi, let name, let vel):
                strudelBridge.noteOn(hand: hand, midi: midi, waveform: engine.selectedWaveform, velocity: vel)
                engine.holdJamVoice(hand, pitches: [midi], velocity: vel)
                haptics.noteTrigger()
                engine.lastGridNote = name
                loopRecorder.recordEvent(.noteOn(midi: midi, waveform: engine.selectedWaveform, velocity: vel), currentTime: elapsed)
            case .melodyOff(let hand):
                strudelBridge.noteOff(hand: hand)
                engine.releaseJamVoice(hand)
                loopRecorder.recordEvent(.noteOff(hand: hand), currentTime: elapsed)
            case .melodySlide(let hand, let midi, let name):
                strudelBridge.noteSlide(hand: hand, midi: midi)
                engine.slideJamVoice(hand, pitches: [midi])
                engine.lastGridNote = name
            }
        }

        // Publish UI state.
        let zones = chordMelodyModeManager.currentZones(hands: engine.currentHands)
        engine.chordMelodyChordHandLane = zones.chordDegree
        engine.chordMelodyMelodyLane = zones.melodyLane
        engine.chordMelodyOctaveShift = chordMelodyModeManager.currentOctaveShift
        // The action-driven path only sets `currentDegree` on `padOn`/`padSlide`.
        // Touch overrides (Split mode) mutate the manager's state without
        // emitting actions, so we also sync the published degree + chord name
        // from the manager every frame — that's what drives the wheel's inner
        // note-name labels.
        if let deg = chordMelodyModeManager.currentChordDegree {
            engine.chordMelodyCurrentDegree = deg
            engine.chordMelodyCurrentChordName = chordDisplayName(
                key: engine.selectedKey, scale: engine.selectedScale, degree: deg)
        } else if let deg = zones.chordDegree, engine.chordMelodyCurrentDegree == nil {
            // Preview chord name even before the user pinches.
            engine.chordMelodyCurrentChordName = chordDisplayName(key: engine.selectedKey, scale: engine.selectedScale, degree: deg)
        }

        // Right-hand X → low-pass filter cutoff (timbre modulation).
        let melodyHandData = chordMelodyModeManager.swapHands ? engine.currentHands.left : engine.currentHands.right
        if let mh = melodyHandData, let lpfDef = PARAM_MAP["lpf"] {
            let mapped = lpfDef.min + max(0, min(1, mh.pinchX)) * (lpfDef.max - lpfDef.min)
            engine.smoothed["lpf"] = mapped
            strudelBridge.setSynthParam("lpf", value: mapped)
        }

        // Auto-strum: re-articulate the held chord on each beat.
        if engine.chordMelodyAutoStrum,
           chordMelodyModeManager.currentChordMidi.isEmpty == false,
           engine.currentBeat != lastBeat {
            lastBeat = engine.currentBeat
            for midi in chordMelodyModeManager.currentChordMidi {
                strudelBridge.playNote(midi: midi, waveform: engine.selectedWaveform, velocity: 0.25, duration: 0.4,
                                       capture: .chord)
            }
            engine.shareJamNotes(chordMelodyModeManager.currentChordMidi, velocity: 0.25, duration: 0.4)
        }

        engine.evaluateDrumLoopsIfChanged(modePrefix: "chordmelody")
    }
}
