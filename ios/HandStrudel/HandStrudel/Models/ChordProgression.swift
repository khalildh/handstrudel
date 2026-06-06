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

    /// True for progressions the user typed in by hand rather than picked from
    /// the built-in list. Custom progressions aren't part of `CHORD_PROGRESSIONS`.
    var isCustom: Bool { id.hasPrefix("custom") }
}

// MARK: - Free-text parsing

extension ChordProgression {

    /// Build a custom progression from a free-text string the user types in.
    ///
    /// Accepts Roman numerals or plain scale-degree numbers in any common
    /// notation, e.g. all of these parse to the Pop progression I–V–vi–IV:
    ///
    ///   "I V vi IV"   "1 5 6 4"   "I-V-vi-IV"   "I, V, vi, IV"   "I → V → vi → IV"
    ///
    /// Chord qualities and extensions are ignored, so "Imaj7 V7 vi9 IVadd9"
    /// still reads as I–V–vi–IV. Tokens that don't resolve to a diatonic
    /// degree (1..7) are skipped. Returns `nil` if nothing parseable is found.
    static func parse(_ text: String,
                      name: String = "Custom",
                      emoji: String = "✍️") -> ChordProgression? {
        // Split on anything that isn't a letter or digit — spaces, dashes,
        // commas, arrows, slashes, pipes all act as separators.
        let separators = CharacterSet.alphanumerics.inverted
        let tokens = text.components(separatedBy: separators).filter { !$0.isEmpty }

        let degrees = tokens.compactMap { degree(forToken: $0) }
        guard !degrees.isEmpty else { return nil }

        return .init(id: "custom", name: name, emoji: emoji, degrees: degrees)
    }

    /// Resolve a single token ("vi", "IV7", "5", "3rd") to a 0-based degree.
    private static func degree(forToken raw: String) -> Int? {
        let token = raw.lowercased()

        // Plain number → scale degree 1..7 (e.g. "5" → V, index 4).
        // Strip a leading run of digits so "3rd" still reads as 3.
        let digits = String(token.prefix(while: { $0.isNumber }))
        if let n = Int(digits) {
            return (1...7).contains(n) ? n - 1 : nil
        }

        // Roman numeral → leading run of i / v characters. Trailing quality
        // markers ("maj7", "°", "dim", "m") are ignored.
        let roman = String(token.prefix(while: { $0 == "i" || $0 == "v" }))
        switch roman {
        case "i":   return 0
        case "ii":  return 1
        case "iii": return 2
        case "iv":  return 3
        case "v":   return 4
        case "vi":  return 5
        case "vii": return 6
        default:    return nil
        }
    }
}

// MARK: - Built-in progressions

