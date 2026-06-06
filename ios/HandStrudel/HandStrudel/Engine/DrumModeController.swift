import Foundation

/// Air-drum mode: hand Y picks a drum lane, pinch crossings strike it.
@MainActor
final class DrumModeController: ModeController {
    func tick(_ engine: EngineController) {
        let strudelBridge = engine.strudelBridge
        let drumModeManager = engine.drumModeManager
        let haptics = engine.haptics
        let loopRecorder = engine.loopRecorder
        let jamSession = engine.jamSession

        strudelBridge.updateDrumParams(intensity: engine.drumIntensity, complexity: engine.drumComplexity)
        let elapsed = engine.startTime.map { Date().timeIntervalSince($0) } ?? 0
        let hits = drumModeManager.checkHits(hands: engine.currentHands, currentTime: elapsed)
        for hit in hits {
            strudelBridge.playHit(hit.hitType)
            haptics.drumHit()
            engine.lastDrumHit = hit.hitType
            loopRecorder.recordEvent(.drumHit(hitType: hit.hitType), currentTime: elapsed)
            jamSession.sendEvent(.drumHit(hitType: hit.hitType))
        }

        // Update lane display for UI
        engine.drumLeftLane = drumModeManager.leftLane
        engine.drumRightLane = drumModeManager.rightLane

        engine.evaluateDrumLoopsIfChanged(modePrefix: "drum")
    }
}
