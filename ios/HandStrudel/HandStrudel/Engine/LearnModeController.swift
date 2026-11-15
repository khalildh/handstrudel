import Foundation

/// Guitar-Hero-style guided play. Reuses the grid lane detection; the
/// LearnModeManager owns scoring and falling-note state.
@MainActor
final class LearnModeController: ModeController {
    func tick(_ engine: EngineController) {
        let learnModeManager = engine.learnModeManager
        let strudelBridge = engine.strudelBridge
        let haptics = engine.haptics

        // Use same grid infrastructure for lane detection
        let gridNotes = scaleNotes(key: engine.selectedKey, scale: engine.selectedScale,
                                   baseOctave: engine.gridBaseOctave, octaveRange: engine.gridOctaveRange)
        guard !gridNotes.isEmpty else { return }

        let elapsed = engine.startTime.map { Date().timeIntervalSince($0) } ?? 0

        // Get current pinch/lane state from grid manager
        let leftHand = engine.currentHands.left
        let rightHand = engine.currentHands.right
        let videoAspect = engine.handTracker.videoWidth / max(1, engine.handTracker.videoHeight)
        func cameraLane(_ hand: HandData?) -> Int? {
            guard let hand else { return nil }
            return LearnLaneLayout.cameraLane(y: hand.pinchY, noteCount: gridNotes.count,
                                              videoAspect: videoAspect, viewportAspect: engine.learnViewportAspect)
        }
        let leftLane = cameraLane(leftHand)
        let rightLane = cameraLane(rightHand)
        let leftPinching = (leftHand?.pinch ?? 0) > 0.8
        let rightPinching = (rightHand?.pinch ?? 0) > 0.8

        engine.gridLeftLane = leftLane
        engine.gridRightLane = rightLane

        let hitNotes = learnModeManager.tick(
            elapsed: elapsed,
            leftLane: leftLane,
            rightLane: rightLane,
            leftPinching: leftPinching,
            rightPinching: rightPinching
        )

        // Play sound for hit notes
        for hit in hitNotes {
            strudelBridge.playNote(midi: hit.midi, waveform: engine.selectedWaveform, velocity: 0.7, duration: 0.3)
            haptics.learnPerfectHit()
        }

        // Sync visual state to published properties (at UI timer rate)
        engine.updateLearnUI()
    }
}
