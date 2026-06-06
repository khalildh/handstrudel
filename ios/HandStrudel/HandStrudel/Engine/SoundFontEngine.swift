import Foundation
import AVFoundation
import AudioToolbox

/// Native SoundFont playback engine for the SoundFont mode.
///
/// Unlike the rest of the app — which synthesises sound in the bundled Strudel
/// WebView (`StrudelBridge`) — this mode plays real SoundFont (`.sf2`)
/// instruments through Apple's `AVAudioUnitSampler`. That gives us authentic
/// General MIDI timbres (grand piano, strings, etc.) decoded natively, fully
/// offline, with proper multi-velocity samples.
///
/// ## Voices and channels
/// Each logical voice (the three sustained chord-pad notes and the melody
/// note) is assigned its own MIDI channel so that turning one note off never
/// silences another that happens to share the same pitch. One-shot accents and
/// auto-strum hits go out on a dedicated channel and stop themselves after a
/// short duration.
///
/// ## The `.sf2` asset
/// A General MIDI SoundFont is **not** bundled in the repo (licensing + size is
/// the app owner's call). Drop a `.sf2` into
/// `Resources/soundfonts/` (see the README there) — the engine loads the first
/// one it finds. Until then the engine simply stays silent: every call is a
/// safe no-op, so the mode is still selectable and the UI works.
@MainActor
final class SoundFontEngine {

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()

    /// Whether a `.sf2` was found and the audio graph started successfully.
    private(set) var isAvailable = false

    /// The URL of the loaded SoundFont, if any (for logging/diagnostics).
    private(set) var soundFontURL: URL?

    /// GM program (0–127) currently loaded into the sampler.
    private(set) var currentProgram: UInt8 = 0

    // MARK: - Voice → channel routing

    /// Sustained voices each own a channel so independent note-offs don't
    /// collide. Channels 0–6 are reserved for sustained voices; one-shots use
    /// channel 8 (avoiding 9, the GM percussion channel).
    private var voiceChannels: [String: UInt8] = [:]
    private var activeNotes: [String: (midi: UInt8, channel: UInt8)] = [:]
    private var voiceVelocity: [String: UInt8] = [:]
    private var nextChannel: UInt8 = 0
    private let oneShotChannel: UInt8 = 8

    // GM "melodic" bank selectors used by loadSoundBankInstrument.
    private let bankMSB = UInt8(kAUSampler_DefaultMelodicBankMSB) // 0x79
    private let bankLSB = UInt8(kAUSampler_DefaultBankLSB)        // 0x00

    // MARK: - Lifecycle

    /// Locate the `.sf2`, wire up the audio graph and load the initial GM
    /// program. Safe to call repeatedly — only the first successful call does
    /// real work. Returns `true` once audio is ready.
    @discardableResult
    func startIfNeeded(program: UInt8) -> Bool {
        if isAvailable { return true }

        guard let url = Self.locateSoundFont() else {
            log("no .sf2 found in bundle — SoundFont mode will be silent")
            return false
        }
        soundFontURL = url

        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)

        do {
            try engine.start()
        } catch {
            log("engine start failed: \(error)")
            return false
        }

        guard loadProgram(program, force: true) else { return false }

