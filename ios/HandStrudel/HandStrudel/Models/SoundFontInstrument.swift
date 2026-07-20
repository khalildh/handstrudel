import Foundation

/// The 16 General MIDI instrument families. Each covers 8 contiguous program
/// numbers, so any GM-compliant `.sf2` lays out the same way.
enum GMCategory: String, CaseIterable, Identifiable {
    case piano, chromaticPercussion, organ, guitar, bass, strings, ensemble,
         brass, reed, pipe, synthLead, synthPad, synthFX, ethnic, percussive, soundFX

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .piano:              return "Piano"
        case .chromaticPercussion: return "Mallets"
        case .organ:              return "Organ"
        case .guitar:             return "Guitar"
        case .bass:               return "Bass"
        case .strings:            return "Strings"
        case .ensemble:           return "Ensemble"
        case .brass:              return "Brass"
        case .reed:               return "Reed"
        case .pipe:               return "Pipe"
        case .synthLead:          return "Synth Lead"
        case .synthPad:           return "Synth Pad"
        case .synthFX:            return "Synth FX"
        case .ethnic:             return "Ethnic"
        case .percussive:         return "Percussive"
        case .soundFX:            return "Sound FX"
        }
    }

    var emoji: String {
        switch self {
        case .piano:              return "🎹"
        case .chromaticPercussion: return "🔔"
        case .organ:              return "🎚️"
        case .guitar:             return "🎸"
        case .bass:               return "🎻"
        case .strings:            return "🎻"
        case .ensemble:           return "👥"
        case .brass:              return "🎺"
        case .reed:               return "🎷"
        case .pipe:               return "🪈"
        case .synthLead:          return "🌊"
        case .synthPad:           return "🌫️"
        case .synthFX:            return "✨"
        case .ethnic:             return "🪕"
        case .percussive:         return "🪘"
        case .soundFX:            return "💥"
        }
    }
}

/// A General MIDI instrument selectable in SoundFont mode.
///
/// `program` is the 0-based GM program number handed to
/// `AVAudioUnitSampler.loadSoundBankInstrument(program:…)`. Names follow the GM
/// standard so any compliant `.sf2` produces the expected timbre.
struct SoundFontInstrument: Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
    let program: UInt8
    let category: GMCategory

    var displayName: String { "\(emoji) \(name)" }

    /// A small curated free tier — one hero instrument per major family so a
    /// non-paying user can still express a piano piece, a guitar riff, and an
    /// ensemble arrangement without hitting the paywall. Everything else in
    /// the 128-instrument GM set is behind the Pro unlock.
    var isPremium: Bool { !FREE_SOUNDFONT_INSTRUMENT_IDS.contains(id) }
    var packId: String? { isPremium ? "pro" : nil }
}

private let FREE_SOUNDFONT_INSTRUMENT_IDS: Set<String> = [
    "grand_piano",
    "electric_piano_1",  // Rhodes EP
    "nylon_guitar",
    "clean_guitar",
    "acoustic_bass",     // Upright Bass
    "violin",
    "strings",           // Strings Ensemble
    "choir",             // Choir Aahs
]

