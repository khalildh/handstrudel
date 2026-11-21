import Foundation

/// A playable on-screen instrument described as data (`shared/instruments/`).
///
/// An instrument is structure, not music: its zones are defined relative to
/// the player's current key, scale and progression (one note wedge per scale
/// note, one chord wedge per progression chord), so it adapts to whatever
/// music is selected and never picks it. Anything that would make the same
/// zone sound different with the same settings — key, scale, chord voicing,
/// sound — is a music setting and stays out of the file.
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
/// Version 2 adds general surfaces (radial, grid, keys/strips, pads, arc,
/// orbs) whose zones, gestures and visuals live in `layout`
/// (`InstrumentLayout`); a split wheel keeps `surface`, `chords` and `notes`
/// in either version.
struct InstrumentSpec: Codable, Equatable {
    static let formatName = "handstrudel.instrument"
    /// The newest format this app reads.
    static let formatVersion = 2
    static let supportedVersions = 1...formatVersion
    static let nameLimit = 40
    static let descriptionLimit = 200
    static let byteLimit = 16 * 1024

    var format: String
    var formatVersion: Int
    var id: String
    var name: String
    var description: String?
    /// The split wheel. For a format 2 instrument with another surface this
    /// is the standard wheel and unused; `layout` describes the instrument.
    var surface: SplitWheel
    var chords: Chords
    var notes: Notes
    /// Format 2 surfaces other than the split wheel. Nil for wheels.
    var layout: InstrumentLayout? = nil

    enum CodingKeys: String, CodingKey {
        case format, formatVersion = "format_version", id, name, description, surface, chords, notes
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
        var side: Side
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

    var isBuiltIn: Bool { id.hasPrefix("builtin.") }

    /// Played by the generic instrument renderer rather than the Scale/Split wheel.
    var isSurfaceInstrument: Bool { layout != nil }

    /// The surface's type name as it appears in the file.
    var surfaceType: String { layout?.surface.type.rawValue ?? SplitWheel.Kind.splitWheel.rawValue }

    /// The wheel mode this instrument runs in. Scale-note instruments use the
    /// Scale mode slot, chord-tone ones the Split slot.
    var baseMode: SoundSetup.Mode {
        notes.source == .scaleOneOctave ? .scalechordmelody : .splitchordmelody
    }

    var rules: WheelRules {
        WheelRules(geometry: WheelGeometry(radius: surface.radius, restRadius: surface.restRadius,
                                           octaveBandRadius: surface.octaveBandRadius),
                   chordsOnRight: chords.side == .right,
                   voicing: ChordVoicing.wheelDefault(for: notes.source),
                   noteSource: notes.source, notesOctaveBand: notes.octaveBand,
                   highlightChordTones: notes.highlightChordTones ?? false)
    }
}

// MARK: - Coding

extension InstrumentSpec {
    private enum SurfaceTypeKey: String, CodingKey { case type }

    /// A split wheel decodes into `surface`/`chords`/`notes` (format 1 or 2);
    /// any other surface needs format 2 and decodes into `layout`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format = try container.decode(String.self, forKey: .format)
        formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        let type = try container.nestedContainer(keyedBy: SurfaceTypeKey.self, forKey: .surface)
            .decode(String.self, forKey: .type)
        if type == SplitWheel.Kind.splitWheel.rawValue {
            surface = try container.decode(SplitWheel.self, forKey: .surface)
            chords = try container.decode(Chords.self, forKey: .chords)
            notes = try container.decode(Notes.self, forKey: .notes)
            layout = nil
        } else {
            guard formatVersion >= 2 else {
                throw DecodingError.dataCorruptedError(forKey: .surface, in: container,
                                                       debugDescription: "\(type) needs format_version 2")
            }
            layout = try InstrumentLayout(from: decoder)
            surface = Self.unusedWheel
            chords = Chords(side: .left)
            notes = Notes(source: .scaleOneOctave, octaveBand: false, highlightChordTones: nil)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(format, forKey: .format)
        try container.encode(formatVersion, forKey: .formatVersion)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        if let layout {
            try layout.encode(to: encoder)
        } else {
            try container.encode(surface, forKey: .surface)
            try container.encode(chords, forKey: .chords)
            try container.encode(notes, forKey: .notes)
        }
    }

