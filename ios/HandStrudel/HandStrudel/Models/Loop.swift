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
    let name: String
    let mode: String         // "grid", "drum", "melodic"
    let createdAt: Date

    init(events: [LoopEvent], duration: Double, bpm: Double, name: String, mode: String) {
        self.id = UUID()
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