        isAvailable = true
        log("ready — soundfont=\(url.lastPathComponent) program=\(program)")
        return true
    }

    /// Switch the GM instrument. No-op if it's already loaded.
    func setInstrument(program: UInt8) {
        guard program != currentProgram || !isAvailable else { return }
        allNotesOff()
        _ = loadProgram(program, force: false)
    }

    @discardableResult
    private func loadProgram(_ program: UInt8, force: Bool) -> Bool {
        guard let url = soundFontURL else { return false }
        do {
            try sampler.loadSoundBankInstrument(
                at: url, program: program, bankMSB: bankMSB, bankLSB: bankLSB
            )
            currentProgram = program
            return true
        } catch {
            // Some SoundFonts don't define every GM program; fall back to 0.
            log("load program \(program) failed: \(error)")
            if program != 0 && force {
                return loadProgram(0, force: false)
            }
            return false
        }
    }

    // MARK: - Note control

    /// Start (or re-strike) a sustained voice. `velocity` is 0…1.
    func noteOn(voice: String, midi: Int, velocity: Double) {
        guard isAvailable else { return }
        let channel = channel(for: voice)
        let note = clampMidi(midi)
        let vel = clampVelocity(velocity)
        if let active = activeNotes[voice] {
            sampler.stopNote(active.midi, onChannel: active.channel)
        }
        sampler.startNote(note, withVelocity: vel, onChannel: channel)
        activeNotes[voice] = (note, channel)
        voiceVelocity[voice] = vel
    }

    /// Release a sustained voice.
    func noteOff(voice: String) {
        guard isAvailable, let active = activeNotes[voice] else { return }
        sampler.stopNote(active.midi, onChannel: active.channel)
        activeNotes[voice] = nil
    }

    /// Move a sustained voice to a new pitch. `AVAudioUnitSampler` has no
    /// portamento, so this re-articulates at the voice's last velocity — close
    /// enough for melody glides and pad voicing changes.
    func slide(voice: String, midi: Int) {
        guard isAvailable else { return }
        let note = clampMidi(midi)
        if let active = activeNotes[voice], active.midi == note { return }
        let channel = channel(for: voice)
        if let active = activeNotes[voice] {
            sampler.stopNote(active.midi, onChannel: active.channel)
        }
        let vel = voiceVelocity[voice] ?? clampVelocity(0.6)
        sampler.startNote(note, withVelocity: vel, onChannel: channel)
        activeNotes[voice] = (note, channel)
    }

    /// Fire-and-forget note used for chord accents and auto-strum. Stops itself
    /// after `duration` seconds on a dedicated channel so it never interferes
    /// with the sustained pad/melody voices.
    func oneShot(midi: Int, velocity: Double, duration: Double) {
        guard isAvailable else { return }
        let note = clampMidi(midi)
        let vel = clampVelocity(velocity)
        sampler.startNote(note, withVelocity: vel, onChannel: oneShotChannel)
        let channel = oneShotChannel
        let s = sampler
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.05, duration)) {
            s.stopNote(note, onChannel: channel)
        }
    }

    /// Silence everything — sustained voices and any lingering one-shots.
    func allNotesOff() {
        guard isAvailable else { return }
        for (_, active) in activeNotes {
            sampler.stopNote(active.midi, onChannel: active.channel)
        }
        activeNotes.removeAll()
        // MIDI "all notes off" (CC 123) on every channel as a safety net.
        for ch in UInt8(0)...UInt8(15) {
            sampler.sendController(123, withValue: 0, onChannel: ch)
        }
    }

    // MARK: - Helpers

    private func channel(for voice: String) -> UInt8 {
        if let ch = voiceChannels[voice] { return ch }
        // Reserve channels 0–6 for sustained voices; wrap if we somehow exceed.
        let ch = nextChannel
        nextChannel = (nextChannel + 1) % 7
        voiceChannels[voice] = ch
        return ch
    }

    private func clampMidi(_ midi: Int) -> UInt8 {
        UInt8(max(0, min(127, midi)))
    }

    private func clampVelocity(_ v: Double) -> UInt8 {
        UInt8(max(1, min(127, Int((v * 127).rounded()))))
    }

    /// Search the app bundle for a usable SoundFont. Prefers a file in the
    /// `soundfonts/` folder reference, then any `.sf2`/`.dls` anywhere in the
    /// bundle, so the owner can drop one in without renaming.
    private static func locateSoundFont() -> URL? {
        let bundle = Bundle.main
        for ext in ["sf2", "dls"] {
            if let urls = bundle.urls(forResourcesWithExtension: ext, subdirectory: "soundfonts"),
               let first = urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).first {
                return first
            }
        }
        for ext in ["sf2", "dls"] {
            if let urls = bundle.urls(forResourcesWithExtension: ext, subdirectory: nil),
               let first = urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).first {
                return first
            }
        }
        return nil
    }

    private func log(_ msg: String) {
        #if DEBUG
        print("[soundfont] \(msg)")
        #endif
    }
}
