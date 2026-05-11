import XCTest
@testable import HandStrudel

final class LearnModeManagerTests: XCTestCase {

    // C major scale notes: C4=60, D4=62, E4=64, F4=65, G4=67, A4=69, B4=71
    private let cMajorScale = [60, 62, 64, 65, 67, 69, 71]

    private func makeSimpleSong() -> LearnSong {
        LearnSong(name: "Test", emoji: "T", bpm: 120, degreeNotes: [
            LearnDegreeNote(degree: 0, startBeat: 0, durationBeats: 1),
            LearnDegreeNote(degree: 2, startBeat: 1, durationBeats: 1),
            LearnDegreeNote(degree: 4, startBeat: 2, durationBeats: 1),
        ])
    }

    /// At 120 BPM: 1 beat = 0.5s.
    /// countdownBeats = 4, so songStartTime = firstTickElapsed + 4 * 0.5 = firstTickElapsed + 2.0.
    /// If first tick at elapsed=0, songStartTime=2.0.
    /// Note 0 (beat 0) is at elapsed 2.0, note 1 (beat 1) at 2.5, note 2 (beat 2) at 3.0.
    private let bpm: Double = 120
    private let secondsPerBeat: Double = 0.5  // 60 / 120

    // With first tick at elapsed=0, songStartTime = 0 + 4 * 0.5 = 2.0
    private let songStart: Double = 2.0

    // MARK: - 1. loadSong

    func testLoadSong_setsSongAndResolvesNotes() {
        let manager = LearnModeManager()
        let song = makeSimpleSong()
        manager.loadSong(song, scaleNotes: cMajorScale, bpm: bpm)

        XCTAssertNotNil(manager.currentSong)
        XCTAssertEqual(manager.currentSong?.name, "Test")
    }

    func testLoadSong_resetsScore() {
        let manager = LearnModeManager()
        let song = makeSimpleSong()
        manager.loadSong(song, scaleNotes: cMajorScale, bpm: bpm)

        XCTAssertEqual(manager.score.perfectHits, 0)
        XCTAssertEqual(manager.score.goodHits, 0)
        XCTAssertEqual(manager.score.misses, 0)
        XCTAssertEqual(manager.score.currentStreak, 0)
        XCTAssertEqual(manager.score.bestStreak, 0)
    }

    func testLoadSong_setsCountdown() {
        let manager = LearnModeManager()
        let song = makeSimpleSong()
        manager.loadSong(song, scaleNotes: cMajorScale, bpm: bpm)

        XCTAssertTrue(manager.isCountingDown)
        XCTAssertEqual(manager.countdownValue, 3)
    }

    func testLoadSong_clearsSongComplete() {
        let manager = LearnModeManager()
        let song = makeSimpleSong()
        manager.loadSong(song, scaleNotes: cMajorScale, bpm: bpm)

        XCTAssertFalse(manager.songComplete)
    }

    func testLoadSong_clearsVisibleNotesAndEffects() {
        let manager = LearnModeManager()
        let song = makeSimpleSong()
        manager.loadSong(song, scaleNotes: cMajorScale, bpm: bpm)

        XCTAssertTrue(manager.visibleNotes.isEmpty)
        XCTAssertTrue(manager.hitEffects.isEmpty)
    }

    // MARK: - 2. Tick Countdown

