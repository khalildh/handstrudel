import UIKit
import CoreHaptics

final class HapticManager {
    private var engine: CHHapticEngine?

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
        } catch {
            debugPrint("Haptic engine failed:", error)
        }
    }

    // Light tap on each beat
    func beatPulse(isDownbeat: Bool) {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: isDownbeat ? 0.6 : 0.3)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: isDownbeat ? 0.5 : 0.8)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        playPattern([event])
    }

    // Medium tap when a note is triggered (grid mode pinch)
    func noteTrigger() {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        playPattern([event])
    }

    // Sharp hit for drum triggers
    func drumHit() {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        playPattern([event])
    }

    // Learn mode: strong positive for perfect hit
    func learnPerfectHit() {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        playPattern([event])
    }

    // Learn mode: medium for good hit
    func learnGoodHit() {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        playPattern([event])
    }

    // Learn mode: short buzz for miss
    func learnMiss() {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        playPattern([event])
    }

    // Gentle feedback for UI interactions
    func lightTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func playPattern(_ events: [CHHapticEvent]) {
        guard let engine else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Silently fail — haptics are optional
        }
    }
}
