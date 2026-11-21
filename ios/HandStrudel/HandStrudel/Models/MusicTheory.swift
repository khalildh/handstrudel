import Foundation

// MARK: - Keys

enum MusicKey: String, CaseIterable, Identifiable, Codable {
    case C, Db, D, Eb, E, F, Gb, G, Ab, A, Bb, B
    var id: String { rawValue }
    var semitone: Int {
        switch self {
        case .C: return 0
        case .Db: return 1
        case .D: return 2
        case .Eb: return 3
        case .E: return 4
        case .F: return 5
        case .Gb: return 6
        case .G: return 7
        case .Ab: return 8
        case .A: return 9
        case .Bb: return 10
        case .B: return 11
        }
    }
}

// MARK: - Scales

enum BuiltInScale: String, CaseIterable, Hashable {
    case major = "Major"
    case minor = "Minor"
    case dorian = "Dorian"
    case pentatonic = "Pentatonic"
    case blues = "Blues"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor = "Melodic Minor"
    case phrygian = "Phrygian"
    case lydian = "Lydian"
    case mixolydian = "Mixolydian"
    case locrian = "Locrian"
    case wholeTone = "Whole Tone"
    case chromatic = "Chromatic"
    case hungarianMinor = "Hungarian Minor"
    case hirajoshi = "Hirajoshi"
    case minorPentatonic = "Minor Pentatonic"
    case majorBlues = "Major Blues"
    case phrygianDominant = "Phrygian Dominant"
    case diminished = "Diminished (Half-Whole)"
    case harmonicMajor = "Harmonic Major"
    case lydianDominant = "Lydian Dominant"
    case altered = "Altered"
    case dominantBebop = "Dominant Bebop"

    var displayName: String {
        switch self {
        case .pentatonic: return "Major Pentatonic"
        case .blues: return "Minor Blues"
        default: return rawValue
        }
    }

    var intervals: [Int] {
        switch self {
        case .major:          return [0, 2, 4, 5, 7, 9, 11]
        case .minor:          return [0, 2, 3, 5, 7, 8, 10]
        case .dorian:         return [0, 2, 3, 5, 7, 9, 10]
        case .pentatonic:     return [0, 2, 4, 7, 9]
        case .blues:          return [0, 3, 5, 6, 7, 10]
        case .harmonicMinor:  return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor:   return [0, 2, 3, 5, 7, 9, 11]
        case .phrygian:       return [0, 1, 3, 5, 7, 8, 10]
        case .lydian:         return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian:     return [0, 2, 4, 5, 7, 9, 10]
        case .locrian:        return [0, 1, 3, 5, 6, 8, 10]
        case .wholeTone:      return [0, 2, 4, 6, 8, 10]
        case .chromatic:      return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        case .hungarianMinor: return [0, 2, 3, 6, 7, 8, 11]
        case .hirajoshi:      return [0, 2, 3, 7, 8]
        case .minorPentatonic: return [0, 3, 5, 7, 10]
        case .majorBlues: return [0, 2, 3, 4, 7, 9]
        case .phrygianDominant: return [0, 1, 4, 5, 7, 8, 10]
        case .diminished: return [0, 1, 3, 4, 6, 7, 9, 10]
        case .harmonicMajor: return [0, 2, 4, 5, 7, 8, 11]
        case .lydianDominant: return [0, 2, 4, 6, 7, 9, 10]
        case .altered: return [0, 1, 3, 4, 6, 8, 10]
        case .dominantBebop: return [0, 2, 4, 5, 7, 9, 10, 11]
        }
    }

    var isPremium: Bool {
        switch self {
        case .major, .minor, .dorian, .pentatonic, .blues: return false
        default: return true
        }
    }

}

struct CustomScale: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let intervals: [Int]

    init?(id: UUID = UUID(), name: String, intervals: [Int]) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.unicodeScalars.count <= 40,
              !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              (3...12).contains(intervals.count), intervals.first == 0,
              intervals == intervals.sorted(), intervals.last.map({ $0 < 12 }) == true,
              Set(intervals).count == intervals.count else { return nil }
        self.id = id
        self.name = name
        self.intervals = intervals
    }

    init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let id = try fields.decode(UUID.self, forKey: .id)
        let name = try fields.decode(String.self, forKey: .name)
        let intervals = try fields.decode([Int].self, forKey: .intervals)
        guard let scale = Self(id: id, name: name, intervals: intervals), name == scale.name else {
            throw DecodingError.dataCorruptedError(forKey: .intervals, in: fields, debugDescription: "Invalid custom scale")
        }
        self = scale
    }
}

enum Scale: CaseIterable, Identifiable, Codable, Hashable {
    case builtIn(BuiltInScale)
    case custom(CustomScale)

