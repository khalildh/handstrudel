import UIKit

/// Pinch-to-play grid: hand Y picks a scale-note lane, pinch articulates it.
/// Optionally the non-pinching hand's finger count sets the base octave.
@MainActor
final class GridModeController: ModeController {
    func tick(_ engine: EngineController) {
        let gridModeManager = engine.gridModeManager
        let strudelBridge = engine.strudelBridge
        let haptics = engine.haptics
        let loopRecorder = engine.loopRecorder
        let jamSession = engine.jamSession

        gridModeManager.videoAspect = engine.handTracker.videoWidth / engine.handTracker.videoHeight
        let screenBounds = UIScreen.main.bounds
        gridModeManager.screenAspect = screenBounds.width / screenBounds.height

        // Finger count octave: non-pinching hand's fingers set the octave
        if engine.fingerOctaveEnabled {
            let leftPinching = gridModeManager.isLeftPinching
            let rightPinching = gridModeManager.isRightPinching

            let fingerHand: HandData?
            if leftPinching && !rightPinching {
                fingerHand = engine.currentHands.right // right hand controls octave
            } else if rightPinching && !leftPinching {
                fingerHand = engine.currentHands.left  // left hand controls octave
            } else if !leftPinching && !rightPinching {
                // Neither pinching — use whichever hand has more fingers up
                let leftFingers = engine.currentHands.left?.fingersUp ?? 0
                let rightFingers = engine.currentHands.right?.fingersUp ?? 0
                fingerHand = leftFingers >= rightFingers ? engine.currentHands.left : engine.currentHands.right
            } else {
                fingerHand = nil // both pinching, don't change
            }

            if let hand = fingerHand {
                let fingers = hand.fingersUp
                engine.currentFingerCount = fingers
                if fingers >= 1 && fingers <= 5 {
                    let newOctave = fingers + 1 // 1 finger = octave 2, 5 fingers = octave 6
                    if newOctave != engine.gridBaseOctave {
                        engine.gridBaseOctave = newOctave
                    }
                }
            }
        }

        let gridNotes = scaleNotes(key: engine.selectedKey, scale: engine.selectedScale, baseOctave: engine.gridBaseOctave, octaveRange: engine.gridOctaveRange)
        let actions = gridModeManager.checkNotes(hands: engine.currentHands, scaleNotes: gridNotes,
                                                 quantize: engine.quantizeEnabled,
                                                 gridBoundaryCrossed: engine.quantizeBoundaryCrossed())
        let elapsed = engine.startTime.map { Date().timeIntervalSince($0) } ?? 0
        for action in actions {
            switch action {
            case .noteOn(let hand, let midi, let name, let vel):
                strudelBridge.noteOn(hand: hand, midi: midi, waveform: engine.selectedWaveform, velocity: vel)
                haptics.noteTrigger()
                engine.lastGridNote = name
                loopRecorder.recordEvent(.noteOn(midi: midi, waveform: engine.selectedWaveform, velocity: vel), currentTime: elapsed)
                jamSession.sendEvent(.noteOn(midi: midi, waveform: engine.selectedWaveform, velocity: vel))
            case .noteOff(let hand):
                strudelBridge.noteOff(hand: hand)
                loopRecorder.recordEvent(.noteOff(hand: hand), currentTime: elapsed)
                jamSession.sendEvent(.noteOff(hand: hand))
            case .slide(let hand, let midi, let name):
                strudelBridge.noteSlide(hand: hand, midi: midi)
                engine.lastGridNote = name
            }
        }

        let lanes = gridModeManager.currentLanes(hands: engine.currentHands, scaleNotes: gridNotes)
        engine.gridLeftLane = lanes.left
        engine.gridRightLane = lanes.right

        // Only drum loops (no continuous synth)
        engine.evaluateDrumLoopsIfChanged(modePrefix: "grid")
    }
}
