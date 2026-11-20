import Foundation
import QuartzCore

/// How a played note should be remembered for "Learn to play".
enum NoteCaptureRole {
    /// A melody note the player chose: taught first.
    case melody
    /// A chord pad, accent or auto-strum tone: taught only when a take has no melody.
    case chord
    /// Accompaniment the player didn't perform (SharePlay partners, saved-loop playback).
    case ignored
}

/// The notes behind a posted performance, timed to the posted clip.
///
/// Stored with the post (`videos.note_track`) so viewers can open the same part in
/// Learn mode. Keys are short because every post carries one.
struct NoteTrack: Codable, Equatable {
    static let currentVersion = 1
    /// A 60-second take of fast two-hand playing stays well under this.
    static let maxNotes = 600

    struct Note: Codable, Equatable {
        /// Start, in seconds.
        var t: Double
        /// Duration, in seconds.
        var d: Double
        /// MIDI pitch.
        var m: Int
        /// True for chord tones; omitted for melody notes.
        var c: Bool?

        var isChordTone: Bool { c == true }
    }

    var v: Int = NoteTrack.currentVersion
    var notes: [Note]

    var isValid: Bool {
        v == Self.currentVersion && !notes.isEmpty && notes.count <= Self.maxNotes && notes.allSatisfy {
            $0.t.isFinite && $0.t >= 0 && $0.t <= 60 && $0.d.isFinite && $0.d > 0 && $0.d <= 60 && (0...127).contains($0.m)
        }
    }

    /// Converts notes captured during a take (seconds since recording started) into the
    /// posted clip's timeline: keep what overlaps the trim, then apply half-speed scaling.
    static func posted(from captured: [Note], trimStart: Double?, trimEnd: Double?,
                       outputScale: Double) -> NoteTrack? {
        let start = max(0, trimStart ?? 0)
        let end = trimEnd ?? .infinity
        guard outputScale.isFinite, outputScale > 0, end > start else { return nil }
        let notes = captured
            .filter { $0.t.isFinite && $0.d.isFinite && $0.t < end && $0.t + $0.d > start }
            .map { note -> Note in
                let from = max(note.t, start)
                let to = min(note.t + note.d, end)
                return Note(t: rounded((from - start) * outputScale),
                            d: max(0.01, rounded((to - from) * outputScale)),
                            m: note.m, c: note.c)
            }
            .sorted { ($0.t, $0.m) < ($1.t, $1.m) }
        let track = NoteTrack(notes: Array(notes.prefix(maxNotes)))
        return track.isValid ? track : nil
    }

    /// Builds a Learn-mode song on the given scale lanes. Melody notes are taught when the
    /// take has any; otherwise each chord is taught by its lowest tone.
    func learnSong(title: String, key: MusicKey, scale: Scale, bpm: Double, scaleNotes: [Int]) -> LearnSong? {
        guard isValid, !scaleNotes.isEmpty else { return nil }
        let tempo = (20...400).contains(bpm) ? bpm : 100
        let beatsPerSecond = tempo / 60
        let melody = notes.filter { !$0.isChordTone }
        let taught = melody.isEmpty ? Self.chordRoots(notes) : melody
        var degreeNotes: [LearnDegreeNote] = []
        for note in taught.sorted(by: { $0.t < $1.t }) {
            let lane = Self.lane(for: note.m, in: scaleNotes)
            let start = note.t * beatsPerSecond
            // Drop a re-strike of the same lane that lands on top of the previous one.
            if let last = degreeNotes.last(where: { $0.degree == lane }), start - last.startBeat < 0.125 { continue }
            degreeNotes.append(LearnDegreeNote(degree: lane, startBeat: start,
                                               durationBeats: max(0.25, note.d * beatsPerSecond)))
        }
        guard !degreeNotes.isEmpty else { return nil }
        return LearnSong(name: title, emoji: "\u{1F3AC}", bpm: tempo, degreeNotes: degreeNotes,
                         category: .imported, suggestedScale: scale, suggestedKey: key)
    }

