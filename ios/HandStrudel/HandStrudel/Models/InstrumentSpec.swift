import Foundation

/// A playable on-screen instrument described as data (`shared/instruments/`).
///
/// The JSON Schema in `shared/instruments/schema.json` is the spec; this type
/// mirrors it. Nothing in an instrument file is executed — the app's own code
/// draws and plays it — so files can come from the bundle, a feed post or a
/// generator. Every file goes through `InstrumentSpec.load(_:)`, which
/// rejects anything outside the vocabulary and repairs values that are merely
/// out of range. The same rules are pinned by `shared/instruments/fixtures/`
/// so another implementation (the web app) can be checked against them.
///
/// Version 1 has one surface, the split wheel that Scale and Split modes use.
struct InstrumentSpec: Codable, Equatable {
    static let formatName = "handstrudel.instrument"
    static let formatVersion = 1
    static let nameLimit = 40
    static let descriptionLimit = 200
    static let byteLimit = 16 * 1024

    var format: String
    var formatVersion: Int
    var id: String
    var name: String
    var description: String?
    var surface: SplitWheel
    var chords: Chords
    var notes: Notes
    var sound: Sound?

    enum CodingKeys: String, CodingKey {
        case format, formatVersion = "format_version", id, name, description, surface, chords, notes, sound
    }

    /// One circle cut into a chord half and a note half around a rest hole.
    /// `radius` is a fraction of half the screen's shorter side; the other
    /// radii are fractions of the wheel radius.
    struct SplitWheel: Codable, Equatable {
        enum Kind: String, Codable { case splitWheel = "split_wheel" }
        var type: Kind
        var radius: Double
        var restRadius: Double
        var octaveBandRadius: Double

        enum CodingKeys: String, CodingKey {
            case type, radius, restRadius = "rest_radius", octaveBandRadius = "octave_band_radius"
        }

        static let radiusRange = 0.7...1.0
        static let restRadiusRange = 0.2...0.5
        static let octaveBandRadiusMax = 0.92
        static let octaveBandRadiusMin = 0.6
        /// The base band (between the rest hole and the octave rim) must stay
        /// deep enough to land a hand in.
        static let minimumBaseBand = 0.25
    }

    struct Chords: Codable, Equatable {
        enum Side: String, Codable { case left, right }
        enum Voicing: String, Codable { case triad, seventh }
        var side: Side
        var voicing: Voicing
    }

    struct Notes: Codable, Equatable {
        enum Source: String, Codable {
            case scaleOneOctave = "scale_one_octave"
            case chordTonesThreeOctaves = "chord_tones_three_octaves"
        }
        var source: Source
        var octaveBand: Bool
        var highlightChordTones: Bool?

        enum CodingKeys: String, CodingKey {
            case source, octaveBand = "octave_band", highlightChordTones = "highlight_chord_tones"
        }
    }

    /// Optional sound. Without it the instrument uses the player's settings.
    struct Sound: Codable, Equatable {
        var key: MusicKey
        var scale: String
        var progression: String
        var customDegrees: [Int]?
        var instrument: String
        var waveform: String
        var useSoundfont: Bool
        var bpm: Double
        var autoStrum: Bool
        var padVolume: Double

        enum CodingKeys: String, CodingKey {
            case key, scale, progression, customDegrees = "custom_degrees", instrument, waveform
            case useSoundfont = "use_soundfont", bpm, autoStrum = "auto_strum", padVolume = "pad_volume"
        }

        /// The equivalent app sound, or nil when any part isn't playable here.
        func soundSetup(mode: SoundSetup.Mode, gridOctave: Int = 3, gridRange: Int = 2) -> SoundSetup? {
            guard let scale = Scale(rawValue: scale) else { return nil }
            let setup = SoundSetup(instrument: instrument, waveform: waveform, key: key, scale: scale,
                                   progression: progression, customDegrees: customDegrees, mode: mode, bpm: bpm,
                                   useSoundFont: useSoundfont, autoStrum: autoStrum, padVolume: padVolume,
                                   gridOctave: gridOctave, gridRange: gridRange)
            return setup.isValid ? setup : nil
        }
    }

    var isBuiltIn: Bool { id.hasPrefix("builtin.") }

    /// The wheel mode this instrument runs in. Scale-note instruments use the
    /// Scale mode slot, chord-tone ones the Split slot.
    var baseMode: SoundSetup.Mode {
        notes.source == .scaleOneOctave ? .scalechordmelody : .splitchordmelody
    }

