import Foundation

struct SongNote: Codable {
    let midi: Int
    let time: Double      // seconds from song start
    let duration: Double   // how long to hold
}

struct Song: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let key: String        // MusicKey rawValue
    let scale: String      // Scale rawValue
    let bpm: Double
    let notes: [SongNote]
    let isPremium: Bool
}

// Built-in songs
let BUILT_IN_SONGS: [Song] = [
    Song(
        id: "twinkle", title: "Twinkle Twinkle", artist: "Traditional",
        key: "C", scale: "Major", bpm: 100,
        notes: [
            // C C G G A A G - F F E E D D C
            SongNote(midi: 60, time: 0.0, duration: 0.4),
            SongNote(midi: 60, time: 0.5, duration: 0.4),
            SongNote(midi: 67, time: 1.0, duration: 0.4),
            SongNote(midi: 67, time: 1.5, duration: 0.4),
            SongNote(midi: 69, time: 2.0, duration: 0.4),
            SongNote(midi: 69, time: 2.5, duration: 0.4),
            SongNote(midi: 67, time: 3.0, duration: 0.8),
            SongNote(midi: 65, time: 4.0, duration: 0.4),
            SongNote(midi: 65, time: 4.5, duration: 0.4),
            SongNote(midi: 64, time: 5.0, duration: 0.4),
            SongNote(midi: 64, time: 5.5, duration: 0.4),
            SongNote(midi: 62, time: 6.0, duration: 0.4),
            SongNote(midi: 62, time: 6.5, duration: 0.4),
            SongNote(midi: 60, time: 7.0, duration: 0.8),
        ],
        isPremium: false
    ),
    Song(
        id: "ode_to_joy", title: "Ode to Joy", artist: "Beethoven",
        key: "C", scale: "Major", bpm: 110,
        notes: [
            // E E F G G F E D C C D E E D D
            SongNote(midi: 64, time: 0.0, duration: 0.4),
            SongNote(midi: 64, time: 0.5, duration: 0.4),
            SongNote(midi: 65, time: 1.0, duration: 0.4),
            SongNote(midi: 67, time: 1.5, duration: 0.4),
            SongNote(midi: 67, time: 2.0, duration: 0.4),
            SongNote(midi: 65, time: 2.5, duration: 0.4),
            SongNote(midi: 64, time: 3.0, duration: 0.4),
            SongNote(midi: 62, time: 3.5, duration: 0.4),
            SongNote(midi: 60, time: 4.0, duration: 0.4),
            SongNote(midi: 60, time: 4.5, duration: 0.4),
            SongNote(midi: 62, time: 5.0, duration: 0.4),
            SongNote(midi: 64, time: 5.5, duration: 0.4),
            SongNote(midi: 64, time: 6.0, duration: 0.6),
            SongNote(midi: 62, time: 6.75, duration: 0.2),
            SongNote(midi: 62, time: 7.0, duration: 0.8),
        ],
        isPremium: false
    ),
    Song(
        id: "happy_birthday", title: "Happy Birthday", artist: "Traditional",
        key: "C", scale: "Major", bpm: 95,
        notes: [
            SongNote(midi: 60, time: 0.0, duration: 0.3),
            SongNote(midi: 60, time: 0.4, duration: 0.2),
            SongNote(midi: 62, time: 0.7, duration: 0.5),
            SongNote(midi: 60, time: 1.3, duration: 0.5),
            SongNote(midi: 65, time: 1.9, duration: 0.5),
            SongNote(midi: 64, time: 2.5, duration: 0.8),
        ],
        isPremium: false
    ),
    Song(
        id: "fur_elise", title: "Fur Elise", artist: "Beethoven",
        key: "A", scale: "Minor", bpm: 130,
        notes: [
            SongNote(midi: 76, time: 0.0, duration: 0.2),
            SongNote(midi: 75, time: 0.25, duration: 0.2),
            SongNote(midi: 76, time: 0.5, duration: 0.2),
            SongNote(midi: 75, time: 0.75, duration: 0.2),
            SongNote(midi: 76, time: 1.0, duration: 0.2),
            SongNote(midi: 71, time: 1.25, duration: 0.2),
            SongNote(midi: 74, time: 1.5, duration: 0.2),
            SongNote(midi: 72, time: 1.75, duration: 0.2),
            SongNote(midi: 69, time: 2.0, duration: 0.5),
        ],
        isPremium: true
    ),
]