    static let allCases = BuiltInScale.allCases.map(Scale.builtIn)
    static let major = Scale.builtIn(.major), minor = Scale.builtIn(.minor), dorian = Scale.builtIn(.dorian)
    static let pentatonic = Scale.builtIn(.pentatonic), blues = Scale.builtIn(.blues)
    static let harmonicMinor = Scale.builtIn(.harmonicMinor), melodicMinor = Scale.builtIn(.melodicMinor)
    static let phrygian = Scale.builtIn(.phrygian), lydian = Scale.builtIn(.lydian), mixolydian = Scale.builtIn(.mixolydian)
    static let locrian = Scale.builtIn(.locrian), wholeTone = Scale.builtIn(.wholeTone), chromatic = Scale.builtIn(.chromatic)
    static let hungarianMinor = Scale.builtIn(.hungarianMinor), hirajoshi = Scale.builtIn(.hirajoshi)
    static let minorPentatonic = Scale.builtIn(.minorPentatonic)

    init?(rawValue: String) {
        guard let scale = BuiltInScale(rawValue: rawValue) else { return nil }
        self = .builtIn(scale)
    }

    var rawValue: String {
        switch self {
        case let .builtIn(scale): return scale.rawValue
        case .custom: return "Custom"
        }
    }

    var id: String { customScale?.id.uuidString ?? rawValue }

    var customScale: CustomScale? {
        if case let .custom(scale) = self { return scale }
        return nil
    }

    var displayName: String {
        switch self {
        case let .builtIn(scale): return scale.displayName
        case let .custom(scale): return scale.name
        }
    }

    var intervals: [Int] {
        switch self {
        case let .builtIn(scale): return scale.intervals
        case let .custom(scale): return scale.intervals
        }
    }

    var isPremium: Bool {
        if case let .builtIn(scale) = self { return scale.isPremium }
        return true
    }

    var packId: String? { isPremium ? "pro" : nil }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let name = try? value.decode(String.self) {
            guard let scale = Scale(rawValue: name) else {
                throw DecodingError.dataCorruptedError(in: value, debugDescription: "Unknown built-in scale")
            }
            self = scale
        } else {
            self = .custom(try value.decode(CustomScale.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case let .builtIn(scale): try value.encode(scale.rawValue)
        case let .custom(scale): try value.encode(scale)
        }
    }
}

// MARK: - Circle of Fifths

let CIRCLE_OF_FIFTHS: [MusicKey] = [.C, .G, .D, .A, .E, .B, .Gb, .Db, .Ab, .Eb, .Bb, .F]

// MARK: - Note Generation

/// Generate MIDI notes in a given key+scale across octaves 2-5
func scaleNotes(key: MusicKey, scale: Scale) -> [Int] {
    var notes = [Int]()
    for octave in 2...5 {
        let base = (octave + 1) * 12 + key.semitone  // MIDI: C2=36, C3=48, etc.
        for interval in scale.intervals {
            let midi = base + interval
            if midi <= 84 { // cap at C6
                notes.append(midi)
            }
        }
    }
    return notes
}

/// Generate scale notes for a limited octave range (for grid mode)
func scaleNotes(key: MusicKey, scale: Scale, baseOctave: Int, octaveRange: Int) -> [Int] {
    var notes = [Int]()
    let endOctave = baseOctave + octaveRange - 1
    for octave in baseOctave...endOctave {
        let base = (octave + 1) * 12 + key.semitone
        for interval in scale.intervals {
            let midi = base + interval
            if midi <= 96 { // cap at C7
                notes.append(midi)
            }
        }
    }
    return notes
}

/// Generate chord (triad) from a scale degree (0-based)
func chordNotes(key: MusicKey, scale: Scale, degree: Int) -> [Int] {
    let scaleIntervals = scale.intervals
    let count = scaleIntervals.count
    guard count > 0 else { return [60] } // fallback to middle C
    let safeDegree = ((degree % count) + count) % count

    // Root in octave 3
    let root = 48 + key.semitone + scaleIntervals[safeDegree]
    // Third = 2 scale steps up
    let thirdDeg = (safeDegree + 2) % count
    var third = 48 + key.semitone + scaleIntervals[thirdDeg]
    if third <= root { third += 12 }
    // Fifth = 4 scale steps up
    let fifthDeg = (safeDegree + 4) % count
    var fifth = 48 + key.semitone + scaleIntervals[fifthDeg]
    while fifth <= third { fifth += 12 }

    return [root, third, fifth]
}

/// 7th chord from a scale degree — root + 3rd + 5th + 7th, all diatonic.
/// I → Imaj7, ii → ii⁷, V → V7, etc. for the major scale. Used by Scale mode
/// where the richer voicing is part of the point.
func chordNotesWithSeventh(key: MusicKey, scale: Scale, degree: Int) -> [Int] {
    let triad = chordNotes(key: key, scale: scale, degree: degree)
    let scaleIntervals = scale.intervals
    let count = scaleIntervals.count
    guard count > 0, let fifth = triad.last else { return triad }
    let safeDegree = ((degree % count) + count) % count
    // 7th = 6 scale steps up
    let seventhDeg = (safeDegree + 6) % count
    var seventh = 48 + key.semitone + scaleIntervals[seventhDeg]
    while seventh <= fifth { seventh += 12 }
    return triad + [seventh]
}

/// How the chord+melody wheels voice a chord. A player setting: each wheel
/// has a default (`defaultFor`), which the player can override.
enum ChordVoicing: String, Codable, CaseIterable, Equatable {
    case triad, seventh