/// A large, browsable library of progressions grouped loosely by feel/genre.
/// Degrees are 0-based diatonic scale degrees (0 = I … 6 = vii°). The actual
/// chord quality is decided later from the selected key/scale; these are just
/// the harmonic skeletons.
let CHORD_PROGRESSIONS: [ChordProgression] = [

    // ───────────────────────── Essentials ─────────────────────────

    // "Free" — all 7 diatonic chords. Power-user default.
    .init(id: "free", name: "Free", emoji: "🎛️", degrees: [0, 1, 2, 3, 4, 5, 6]),
    // Pop — Let It Be, Don't Stop Believin', countless others.
    .init(id: "pop", name: "Pop", emoji: "🎤", degrees: [0, 4, 5, 3]),          // I–V–vi–IV
    // Sad / reflective pop — Despacito, Apologize, indie ballads.
    .init(id: "sad_pop", name: "Sad Pop", emoji: "🌧️", degrees: [5, 3, 0, 4]),  // vi–IV–I–V
    // 50s doo-wop — Stand By Me, Earth Angel.
    .init(id: "fifties", name: "50s", emoji: "🪩", degrees: [0, 5, 3, 4]),       // I–vi–IV–V
    // Doo-wop variant — Heart and Soul.
    .init(id: "doo_wop", name: "Doo-Wop", emoji: "🎶", degrees: [0, 5, 1, 4]),   // I–vi–ii–V
    // Andalusian descent — Hit the Road Jack, Sultans of Swing.
    .init(id: "andalusian", name: "Andalusian", emoji: "🌅", degrees: [0, 6, 5, 4]),
    // Jazz turnaround — ii–V–I–vi.
    .init(id: "jazz", name: "Jazz ii-V-I", emoji: "🎷", degrees: [1, 4, 0, 5]),
    // 12-bar blues compressed into a single playable lane.
    .init(id: "blues", name: "Blues", emoji: "🎸", degrees: [0, 3, 4]),          // I–IV–V
    // Modal / cinematic vamp — Eleanor Rigby, House of the Rising Sun.
    .init(id: "minor_vamp", name: "Minor Vamp", emoji: "🕯️", degrees: [0, 5, 3]),

    // ───────────────────────── Pop & Rock ─────────────────────────

    .init(id: "pop_rock", name: "Pop-Rock", emoji: "🎸", degrees: [0, 3, 4, 3]),         // I–IV–V–IV
    .init(id: "power_pop", name: "Power Pop", emoji: "⚡", degrees: [0, 4, 3]),           // I–V–IV
    .init(id: "stadium", name: "Stadium", emoji: "🏟️", degrees: [0, 3, 5, 4]),          // I–IV–vi–V
    .init(id: "anthem", name: "Anthem", emoji: "📣", degrees: [3, 0, 4, 5]),             // IV–I–V–vi
    .init(id: "axis", name: "Axis", emoji: "🪓", degrees: [5, 3, 4, 0]),                 // vi–IV–V–I
    .init(id: "heartland", name: "Heartland", emoji: "🌾", degrees: [0, 3, 0, 4]),       // I–IV–I–V
    .init(id: "optimist", name: "Optimist", emoji: "☀️", degrees: [0, 2, 3, 4]),        // I–iii–IV–V
    .init(id: "bittersweet", name: "Bittersweet", emoji: "🍫", degrees: [0, 2, 5, 3]),   // I–iii–vi–IV
    .init(id: "royal_road", name: "Royal Road", emoji: "👑", degrees: [3, 4, 2, 5]),     // IV–V–iii–vi
    .init(id: "city_pop", name: "City Pop", emoji: "🌃", degrees: [3, 4, 5, 0]),         // IV–V–vi–I
    .init(id: "build_up", name: "Build-Up", emoji: "📈", degrees: [0, 4, 5, 3, 3, 4]),   // pop loop + lift
    .init(id: "pop_loop8", name: "Pop Loop 8", emoji: "🔁", degrees: [0, 4, 5, 3, 0, 4, 3, 4]),
    .init(id: "two_chord", name: "Two-Chord", emoji: "🥁", degrees: [0, 4]),             // I–V vamp
    .init(id: "i_iv_vamp", name: "I–IV Vamp", emoji: "🌊", degrees: [0, 3]),             // I–IV vamp
    .init(id: "i_vi_vamp", name: "I–vi Vamp", emoji: "💭", degrees: [0, 5]),             // I–vi vamp
    .init(id: "millennial", name: "Millennial", emoji: "📱", degrees: [0, 4, 5, 4]),     // I–V–vi–V
    .init(id: "indie", name: "Indie", emoji: "🎧", degrees: [3, 5, 0, 4]),               // IV–vi–I–V
    .init(id: "dream_pop", name: "Dream Pop", emoji: "☁️", degrees: [0, 2, 3, 5]),       // I–iii–IV–vi
    .init(id: "shoegaze", name: "Shoegaze", emoji: "👟", degrees: [0, 3, 5, 3]),         // I–IV–vi–IV
    .init(id: "synthwave", name: "Synthwave", emoji: "🌆", degrees: [5, 4, 3, 4]),       // vi–V–IV–V
    .init(id: "new_wave", name: "New Wave", emoji: "🎹", degrees: [5, 3, 0, 4, 5, 3, 4, 4]),
    .init(id: "britpop", name: "Britpop", emoji: "🇬🇧", degrees: [0, 4, 3, 0]),          // I–V–IV–I
    .init(id: "grunge", name: "Grunge", emoji: "🤘", degrees: [0, 5, 3, 4]),             // I–vi–IV–V (alt voicing)
    .init(id: "emo", name: "Emo", emoji: "🖤", degrees: [5, 3, 0, 4, 5, 3, 0, 4]),       // long sad loop
    .init(id: "arena_rock", name: "Arena Rock", emoji: "🎆", degrees: [0, 4, 3, 4]),     // I–V–IV–V

    // ───────────────────────── Punk & Hard Rock ─────────────────────────

    .init(id: "punk", name: "Punk", emoji: "💢", degrees: [0, 3, 4, 0]),                 // I–IV–V–I
    .init(id: "pop_punk", name: "Pop-Punk", emoji: "🛹", degrees: [0, 4, 5, 3, 0, 4, 3, 3]),
    .init(id: "garage", name: "Garage", emoji: "🚗", degrees: [0, 3, 0, 4]),             // I–IV–I–V
    .init(id: "surf", name: "Surf", emoji: "🏄", degrees: [0, 5, 3, 4]),                 // I–vi–IV–V
    .init(id: "metal", name: "Metal", emoji: "🤟", degrees: [0, 6, 5, 0]),               // i–♭VII–♭VI–i feel
    .init(id: "hard_rock", name: "Hard Rock", emoji: "🔊", degrees: [0, 6, 3, 0]),       // i–♭VII–IV–i feel
    .init(id: "boogie", name: "Boogie", emoji: "🦵", degrees: [0, 0, 3, 0, 4, 3, 0, 4]),
    .init(id: "riff_rock", name: "Riff Rock", emoji: "🎚️", degrees: [0, 2, 3]),         // I–iii–IV

    // ───────────────────────── Blues ─────────────────────────

    .init(id: "blues12", name: "12-Bar Blues", emoji: "🎷",
          degrees: [0, 0, 0, 0, 3, 3, 0, 0, 4, 3, 0, 4]),
    .init(id: "quick_blues", name: "Quick-Change", emoji: "🚦",
          degrees: [0, 3, 0, 0, 3, 3, 0, 0, 4, 3, 0, 4]),
    .init(id: "slow_blues", name: "Slow Blues", emoji: "🐌", degrees: [0, 3, 0, 4, 3, 0]),
    .init(id: "minor_blues", name: "Minor Blues", emoji: "🌑",
          degrees: [0, 0, 0, 0, 3, 3, 0, 0, 5, 4, 0, 4]),
    .init(id: "jump_blues", name: "Jump Blues", emoji: "🦘", degrees: [0, 3, 0, 4]),
    .init(id: "blues_turn", name: "Blues Turnaround", emoji: "↩️", degrees: [0, 4, 0, 3, 0, 4]),
    .init(id: "delta", name: "Delta", emoji: "🛶", degrees: [0, 3, 4, 0]),
    .init(id: "eight_bar", name: "8-Bar Blues", emoji: "8️⃣", degrees: [0, 4, 3, 0, 0, 4, 0, 4]),

    // ───────────────────────── Jazz ─────────────────────────

    .init(id: "ii_v_i", name: "ii–V–I", emoji: "🎺", degrees: [1, 4, 0]),
    .init(id: "vi_ii_v_i", name: "vi–ii–V–I", emoji: "🎼", degrees: [5, 1, 4, 0]),
    .init(id: "iii_vi_ii_v", name: "iii–vi–ii–V", emoji: "🪕", degrees: [2, 5, 1, 4]),
    .init(id: "rhythm_changes", name: "Rhythm Changes", emoji: "🎙️",
          degrees: [0, 5, 1, 4, 0, 5, 1, 4]),
    .init(id: "bird_blues", name: "Bird Blues", emoji: "🐦",
          degrees: [0, 4, 1, 4, 3, 3, 0, 5, 1, 4, 0, 4]),
    .init(id: "montgomery", name: "Stepwise", emoji: "🪜", degrees: [0, 1, 2, 3]),
    .init(id: "jazz_blues", name: "Jazz Blues", emoji: "🎻",
          degrees: [0, 3, 0, 0, 3, 3, 0, 5, 1, 4, 0, 4]),
    .init(id: "minor_ii_v", name: "Minor ii–V–i", emoji: "🍷", degrees: [1, 4, 0, 0]),
    .init(id: "backdoor", name: "Backdoor", emoji: "🚪", degrees: [1, 4, 3, 0]),
    .init(id: "lady_bird", name: "Lady Bird", emoji: "🐞", degrees: [0, 2, 1, 4]),
    .init(id: "satin", name: "Satin Doll", emoji: "🎀", degrees: [1, 4, 1, 4, 2, 5, 1, 4]),
    .init(id: "autumn", name: "Autumn", emoji: "🍂", degrees: [1, 4, 0, 3, 6, 2, 5, 5]),
    .init(id: "bossa", name: "Bossa Nova", emoji: "🇧🇷", degrees: [0, 1, 4, 0]),
    .init(id: "samba", name: "Samba", emoji: "🥁", degrees: [0, 5, 1, 4, 0]),
    .init(id: "gypsy", name: "Gypsy Jazz", emoji: "🎻", degrees: [5, 1, 4, 0]),
    .init(id: "modal_jazz", name: "Modal Jazz", emoji: "🌀", degrees: [0, 3]),

    // ───────────────────────── Soul, R&B & Gospel ─────────────────────────

    .init(id: "soul", name: "Soul", emoji: "💜", degrees: [0, 3, 1, 4]),                 // I–IV–ii–V
    .init(id: "neo_soul", name: "Neo-Soul", emoji: "🫧", degrees: [1, 4, 2, 5]),         // ii–V–iii–vi
    .init(id: "motown", name: "Motown", emoji: "🚙", degrees: [0, 5, 3, 4]),
    .init(id: "rnb", name: "R&B", emoji: "🎙️", degrees: [0, 2, 5, 3]),                  // I–iii–vi–IV
    .init(id: "gospel", name: "Gospel", emoji: "⛪", degrees: [0, 3, 0, 4]),
    .init(id: "gospel_run", name: "Gospel Run", emoji: "🙌", degrees: [0, 0, 3, 4, 2, 5, 1, 4]),
    .init(id: "amen", name: "Amen", emoji: "🕊️", degrees: [3, 0]),                      // plagal cadence
    .init(id: "funk", name: "Funk", emoji: "🕺", degrees: [0, 3]),                       // one-chord vamp w/ IV
    .init(id: "disco", name: "Disco", emoji: "🪩", degrees: [0, 5, 3, 4, 0, 5, 4, 4]),
    .init(id: "quiet_storm", name: "Quiet Storm", emoji: "🌙", degrees: [1, 4, 0, 5]),

    // ───────────────────────── Folk, Country & Singer-Songwriter ─────────────────────────

    .init(id: "folk", name: "Folk", emoji: "🪗", degrees: [0, 3, 4, 4]),
    .init(id: "country", name: "Country", emoji: "🤠", degrees: [0, 0, 3, 4]),
    .init(id: "country_walk", name: "Country Walk", emoji: "👢", degrees: [0, 3, 0, 4, 0, 3, 4, 0]),
    .init(id: "campfire", name: "Campfire", emoji: "🔥", degrees: [0, 3, 5, 4]),
    .init(id: "ballad", name: "Ballad", emoji: "💌", degrees: [0, 4, 5, 3, 3, 0, 4, 4]),
    .init(id: "waltz", name: "Waltz", emoji: "💃", degrees: [0, 3, 4]),
    .init(id: "celtic", name: "Celtic", emoji: "☘️", degrees: [0, 6, 3, 0]),            // I–♭VII–IV–I feel
    .init(id: "sea_shanty", name: "Sea Shanty", emoji: "⚓", degrees: [0, 6, 3, 4]),
    .init(id: "bluegrass", name: "Bluegrass", emoji: "🪕", degrees: [0, 3, 0, 4]),
    .init(id: "americana", name: "Americana", emoji: "🛣️", degrees: [0, 4, 3, 0]),

    // ───────────────────────── Classical ─────────────────────────

    .init(id: "pachelbel", name: "Pachelbel", emoji: "🎻",
          degrees: [0, 4, 5, 2, 3, 0, 3, 4]),                                            // Canon in D
    .init(id: "circle", name: "Circle of 5ths", emoji: "⭕",
          degrees: [0, 3, 6, 2, 5, 1, 4, 0]),
    .init(id: "authentic", name: "Authentic Cadence", emoji: "✅", degrees: [0, 3, 4, 0]),
    .init(id: "deceptive", name: "Deceptive", emoji: "🃏", degrees: [0, 3, 4, 5]),       // V–vi
    .init(id: "half_cadence", name: "Half Cadence", emoji: "⏸️", degrees: [0, 5, 1, 4]),
    .init(id: "romanesca", name: "Romanesca", emoji: "🏛️", degrees: [0, 4, 5, 2]),
    .init(id: "passamezzo", name: "Passamezzo", emoji: "📜", degrees: [0, 6, 0, 4]),
    .init(id: "folia", name: "La Folía", emoji: "🪶", degrees: [5, 4, 5, 2, 3, 0, 3, 4]),
    .init(id: "lament", name: "Lament", emoji: "😢", degrees: [0, 6, 5, 4]),
    .init(id: "grand_cadence", name: "Grand Cadence", emoji: "🎩", degrees: [0, 3, 1, 4, 0]),

    // ───────────────────────── Cinematic & Minor ─────────────────────────

    .init(id: "epic", name: "Epic", emoji: "⚔️", degrees: [5, 3, 0, 4]),
    .init(id: "trailer", name: "Trailer", emoji: "🎬", degrees: [5, 4, 3, 5]),
    .init(id: "dark", name: "Dark", emoji: "🦇", degrees: [0, 5, 6, 4]),
    .init(id: "suspense", name: "Suspense", emoji: "🫥", degrees: [0, 1, 5, 4]),
    .init(id: "heroic", name: "Heroic", emoji: "🦸", degrees: [0, 3, 5, 4, 0, 3, 4, 0]),
    .init(id: "fantasy", name: "Fantasy", emoji: "🐉", degrees: [0, 5, 3, 6]),
    .init(id: "nordic", name: "Nordic", emoji: "❄️", degrees: [5, 4, 5, 3]),
    .init(id: "tragic", name: "Tragic", emoji: "🎭", degrees: [0, 4, 5, 2, 3, 0, 1, 4]),
    .init(id: "noir", name: "Noir", emoji: "🕴️", degrees: [0, 6, 1, 4]),
    .init(id: "lullaby", name: "Lullaby", emoji: "🌛", degrees: [0, 3, 4, 0, 0, 3, 4, 4]),

    // ───────────────────────── Modal ─────────────────────────

    .init(id: "dorian", name: "Dorian", emoji: "🌿", degrees: [0, 3, 0, 6]),             // i–IV vamp feel
    .init(id: "mixolydian", name: "Mixolydian", emoji: "🌞", degrees: [0, 6, 3, 0]),     // I–♭VII–IV–I
    .init(id: "phrygian", name: "Phrygian", emoji: "🏜️", degrees: [0, 1, 0, 6]),
    .init(id: "lydian", name: "Lydian", emoji: "🛸", degrees: [0, 1, 0, 4]),
    .init(id: "aeolian", name: "Aeolian", emoji: "🌫️", degrees: [0, 5, 3, 6]),
    .init(id: "spanish", name: "Spanish", emoji: "🇪🇸", degrees: [0, 6, 5, 4]),
    .init(id: "klezmer", name: "Klezmer", emoji: "🎻", degrees: [0, 3, 0, 4]),
    .init(id: "raga", name: "Raga Drone", emoji: "🪔", degrees: [0]),                    // tonic drone

    // ───────────────────────── Electronic & Hip-Hop ─────────────────────────

    .init(id: "edm", name: "EDM", emoji: "🎚️", degrees: [5, 3, 0, 4]),
    .init(id: "house", name: "House", emoji: "🏠", degrees: [1, 4, 0, 5]),
    .init(id: "trance", name: "Trance", emoji: "🌌", degrees: [5, 3, 0, 4, 5, 3, 4, 4]),
    .init(id: "future_bass", name: "Future Bass", emoji: "🔮", degrees: [3, 4, 5, 0]),
    .init(id: "lofi", name: "Lo-Fi", emoji: "📻", degrees: [0, 5, 1, 4]),
    .init(id: "trap", name: "Trap", emoji: "📿", degrees: [0, 5, 3]),                    // minor vamp
    .init(id: "boom_bap", name: "Boom Bap", emoji: "🎙️", degrees: [5, 1, 4, 0]),
    .init(id: "drill", name: "Drill", emoji: "🥶", degrees: [0, 6, 5, 6]),
    .init(id: "phonk", name: "Phonk", emoji: "💀", degrees: [0, 5, 6, 4]),
    .init(id: "vaporwave", name: "Vaporwave", emoji: "📼", degrees: [3, 4, 2, 5]),

    // ───────────────────────── Reggae, Latin & World ─────────────────────────

    .init(id: "reggae", name: "Reggae", emoji: "🌴", degrees: [0, 3]),
    .init(id: "ska", name: "Ska", emoji: "🎺", degrees: [0, 3, 4, 3]),
    .init(id: "dub", name: "Dub", emoji: "🔉", degrees: [0, 5]),
    .init(id: "salsa", name: "Salsa", emoji: "💃", degrees: [0, 3, 4, 4]),
    .init(id: "cumbia", name: "Cumbia", emoji: "🪘", degrees: [0, 4, 0, 4]),
    .init(id: "tango", name: "Tango", emoji: "🌹", degrees: [0, 5, 1, 4]),
    .init(id: "flamenco", name: "Flamenco", emoji: "🔥", degrees: [0, 6, 5, 4]),
    .init(id: "afrobeat", name: "Afrobeat", emoji: "🥁", degrees: [0, 3, 4, 3]),
    .init(id: "highlife", name: "Highlife", emoji: "🌍", degrees: [0, 3, 0, 4]),
    .init(id: "bollywood", name: "Bollywood", emoji: "🪷", degrees: [0, 3, 5, 4]),

    // ───────────────────────── Long-form & Misc ─────────────────────────

    .init(id: "verse_chorus", name: "Verse→Chorus", emoji: "📝",
          degrees: [0, 5, 3, 4, 0, 4, 5, 3]),
    .init(id: "journey", name: "Journey", emoji: "🧭",
          degrees: [0, 4, 5, 3, 1, 4, 0, 0]),
    .init(id: "ascending", name: "Ascending", emoji: "⬆️", degrees: [0, 1, 2, 3, 4, 5, 6]),
    .init(id: "descending", name: "Descending", emoji: "⬇️", degrees: [6, 5, 4, 3, 2, 1, 0]),
    .init(id: "bass_walk", name: "Walking Bass", emoji: "🚶", degrees: [0, 2, 3, 4]),
    .init(id: "step_down", name: "Step Down", emoji: "📉", degrees: [0, 6, 5, 3]),
    .init(id: "all_minor", name: "Minor Tour", emoji: "🌃", degrees: [5, 1, 2, 5]),
    .init(id: "wide_open", name: "Wide Open", emoji: "🏞️", degrees: [0, 4, 3]),
    .init(id: "question", name: "Question", emoji: "❓", degrees: [0, 4]),               // ends on V
    .init(id: "resolution", name: "Resolution", emoji: "❗", degrees: [4, 0]),           // V–I
]