/// All 128 General MIDI programs, in order. The category for program N is
/// always `N / 8` mapped to `GMCategory.allCases[N / 8]`.
let SOUNDFONT_INSTRUMENTS: [SoundFontInstrument] = [
    // Piano (0–7)
    SoundFontInstrument(id: "grand_piano",       name: "Grand Piano",        emoji: "🎹", program: 0,   category: .piano),
    SoundFontInstrument(id: "bright_piano",      name: "Bright Piano",       emoji: "🎹", program: 1,   category: .piano),
    SoundFontInstrument(id: "electric_grand",    name: "Electric Grand",     emoji: "🎹", program: 2,   category: .piano),
    SoundFontInstrument(id: "honky_tonk",        name: "Honky-tonk",         emoji: "🎹", program: 3,   category: .piano),
    SoundFontInstrument(id: "electric_piano_1",  name: "Rhodes EP",          emoji: "🎛️", program: 4,   category: .piano),
    SoundFontInstrument(id: "electric_piano_2",  name: "FM EP",              emoji: "🎛️", program: 5,   category: .piano),
    SoundFontInstrument(id: "harpsichord",       name: "Harpsichord",        emoji: "🎼", program: 6,   category: .piano),
    SoundFontInstrument(id: "clavinet",          name: "Clavinet",           emoji: "⚡️", program: 7,   category: .piano),

    // Chromatic Percussion (8–15)
    SoundFontInstrument(id: "celesta",           name: "Celesta",            emoji: "✨", program: 8,   category: .chromaticPercussion),
    SoundFontInstrument(id: "glockenspiel",      name: "Glockenspiel",       emoji: "🔔", program: 9,   category: .chromaticPercussion),
    SoundFontInstrument(id: "music_box",         name: "Music Box",          emoji: "🎶", program: 10,  category: .chromaticPercussion),
    SoundFontInstrument(id: "vibraphone",        name: "Vibraphone",         emoji: "🔔", program: 11,  category: .chromaticPercussion),
    SoundFontInstrument(id: "marimba",           name: "Marimba",            emoji: "🪘", program: 12,  category: .chromaticPercussion),
    SoundFontInstrument(id: "xylophone",         name: "Xylophone",          emoji: "🪵", program: 13,  category: .chromaticPercussion),
    SoundFontInstrument(id: "tubular_bells",     name: "Tubular Bells",      emoji: "🛎️", program: 14,  category: .chromaticPercussion),
    SoundFontInstrument(id: "dulcimer",          name: "Dulcimer",           emoji: "🪕", program: 15,  category: .chromaticPercussion),

    // Organ (16–23)
    SoundFontInstrument(id: "drawbar_organ",     name: "Drawbar Organ",      emoji: "🎚️", program: 16,  category: .organ),
    SoundFontInstrument(id: "percussive_organ",  name: "Percussive Organ",   emoji: "🎚️", program: 17,  category: .organ),
    SoundFontInstrument(id: "rock_organ",        name: "Rock Organ",         emoji: "🎚️", program: 18,  category: .organ),
    SoundFontInstrument(id: "church_organ",      name: "Church Organ",       emoji: "⛪️", program: 19,  category: .organ),
    SoundFontInstrument(id: "reed_organ",        name: "Reed Organ",         emoji: "🎚️", program: 20,  category: .organ),
    SoundFontInstrument(id: "accordion",         name: "Accordion",          emoji: "🪗", program: 21,  category: .organ),
    SoundFontInstrument(id: "harmonica",         name: "Harmonica",          emoji: "🪗", program: 22,  category: .organ),
    SoundFontInstrument(id: "tango_accordion",   name: "Tango Accordion",    emoji: "🪗", program: 23,  category: .organ),

    // Guitar (24–31)
    SoundFontInstrument(id: "nylon_guitar",      name: "Nylon Guitar",       emoji: "🎸", program: 24,  category: .guitar),
    SoundFontInstrument(id: "steel_guitar",      name: "Steel Guitar",       emoji: "🎸", program: 25,  category: .guitar),
    SoundFontInstrument(id: "jazz_guitar",       name: "Jazz Guitar",        emoji: "🎸", program: 26,  category: .guitar),
    SoundFontInstrument(id: "clean_guitar",      name: "Clean Guitar",       emoji: "🎸", program: 27,  category: .guitar),
    SoundFontInstrument(id: "muted_guitar",      name: "Muted Guitar",       emoji: "🎸", program: 28,  category: .guitar),
    SoundFontInstrument(id: "overdrive_guitar",  name: "Overdrive Guitar",   emoji: "🎸", program: 29,  category: .guitar),
    SoundFontInstrument(id: "distortion_guitar", name: "Distortion Guitar",  emoji: "🎸", program: 30,  category: .guitar),
    SoundFontInstrument(id: "guitar_harmonics",  name: "Guitar Harmonics",   emoji: "🎸", program: 31,  category: .guitar),

    // Bass (32–39)
    SoundFontInstrument(id: "acoustic_bass",     name: "Upright Bass",       emoji: "🎻", program: 32,  category: .bass),
    SoundFontInstrument(id: "fingered_bass",     name: "Fingered Bass",      emoji: "🎸", program: 33,  category: .bass),
    SoundFontInstrument(id: "picked_bass",       name: "Picked Bass",        emoji: "🎸", program: 34,  category: .bass),
    SoundFontInstrument(id: "fretless_bass",     name: "Fretless Bass",      emoji: "🎸", program: 35,  category: .bass),
    SoundFontInstrument(id: "slap_bass_1",       name: "Slap Bass 1",        emoji: "🎸", program: 36,  category: .bass),
    SoundFontInstrument(id: "slap_bass_2",       name: "Slap Bass 2",        emoji: "🎸", program: 37,  category: .bass),
    SoundFontInstrument(id: "synth_bass_1",      name: "Synth Bass 1",       emoji: "🎛️", program: 38,  category: .bass),
    SoundFontInstrument(id: "synth_bass_2",      name: "Synth Bass 2",       emoji: "🎛️", program: 39,  category: .bass),

    // Strings (40–47)
    SoundFontInstrument(id: "violin",            name: "Violin",             emoji: "🎻", program: 40,  category: .strings),
    SoundFontInstrument(id: "viola",             name: "Viola",              emoji: "🎻", program: 41,  category: .strings),
    SoundFontInstrument(id: "cello",             name: "Cello",              emoji: "🎻", program: 42,  category: .strings),
    SoundFontInstrument(id: "contrabass",        name: "Contrabass",         emoji: "🎻", program: 43,  category: .strings),
    SoundFontInstrument(id: "tremolo_strings",   name: "Tremolo Strings",    emoji: "🎻", program: 44,  category: .strings),
    SoundFontInstrument(id: "pizzicato",         name: "Pizzicato",          emoji: "🎻", program: 45,  category: .strings),
    SoundFontInstrument(id: "harp",              name: "Orchestral Harp",    emoji: "🪕", program: 46,  category: .strings),
    SoundFontInstrument(id: "timpani",           name: "Timpani",            emoji: "🪘", program: 47,  category: .strings),

    // Ensemble (48–55)
    SoundFontInstrument(id: "strings",           name: "Strings Ensemble",   emoji: "🎻", program: 48,  category: .ensemble),
    SoundFontInstrument(id: "strings_slow",      name: "Slow Strings",       emoji: "🎻", program: 49,  category: .ensemble),
    SoundFontInstrument(id: "synth_strings_1",   name: "Synth Strings 1",    emoji: "🎻", program: 50,  category: .ensemble),
    SoundFontInstrument(id: "synth_strings_2",   name: "Synth Strings 2",    emoji: "🎻", program: 51,  category: .ensemble),
    SoundFontInstrument(id: "choir",             name: "Choir Aahs",         emoji: "👥", program: 52,  category: .ensemble),
    SoundFontInstrument(id: "voice_oohs",        name: "Voice Oohs",         emoji: "👥", program: 53,  category: .ensemble),
    SoundFontInstrument(id: "synth_voice",       name: "Synth Voice",        emoji: "👥", program: 54,  category: .ensemble),
    SoundFontInstrument(id: "orchestra_hit",     name: "Orchestra Hit",      emoji: "💥", program: 55,  category: .ensemble),

    // Brass (56–63)
    SoundFontInstrument(id: "trumpet",           name: "Trumpet",            emoji: "🎺", program: 56,  category: .brass),
    SoundFontInstrument(id: "trombone",          name: "Trombone",           emoji: "🎺", program: 57,  category: .brass),
    SoundFontInstrument(id: "tuba",              name: "Tuba",               emoji: "🎺", program: 58,  category: .brass),
    SoundFontInstrument(id: "muted_trumpet",     name: "Muted Trumpet",      emoji: "🎺", program: 59,  category: .brass),
    SoundFontInstrument(id: "french_horn",       name: "French Horn",        emoji: "🎺", program: 60,  category: .brass),
    SoundFontInstrument(id: "brass_section",     name: "Brass Section",      emoji: "🎺", program: 61,  category: .brass),
    SoundFontInstrument(id: "synth_brass_1",     name: "Synth Brass 1",      emoji: "🎺", program: 62,  category: .brass),
    SoundFontInstrument(id: "synth_brass_2",     name: "Synth Brass 2",      emoji: "🎺", program: 63,  category: .brass),

    // Reed (64–71)
    SoundFontInstrument(id: "soprano_sax",       name: "Soprano Sax",        emoji: "🎷", program: 64,  category: .reed),
    SoundFontInstrument(id: "alto_sax",          name: "Alto Sax",           emoji: "🎷", program: 65,  category: .reed),
    SoundFontInstrument(id: "tenor_sax",         name: "Tenor Sax",          emoji: "🎷", program: 66,  category: .reed),
    SoundFontInstrument(id: "baritone_sax",      name: "Baritone Sax",       emoji: "🎷", program: 67,  category: .reed),
    SoundFontInstrument(id: "oboe",              name: "Oboe",               emoji: "🪈", program: 68,  category: .reed),
    SoundFontInstrument(id: "english_horn",      name: "English Horn",       emoji: "🪈", program: 69,  category: .reed),
    SoundFontInstrument(id: "bassoon",           name: "Bassoon",            emoji: "🪈", program: 70,  category: .reed),
    SoundFontInstrument(id: "clarinet",          name: "Clarinet",           emoji: "🎷", program: 71,  category: .reed),

    // Pipe (72–79)
    SoundFontInstrument(id: "piccolo",           name: "Piccolo",            emoji: "🪈", program: 72,  category: .pipe),
    SoundFontInstrument(id: "flute",             name: "Flute",              emoji: "🪈", program: 73,  category: .pipe),
    SoundFontInstrument(id: "recorder",          name: "Recorder",           emoji: "🪈", program: 74,  category: .pipe),
    SoundFontInstrument(id: "pan_flute",         name: "Pan Flute",          emoji: "🪈", program: 75,  category: .pipe),
    SoundFontInstrument(id: "blown_bottle",      name: "Blown Bottle",       emoji: "🍾", program: 76,  category: .pipe),
    SoundFontInstrument(id: "shakuhachi",        name: "Shakuhachi",         emoji: "🪈", program: 77,  category: .pipe),
    SoundFontInstrument(id: "whistle",           name: "Whistle",            emoji: "😗", program: 78,  category: .pipe),
    SoundFontInstrument(id: "ocarina",           name: "Ocarina",            emoji: "🪈", program: 79,  category: .pipe),

    // Synth Lead (80–87)
    SoundFontInstrument(id: "lead_square",       name: "Square Lead",        emoji: "⬜", program: 80,  category: .synthLead),
    SoundFontInstrument(id: "lead_saw",          name: "Saw Lead",           emoji: "🪚", program: 81,  category: .synthLead),
    SoundFontInstrument(id: "lead_calliope",     name: "Calliope",           emoji: "🎠", program: 82,  category: .synthLead),
    SoundFontInstrument(id: "lead_chiff",        name: "Chiff Lead",         emoji: "🌬️", program: 83,  category: .synthLead),
    SoundFontInstrument(id: "lead_charang",      name: "Charang",            emoji: "🎛️", program: 84,  category: .synthLead),
    SoundFontInstrument(id: "lead_voice",        name: "Voice Lead",         emoji: "👤", program: 85,  category: .synthLead),
    SoundFontInstrument(id: "lead_fifths",       name: "Fifths Lead",        emoji: "🌊", program: 86,  category: .synthLead),
    SoundFontInstrument(id: "lead_bass_lead",    name: "Bass + Lead",        emoji: "🎛️", program: 87,  category: .synthLead),

    // Synth Pad (88–95)
    SoundFontInstrument(id: "pad_new_age",       name: "New Age Pad",        emoji: "🌌", program: 88,  category: .synthPad),
    SoundFontInstrument(id: "warm_pad",          name: "Warm Pad",           emoji: "🌫️", program: 89,  category: .synthPad),
    SoundFontInstrument(id: "pad_polysynth",     name: "Polysynth Pad",      emoji: "🌫️", program: 90,  category: .synthPad),
    SoundFontInstrument(id: "pad_choir",         name: "Choir Pad",          emoji: "👥", program: 91,  category: .synthPad),
    SoundFontInstrument(id: "pad_bowed",         name: "Bowed Pad",          emoji: "🌫️", program: 92,  category: .synthPad),
    SoundFontInstrument(id: "pad_metallic",      name: "Metallic Pad",       emoji: "⚙️", program: 93,  category: .synthPad),
    SoundFontInstrument(id: "pad_halo",          name: "Halo Pad",           emoji: "😇", program: 94,  category: .synthPad),
    SoundFontInstrument(id: "pad_sweep",         name: "Sweep Pad",          emoji: "🌪️", program: 95,  category: .synthPad),

    // Synth Effects (96–103)
    SoundFontInstrument(id: "fx_rain",           name: "Rain",               emoji: "🌧️", program: 96,  category: .synthFX),
    SoundFontInstrument(id: "fx_soundtrack",     name: "Soundtrack",         emoji: "🎬", program: 97,  category: .synthFX),
    SoundFontInstrument(id: "fx_crystal",        name: "Crystal",            emoji: "💎", program: 98,  category: .synthFX),
    SoundFontInstrument(id: "fx_atmosphere",     name: "Atmosphere",         emoji: "🌌", program: 99,  category: .synthFX),
    SoundFontInstrument(id: "fx_brightness",     name: "Brightness",         emoji: "🌟", program: 100, category: .synthFX),
    SoundFontInstrument(id: "fx_goblins",        name: "Goblins",            emoji: "👹", program: 101, category: .synthFX),
    SoundFontInstrument(id: "fx_echoes",         name: "Echoes",             emoji: "🔊", program: 102, category: .synthFX),
    SoundFontInstrument(id: "fx_sci_fi",         name: "Sci-Fi",             emoji: "🛸", program: 103, category: .synthFX),

    // Ethnic (104–111)
    SoundFontInstrument(id: "sitar",             name: "Sitar",              emoji: "🪕", program: 104, category: .ethnic),
    SoundFontInstrument(id: "banjo",             name: "Banjo",              emoji: "🪕", program: 105, category: .ethnic),
    SoundFontInstrument(id: "shamisen",          name: "Shamisen",           emoji: "🪕", program: 106, category: .ethnic),
    SoundFontInstrument(id: "koto",              name: "Koto",               emoji: "🪕", program: 107, category: .ethnic),
    SoundFontInstrument(id: "kalimba",           name: "Kalimba",            emoji: "🎼", program: 108, category: .ethnic),
    SoundFontInstrument(id: "bagpipe",           name: "Bagpipe",            emoji: "🪈", program: 109, category: .ethnic),
    SoundFontInstrument(id: "fiddle",            name: "Fiddle",             emoji: "🎻", program: 110, category: .ethnic),
    SoundFontInstrument(id: "shanai",            name: "Shanai",             emoji: "🪈", program: 111, category: .ethnic),

    // Percussive (112–119)
    SoundFontInstrument(id: "tinkle_bell",       name: "Tinkle Bell",        emoji: "🔔", program: 112, category: .percussive),
    SoundFontInstrument(id: "agogo",             name: "Agogo",              emoji: "🛎️", program: 113, category: .percussive),
    SoundFontInstrument(id: "steel_drums",       name: "Steel Drums",        emoji: "🥁", program: 114, category: .percussive),
    SoundFontInstrument(id: "woodblock",         name: "Woodblock",          emoji: "🪵", program: 115, category: .percussive),
    SoundFontInstrument(id: "taiko",             name: "Taiko",              emoji: "🪘", program: 116, category: .percussive),
    SoundFontInstrument(id: "melodic_tom",       name: "Melodic Tom",        emoji: "🥁", program: 117, category: .percussive),
    SoundFontInstrument(id: "synth_drum",        name: "Synth Drum",         emoji: "🥁", program: 118, category: .percussive),
    SoundFontInstrument(id: "reverse_cymbal",    name: "Reverse Cymbal",     emoji: "🌀", program: 119, category: .percussive),

    // Sound Effects (120–127)
    SoundFontInstrument(id: "fret_noise",        name: "Fret Noise",         emoji: "🎸", program: 120, category: .soundFX),
    SoundFontInstrument(id: "breath_noise",      name: "Breath Noise",       emoji: "💨", program: 121, category: .soundFX),
    SoundFontInstrument(id: "seashore",          name: "Seashore",           emoji: "🌊", program: 122, category: .soundFX),
    SoundFontInstrument(id: "bird_tweet",        name: "Bird Tweet",         emoji: "🐦", program: 123, category: .soundFX),
    SoundFontInstrument(id: "telephone",         name: "Telephone",          emoji: "📞", program: 124, category: .soundFX),
    SoundFontInstrument(id: "helicopter",        name: "Helicopter",         emoji: "🚁", program: 125, category: .soundFX),
    SoundFontInstrument(id: "applause",          name: "Applause",           emoji: "👏", program: 126, category: .soundFX),
    SoundFontInstrument(id: "gunshot",           name: "Gunshot",            emoji: "💥", program: 127, category: .soundFX),
]

let DEFAULT_SOUNDFONT_INSTRUMENT: SoundFontInstrument =
    SOUNDFONT_INSTRUMENTS.first(where: { $0.id == "violin" }) ?? SOUNDFONT_INSTRUMENTS[0]

/// Look up an instrument by id, falling back to the default.
func soundFontInstrument(id: String) -> SoundFontInstrument {
    SOUNDFONT_INSTRUMENTS.first { $0.id == id } ?? DEFAULT_SOUNDFONT_INSTRUMENT
}
