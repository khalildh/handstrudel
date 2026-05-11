import Foundation

// MARK: - Degree Note (scale-relative pitch)

struct LearnDegreeNote {
    let degree: Int          // 0-based index into scaleNotes array
    let startBeat: Double    // beat offset from song start
    let durationBeats: Double
}

// MARK: - Resolved Note (absolute MIDI pitch)

struct LearnNote: Identifiable {
    let id: UUID
    let midi: Int
    let laneIndex: Int       // index into scaleNotes array
    let startBeat: Double
    let durationBeats: Double
}

// MARK: - Score

struct LearnScore {
    var perfectHits: Int = 0
    var goodHits: Int = 0
    var misses: Int = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0

    var totalNotes: Int { perfectHits + goodHits + misses }
    var accuracy: Double {
        guard totalNotes > 0 else { return 0 }
        return Double(perfectHits + goodHits) / Double(totalNotes)
    }
}

// MARK: - Song

struct LearnSong: Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let bpm: Double
    let degreeNotes: [LearnDegreeNote]
    let category: SongCategory
    let suggestedScale: Scale
    let suggestedKey: MusicKey

    enum SongCategory: String, CaseIterable {
        case melody = "Melodies"
        case practice = "Practice"
        case imported = "Imported"
    }

    init(name: String, emoji: String, bpm: Double, degreeNotes: [LearnDegreeNote], category: SongCategory = .melody, suggestedScale: Scale = .major, suggestedKey: MusicKey = .C) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.bpm = bpm
        self.degreeNotes = degreeNotes
        self.category = category
        self.suggestedScale = suggestedScale
        self.suggestedKey = suggestedKey
    }

    /// Create a longer version by repeating the melody
    func repeated(_ times: Int) -> LearnSong {
        var allNotes = [LearnDegreeNote]()
        let lastBeat = degreeNotes.last.map { $0.startBeat + $0.durationBeats } ?? 0
        for rep in 0..<times {
            let offset = Double(rep) * (lastBeat + 1) // 1 beat gap between repeats
            for note in degreeNotes {
                allNotes.append(LearnDegreeNote(
                    degree: note.degree,
                    startBeat: note.startBeat + offset,
                    durationBeats: note.durationBeats
                ))
            }
        }
        return LearnSong(name: name, emoji: emoji, bpm: bpm, degreeNotes: allNotes, category: category, suggestedScale: suggestedScale, suggestedKey: suggestedKey)
    }

    /// Resolve degree notes to actual MIDI using current scale
    func resolve(scaleNotes: [Int]) -> [LearnNote] {
        degreeNotes.map { dn in
            let clampedDegree = max(0, min(scaleNotes.count - 1, dn.degree))
            return LearnNote(
                id: UUID(),
                midi: scaleNotes[clampedDegree],
                laneIndex: clampedDegree,
                startBeat: dn.startBeat,
                durationBeats: dn.durationBeats
            )
        }
    }
}

// MARK: - Pattern Generators

extension LearnSong {
    /// Ascending scale from degree 0 upward
    static func ascending(noteCount: Int, bpm: Double = 120) -> LearnSong {
        let notes = (0..<noteCount).map { i in
            LearnDegreeNote(degree: i, startBeat: Double(i), durationBeats: 1)
        }
        return LearnSong(name: "Ascending \(noteCount)", emoji: "\u{2B06}\u{FE0F}", bpm: bpm, degreeNotes: notes, category: .practice)
    }

    /// Descending scale from highest degree downward
    static func descending(noteCount: Int, bpm: Double = 120) -> LearnSong {
        let notes = (0..<noteCount).map { i in
            LearnDegreeNote(degree: noteCount - 1 - i, startBeat: Double(i), durationBeats: 1)
        }
        return LearnSong(name: "Descending \(noteCount)", emoji: "\u{2B07}\u{FE0F}", bpm: bpm, degreeNotes: notes, category: .practice)
    }

    /// Ascending then descending (mountain shape)
    static func ascendingDescending(noteCount: Int, bpm: Double = 120) -> LearnSong {
        let peak = noteCount - 1
        var notes: [LearnDegreeNote] = []
        // Ascending
        for i in 0...peak {
            notes.append(LearnDegreeNote(degree: i, startBeat: Double(notes.count), durationBeats: 1))
        }
        // Descending (skip the peak to avoid repeat)
        for i in stride(from: peak - 1, through: 0, by: -1) {
            notes.append(LearnDegreeNote(degree: i, startBeat: Double(notes.count), durationBeats: 1))
        }
        return LearnSong(name: "Up & Down \(noteCount)", emoji: "\u{26F0}\u{FE0F}", bpm: bpm, degreeNotes: notes, category: .practice)
    }

    /// Arpeggio pattern: root, 2nd, 4th degrees (triad feel) across range
    static func arpeggio(noteCount: Int, bpm: Double = 120) -> LearnSong {
        let arpeggioSteps = [0, 2, 4, 7, 9, 11, 14]
        var notes: [LearnDegreeNote] = []
        for i in 0..<noteCount {
            let degree = arpeggioSteps[i % arpeggioSteps.count] + (i / arpeggioSteps.count) * 7
            notes.append(LearnDegreeNote(degree: degree, startBeat: Double(i), durationBeats: 1))
        }
        return LearnSong(name: "Arpeggio \(noteCount)", emoji: "\u{1F3B6}", bpm: bpm, degreeNotes: notes, category: .practice)
    }

