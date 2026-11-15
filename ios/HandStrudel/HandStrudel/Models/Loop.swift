import Foundation

/// A single recorded event (note or drum hit) with timing
struct LoopEvent: Codable {
    let timestamp: Double    // seconds from loop start
    let type: EventType

    enum EventType: Codable {
        case noteOn(midi: Int, waveform: String, velocity: Double)
        case noteOff(hand: String)
        case drumHit(hitType: String)
        case codeSnapshot(code: String)  // melodic mode: full Strudel code at this moment
    }
}

/// A recorded loop — a sequence of events over a fixed duration
struct RecordedLoop: Identifiable, Codable {
    let id: UUID
    let events: [LoopEvent]
    let duration: Double     // total loop length in seconds
    let bpm: Double
    var name: String
    let mode: String         // "grid", "drum", "melodic"
    let createdAt: Date
    var hasCapturedAudio: Bool? = nil
    var gain: Double? = nil
    var muted: Bool? = nil

    var playbackGain: Double { Self.clampedGain(gain ?? 1) }
    var effectiveGain: Double { muted == true ? 0 : playbackGain }

    static func clampedGain(_ value: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : 1
    }

    static func cleanName(_ value: String) -> String {
        let singleLine = value.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        return String(String(String.UnicodeScalarView(singleLine)).trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
    }

    init(id: UUID = UUID(), events: [LoopEvent], duration: Double, bpm: Double, name: String, mode: String) {
        self.id = id
        self.events = events
        self.duration = duration
        self.bpm = bpm
        self.name = name
        self.mode = mode
        self.createdAt = Date()
    }
}

/// A composition — multiple loops stacked and arranged
struct Composition: Identifiable, Codable {
    let id: UUID
    var name: String
    var layers: [Layer]
    var bpm: Double
    let createdAt: Date

    struct Layer: Identifiable, Codable {
        let id: UUID
        let loopId: UUID     // references a RecordedLoop
        var volume: Double
        var muted: Bool

        init(loopId: UUID, volume: Double = 1.0) {
            self.id = UUID()
            self.loopId = loopId
            self.volume = volume
            self.muted = false
        }
    }

    init(name: String, bpm: Double) {
        self.id = UUID()
        self.name = name
        self.layers = []
        self.bpm = bpm
        self.createdAt = Date()
    }
}