    /// Placeholder wheel for instruments that aren't wheels.
    static let unusedWheel = SplitWheel(type: .splitWheel, radius: 1.0, restRadius: 0.36, octaveBandRadius: 0.8)
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
    case zonesMissing = "zones_missing"
    case zoneInvalid = "zone_invalid"
    case zonesOverlap = "zones_overlap"
    // Repairs
    case nameTrimmed = "name_trimmed"
    case descriptionTrimmed = "description_trimmed"
    case radiusClamped = "radius_clamped"
    case restRadiusClamped = "rest_radius_clamped"
    case octaveBandRadiusClamped = "octave_band_radius_clamped"
    case surfaceClamped = "surface_clamped"
    case zoneClamped = "zone_clamped"
    case zoneMoved = "zone_moved"
    case zoneResized = "zone_resized"
    case zonesDropped = "zones_dropped"
    case octaveBandsRemoved = "octave_bands_removed"
    case labelTrimmed = "label_trimmed"
    case gestureDropped = "gesture_dropped"
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
    /// only on the bytes. Fields this version doesn't know are ignored.
    static func load(_ data: Data) -> InstrumentLoadResult {
        guard data.count <= byteLimit else { return .init(spec: nil, issues: [.tooLarge]) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data) else {
            return .init(spec: nil, issues: [.malformed])
        }
        guard header.format == formatName else { return .init(spec: nil, issues: [.unsupportedFormat]) }
        guard let version = header.formatVersion, supportedVersions.contains(version) else { return .init(spec: nil, issues: [.unsupportedVersion]) }
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

        if let layout {
            switch layout.validated() {
            case .rejected(let issue):
                return .init(spec: nil, issues: [issue])
            case .accepted(let repaired, let layoutIssues):
                spec.layout = repaired
                return .init(spec: spec, issues: issues + layoutIssues)
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

        return .init(spec: spec, issues: issues)
    }

    static func isValidID(_ id: String) -> Bool {
        id.range(of: #"^[a-z0-9][a-z0-9._-]{0,79}$"#, options: .regularExpression) != nil
    }

    /// Trim whitespace, cut to `limit` characters, then trim again.
    static func trim(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, value))
    }

    /// Keep sums like 0.5 + 0.25 exact so repaired files round-trip cleanly.
    static func rounded(_ value: Double) -> Double { (value * 1_000_000).rounded() / 1_000_000 }
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

/// How chords are voiced. A music setting, not part of an instrument: until
/// it becomes a player setting, each wheel keeps the voicing it always had.
enum ChordVoicing: Equatable {
    case triad, seventh

    /// The Scale wheel (scale notes) plays 7ths; the Split wheel plays triads.
    static func wheelDefault(for source: InstrumentSpec.Notes.Source) -> ChordVoicing {
        source == .scaleOneOctave ? .seventh : .triad
    }
}

/// What the wheel engine, overlay and touch layer need from an instrument
/// (plus the voicing the player's music implies).
struct WheelRules: Equatable {
    var geometry: WheelGeometry
    var chordsOnRight: Bool
    var voicing: ChordVoicing
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
        // Built-ins first, wheels before other surfaces, then by name.
        return specs.sorted {
            ($0.isBuiltIn ? 0 : 1, $0.isSurfaceInstrument ? 1 : 0, $0.name) < ($1.isBuiltIn ? 0 : 1, $1.isSurfaceInstrument ? 1 : 0, $1.name)
        }
    }

    private static let fallbackScaleWheel = InstrumentSpec(
        format: InstrumentSpec.formatName, formatVersion: 1, id: scaleWheelID, name: "Scale Wheel", description: nil,
        surface: .init(type: .splitWheel, radius: 1.0, restRadius: 0.36, octaveBandRadius: 0.8),
        chords: .init(side: .left),
        notes: .init(source: .scaleOneOctave, octaveBand: true, highlightChordTones: true))

    private static let fallbackSplitWheel = InstrumentSpec(
        format: InstrumentSpec.formatName, formatVersion: 1, id: splitWheelID, name: "Split Wheel", description: nil,
        surface: .init(type: .splitWheel, radius: 1.0, restRadius: 0.36, octaveBandRadius: 0.8),
        chords: .init(side: .left),
        notes: .init(source: .chordTonesThreeOctaves, octaveBand: false, highlightChordTones: nil))
}