    var rules: WheelRules {
        WheelRules(geometry: WheelGeometry(radius: surface.radius, restRadius: surface.restRadius,
                                           octaveBandRadius: surface.octaveBandRadius),
                   chordsOnRight: chords.side == .right, voicing: chords.voicing,
                   noteSource: notes.source, notesOctaveBand: notes.octaveBand,
                   highlightChordTones: notes.highlightChordTones ?? false)
    }
}

// MARK: - Loading and validation

/// Why an instrument was rejected or changed while loading. Raw values match
/// the codes in `shared/instruments/fixtures/`.
enum InstrumentIssue: String, Equatable {
    // Rejections
    case tooLarge = "too_large"
    case malformed
    case unsupportedFormat = "unsupported_format"
    case unsupportedVersion = "unsupported_version"
    case idInvalid = "id_invalid"
    case nameMissing = "name_missing"
    // Repairs
    case nameTrimmed = "name_trimmed"
    case descriptionTrimmed = "description_trimmed"
    case radiusClamped = "radius_clamped"
    case restRadiusClamped = "rest_radius_clamped"
    case octaveBandRadiusClamped = "octave_band_radius_clamped"
    case soundDropped = "sound_dropped"
}

struct InstrumentLoadResult: Equatable {
    /// The playable instrument, after repairs. Nil when it was rejected.
    let spec: InstrumentSpec?
    /// Rejection reason, or the repairs made, in a fixed order.
    let issues: [InstrumentIssue]
    var accepted: Bool { spec != nil }
}

extension InstrumentSpec {
    private struct Header: Decodable {
        let format: String?
        let formatVersion: Int?
        enum CodingKeys: String, CodingKey { case format, formatVersion = "format_version" }
    }

    /// Decode, check and repair an instrument file. Pure: the result depends
    /// only on the bytes and on which sounds this app version knows.
    static func load(_ data: Data) -> InstrumentLoadResult {
        guard data.count <= byteLimit else { return .init(spec: nil, issues: [.tooLarge]) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data) else {
            return .init(spec: nil, issues: [.malformed])
        }
        guard header.format == formatName else { return .init(spec: nil, issues: [.unsupportedFormat]) }
        guard header.formatVersion == formatVersion else { return .init(spec: nil, issues: [.unsupportedVersion]) }
        guard let spec = try? decoder.decode(InstrumentSpec.self, from: data) else {
            return .init(spec: nil, issues: [.malformed])
        }
        return spec.validated()
    }

    /// Check and repair an already-decoded instrument.
    func validated() -> InstrumentLoadResult {
        guard Self.isValidID(id) else { return .init(spec: nil, issues: [.idInvalid]) }
        var spec = self
        var issues: [InstrumentIssue] = []

        let trimmedName = Self.trim(name, limit: Self.nameLimit)
        guard !trimmedName.isEmpty else { return .init(spec: nil, issues: [.nameMissing]) }
        if trimmedName != name { spec.name = trimmedName; issues.append(.nameTrimmed) }
        if let description {
            let trimmed = Self.trim(description, limit: Self.descriptionLimit)
            if trimmed != description {
                spec.description = trimmed.isEmpty ? nil : trimmed
                issues.append(.descriptionTrimmed)
            }
        }

        typealias Wheel = SplitWheel
        let radius = Self.clamp(surface.radius, Wheel.radiusRange)
        if radius != surface.radius { spec.surface.radius = radius; issues.append(.radiusClamped) }
        let rest = Self.clamp(surface.restRadius, Wheel.restRadiusRange)
        if rest != surface.restRadius { spec.surface.restRadius = rest; issues.append(.restRadiusClamped) }
        let bandMin = max(Wheel.octaveBandRadiusMin, Self.rounded(rest + Wheel.minimumBaseBand))
        let band = Self.clamp(surface.octaveBandRadius, bandMin...Wheel.octaveBandRadiusMax)
        if band != surface.octaveBandRadius { spec.surface.octaveBandRadius = band; issues.append(.octaveBandRadiusClamped) }

        if let sound, sound.soundSetup(mode: baseMode) == nil {
            spec.sound = nil
            issues.append(.soundDropped)
        }
        return .init(spec: spec, issues: issues)
    }

    private static func isValidID(_ id: String) -> Bool {
        id.range(of: #"^[a-z0-9][a-z0-9._-]{0,79}$"#, options: .regularExpression) != nil
    }

    /// Trim whitespace, cut to `limit` characters, then trim again.
    private static func trim(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, value))
    }

    /// Keep sums like 0.5 + 0.25 exact so repaired files round-trip cleanly.
    private static func rounded(_ value: Double) -> Double { (value * 1_000_000).rounded() / 1_000_000 }
}

// MARK: - Runtime rules

