import Foundation

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

    var displayName: String { "\(emoji) \(name)" }
}

/// Curated set of GM instruments that suit the chord-pad + melody interaction.
/// Order roughly groups keys, mallets, plucked, bowed/ensemble, winds, pads.
let SOUNDFONT_INSTRUMENTS: [SoundFontInstrument] = [
    SoundFontInstrument(id: "grand_piano",   name: "Grand Piano",   emoji: "🎹", program: 0),
    SoundFontInstrument(id: "electric_piano", name: "Electric Piano", emoji: "🎛️", program: 4),
    SoundFontInstrument(id: "harpsichord",   name: "Harpsichord",   emoji: "🎼", program: 6),
    SoundFontInstrument(id: "celesta",       name: "Celesta",       emoji: "✨", program: 8),
    SoundFontInstrument(id: "vibraphone",    name: "Vibraphone",    emoji: "🔔", program: 11),
    SoundFontInstrument(id: "marimba",       name: "Marimba",       emoji: "🪘", program: 12),
    SoundFontInstrument(id: "music_box",     name: "Music Box",     emoji: "🎶", program: 10),
    SoundFontInstrument(id: "nylon_guitar",  name: "Nylon Guitar",  emoji: "🎸", program: 24),
    SoundFontInstrument(id: "steel_guitar",  name: "Steel Guitar",  emoji: "🎸", program: 25),
    SoundFontInstrument(id: "harp",          name: "Harp",          emoji: "🪕", program: 46),
    SoundFontInstrument(id: "acoustic_bass", name: "Upright Bass",  emoji: "🎻", program: 32),
    SoundFontInstrument(id: "violin",        name: "Violin",        emoji: "🎻", program: 40),
    SoundFontInstrument(id: "cello",         name: "Cello",         emoji: "🎻", program: 42),
    SoundFontInstrument(id: "strings",       name: "Strings",       emoji: "🎻", program: 48),
    SoundFontInstrument(id: "pizzicato",     name: "Pizzicato",     emoji: "🎻", program: 45),
    SoundFontInstrument(id: "choir",         name: "Choir",         emoji: "👥", program: 52),
    SoundFontInstrument(id: "church_organ",  name: "Church Organ",  emoji: "⛪️", program: 19),
    SoundFontInstrument(id: "flute",         name: "Flute",         emoji: "🪈", program: 73),
    SoundFontInstrument(id: "pan_flute",     name: "Pan Flute",     emoji: "🪈", program: 75),
    SoundFontInstrument(id: "clarinet",      name: "Clarinet",      emoji: "🎷", program: 71),
    SoundFontInstrument(id: "trumpet",       name: "Trumpet",       emoji: "🎺", program: 56),
    SoundFontInstrument(id: "warm_pad",      name: "Warm Pad",      emoji: "🌫️", program: 89),
    SoundFontInstrument(id: "sitar",         name: "Sitar",         emoji: "🪕", program: 104),
    SoundFontInstrument(id: "kalimba",       name: "Kalimba",       emoji: "🎼", program: 108),
]

let DEFAULT_SOUNDFONT_INSTRUMENT = SOUNDFONT_INSTRUMENTS[0]

/// Look up an instrument by id, falling back to the default.
func soundFontInstrument(id: String) -> SoundFontInstrument {
    SOUNDFONT_INSTRUMENTS.first { $0.id == id } ?? DEFAULT_SOUNDFONT_INSTRUMENT
}
