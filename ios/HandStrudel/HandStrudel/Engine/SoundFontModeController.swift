import Foundation

/// SoundFont mode: same two-hand chord+melody interaction as the standard
/// chord-melody mode, but voiced through Apple's `AVAudioUnitSampler` against
/// a bundled General MIDI `.sf2` instead of the WebView synth. The tick body
/// lives on `EngineController.tickSoundFontMode()` because it shares state
/// with the chord-melody UI; this controller is a thin shim so the mode slots
/// into the `activeMode` dispatch.
@MainActor
final class SoundFontModeController: ModeController {
    func tick(_ engine: EngineController) {
        engine.tickSoundFontMode()
    }
}