    /// The scale lane nearest a pitch, after folding it by octaves into the lane range.
    static func lane(for midi: Int, in scaleNotes: [Int]) -> Int {
        guard let low = scaleNotes.min(), let high = scaleNotes.max() else { return 0 }
        var pitch = midi
        while pitch < low - 6 { pitch += 12 }
        while pitch > high + 6 { pitch -= 12 }
        return scaleNotes.indices.min { abs(scaleNotes[$0] - pitch) < abs(scaleNotes[$1] - pitch) } ?? 0
    }

    /// One note per chord strike: tones starting within 30 ms are one chord.
    private static func chordRoots(_ notes: [Note]) -> [Note] {
        var roots: [Note] = []
        for note in notes.sorted(by: { ($0.t, $0.m) < ($1.t, $1.m) }) {
            if let last = roots.last, note.t - last.t < 0.03 { continue }
            roots.append(note)
        }
        return roots
    }

    private static func rounded(_ seconds: Double) -> Double { (seconds * 1000).rounded() / 1000 }
}

/// Collects the notes played while a video take is recording.
///
/// The synth and sampler report every note they sound; this keeps only what happens
/// between `start()` and `stop()`. Sustained voices are matched by voice name.
final class PerformanceNoteCapture {
    private struct OpenNote { let midi: Int; let start: Double; let chord: Bool }

    private let lock = NSLock()
    private let clock: () -> CFTimeInterval
    private var origin: CFTimeInterval?
    private var open: [String: OpenNote] = [:]
    private var notes: [NoteTrack.Note] = []

    init(clock: @escaping () -> CFTimeInterval = CACurrentMediaTime) { self.clock = clock }

    var isCapturing: Bool { lock.withLock { origin != nil } }

    func start() {
        lock.withLock {
            origin = clock()
            open.removeAll()
            notes.removeAll()
        }
    }

    /// Ends the take and returns its notes, timed from `start()`.
    func stop() -> [NoteTrack.Note] {
        lock.withLock {
            guard let origin else { return [] }
            let now = clock() - origin
            for voice in Array(open.keys) { close(voice, at: now) }
            self.origin = nil
            defer { notes.removeAll() }
            return notes.sorted { ($0.t, $0.m) < ($1.t, $1.m) }
        }
    }

    func noteOn(voice: String, midi: Int, role: NoteCaptureRole) {
        guard role != .ignored, !Self.isRemote(voice) else { return }
        lock.withLock {
            guard let now = elapsed() else { return }
            close(voice, at: now)
            open[voice] = OpenNote(midi: midi, start: now, chord: role == .chord)
        }
    }

    func slide(voice: String, midi: Int) {
        lock.withLock {
            guard let now = elapsed(), let current = open[voice], current.midi != midi else { return }
            close(voice, at: now)
            open[voice] = OpenNote(midi: midi, start: now, chord: current.chord)
        }
    }

    func noteOff(voice: String) {
        lock.withLock {
            guard let now = elapsed() else { return }
            close(voice, at: now)
        }
    }

    func oneShot(midi: Int, duration: Double, role: NoteCaptureRole) {
        guard role != .ignored else { return }
        lock.withLock {
            guard let now = elapsed(), notes.count < NoteTrack.maxNotes * 2 else { return }
            let length = duration.isFinite ? min(60, max(0.05, duration)) : 0.3
            notes.append(NoteTrack.Note(t: now, d: length, m: midi, c: role == .chord ? true : nil))
        }
    }

    /// Voices that belong to a pad chord rather than a melody hand.
    static func role(forVoice voice: String) -> NoteCaptureRole { voice.hasPrefix("pad") ? .chord : .melody }

    private static func isRemote(_ voice: String) -> Bool { voice.hasPrefix("jam-") || voice == "studio-preview" }

    private func elapsed() -> Double? { origin.map { clock() - $0 } }

    private func close(_ voice: String, at now: Double) {
        guard let note = open.removeValue(forKey: voice), notes.count < NoteTrack.maxNotes * 2 else { return }
        notes.append(NoteTrack.Note(t: note.start, d: max(0.05, now - note.start), m: note.midi,
                                    c: note.chord ? true : nil))
    }
}
