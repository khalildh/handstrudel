import Foundation

final class PersistenceManager {
    static let shared = PersistenceManager()

    private let defaults: UserDefaults
    private let loopsKey = "savedLoops"
    private let snippetsKey = "savedSnippets"
    private let setupsKey = "savedSoundSetups"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSetups() -> [NamedSoundSetup] {
        guard let data = defaults.data(forKey: setupsKey) else { return [] }
        return (try? JSONDecoder().decode([NamedSoundSetup].self, from: data)) ?? []
    }

    func saveSetups(_ setups: [NamedSoundSetup]) {
        if let data = try? JSONEncoder().encode(setups) { defaults.set(data, forKey: setupsKey) }
    }

    @discardableResult
    func addPreset(_ sound: SoundSetup, named name: String) -> Bool {
        let name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard sound.isValid, !name.isEmpty else { return false }
        var setups = loadSetups()
        guard !setups.contains(where: { $0.sound == sound && $0.name == name }) else { return false }
        setups.insert(NamedSoundSetup(id: UUID(), name: name, sound: sound), at: 0)
        saveSetups(setups)
        return true
    }

    // MARK: - Settings

    var lastPresetId: String? {
        get { defaults.string(forKey: "lastPresetId") }
        set { defaults.set(newValue, forKey: "lastPresetId") }
    }

    var lastMode: String {
        // Split chord+melody is the app's default mode on first launch.
        // Existing users keep whichever mode they last used.
        get { defaults.string(forKey: "lastMode") ?? "splitchordmelody" }
        set { defaults.set(newValue, forKey: "lastMode") }
    }

    var lastKey: String {
        get { defaults.string(forKey: "lastKey") ?? "C" }
        set { defaults.set(newValue, forKey: "lastKey") }
    }

    var lastScale: String {
        get { defaults.string(forKey: "lastScale") ?? "Pentatonic" }
        set { defaults.set(newValue, forKey: "lastScale") }
    }

    var lastWaveform: String {
        get { defaults.string(forKey: "lastWaveform") ?? "sawtooth" }
        set { defaults.set(newValue, forKey: "lastWaveform") }
    }

    var lastSoundFont: String {
        get { defaults.string(forKey: "lastSoundFont") ?? DEFAULT_SOUNDFONT_INSTRUMENT.id }
        set { defaults.set(newValue, forKey: "lastSoundFont") }
    }

    var lastBPM: Double {
        get { defaults.double(forKey: "lastBPM").nonZero ?? 120 }
        set { defaults.set(newValue, forKey: "lastBPM") }
    }

    var lastFilterId: String {
        get { defaults.string(forKey: "lastFilterId") ?? "none" }
        set { defaults.set(newValue, forKey: "lastFilterId") }
    }

    var lastGridBaseOctave: Int {
        get { let v = defaults.integer(forKey: "lastGridBaseOctave"); return v == 0 ? 3 : v }
        set { defaults.set(newValue, forKey: "lastGridBaseOctave") }
    }

    var lastGridOctaveRange: Int {
        get { let v = defaults.integer(forKey: "lastGridOctaveRange"); return v == 0 ? 2 : v }
        set { defaults.set(newValue, forKey: "lastGridOctaveRange") }
    }

    var lastQuantizeEnabled: Bool {
        get { defaults.bool(forKey: "lastQuantizeEnabled") }
        set { defaults.set(newValue, forKey: "lastQuantizeEnabled") }
    }

    var lastQuantizeDiv: Double {
        get { let v = defaults.double(forKey: "lastQuantizeDiv"); return v == 0 ? 8 : v }
        set { defaults.set(newValue, forKey: "lastQuantizeDiv") }
    }

    // MARK: - Loops

    func saveLoops(_ loops: [RecordedLoop]) {
        if let data = try? JSONEncoder().encode(loops) {
            defaults.set(data, forKey: loopsKey)
        }
    }

    func loadLoops() -> [RecordedLoop] {
        guard let data = defaults.data(forKey: loopsKey),
              let loops = try? JSONDecoder().decode([RecordedLoop].self, from: data) else {
            return []
        }
        return loops
    }

    // MARK: - Snippets

    func saveSnippets(_ snippets: [SavedSnippet]) {
        if let data = try? JSONEncoder().encode(snippets) {
            defaults.set(data, forKey: snippetsKey)
        }
    }

    func loadSnippets() -> [SavedSnippet] {
        guard let data = defaults.data(forKey: snippetsKey),
              let snippets = try? JSONDecoder().decode([SavedSnippet].self, from: data) else {
            return []
        }
        return snippets
    }

    // MARK: - Save All State

    func saveEngineState(presetId: String?, mode: String, key: String, scale: String,
                         waveform: String, bpm: Double, filterId: String,
                         gridBaseOctave: Int, gridOctaveRange: Int,
                         quantizeEnabled: Bool, quantizeDiv: Double) {
        lastPresetId = presetId
        lastMode = mode
        lastKey = key
        lastScale = scale
        lastWaveform = waveform
        lastBPM = bpm
        lastFilterId = filterId
        lastGridBaseOctave = gridBaseOctave
        lastGridOctaveRange = gridOctaveRange
        lastQuantizeEnabled = quantizeEnabled
        lastQuantizeDiv = quantizeDiv
    }
}

