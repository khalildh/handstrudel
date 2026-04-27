import Foundation

// MARK: - Keys

enum MusicKey: String, CaseIterable, Identifiable {
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

enum Scale: String, CaseIterable, Identifiable {
    case major = "Major"
    case minor = "Minor"
    case dorian = "Dorian"
    case pentatonic = "Pentatonic"
    case blues = "Blues"
    var id: String { rawValue }
    var intervals: [Int] {
        switch self {
        case .major:      return [0, 2, 4, 5, 7, 9, 11]
        case .minor:      return [0, 2, 3, 5, 7, 8, 10]
        case .dorian:     return [0, 2, 3, 5, 7, 9, 10]
        case .pentatonic: return [0, 2, 4, 7, 9]
        case .blues:      return [0, 3, 5, 6, 7, 10]
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

/// Generate chord (triad) from a scale degree (0-based)
func chordNotes(key: MusicKey, scale: Scale, degree: Int) -> [Int] {
    let scaleIntervals = scale.intervals
    let count = scaleIntervals.count
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
    if fifth <= third { fifth += 12 }

    return [root, third, fifth]
}

// MARK: - Display Helpers

private let NOTE_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

func midiNoteName(_ midi: Int) -> String {
    let name = NOTE_NAMES[((midi % 12) + 12) % 12]
    let octave = midi / 12 - 1
    return "\(name)\(octave)"
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
