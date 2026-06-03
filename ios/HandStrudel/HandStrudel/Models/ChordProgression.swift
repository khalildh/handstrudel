import Foundation

/// A named chord progression — an ordered list of scale degrees (0-based).
///
/// In Chord+Melody mode the chord hand's zones are limited to the progression
/// the player picks: "Pop" gives 4 zones (I, V, vi, IV), "Blues" gives more,
/// "Free" gives all 7 diatonic chords. Smaller progressions are much easier
/// for non-musicians to play song-shaped material with.
struct ChordProgression: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let degrees: [Int]

    var isFree: Bool { id == "free" }
}

let CHORD_PROGRESSIONS: [ChordProgression] = [
    // "Free" — the original 7 diatonic chords. Power-user default.
    .init(id: "free",
          name: "Free",
          emoji: "🎛️",
          degrees: [0, 1, 2, 3, 4, 5, 6]),

    // Pop progression — Let It Be, Don't Stop Believin', countless others.
    .init(id: "pop",
          name: "Pop",
          emoji: "🎤",
          degrees: [0, 4, 5, 3]),       // I – V – vi – IV

    // Sad / reflective pop — Despacito, Apologize, lots of indie ballads.
    .init(id: "sad_pop",
          name: "Sad Pop",
          emoji: "🌧️",
          degrees: [5, 3, 0, 4]),       // vi – IV – I – V

    // 50s doo-wop — Stand By Me, Earth Angel.
    .init(id: "fifties",
          name: "50s",
          emoji: "🪩",
          degrees: [0, 5, 3, 4]),       // I – vi – IV – V

    // Doo-wop variant — Heart and Soul.
    .init(id: "doo_wop",
          name: "Doo-Wop",
          emoji: "🎶",
          degrees: [0, 5, 1, 4]),       // I – vi – ii – V

    // Andalusian descent — Hit the Road Jack, Sultans of Swing.
    // In a minor key this naturally becomes i – ♭VII – ♭VI – V.
    .init(id: "andalusian",
          name: "Andalusian",
          emoji: "🌅",
          degrees: [0, 6, 5, 4]),       // walking step-down

    // Jazz turnaround — ii – V – I – vi.
    .init(id: "jazz",
          name: "Jazz ii-V-I",
          emoji: "🎷",
          degrees: [1, 4, 0, 5]),

    // 12-bar blues compressed into a single playable lane.
    .init(id: "blues",
          name: "Blues",
          emoji: "🎸",
          degrees: [0, 3, 4]),          // I – IV – V

    // Modal / cinematic vamp — Eleanor Rigby, House of the Rising Sun feel.
    .init(id: "minor_vamp",
          name: "Minor Vamp",
          emoji: "🕯️",
          degrees: [0, 5, 3]),          // i – VI – IV (in a minor scale)
]