/// Wheel radii, as `InstrumentSpec.SplitWheel` describes them.
struct WheelGeometry: Equatable {
    var radius: Double
    var restRadius: Double
    var octaveBandRadius: Double

    /// The Scale and Split wheels' geometry before it moved into
    /// `shared/instruments/library/`. Used only if a bundled file is missing.
    static let standard = WheelGeometry(radius: 1.0, restRadius: 0.36, octaveBandRadius: 0.80)
}

/// What the wheel engine, overlay and touch layer need from an instrument.
struct WheelRules: Equatable {
    var geometry: WheelGeometry
    var chordsOnRight: Bool
    var voicing: InstrumentSpec.Chords.Voicing
    var noteSource: InstrumentSpec.Notes.Source
    var notesOctaveBand: Bool
    var highlightChordTones: Bool

    /// Chord hand on the right half: the instrument's side, mirrored by the
    /// player's swap-hands setting.
    func swapHands(playerSwap: Bool) -> Bool { playerSwap != chordsOnRight }

    var chordNameSuffix: String { voicing == .seventh ? "⁷" : "" }

    func chordTones(key: MusicKey, scale: Scale, degree: Int) -> [Int] {
        switch voicing {
        case .triad: return chordNotes(key: key, scale: scale, degree: degree)
        case .seventh: return chordNotesWithSeventh(key: key, scale: scale, degree: degree)
        }
    }

    /// The notes the note half fans, bottom to top. With an octave band the
    /// rim adds ±12 to these.
    func noteLanes(key: MusicKey, scale: Scale, chordDegree: Int) -> [Int] {
        switch noteSource {
        case .scaleOneOctave:
            return scaleNotesOneOctave(key: key, scale: scale)
        case .chordTonesThreeOctaves:
            let triad = chordNotes(key: key, scale: scale, degree: chordDegree)
            return (0..<3).flatMap { octave in triad.map { $0 + octave * 12 } }.sorted()
        }
    }

    /// Lanes that belong to the held chord, for tinting (empty when off).
    func chordToneLanes(key: MusicKey, scale: Scale, chordDegree: Int, lanes: [Int]) -> Set<Int> {
        guard highlightChordTones else { return [] }
        let classes = Set(chordTones(key: key, scale: scale, degree: chordDegree).map { $0 % 12 })
        return Set(lanes.indices.filter { classes.contains(lanes[$0] % 12) })
    }
}

// MARK: - Bundled library

/// Instruments shipped in the app, loaded from `shared/instruments/library/`
/// (bundled as the `library` folder).
enum InstrumentLibrary {
    static let scaleWheelID = "builtin.scale-wheel"
    static let splitWheelID = "builtin.split-wheel"

    static let all: [InstrumentSpec] = loadAll()

    static let scaleWheel: InstrumentSpec = builtIn(scaleWheelID) ?? fallbackScaleWheel
    static let splitWheel: InstrumentSpec = builtIn(splitWheelID) ?? fallbackSplitWheel

    static func builtIn(_ id: String) -> InstrumentSpec? { all.first { $0.id == id } }

    static func loadAll(bundle: Bundle = .main) -> [InstrumentSpec] {
        let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: "library") ?? []
        let specs = urls.compactMap { url -> InstrumentSpec? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            let result = InstrumentSpec.load(data)
            #if DEBUG
            if !result.issues.isEmpty { print("[Instruments] \(url.lastPathComponent): \(result.issues)") }
            #endif
            return result.spec
        }
        return specs.sorted { ($0.isBuiltIn ? 0 : 1, $0.name) < ($1.isBuiltIn ? 0 : 1, $1.name) }
    }

    private static let fallbackScaleWheel = InstrumentSpec(
        format: InstrumentSpec.formatName, formatVersion: 1, id: scaleWheelID, name: "Scale Wheel", description: nil,
        surface: .init(type: .splitWheel, radius: 1.0, restRadius: 0.36, octaveBandRadius: 0.8),
        chords: .init(side: .left, voicing: .seventh),
        notes: .init(source: .scaleOneOctave, octaveBand: true, highlightChordTones: true), sound: nil)

    private static let fallbackSplitWheel = InstrumentSpec(
        format: InstrumentSpec.formatName, formatVersion: 1, id: splitWheelID, name: "Split Wheel", description: nil,
        surface: .init(type: .splitWheel, radius: 1.0, restRadius: 0.36, octaveBandRadius: 0.8),
        chords: .init(side: .left, voicing: .triad),
        notes: .init(source: .chordTonesThreeOctaves, octaveBand: false, highlightChordTones: nil), sound: nil)
}