    /// Random degrees within the given note count range
    static func random(noteCount: Int, bpm: Double = 120) -> LearnSong {
        let notes = (0..<noteCount).map { i in
            LearnDegreeNote(degree: Int.random(in: 0..<noteCount), startBeat: Double(i), durationBeats: 1)
        }
        return LearnSong(name: "Random \(noteCount)", emoji: "\u{1F3B2}", bpm: bpm, degreeNotes: notes, category: .practice)
    }
}

// MARK: - Bundled Melodies

/// Helper to build a note array from (degree, durationBeats) pairs with auto-advancing startBeat
private func buildNotes(_ pairs: [(Int, Double)]) -> [LearnDegreeNote] {
    var beat: Double = 0
    return pairs.map { (degree, dur) in
        let note = LearnDegreeNote(degree: degree, startBeat: beat, durationBeats: dur)
        beat += dur
        return note
    }
}

let BUNDLED_SONGS: [LearnSong] = [
    // 1. Twinkle Twinkle Little Star
    LearnSong(
        name: "Twinkle Twinkle",
        emoji: "\u{2B50}",
        bpm: 100,
        degreeNotes: buildNotes([
            (0, 1), (0, 1), (4, 1), (4, 1), (5, 1), (5, 1), (4, 2),
            (3, 1), (3, 1), (2, 1), (2, 1), (1, 1), (1, 1), (0, 2),
        ]),
        suggestedScale: .major, suggestedKey: .C
    ).repeated(3),

    // 2. Ode to Joy
    LearnSong(
        name: "Ode to Joy",
        emoji: "\u{1F3B5}",
        bpm: 108,
        degreeNotes: buildNotes([
            (2, 1), (2, 1), (3, 1), (4, 1), (4, 1), (3, 1), (2, 1), (1, 1),
            (0, 1), (0, 1), (1, 1), (2, 1), (2, 1.5), (1, 0.5), (1, 2),
        ]),
        suggestedScale: .major, suggestedKey: .C
    ).repeated(3),

    // 3. Mary Had a Little Lamb
    LearnSong(
        name: "Mary Had a Little Lamb",
        emoji: "\u{1F411}",
        bpm: 110,
        degreeNotes: buildNotes([
            (2, 1), (1, 1), (0, 1), (1, 1), (2, 1), (2, 1), (2, 2),
            (1, 1), (1, 1), (1, 2),
            (2, 1), (4, 1), (4, 2),
        ]),
        suggestedScale: .major, suggestedKey: .C
    ).repeated(4),

    // 4. When the Saints
    LearnSong(
        name: "When the Saints",
        emoji: "\u{1F3BA}",
        bpm: 112,
        degreeNotes: buildNotes([
            (0, 1), (2, 1), (3, 1), (4, 2),
            (0, 1), (2, 1), (3, 1), (4, 2),
            (0, 1), (2, 1), (3, 1), (4, 1), (2, 1), (0, 1), (2, 1), (1, 2),
        ]),
        suggestedScale: .major, suggestedKey: .C
    ).repeated(3),

    // 5. Amazing Grace
    LearnSong(
        name: "Amazing Grace",
        emoji: "\u{1F54A}\u{FE0F}",
        bpm: 80,
        degreeNotes: buildNotes([
            (4, 1),
            (7, 2), (9, 1), (7, 2), (9, 2), (7, 2),
            (5, 2), (4, 2), (2, 2), (4, 1), (4, 2),
        ]),
        suggestedScale: .major, suggestedKey: .C
    ).repeated(3),

    // 6. Frere Jacques
    LearnSong(
        name: "Frere Jacques",
        emoji: "\u{1F514}",
        bpm: 120,
        degreeNotes: buildNotes([
            (0, 1), (1, 1), (2, 1), (0, 1),
            (0, 1), (1, 1), (2, 1), (0, 1),
            (2, 1), (3, 1), (4, 2),
            (2, 1), (3, 1), (4, 2),
        ]),
        suggestedScale: .major, suggestedKey: .C
    ).repeated(3),

    // 7. Jingle Bells
    LearnSong(
        name: "Jingle Bells",
        emoji: "\u{1F384}",
        bpm: 130,
        degreeNotes: buildNotes([
            (2, 1), (2, 1), (2, 2),
            (2, 1), (2, 1), (2, 2),
            (2, 1), (4, 1), (0, 1.5), (1, 0.5), (2, 2),
        ]),
        suggestedScale: .major, suggestedKey: .C
    ).repeated(3),

    // 8. Scarborough Fair
    LearnSong(
        name: "Scarborough Fair",
        emoji: "\u{1F33F}",
        bpm: 90,
        degreeNotes: buildNotes([
            (5, 2), (5, 1), (5, 1), (2, 2),
            (5, 1), (6, 1), (5, 2),
            (4, 2), (2, 2),
        ]),
        suggestedScale: .minor, suggestedKey: .A
    ).repeated(4),
]
