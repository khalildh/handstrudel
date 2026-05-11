import Foundation

// MARK: - Learn Mode Manager

final class LearnModeManager {
    // Song state
    private(set) var currentSong: LearnSong?
    private var resolvedNotes: [LearnNote] = []
    private var songStartTime: Double = 0
    private var songBPM: Double = 120
    private(set) var songComplete = false

    // Scrolling config
    let scrollLeadBeats: Double = 4.0      // notes appear 4 beats ahead
    let hitLineX: Double = 0.25            // 25% from left edge
    let countdownBeats: Double = 4.0       // 4 beats of countdown before first note

    // Countdown state
    private(set) var countdownValue: Int = 0  // 3, 2, 1, 0 (0 = playing)
    private(set) var isCountingDown = false

    // Hit detection windows (seconds)
    let hitWindowPerfect: Double = 0.100
    let hitWindowGood: Double = 0.200

    // Tracking
    private var consumedNoteIds = Set<UUID>()
    private var firstTick = true

    // Score
    private(set) var score = LearnScore()

    // Visual output (read by UI)
    private(set) var visibleNotes: [VisibleNote] = []
    private(set) var hitEffects: [HitEffect] = []

    struct VisibleNote: Identifiable {
        let id: UUID
        let laneIndex: Int
        let xFraction: Double       // 0=left edge, 1=right edge
        let widthFraction: Double   // note visual width
        let state: NoteState
    }

    enum NoteState {
        case upcoming, active, hitPerfect, hitGood, missed
    }

    struct HitEffect: Identifiable {
        let id: UUID
        let laneIndex: Int
        let type: NoteState
        let timestamp: Double
    }

    // Track final state of consumed notes for display
    private var consumedStates: [UUID: NoteState] = [:]

    // MARK: - Load Song

    func loadSong(_ song: LearnSong, scaleNotes: [Int], bpm: Double) {
        currentSong = song
        resolvedNotes = song.resolve(scaleNotes: scaleNotes)
        songBPM = bpm
        songStartTime = 0
        firstTick = true
        songComplete = false
        isCountingDown = true
        countdownValue = 3
        consumedNoteIds.removeAll()
        consumedStates.removeAll()
        score = LearnScore()
        visibleNotes.removeAll()
        hitEffects.removeAll()
    }

    // MARK: - Tick

    /// Called every frame. Returns list of notes that were just hit (midi + laneIndex) so caller can play sounds.
    func tick(
        elapsed: Double,
        leftLane: Int?,
        rightLane: Int?,
        leftPinching: Bool,
        rightPinching: Bool
    ) -> [(midi: Int, laneIndex: Int)] {
        guard currentSong != nil, !resolvedNotes.isEmpty else { return [] }

        // Set songStartTime on first call (with countdown offset)
        if firstTick {
            songStartTime = elapsed + countdownBeats * (60.0 / songBPM)
            firstTick = false
        }

        let secondsPerBeat = 60.0 / songBPM
        let currentBeat = (elapsed - songStartTime) / secondsPerBeat

        // Handle countdown
        if currentBeat < 0 {
            let beatsUntilStart = -currentBeat
            countdownValue = max(0, min(3, Int(ceil(beatsUntilStart))))
            isCountingDown = true
            // Still show upcoming notes scrolling in during countdown
        } else if isCountingDown {
            isCountingDown = false
            countdownValue = 0
        }

        // Visible beat range: 1 beat behind hit line to scrollLeadBeats ahead
        let visibleStart = currentBeat - 1
        let visibleEnd = currentBeat + scrollLeadBeats

        // Build visible notes
        var newVisible: [VisibleNote] = []
        for note in resolvedNotes {
            let noteEndBeat = note.startBeat + note.durationBeats
            // Skip notes entirely outside visible range
            guard noteEndBeat >= visibleStart && note.startBeat <= visibleEnd else { continue }

            let xFraction = hitLineX + (note.startBeat - currentBeat) / scrollLeadBeats * (1.0 - hitLineX)
            let widthFraction = max(0.03, note.durationBeats / scrollLeadBeats * (1.0 - hitLineX))

            let state: NoteState
            if let consumedState = consumedStates[note.id] {
                state = consumedState
            } else if xFraction <= hitLineX {
                state = .active
            } else {
                state = .upcoming
            }

            newVisible.append(VisibleNote(
                id: note.id,
                laneIndex: note.laneIndex,
                xFraction: xFraction,
                widthFraction: widthFraction,
                state: state
            ))
        }
        visibleNotes = newVisible

        // Hit detection
        var justHit: [(midi: Int, laneIndex: Int)] = []

        for note in resolvedNotes {
            guard !consumedNoteIds.contains(note.id) else { continue }

            let noteTime = songStartTime + note.startBeat * secondsPerBeat
            let timeDelta = abs(elapsed - noteTime)

            // Check if within hit window
            if timeDelta <= hitWindowGood {
                // Check if either hand is pinching in the correct lane
                let leftMatch = leftPinching && leftLane == note.laneIndex
                let rightMatch = rightPinching && rightLane == note.laneIndex

                if leftMatch || rightMatch {
                    consumedNoteIds.insert(note.id)

                    if timeDelta <= hitWindowPerfect {
                        consumedStates[note.id] = .hitPerfect
                        score.perfectHits += 1
                        hitEffects.append(HitEffect(
                            id: UUID(),
                            laneIndex: note.laneIndex,
                            type: .hitPerfect,
                            timestamp: elapsed
                        ))
                    } else {
                        consumedStates[note.id] = .hitGood
                        score.goodHits += 1
                        hitEffects.append(HitEffect(
                            id: UUID(),
                            laneIndex: note.laneIndex,
                            type: .hitGood,
                            timestamp: elapsed
                        ))
                    }

                    score.currentStreak += 1
                    if score.currentStreak > score.bestStreak {
                        score.bestStreak = score.currentStreak
                    }

                    justHit.append((midi: note.midi, laneIndex: note.laneIndex))
                }
            }

            // Miss detection: note has passed beyond the hit window
            if !consumedNoteIds.contains(note.id) && elapsed > noteTime + hitWindowGood {
                consumedNoteIds.insert(note.id)
                consumedStates[note.id] = .missed
                score.misses += 1
                score.currentStreak = 0
                hitEffects.append(HitEffect(
                    id: UUID(),
                    laneIndex: note.laneIndex,
                    type: .missed,
                    timestamp: elapsed
                ))
            }
        }

        // Expire old hit effects (> 0.5s old)
        hitEffects.removeAll { elapsed - $0.timestamp > 0.5 }

        // Check song complete: all notes consumed
        if consumedNoteIds.count >= resolvedNotes.count {
            songComplete = true
        }

        return justHit
    }

    // MARK: - Reset

    func reset() {
        currentSong = nil
        resolvedNotes.removeAll()
        songStartTime = 0
        songBPM = 120
        firstTick = true
        songComplete = false
        consumedNoteIds.removeAll()
        consumedStates.removeAll()
        score = LearnScore()
        visibleNotes.removeAll()
        hitEffects.removeAll()
    }
}
