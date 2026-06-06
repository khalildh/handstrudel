import Foundation

final class PersistenceManager {
    static let shared = PersistenceManager()

    private let defaults = UserDefaults.standard
    private let loopsKey = "savedLoops"
    private let snippetsKey = "savedSnippets"

    // MARK: - Settings

    var lastPresetId: String? {
        get { defaults.string(forKey: "lastPresetId") }
        set { defaults.set(newValue, forKey: "lastPresetId") }
    }

    var lastMode: String {
        get { defaults.string(forKey: "lastMode") ?? "melodic" }
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

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
