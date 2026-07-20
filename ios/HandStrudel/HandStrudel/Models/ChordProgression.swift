import Foundation

/// Genre/feel buckets used to make the 130+ built-in progression list
/// browsable. Each `ChordProgression` belongs to exactly one category;
/// `.custom` is reserved for user-typed progressions and never appears in
/// `CHORD_PROGRESSIONS`.
enum ProgressionCategory: String, CaseIterable, Identifiable {
    case essentials, popRock, punkHardRock, blues, jazz, soulRnB, folkCountry,
         classical, cinematic, modal, electronic, world, longForm, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .essentials:   return "Essentials"
        case .popRock:      return "Pop / Rock"
        case .punkHardRock: return "Punk / Hard Rock"
        case .blues:        return "Blues"
        case .jazz:         return "Jazz"
        case .soulRnB:      return "Soul / R&B"
        case .folkCountry:  return "Folk / Country"
        case .classical:    return "Classical"
        case .cinematic:    return "Cinematic"
        case .modal:        return "Modal"
        case .electronic:   return "Electronic"
        case .world:        return "World"
        case .longForm:     return "Long-form"
        case .custom:       return "Custom"
        }
    }

    var emoji: String {
        switch self {
        case .essentials:   return "⭐️"
        case .popRock:      return "🎸"
        case .punkHardRock: return "🤘"
        case .blues:        return "🎷"
        case .jazz:         return "🎺"
        case .soulRnB:      return "💜"
        case .folkCountry:  return "🤠"
        case .classical:    return "🎻"
        case .cinematic:    return "🎬"
        case .modal:        return "🌀"
        case .electronic:   return "🎚️"
        case .world:        return "🌍"
        case .longForm:     return "📜"
        case .custom:       return "✍️"
        }
    }
}

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
    let category: ProgressionCategory

    var isFree: Bool { id == "free" }

    /// True for progressions the user typed in by hand rather than picked from
    /// the built-in list. Custom progressions aren't part of `CHORD_PROGRESSIONS`.
    var isCustom: Bool { id.hasPrefix("custom") }

    /// Everything outside the Essentials category (and any user-typed custom
    /// progression) is behind the Pro unlock. Essentials keeps the 9 most
    /// idiomatic pop/blues/jazz shapes free so a new user can still play
    /// something song-shaped on day one.
    var isPremium: Bool { category != .essentials && !isCustom }
    var packId: String? { isPremium ? "pro" : nil }
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

        return .init(id: "custom", name: name, emoji: emoji, degrees: degrees, category: .custom)
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

    .init(id: "free", name: "Free", emoji: "🎛️", degrees: [0, 1, 2, 3, 4, 5, 6], category: .essentials),
    .init(id: "pop", name: "Pop", emoji: "🎤", degrees: [0, 4, 5, 3], category: .essentials),
    .init(id: "sad_pop", name: "Sad Pop", emoji: "🌧️", degrees: [5, 3, 0, 4], category: .essentials),
    .init(id: "fifties", name: "50s", emoji: "🪩", degrees: [0, 5, 3, 4], category: .essentials),
    .init(id: "doo_wop", name: "Doo-Wop", emoji: "🎶", degrees: [0, 5, 1, 4], category: .essentials),
    .init(id: "andalusian", name: "Andalusian", emoji: "🌅", degrees: [0, 6, 5, 4], category: .essentials),
    .init(id: "jazz", name: "Jazz ii-V-I", emoji: "🎷", degrees: [1, 4, 0, 5], category: .essentials),
    .init(id: "blues", name: "Blues", emoji: "🎸", degrees: [0, 3, 4], category: .essentials),
    .init(id: "minor_vamp", name: "Minor Vamp", emoji: "🕯️", degrees: [0, 5, 3], category: .essentials),

    // ───────────────────────── Pop & Rock ─────────────────────────

    .init(id: "pop_rock", name: "Pop-Rock", emoji: "🎸", degrees: [0, 3, 4, 3], category: .popRock),
    .init(id: "power_pop", name: "Power Pop", emoji: "⚡", degrees: [0, 4, 3], category: .popRock),
    .init(id: "stadium", name: "Stadium", emoji: "🏟️", degrees: [0, 3, 5, 4], category: .popRock),
    .init(id: "anthem", name: "Anthem", emoji: "📣", degrees: [3, 0, 4, 5], category: .popRock),
    .init(id: "axis", name: "Axis", emoji: "🪓", degrees: [5, 3, 4, 0], category: .popRock),
    .init(id: "heartland", name: "Heartland", emoji: "🌾", degrees: [0, 3, 0, 4], category: .popRock),
    .init(id: "optimist", name: "Optimist", emoji: "☀️", degrees: [0, 2, 3, 4], category: .popRock),
    .init(id: "bittersweet", name: "Bittersweet", emoji: "🍫", degrees: [0, 2, 5, 3], category: .popRock),
    .init(id: "royal_road", name: "Royal Road", emoji: "👑", degrees: [3, 4, 2, 5], category: .popRock),
    .init(id: "city_pop", name: "City Pop", emoji: "🌃", degrees: [3, 4, 5, 0], category: .popRock),
    .init(id: "build_up", name: "Build-Up", emoji: "📈", degrees: [0, 4, 5, 3, 3, 4], category: .popRock),
    .init(id: "pop_loop8", name: "Pop Loop 8", emoji: "🔁", degrees: [0, 4, 5, 3, 0, 4, 3, 4], category: .popRock),
    .init(id: "two_chord", name: "Two-Chord", emoji: "🥁", degrees: [0, 4], category: .popRock),
    .init(id: "i_iv_vamp", name: "I–IV Vamp", emoji: "🌊", degrees: [0, 3], category: .popRock),
    .init(id: "i_vi_vamp", name: "I–vi Vamp", emoji: "💭", degrees: [0, 5], category: .popRock),
    .init(id: "millennial", name: "Millennial", emoji: "📱", degrees: [0, 4, 5, 4], category: .popRock),
    .init(id: "indie", name: "Indie", emoji: "🎧", degrees: [3, 5, 0, 4], category: .popRock),
    .init(id: "dream_pop", name: "Dream Pop", emoji: "☁️", degrees: [0, 2, 3, 5], category: .popRock),
    .init(id: "shoegaze", name: "Shoegaze", emoji: "👟", degrees: [0, 3, 5, 3], category: .popRock),
    .init(id: "synthwave", name: "Synthwave", emoji: "🌆", degrees: [5, 4, 3, 4], category: .popRock),
    .init(id: "new_wave", name: "New Wave", emoji: "🎹", degrees: [5, 3, 0, 4, 5, 3, 4, 4], category: .popRock),
    .init(id: "britpop", name: "Britpop", emoji: "🇬🇧", degrees: [0, 4, 3, 0], category: .popRock),
    .init(id: "grunge", name: "Grunge", emoji: "🤘", degrees: [0, 5, 3, 4], category: .popRock),
    .init(id: "emo", name: "Emo", emoji: "🖤", degrees: [5, 3, 0, 4, 5, 3, 0, 4], category: .popRock),
    .init(id: "arena_rock", name: "Arena Rock", emoji: "🎆", degrees: [0, 4, 3, 4], category: .popRock),

    // ───────────────────────── Punk & Hard Rock ─────────────────────────

    .init(id: "punk", name: "Punk", emoji: "💢", degrees: [0, 3, 4, 0], category: .punkHardRock),
    .init(id: "pop_punk", name: "Pop-Punk", emoji: "🛹", degrees: [0, 4, 5, 3, 0, 4, 3, 3], category: .punkHardRock),
    .init(id: "garage", name: "Garage", emoji: "🚗", degrees: [0, 3, 0, 4], category: .punkHardRock),
    .init(id: "surf", name: "Surf", emoji: "🏄", degrees: [0, 5, 3, 4], category: .punkHardRock),
    .init(id: "metal", name: "Metal", emoji: "🤟", degrees: [0, 6, 5, 0], category: .punkHardRock),
    .init(id: "hard_rock", name: "Hard Rock", emoji: "🔊", degrees: [0, 6, 3, 0], category: .punkHardRock),
    .init(id: "boogie", name: "Boogie", emoji: "🦵", degrees: [0, 0, 3, 0, 4, 3, 0, 4], category: .punkHardRock),
    .init(id: "riff_rock", name: "Riff Rock", emoji: "🎚️", degrees: [0, 2, 3], category: .punkHardRock),

    // ───────────────────────── Blues ─────────────────────────

    .init(id: "blues12", name: "12-Bar Blues", emoji: "🎷", degrees: [0, 0, 0, 0, 3, 3, 0, 0, 4, 3, 0, 4], category: .blues),
    .init(id: "quick_blues", name: "Quick-Change", emoji: "🚦", degrees: [0, 3, 0, 0, 3, 3, 0, 0, 4, 3, 0, 4], category: .blues),
    .init(id: "slow_blues", name: "Slow Blues", emoji: "🐌", degrees: [0, 3, 0, 4, 3, 0], category: .blues),
    .init(id: "minor_blues", name: "Minor Blues", emoji: "🌑", degrees: [0, 0, 0, 0, 3, 3, 0, 0, 5, 4, 0, 4], category: .blues),
    .init(id: "jump_blues", name: "Jump Blues", emoji: "🦘", degrees: [0, 3, 0, 4], category: .blues),
    .init(id: "blues_turn", name: "Blues Turnaround", emoji: "↩️", degrees: [0, 4, 0, 3, 0, 4], category: .blues),
    .init(id: "delta", name: "Delta", emoji: "🛶", degrees: [0, 3, 4, 0], category: .blues),
    .init(id: "eight_bar", name: "8-Bar Blues", emoji: "8️⃣", degrees: [0, 4, 3, 0, 0, 4, 0, 4], category: .blues),

    // ───────────────────────── Jazz ─────────────────────────

    .init(id: "ii_v_i", name: "ii–V–I", emoji: "🎺", degrees: [1, 4, 0], category: .jazz),
    .init(id: "vi_ii_v_i", name: "vi–ii–V–I", emoji: "🎼", degrees: [5, 1, 4, 0], category: .jazz),
    .init(id: "iii_vi_ii_v", name: "iii–vi–ii–V", emoji: "🪕", degrees: [2, 5, 1, 4], category: .jazz),
    .init(id: "rhythm_changes", name: "Rhythm Changes", emoji: "🎙️", degrees: [0, 5, 1, 4, 0, 5, 1, 4], category: .jazz),
    .init(id: "bird_blues", name: "Bird Blues", emoji: "🐦", degrees: [0, 4, 1, 4, 3, 3, 0, 5, 1, 4, 0, 4], category: .jazz),
    .init(id: "montgomery", name: "Stepwise", emoji: "🪜", degrees: [0, 1, 2, 3], category: .jazz),
    .init(id: "jazz_blues", name: "Jazz Blues", emoji: "🎻", degrees: [0, 3, 0, 0, 3, 3, 0, 5, 1, 4, 0, 4], category: .jazz),
    .init(id: "minor_ii_v", name: "Minor ii–V–i", emoji: "🍷", degrees: [1, 4, 0, 0], category: .jazz),
    .init(id: "backdoor", name: "Backdoor", emoji: "🚪", degrees: [1, 4, 3, 0], category: .jazz),
    .init(id: "lady_bird", name: "Lady Bird", emoji: "🐞", degrees: [0, 2, 1, 4], category: .jazz),
    .init(id: "satin", name: "Satin Doll", emoji: "🎀", degrees: [1, 4, 1, 4, 2, 5, 1, 4], category: .jazz),
    .init(id: "autumn", name: "Autumn", emoji: "🍂", degrees: [1, 4, 0, 3, 6, 2, 5, 5], category: .jazz),
    .init(id: "bossa", name: "Bossa Nova", emoji: "🇧🇷", degrees: [0, 1, 4, 0], category: .jazz),
    .init(id: "samba", name: "Samba", emoji: "🥁", degrees: [0, 5, 1, 4, 0], category: .jazz),
    .init(id: "gypsy", name: "Gypsy Jazz", emoji: "🎻", degrees: [5, 1, 4, 0], category: .jazz),
    .init(id: "modal_jazz", name: "Modal Jazz", emoji: "🌀", degrees: [0, 3], category: .jazz),

    // ───────────────────────── Soul, R&B & Gospel ─────────────────────────

    .init(id: "soul", name: "Soul", emoji: "💜", degrees: [0, 3, 1, 4], category: .soulRnB),
    .init(id: "neo_soul", name: "Neo-Soul", emoji: "🫧", degrees: [1, 4, 2, 5], category: .soulRnB),
    .init(id: "motown", name: "Motown", emoji: "🚙", degrees: [0, 5, 3, 4], category: .soulRnB),
    .init(id: "rnb", name: "R&B", emoji: "🎙️", degrees: [0, 2, 5, 3], category: .soulRnB),
    .init(id: "gospel", name: "Gospel", emoji: "⛪", degrees: [0, 3, 0, 4], category: .soulRnB),
    .init(id: "gospel_run", name: "Gospel Run", emoji: "🙌", degrees: [0, 0, 3, 4, 2, 5, 1, 4], category: .soulRnB),
    .init(id: "amen", name: "Amen", emoji: "🕊️", degrees: [3, 0], category: .soulRnB),
    .init(id: "funk", name: "Funk", emoji: "🕺", degrees: [0, 3], category: .soulRnB),
    .init(id: "disco", name: "Disco", emoji: "🪩", degrees: [0, 5, 3, 4, 0, 5, 4, 4], category: .soulRnB),
    .init(id: "quiet_storm", name: "Quiet Storm", emoji: "🌙", degrees: [1, 4, 0, 5], category: .soulRnB),

    // ───────────────────────── Folk, Country & Singer-Songwriter ─────────────────────────

    .init(id: "folk", name: "Folk", emoji: "🪗", degrees: [0, 3, 4, 4], category: .folkCountry),
    .init(id: "country", name: "Country", emoji: "🤠", degrees: [0, 0, 3, 4], category: .folkCountry),
    .init(id: "country_walk", name: "Country Walk", emoji: "👢", degrees: [0, 3, 0, 4, 0, 3, 4, 0], category: .folkCountry),
    .init(id: "campfire", name: "Campfire", emoji: "🔥", degrees: [0, 3, 5, 4], category: .folkCountry),
    .init(id: "ballad", name: "Ballad", emoji: "💌", degrees: [0, 4, 5, 3, 3, 0, 4, 4], category: .folkCountry),
    .init(id: "waltz", name: "Waltz", emoji: "💃", degrees: [0, 3, 4], category: .folkCountry),
    .init(id: "celtic", name: "Celtic", emoji: "☘️", degrees: [0, 6, 3, 0], category: .folkCountry),
    .init(id: "sea_shanty", name: "Sea Shanty", emoji: "⚓", degrees: [0, 6, 3, 4], category: .folkCountry),
    .init(id: "bluegrass", name: "Bluegrass", emoji: "🪕", degrees: [0, 3, 0, 4], category: .folkCountry),
    .init(id: "americana", name: "Americana", emoji: "🛣️", degrees: [0, 4, 3, 0], category: .folkCountry),

    // ───────────────────────── Classical ─────────────────────────

    .init(id: "pachelbel", name: "Pachelbel", emoji: "🎻", degrees: [0, 4, 5, 2, 3, 0, 3, 4], category: .classical),
    .init(id: "circle", name: "Circle of 5ths", emoji: "⭕", degrees: [0, 3, 6, 2, 5, 1, 4, 0], category: .classical),
    .init(id: "authentic", name: "Authentic Cadence", emoji: "✅", degrees: [0, 3, 4, 0], category: .classical),
    .init(id: "deceptive", name: "Deceptive", emoji: "🃏", degrees: [0, 3, 4, 5], category: .classical),
    .init(id: "half_cadence", name: "Half Cadence", emoji: "⏸️", degrees: [0, 5, 1, 4], category: .classical),
    .init(id: "romanesca", name: "Romanesca", emoji: "🏛️", degrees: [0, 4, 5, 2], category: .classical),
    .init(id: "passamezzo", name: "Passamezzo", emoji: "📜", degrees: [0, 6, 0, 4], category: .classical),
    .init(id: "folia", name: "La Folía", emoji: "🪶", degrees: [5, 4, 5, 2, 3, 0, 3, 4], category: .classical),
    .init(id: "lament", name: "Lament", emoji: "😢", degrees: [0, 6, 5, 4], category: .classical),
    .init(id: "grand_cadence", name: "Grand Cadence", emoji: "🎩", degrees: [0, 3, 1, 4, 0], category: .classical),

    // ───────────────────────── Cinematic & Minor ─────────────────────────

    .init(id: "epic", name: "Epic", emoji: "⚔️", degrees: [5, 3, 0, 4], category: .cinematic),
    .init(id: "trailer", name: "Trailer", emoji: "🎬", degrees: [5, 4, 3, 5], category: .cinematic),
    .init(id: "dark", name: "Dark", emoji: "🦇", degrees: [0, 5, 6, 4], category: .cinematic),
    .init(id: "suspense", name: "Suspense", emoji: "🫥", degrees: [0, 1, 5, 4], category: .cinematic),
    .init(id: "heroic", name: "Heroic", emoji: "🦸", degrees: [0, 3, 5, 4, 0, 3, 4, 0], category: .cinematic),
    .init(id: "fantasy", name: "Fantasy", emoji: "🐉", degrees: [0, 5, 3, 6], category: .cinematic),
    .init(id: "nordic", name: "Nordic", emoji: "❄️", degrees: [5, 4, 5, 3], category: .cinematic),
    .init(id: "tragic", name: "Tragic", emoji: "🎭", degrees: [0, 4, 5, 2, 3, 0, 1, 4], category: .cinematic),
    .init(id: "noir", name: "Noir", emoji: "🕴️", degrees: [0, 6, 1, 4], category: .cinematic),
    .init(id: "lullaby", name: "Lullaby", emoji: "🌛", degrees: [0, 3, 4, 0, 0, 3, 4, 4], category: .cinematic),

    // ───────────────────────── Modal ─────────────────────────

    .init(id: "dorian", name: "Dorian", emoji: "🌿", degrees: [0, 3, 0, 6], category: .modal),
    .init(id: "mixolydian", name: "Mixolydian", emoji: "🌞", degrees: [0, 6, 3, 0], category: .modal),
    .init(id: "phrygian", name: "Phrygian", emoji: "🏜️", degrees: [0, 1, 0, 6], category: .modal),
    .init(id: "lydian", name: "Lydian", emoji: "🛸", degrees: [0, 1, 0, 4], category: .modal),
    .init(id: "aeolian", name: "Aeolian", emoji: "🌫️", degrees: [0, 5, 3, 6], category: .modal),
    .init(id: "spanish", name: "Spanish", emoji: "🇪🇸", degrees: [0, 6, 5, 4], category: .modal),
    .init(id: "klezmer", name: "Klezmer", emoji: "🎻", degrees: [0, 3, 0, 4], category: .modal),
    .init(id: "raga", name: "Raga Drone", emoji: "🪔", degrees: [0], category: .modal),

    // ───────────────────────── Electronic & Hip-Hop ─────────────────────────

    .init(id: "edm", name: "EDM", emoji: "🎚️", degrees: [5, 3, 0, 4], category: .electronic),
    .init(id: "house", name: "House", emoji: "🏠", degrees: [1, 4, 0, 5], category: .electronic),
    .init(id: "trance", name: "Trance", emoji: "🌌", degrees: [5, 3, 0, 4, 5, 3, 4, 4], category: .electronic),
    .init(id: "future_bass", name: "Future Bass", emoji: "🔮", degrees: [3, 4, 5, 0], category: .electronic),
    .init(id: "lofi", name: "Lo-Fi", emoji: "📻", degrees: [0, 5, 1, 4], category: .electronic),
    .init(id: "trap", name: "Trap", emoji: "📿", degrees: [0, 5, 3], category: .electronic),
    .init(id: "boom_bap", name: "Boom Bap", emoji: "🎙️", degrees: [5, 1, 4, 0], category: .electronic),
    .init(id: "drill", name: "Drill", emoji: "🥶", degrees: [0, 6, 5, 6], category: .electronic),
    .init(id: "phonk", name: "Phonk", emoji: "💀", degrees: [0, 5, 6, 4], category: .electronic),
    .init(id: "vaporwave", name: "Vaporwave", emoji: "📼", degrees: [3, 4, 2, 5], category: .electronic),

    // ───────────────────────── Reggae, Latin & World ─────────────────────────

    .init(id: "reggae", name: "Reggae", emoji: "🌴", degrees: [0, 3], category: .world),
    .init(id: "ska", name: "Ska", emoji: "🎺", degrees: [0, 3, 4, 3], category: .world),
    .init(id: "dub", name: "Dub", emoji: "🔉", degrees: [0, 5], category: .world),
    .init(id: "salsa", name: "Salsa", emoji: "💃", degrees: [0, 3, 4, 4], category: .world),
    .init(id: "cumbia", name: "Cumbia", emoji: "🪘", degrees: [0, 4, 0, 4], category: .world),
    .init(id: "tango", name: "Tango", emoji: "🌹", degrees: [0, 5, 1, 4], category: .world),
    .init(id: "flamenco", name: "Flamenco", emoji: "🔥", degrees: [0, 6, 5, 4], category: .world),
    .init(id: "afrobeat", name: "Afrobeat", emoji: "🥁", degrees: [0, 3, 4, 3], category: .world),
    .init(id: "highlife", name: "Highlife", emoji: "🌍", degrees: [0, 3, 0, 4], category: .world),
    .init(id: "bollywood", name: "Bollywood", emoji: "🪷", degrees: [0, 3, 5, 4], category: .world),

    // ───────────────────────── Long-form & Misc ─────────────────────────

    .init(id: "verse_chorus", name: "Verse→Chorus", emoji: "📝", degrees: [0, 5, 3, 4, 0, 4, 5, 3], category: .longForm),
    .init(id: "journey", name: "Journey", emoji: "🧭", degrees: [0, 4, 5, 3, 1, 4, 0, 0], category: .longForm),
    .init(id: "ascending", name: "Ascending", emoji: "⬆️", degrees: [0, 1, 2, 3, 4, 5, 6], category: .longForm),
    .init(id: "descending", name: "Descending", emoji: "⬇️", degrees: [6, 5, 4, 3, 2, 1, 0], category: .longForm),
    .init(id: "bass_walk", name: "Walking Bass", emoji: "🚶", degrees: [0, 2, 3, 4], category: .longForm),
    .init(id: "step_down", name: "Step Down", emoji: "📉", degrees: [0, 6, 5, 3], category: .longForm),
    .init(id: "all_minor", name: "Minor Tour", emoji: "🌃", degrees: [5, 1, 2, 5], category: .longForm),
    .init(id: "wide_open", name: "Wide Open", emoji: "🏞️", degrees: [0, 4, 3], category: .longForm),
    .init(id: "question", name: "Question", emoji: "❓", degrees: [0, 4], category: .longForm),
    .init(id: "resolution", name: "Resolution", emoji: "❗", degrees: [4, 0], category: .longForm),
]