    /// The Scale wheel plays 7ths; every other chord wheel plays triads.
    static func defaultFor(scaleWheel: Bool) -> ChordVoicing { scaleWheel ? .seventh : .triad }

    var displayName: String { self == .triad ? "Triads" : "7ths" }

    /// Appended to wheel chord names so the player can see 7th voicing.
    var chordNameSuffix: String { self == .seventh ? "⁷" : "" }

    func notes(key: MusicKey, scale: Scale, degree: Int) -> [Int] {
        switch self {
        case .triad: return chordNotes(key: key, scale: scale, degree: degree)
        case .seventh: return chordNotesWithSeventh(key: key, scale: scale, degree: degree)
        }
    }
}

/// One octave of scale notes starting at the given MIDI octave. Used by Scale
/// mode's melody side, where the 7 wedges fan one diatonic octave.
func scaleNotesOneOctave(key: MusicKey, scale: Scale, octave: Int = 4) -> [Int] {
    let base = (octave + 1) * 12 + key.semitone
    return scale.intervals.map { base + $0 }
}

// MARK: - Display Helpers

private let NOTE_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

func midiNoteName(_ midi: Int) -> String {
    let name = NOTE_NAMES[((midi % 12) + 12) % 12]
    let octave = midi / 12 - 1
    return "\(name)\(octave)"
}

/// Note letter without the octave number (e.g. "C", "Eb"). Used for compact
/// labels like the radial wheel's lettered keys.
func pitchClassName(_ midi: Int) -> String {
    NOTE_NAMES[((midi % 12) + 12) % 12]
}

/// Find the lane index (into scaleNotes) closest to a given MIDI value
func midiToLaneIndex(_ midi: Int, scaleNotes: [Int]) -> Int {
    guard !scaleNotes.isEmpty else { return 0 }
    var bestIdx = 0
    var bestDist = Int.max
    for (i, sn) in scaleNotes.enumerated() {
        let dist = abs(sn - midi)
        if dist < bestDist { bestDist = dist; bestIdx = i }
    }
    return bestIdx
}

/// Quantize a MIDI note to the nearest note in the scale
func quantizeToScale(_ midi: Int, scaleNotes: [Int]) -> Int {
    guard !scaleNotes.isEmpty else { return midi }
    return scaleNotes.min(by: { abs($0 - midi) < abs($1 - midi) }) ?? midi
}

/// Strudel note name (lowercase) from MIDI
func midiToStrudelNote(_ midi: Int) -> String {
    let names = ["c", "db", "d", "eb", "e", "f", "gb", "g", "ab", "a", "bb", "b"]
    let name = names[((midi % 12) + 12) % 12]
    let octave = midi / 12 - 1
    return "\(name)\(octave)"
}

/// Chord display name (e.g., "Cmaj", "Am", "Ddor")
func chordDisplayName(key: MusicKey, scale: Scale, degree: Int) -> String {
    let scaleIntervals = scale.intervals
    let count = scaleIntervals.count
    let safeDegree = ((degree % count) + count) % count

    let rootSemitone = (key.semitone + scaleIntervals[safeDegree]) % 12
    let rootName = NOTE_NAMES[rootSemitone]

    // Determine chord quality from interval between root-third and root-fifth
    let thirdDeg = (safeDegree + 2) % count
    let fifthDeg = (safeDegree + 4) % count

    let thirdInterval = ((scaleIntervals[thirdDeg] - scaleIntervals[safeDegree]) % 12 + 12) % 12
    let fifthInterval = ((scaleIntervals[fifthDeg] - scaleIntervals[safeDegree]) % 12 + 12) % 12

    let quality: String
    if thirdInterval == 4 && fifthInterval == 7 {
        quality = "maj"
    } else if thirdInterval == 3 && fifthInterval == 7 {
        quality = "min"
    } else if thirdInterval == 3 && fifthInterval == 6 {
        quality = "dim"
    } else if thirdInterval == 4 && fifthInterval == 8 {
        quality = "aug"
    } else {
        quality = ""
    }

    return "\(rootName)\(quality)"
}