struct NamedSoundSetup: Identifiable, Codable {
    let id: UUID
    let name: String
    let sound: SoundSetup
}

struct SoundSetup: Codable, Equatable {
    var version = 1
    let instrument: String
    let waveform: String
    let key: MusicKey
    let scale: Scale
    let progression: String
    let customDegrees: [Int]?
    let mode: Mode
    let bpm: Double
    let useSoundFont: Bool
    let autoStrum: Bool
    let padVolume: Double
    let gridOctave: Int
    let gridRange: Int

    enum Mode: String, Codable {
        case melodic, flow, hybrid, lead, grid, drum, chordmelody, radialchordmelody
        case splitchordmelody, scalechordmelody, soundfont
    }

    var resolvedInstrument: SoundFontInstrument? { SOUNDFONT_INSTRUMENTS.first { $0.id == instrument } }
    var resolvedWaveform: Waveform? { WAVEFORMS.first { $0.id == waveform } }
    var instrumentName: String? { useSoundFont ? resolvedInstrument?.name : resolvedWaveform?.name }
    var keyAndScale: String { "\(key.rawValue) \(scale.rawValue)" }
    var presetDetails: String {
        var parts = [keyAndScale]
        if (20...400).contains(bpm) { parts.append("\(Int(bpm.rounded())) BPM") }
        if let progression = resolvedProgression, progression.id != "free" {
            parts.append(progression.isCustom ? progression.degrees.map { String($0 + 1) }.joined(separator: "-") : progression.name)
        }
        return parts.joined(separator: " · ")
    }

    var resolvedProgression: ChordProgression? {
        if progression == "custom" {
            guard let customDegrees, (1...64).contains(customDegrees.count),
                  customDegrees.allSatisfy({ (0...6).contains($0) }) else { return nil }
            return ChordProgression.parse(customDegrees.map { String($0 + 1) }.joined(separator: " "))
        }
        return CHORD_PROGRESSIONS.first { $0.id == progression }
    }

    var isValid: Bool {
        version == 1 && resolvedInstrument != nil && resolvedWaveform != nil && resolvedProgression != nil
            && (20...400).contains(bpm) && (0...0.6).contains(padVolume)
            && (1...6).contains(gridOctave) && (1...3).contains(gridRange)
            && (mode == .soundfont ? useSoundFont : (!useSoundFont || [.radialchordmelody, .splitchordmelody, .scalechordmelody].contains(mode)))
    }

    var requiredPacks: [String] {
        // Ignore the inactive synth's selection, which isn't used when this sound is applied.
        [useSoundFont ? resolvedInstrument?.packId : resolvedWaveform?.packId,
         scale.packId, resolvedProgression?.packId].compactMap { $0 }
    }
}

extension EngineController {
    var currentSoundSetup: SoundSetup? {
        guard !learnModeEnabled, let mode = SoundSetup.Mode(rawValue: currentModeString) else { return nil }
        return SoundSetup(instrument: selectedSoundFontInstrument.id, waveform: selectedWaveform,
                          key: selectedKey, scale: selectedScale, progression: chordMelodyProgression.id,
                          customDegrees: chordMelodyProgression.isCustom ? chordMelodyProgression.degrees : nil,
                          mode: mode, bpm: manualBPM, useSoundFont: activeSoundFontRouting,
                          autoStrum: chordMelodyAutoStrum, padVolume: chordMelodyPadVolume,
                          gridOctave: gridBaseOctave, gridRange: gridOctaveRange)
    }

    private var activeSoundFontRouting: Bool {
        soundFontModeEnabled || (radialChordMelodyModeEnabled && radialUseSoundFont)
            || (splitChordMelodyModeEnabled && splitUseSoundFont) || (scaleChordMelodyModeEnabled && scaleUseSoundFont)
    }

    @discardableResult
    func applySoundSetup(_ setup: SoundSetup, store: StoreManager) -> Bool {
        guard setup.isValid, let progression = setup.resolvedProgression,
              setup.requiredPacks.allSatisfy({ store.isUnlocked($0) }) else { return false }
        let mode = setup.mode
        silenceAll()
        selectedKey = setup.key
        selectedScale = setup.scale
        chordMelodyProgression = progression
        if setup.useSoundFont, let instrument = setup.resolvedInstrument { selectedSoundFontInstrument = instrument }
        else { selectedWaveform = setup.waveform }
        if mode == .radialchordmelody { radialUseSoundFont = setup.useSoundFont }
        if mode == .splitchordmelody { splitUseSoundFont = setup.useSoundFont }
        if mode == .scalechordmelody { scaleUseSoundFont = setup.useSoundFont }
        manualBPM = setup.bpm
        chordMelodyAutoStrum = setup.autoStrum
        chordMelodyPadVolume = setup.padVolume
        gridBaseOctave = setup.gridOctave
        gridOctaveRange = setup.gridRange
        switchMode(grid: mode == .grid, drums: mode == .drum, learn: false, chordMelody: mode == .chordmelody,
                   lead: mode == .lead, hybrid: mode == .hybrid, flow: mode == .flow, soundFont: mode == .soundfont,
                   radialChordMelody: mode == .radialchordmelody, splitChordMelody: mode == .splitchordmelody,
                   scaleChordMelody: mode == .scalechordmelody)
        return true
    }
}

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