    func testTickCountdown_initialValueIs3() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        // First tick at elapsed=0 sets songStartTime=2.0, currentBeat = (0-2)/0.5 = -4
        // beatsUntilStart = 4, ceil(4) = 4, min(3,4) = 3
        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        XCTAssertTrue(manager.isCountingDown)
        XCTAssertEqual(manager.countdownValue, 3)
    }

    func testTickCountdown_countsDown321() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        // First tick at elapsed=0 => songStartTime=2.0
        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        XCTAssertEqual(manager.countdownValue, 3)

        // elapsed=0.5 => currentBeat = (0.5 - 2.0) / 0.5 = -3.0, beatsUntilStart=3.0, ceil=3, min(3,3)=3
        _ = manager.tick(elapsed: 0.5, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        XCTAssertEqual(manager.countdownValue, 3)

        // elapsed=0.6 => currentBeat = (0.6 - 2.0) / 0.5 = -2.8, beatsUntilStart=2.8, ceil=3, min(3,3)=3
        _ = manager.tick(elapsed: 0.6, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        XCTAssertEqual(manager.countdownValue, 3)

        // elapsed=1.0 => currentBeat = -2.0, beatsUntilStart=2.0, ceil=2, min(3,2)=2
        _ = manager.tick(elapsed: 1.0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        XCTAssertEqual(manager.countdownValue, 2)

        // elapsed=1.5 => currentBeat = -1.0, beatsUntilStart=1.0, ceil=1, min(3,1)=1
        _ = manager.tick(elapsed: 1.5, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        XCTAssertEqual(manager.countdownValue, 1)

        // elapsed=2.0 => currentBeat = 0.0, no longer negative => countdown ends
        _ = manager.tick(elapsed: 2.0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        XCTAssertFalse(manager.isCountingDown)
        XCTAssertEqual(manager.countdownValue, 0)
    }

    // MARK: - 3. Visible Notes

    func testTickVisibleNotes_notesAppearWithinScrollWindow() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        // First tick at elapsed=0
        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // currentBeat = (0 - 2.0) / 0.5 = -4.0
        // visibleStart = -4 - 1 = -5, visibleEnd = -4 + 4 = 0
        // Note 0 at beat 0 (endBeat=1): 1 >= -5 && 0 <= 0 => visible
        // Note 1 at beat 1 (endBeat=2): 2 >= -5 && 1 <= 0 => NOT visible (1 > 0)
        // Note 2 at beat 2 (endBeat=3): 3 >= -5 && 2 <= 0 => NOT visible (2 > 0)
        XCTAssertEqual(manager.visibleNotes.count, 1, "Only note at beat 0 should be visible at start")
    }

    func testTickVisibleNotes_moreNotesAppearAsTimeAdvances() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // elapsed=0.5 => currentBeat = -3.0, visibleEnd = -3 + 4 = 1
        // Note 0 at beat 0: endBeat=1, 1 >= -4 && 0 <= 1 => visible
        // Note 1 at beat 1: endBeat=2, 2 >= -4 && 1 <= 1 => visible
        // Note 2 at beat 2: endBeat=3, 3 >= -4 && 2 <= 1 => NOT visible
        _ = manager.tick(elapsed: 0.5, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        XCTAssertEqual(manager.visibleNotes.count, 2)
    }

    func testTickVisibleNotes_allNotesVisibleWhenClose() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // elapsed=1.0 => currentBeat = -2.0, visibleEnd = -2 + 4 = 2
        // All notes (beat 0, 1, 2) are within range
        _ = manager.tick(elapsed: 1.0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        XCTAssertEqual(manager.visibleNotes.count, 3)
    }

    func testTickVisibleNotes_notesHaveCorrectLaneIndex() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Show all 3 notes
        _ = manager.tick(elapsed: 1.0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        let lanes = manager.visibleNotes.map { $0.laneIndex }.sorted()
        // degree 0 => laneIndex 0, degree 2 => laneIndex 2, degree 4 => laneIndex 4
        XCTAssertEqual(lanes, [0, 2, 4])
    }

    // MARK: - 4. Hit Detection: Perfect

    func testHitDetection_perfectHit_withinPerfectWindow() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        // First tick to initialize songStartTime
        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Note 0 (degree 0, laneIndex 0) is at elapsed=2.0 (songStart + 0 * 0.5)
        // Pinch in lane 0 at exactly elapsed=2.0 => timeDelta = 0 => perfect
        let hits = manager.tick(elapsed: 2.0, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)

        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].midi, 60, "Degree 0 in C major = C4 = MIDI 60")
        XCTAssertEqual(hits[0].laneIndex, 0)
        XCTAssertEqual(manager.score.perfectHits, 1)
        XCTAssertEqual(manager.score.goodHits, 0)
    }

    func testHitDetection_perfectHit_within50ms() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Note 0 at elapsed=2.0. Hit at elapsed=2.05 => timeDelta=0.05 < 0.1 => perfect
        let hits = manager.tick(elapsed: 2.05, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)

        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(manager.score.perfectHits, 1)
    }

    func testHitDetection_perfectHit_atBoundary100ms() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Note 0 at elapsed=2.0. Hit at elapsed=2.099 => timeDelta ~0.099 < 0.1 => perfect
        // (Using 2.099 instead of 2.1 to avoid floating-point rounding past the boundary)
        let hits = manager.tick(elapsed: 2.099, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)

        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(manager.score.perfectHits, 1, "timeDelta just under 0.1s should be perfect")
    }

    func testHitDetection_perfectHit_withRightHand() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Right hand pinching in correct lane
        let hits = manager.tick(elapsed: 2.0, leftLane: nil, rightLane: 0, leftPinching: false, rightPinching: true)

        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(manager.score.perfectHits, 1)
    }

    // MARK: - 5. Hit Detection: Good

    func testHitDetection_goodHit_between100and200ms() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Note 0 at elapsed=2.0. Hit at elapsed=2.15 => timeDelta=0.15 > 0.1 but <= 0.2 => good
        let hits = manager.tick(elapsed: 2.15, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)

        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(manager.score.goodHits, 1)
        XCTAssertEqual(manager.score.perfectHits, 0)
    }

    func testHitDetection_goodHit_atBoundary200ms() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Note 0 at elapsed=2.0. Hit at elapsed=2.199 => timeDelta ~0.199 < 0.2 => good
        // (Using 2.199 instead of 2.2 to avoid floating-point rounding past the boundary)
        let hits = manager.tick(elapsed: 2.199, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)

        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(manager.score.goodHits, 1, "timeDelta just under 0.2s should be good")
    }

    func testHitDetection_goodHit_earlyPinch() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Note 0 at elapsed=2.0. Hit at elapsed=1.85 => timeDelta=0.15 => good (early hit)
        let hits = manager.tick(elapsed: 1.85, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)

        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(manager.score.goodHits, 1)
    }

    // MARK: - 6. Hit Detection: Miss

    func testHitDetection_miss_notePassesWithoutPinch() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Note 0 at elapsed=2.0. Tick past hit window without pinching.
        // Miss occurs when elapsed > noteTime + hitWindowGood = 2.0 + 0.2 = 2.2
        _ = manager.tick(elapsed: 2.21, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        XCTAssertEqual(manager.score.misses, 1)
        XCTAssertEqual(manager.score.currentStreak, 0)
    }

    func testHitDetection_miss_resetsStreak() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Hit note 0 perfectly
        _ = manager.tick(elapsed: 2.0, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)
        XCTAssertEqual(manager.score.currentStreak, 1)

        // Miss note 1 (at elapsed=2.5). Tick past its window.
        _ = manager.tick(elapsed: 2.71, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        XCTAssertEqual(manager.score.misses, 1)
        XCTAssertEqual(manager.score.currentStreak, 0, "Miss should reset streak")
    }

    // MARK: - 7. Hit Detection: Wrong Lane

    func testHitDetection_wrongLane_noHit() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Note 0 has laneIndex=0. Pinch in lane 3 instead.
        let hits = manager.tick(elapsed: 2.0, leftLane: 3, rightLane: nil, leftPinching: true, rightPinching: false)

        XCTAssertTrue(hits.isEmpty, "Pinching in wrong lane should not hit the note")
        XCTAssertEqual(manager.score.perfectHits, 0)
        XCTAssertEqual(manager.score.goodHits, 0)
    }

    func testHitDetection_wrongLane_noteEventuallyMisses() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Pinch in wrong lane at note time
        _ = manager.tick(elapsed: 2.0, leftLane: 5, rightLane: nil, leftPinching: true, rightPinching: false)

        // Note passes the hit window => miss
        _ = manager.tick(elapsed: 2.21, leftLane: 5, rightLane: nil, leftPinching: true, rightPinching: false)

        XCTAssertEqual(manager.score.misses, 1)
    }

    // MARK: - 8. Streak Tracking

    func testStreak_consecutiveHitsIncrement() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Hit note 0 (lane 0, beat 0 => elapsed=2.0)
        _ = manager.tick(elapsed: 2.0, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)
        XCTAssertEqual(manager.score.currentStreak, 1)

        // Hit note 1 (lane 2, beat 1 => elapsed=2.5)
        _ = manager.tick(elapsed: 2.5, leftLane: 2, rightLane: nil, leftPinching: true, rightPinching: false)
        XCTAssertEqual(manager.score.currentStreak, 2)

        // Hit note 2 (lane 4, beat 2 => elapsed=3.0)
        _ = manager.tick(elapsed: 3.0, leftLane: 4, rightLane: nil, leftPinching: true, rightPinching: false)
        XCTAssertEqual(manager.score.currentStreak, 3)
    }

    func testStreak_missResets_bestStreakPreserved() {
        let manager = LearnModeManager()
        let song = LearnSong(name: "Test", emoji: "T", bpm: 120, degreeNotes: [
            LearnDegreeNote(degree: 0, startBeat: 0, durationBeats: 1),
            LearnDegreeNote(degree: 2, startBeat: 1, durationBeats: 1),
            LearnDegreeNote(degree: 4, startBeat: 2, durationBeats: 1),
            LearnDegreeNote(degree: 0, startBeat: 3, durationBeats: 1),
        ])
        manager.loadSong(song, scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Hit note 0 and note 1
        _ = manager.tick(elapsed: 2.0, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)
        _ = manager.tick(elapsed: 2.5, leftLane: 2, rightLane: nil, leftPinching: true, rightPinching: false)
        XCTAssertEqual(manager.score.currentStreak, 2)
        XCTAssertEqual(manager.score.bestStreak, 2)

        // Miss note 2 (at beat 2 => elapsed=3.0)
        _ = manager.tick(elapsed: 3.21, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        XCTAssertEqual(manager.score.currentStreak, 0, "Miss should reset current streak")
        XCTAssertEqual(manager.score.bestStreak, 2, "Best streak should be preserved after miss")

        // Hit note 3 (at beat 3 => elapsed=3.5)
        _ = manager.tick(elapsed: 3.5, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)
        XCTAssertEqual(manager.score.currentStreak, 1)
        XCTAssertEqual(manager.score.bestStreak, 2, "Best streak stays at 2 since current is only 1")
    }

    // MARK: - 9. Song Complete

    func testSongComplete_allNotesConsumed() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        XCTAssertFalse(manager.songComplete)

        // Hit all 3 notes
        _ = manager.tick(elapsed: 2.0, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)
        XCTAssertFalse(manager.songComplete)

        _ = manager.tick(elapsed: 2.5, leftLane: 2, rightLane: nil, leftPinching: true, rightPinching: false)
        XCTAssertFalse(manager.songComplete)

        _ = manager.tick(elapsed: 3.0, leftLane: 4, rightLane: nil, leftPinching: true, rightPinching: false)
        XCTAssertTrue(manager.songComplete, "Song should be complete after all notes are consumed")
    }

    func testSongComplete_allNotesMissed() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Let all notes pass without hitting them
        // Note 0 at 2.0, note 1 at 2.5, note 2 at 3.0
        // All miss after noteTime + 0.2
        _ = manager.tick(elapsed: 3.21, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        XCTAssertTrue(manager.songComplete, "Song completes when all notes are consumed (even via miss)")
        XCTAssertEqual(manager.score.misses, 3)
    }

    func testSongComplete_mixOfHitsAndMisses() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Hit note 0
        _ = manager.tick(elapsed: 2.0, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)
        // Miss note 1
        _ = manager.tick(elapsed: 2.71, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        // Hit note 2
        _ = manager.tick(elapsed: 3.0, leftLane: 4, rightLane: nil, leftPinching: true, rightPinching: false)

        XCTAssertTrue(manager.songComplete)
        XCTAssertEqual(manager.score.perfectHits, 2)
        XCTAssertEqual(manager.score.misses, 1)
    }

    // MARK: - 10. Reset

    func testReset_clearsAllState() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        // Tick to generate some state
        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        _ = manager.tick(elapsed: 2.0, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)

        XCTAssertEqual(manager.score.perfectHits, 1)

        manager.reset()

        XCTAssertNil(manager.currentSong)
        XCTAssertFalse(manager.songComplete)
        XCTAssertEqual(manager.score.perfectHits, 0)
        XCTAssertEqual(manager.score.goodHits, 0)
        XCTAssertEqual(manager.score.misses, 0)
        XCTAssertEqual(manager.score.currentStreak, 0)
        XCTAssertEqual(manager.score.bestStreak, 0)
        XCTAssertTrue(manager.visibleNotes.isEmpty)
        XCTAssertTrue(manager.hitEffects.isEmpty)
    }

    func testReset_allowsReloadingSong() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        _ = manager.tick(elapsed: 2.0, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)

        manager.reset()

        // Reload and tick again
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)
        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        XCTAssertTrue(manager.isCountingDown)
        XCTAssertEqual(manager.score.perfectHits, 0)
    }

    // MARK: - 11. xFraction Calculation

    func testXFraction_noteAtCurrentBeat_isAtHitLineX() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // At elapsed=2.0, currentBeat=0. Note 0 is at startBeat=0.
        // xFraction = hitLineX + (0 - 0) / scrollLeadBeats * (1 - hitLineX)
        //           = 0.25 + 0 = 0.25
        _ = manager.tick(elapsed: 2.0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Note 0 might be consumed as a miss or still visible; check note at beat 0
        // Since we didn't pinch, it's not consumed yet (timeDelta = 0 <= 0.2 but no pinch)
        // It will show as active
        let noteAtBeat0 = manager.visibleNotes.first { $0.laneIndex == 0 }
        XCTAssertNotNil(noteAtBeat0)
        XCTAssertEqual(noteAtBeat0!.xFraction, 0.25, accuracy: 0.001,
                       "Note at current beat should be at hitLineX (0.25)")
    }

    func testXFraction_futureNote_isRightOfHitLine() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // At elapsed=2.0, currentBeat=0. Note 1 at startBeat=1.
        // xFraction = 0.25 + (1 - 0) / 4 * (1 - 0.25) = 0.25 + 0.1875 = 0.4375
        _ = manager.tick(elapsed: 2.0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        let noteAtBeat1 = manager.visibleNotes.first { $0.laneIndex == 2 }
        XCTAssertNotNil(noteAtBeat1)
        XCTAssertGreaterThan(noteAtBeat1!.xFraction, 0.25,
                             "Future note should be to the right of hit line")
        XCTAssertEqual(noteAtBeat1!.xFraction, 0.4375, accuracy: 0.001)
    }

    func testXFraction_pastNote_isLeftOfHitLine() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // At elapsed=2.25, currentBeat=0.5. Note 0 at startBeat=0.
        // xFraction = 0.25 + (0 - 0.5) / 4 * 0.75 = 0.25 - 0.09375 = 0.15625
        _ = manager.tick(elapsed: 2.25, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        let noteAtBeat0 = manager.visibleNotes.first { $0.laneIndex == 0 }
        XCTAssertNotNil(noteAtBeat0)
        XCTAssertLessThan(noteAtBeat0!.xFraction, 0.25,
                          "Past note should be to the left of hit line")
    }

    // MARK: - 12. Hit Effects

    func testHitEffects_perfectHitCreatesEffect() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        _ = manager.tick(elapsed: 2.0, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)

        XCTAssertEqual(manager.hitEffects.count, 1)
        XCTAssertEqual(manager.hitEffects[0].laneIndex, 0)
        XCTAssertEqual(manager.hitEffects[0].type, .hitPerfect)
    }

    func testHitEffects_goodHitCreatesEffect() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // timeDelta = 0.15 => good hit
        _ = manager.tick(elapsed: 2.15, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)

        XCTAssertEqual(manager.hitEffects.count, 1)
        XCTAssertEqual(manager.hitEffects[0].type, .hitGood)
    }

    func testHitEffects_missCreatesEffect() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Let note 0 pass
        _ = manager.tick(elapsed: 2.21, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        let missEffects = manager.hitEffects.filter { $0.type == .missed }
        XCTAssertEqual(missEffects.count, 1)
        XCTAssertEqual(missEffects[0].laneIndex, 0)
    }

    func testHitEffects_expireAfterHalfSecond() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Hit note 0 at elapsed=2.0
        _ = manager.tick(elapsed: 2.0, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)
        XCTAssertEqual(manager.hitEffects.count, 1)

        // Tick at 2.4 => effect is 0.4s old => still present
        _ = manager.tick(elapsed: 2.4, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        // At this point note 1 might also miss-trigger if past window, but effect from note 0 should remain
        let effectsFromNote0 = manager.hitEffects.filter { $0.type == .hitPerfect }
        XCTAssertFalse(effectsFromNote0.isEmpty, "Effect should still exist at 0.4s")

        // Tick at 2.51 => effect is 0.51s old => expired
        _ = manager.tick(elapsed: 2.51, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        let expiredEffects = manager.hitEffects.filter { $0.type == .hitPerfect }
        XCTAssertTrue(expiredEffects.isEmpty, "Perfect hit effect should expire after 0.5s")
    }

    // MARK: - 13. No Double-Hit

    func testNoDoubleHit_consumedNoteCantBeHitAgain() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Hit note 0
        let hits1 = manager.tick(elapsed: 2.0, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)
        XCTAssertEqual(hits1.count, 1)
        XCTAssertEqual(manager.score.perfectHits, 1)

        // Try to hit note 0 again at slightly later time (still within window)
        let hits2 = manager.tick(elapsed: 2.05, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)
        XCTAssertTrue(hits2.isEmpty, "Consumed note should not be hittable again")
        XCTAssertEqual(manager.score.perfectHits, 1, "Score should not increment for already-consumed note")
    }

    func testNoDoubleHit_missedNoteCantBeHitAfterMiss() {
        let manager = LearnModeManager()
        let song = LearnSong(name: "Test", emoji: "T", bpm: 120, degreeNotes: [
            LearnDegreeNote(degree: 0, startBeat: 0, durationBeats: 1),
            // Add a second note far enough away to avoid interference
            LearnDegreeNote(degree: 2, startBeat: 10, durationBeats: 1),
        ])
        manager.loadSong(song, scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Let note 0 miss
        _ = manager.tick(elapsed: 2.21, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        XCTAssertEqual(manager.score.misses, 1)

        // The note is consumed — even if we somehow tried to pinch, nothing should change
        // (note is already past the window anyway, but also consumed)
        let hits = manager.tick(elapsed: 2.25, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)
        XCTAssertTrue(hits.isEmpty)
        XCTAssertEqual(manager.score.misses, 1, "Miss count should not change for already-consumed note")
    }

    // MARK: - 14. Empty Song / No Song Loaded

    func testTick_noSongLoaded_returnsEmpty() {
        let manager = LearnModeManager()

        let hits = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        XCTAssertTrue(hits.isEmpty)
        XCTAssertTrue(manager.visibleNotes.isEmpty)
    }

    func testTick_afterReset_returnsEmpty() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)
        manager.reset()

        let hits = manager.tick(elapsed: 1.0, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)
        XCTAssertTrue(hits.isEmpty)
        XCTAssertTrue(manager.visibleNotes.isEmpty)
    }

    func testTick_emptySong_returnsEmpty() {
        let manager = LearnModeManager()
        let emptySong = LearnSong(name: "Empty", emoji: "E", bpm: 120, degreeNotes: [])
        manager.loadSong(emptySong, scaleNotes: cMajorScale, bpm: bpm)

        let hits = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        XCTAssertTrue(hits.isEmpty)
    }

    // MARK: - Additional Edge Cases

    func testHit_bothHandsCanHitDifferentNotes() {
        let manager = LearnModeManager()
        let song = LearnSong(name: "Test", emoji: "T", bpm: 120, degreeNotes: [
            LearnDegreeNote(degree: 0, startBeat: 0, durationBeats: 1),
            LearnDegreeNote(degree: 4, startBeat: 0, durationBeats: 1),
        ])
        manager.loadSong(song, scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Both notes at beat 0 => elapsed=2.0. Left hits lane 0, right hits lane 4.
        let hits = manager.tick(elapsed: 2.0, leftLane: 0, rightLane: 4, leftPinching: true, rightPinching: true)

        XCTAssertEqual(hits.count, 2, "Both hands should be able to hit simultaneous notes")
        XCTAssertEqual(manager.score.perfectHits, 2)
        XCTAssertEqual(manager.score.currentStreak, 2)
    }

    func testVisibleNotes_stateTransitions() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Note 0 should be .upcoming when far in future
        // At elapsed=0, currentBeat=-4, note 0 at beat 0 => xFraction > hitLineX => upcoming
        if let note = manager.visibleNotes.first(where: { $0.laneIndex == 0 }) {
            XCTAssertEqual(note.state, .upcoming)
        }

        // At elapsed=2.0, currentBeat=0, note 0 at beat 0 => xFraction = hitLineX => active
        _ = manager.tick(elapsed: 2.0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        if let note = manager.visibleNotes.first(where: { $0.laneIndex == 0 }) {
            // xFraction = 0.25 which is <= hitLineX, so .active
            XCTAssertEqual(note.state, .active)
        }

        // Hit it
        _ = manager.tick(elapsed: 2.0, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)
        // visibleNotes are built before hit detection in the same tick,
        // so the consumed state appears on the *next* tick.
        _ = manager.tick(elapsed: 2.01, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        if let note = manager.visibleNotes.first(where: { $0.laneIndex == 0 }) {
            XCTAssertEqual(note.state, .hitPerfect)
        }
    }

    func testDegreeResolution_clampsOutOfRange() {
        let manager = LearnModeManager()
        let song = LearnSong(name: "Test", emoji: "T", bpm: 120, degreeNotes: [
            LearnDegreeNote(degree: 99, startBeat: 0, durationBeats: 1),
        ])
        // Scale has 7 notes (indices 0-6). Degree 99 should clamp to 6.
        manager.loadSong(song, scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Hit the note in lane 6 (clamped from degree 99)
        let hits = manager.tick(elapsed: 2.0, leftLane: 6, rightLane: nil, leftPinching: true, rightPinching: false)

        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].midi, 71, "Clamped degree 99 should map to last scale note B4=71")
        XCTAssertEqual(hits[0].laneIndex, 6)
    }

    func testScoreAccuracy_reflectsHitsAndMisses() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // Hit 2 notes, miss 1
        _ = manager.tick(elapsed: 2.0, leftLane: 0, rightLane: nil, leftPinching: true, rightPinching: false)
        _ = manager.tick(elapsed: 2.71, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false) // miss note 1
        _ = manager.tick(elapsed: 3.0, leftLane: 4, rightLane: nil, leftPinching: true, rightPinching: false)

        XCTAssertEqual(manager.score.totalNotes, 3)
        XCTAssertEqual(manager.score.accuracy, 2.0 / 3.0, accuracy: 0.001)
    }

    func testCountdownValue_staysAtZeroDuringPlayback() {
        let manager = LearnModeManager()
        manager.loadSong(makeSimpleSong(), scaleNotes: cMajorScale, bpm: bpm)

        _ = manager.tick(elapsed: 0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)

        // After countdown ends (elapsed >= 2.0)
        _ = manager.tick(elapsed: 2.0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        XCTAssertFalse(manager.isCountingDown)
        XCTAssertEqual(manager.countdownValue, 0)

        // Keep ticking well past song start
        _ = manager.tick(elapsed: 5.0, leftLane: nil, rightLane: nil, leftPinching: false, rightPinching: false)
        XCTAssertFalse(manager.isCountingDown)
        XCTAssertEqual(manager.countdownValue, 0)
    }
}
