import Foundation

@MainActor
final class SongPlayer: ObservableObject {
    @Published var currentSong: Song?
    @Published var isPlaying = false
    @Published var songTime: Double = 0
    @Published var score: Int = 0
    @Published var combo: Int = 0
    @Published var maxCombo: Int = 0
    @Published var totalNotes: Int = 0
    @Published var hitNotes: Int = 0

    // Track which notes have been hit
    private var hitNoteIndices = Set<Int>()

    // Timing window for a "hit" (seconds)
    let hitWindow: Double = 0.3

    func startSong(_ song: Song) {
        currentSong = song
        isPlaying = true
        songTime = -2.0 // 2 second lead-in
        score = 0
        combo = 0
        maxCombo = 0
        totalNotes = song.notes.count
        hitNotes = 0
        hitNoteIndices.removeAll()
    }

    func stopSong() {
        isPlaying = false
        currentSong = nil
    }

    /// Called at 60fps to advance song time
    func tick(deltaTime: Double) {
        guard isPlaying, let song = currentSong else { return }
        songTime += deltaTime

        // Song ended?
        if let lastNote = song.notes.last, songTime > lastNote.time + lastNote.duration + 2 {
            isPlaying = false
        }
    }

    /// Check if a played MIDI note matches any upcoming song note
    func checkHit(midi: Int) -> Bool {
        guard let song = currentSong else { return false }

        for (idx, note) in song.notes.enumerated() {
            if hitNoteIndices.contains(idx) { continue }

            // Check if note is within hit window
            let diff = abs(songTime - note.time)
            if diff <= hitWindow && note.midi == midi {
                hitNoteIndices.insert(idx)
                hitNotes += 1
                combo += 1
                maxCombo = max(maxCombo, combo)

                // Score based on accuracy
                let accuracy = 1.0 - (diff / hitWindow)
                let points = Int(accuracy * 100) * max(1, combo)
                score += points

                return true
            }
        }

        // Missed — break combo
        combo = 0
        return false
    }

    /// Get notes that should be visible (falling toward the hit line)
    func visibleNotes(lookAhead: Double = 3.0) -> [(note: SongNote, index: Int, isHit: Bool)] {
        guard let song = currentSong else { return [] }

        return song.notes.enumerated().compactMap { idx, note in
            let relativeTime = note.time - songTime
            if relativeTime > -0.5 && relativeTime < lookAhead {
                return (note: note, index: idx, isHit: hitNoteIndices.contains(idx))
            }
            return nil
        }
    }

    /// Completion percentage
    var progress: Double {
        guard totalNotes > 0 else { return 0 }
        return Double(hitNotes) / Double(totalNotes)
    }

    /// Grade based on accuracy
    var grade: String {
        let pct = progress
        if pct >= 0.95 { return "S" }
        if pct >= 0.9 { return "A" }
        if pct >= 0.8 { return "B" }
        if pct >= 0.7 { return "C" }
        if pct >= 0.5 { return "D" }
        return "F"
    }
}
