package com.handstrudel.models

/// A General MIDI instrument selectable in SoundFont mode. `program` is the
/// 0-based GM program number — the same value TinySoundFont uses for the
/// `preset` argument of note_on / note_off, and identical to the patches in
/// any GM-compliant `.sf2`.
data class SoundFontInstrument(
    val id: String,
    val name: String,
    val emoji: String,
    val program: Int,
)

/// Curated subset of the GM bank — one or two per family so the picker stays
/// scannable. Order roughly follows the GM program-number layout so the rows
/// progress piano → guitar → bass → strings → reed → pipe → synth.
val SOUNDFONT_INSTRUMENTS: List<SoundFontInstrument> = listOf(
    SoundFontInstrument("grand_piano",      "Grand Piano",     "🎹", 0),
    SoundFontInstrument("rhodes",           "Rhodes EP",       "🎛️", 4),
    SoundFontInstrument("harpsichord",      "Harpsichord",     "🎼", 6),
    SoundFontInstrument("marimba",          "Marimba",         "🪵", 12),
    SoundFontInstrument("vibraphone",       "Vibraphone",      "🔔", 11),
    SoundFontInstrument("organ",            "Drawbar Organ",   "🎚️", 16),
    SoundFontInstrument("church_organ",     "Church Organ",    "⛪", 19),
    SoundFontInstrument("nylon_guitar",     "Nylon Guitar",    "🎸", 24),
    SoundFontInstrument("clean_guitar",     "Clean Guitar",    "🎸", 27),
    SoundFontInstrument("finger_bass",      "Finger Bass",     "🎻", 33),
    SoundFontInstrument("violin",           "Violin",          "🎻", 40),
    SoundFontInstrument("strings",          "Strings",         "🎻", 48),
    SoundFontInstrument("choir",            "Choir",           "👥", 52),
    SoundFontInstrument("trumpet",          "Trumpet",         "🎺", 56),
    SoundFontInstrument("alto_sax",         "Alto Sax",        "🎷", 65),
    SoundFontInstrument("flute",            "Flute",           "🪈", 73),
    SoundFontInstrument("square_lead",      "Square Lead",     "🌊", 80),
    SoundFontInstrument("sawtooth_lead",    "Saw Lead",        "🌊", 81),
    SoundFontInstrument("warm_pad",         "Warm Pad",        "🌫️", 89),
    SoundFontInstrument("kalimba",          "Kalimba",         "🪕", 108),
)

val DEFAULT_SOUNDFONT_INSTRUMENT: SoundFontInstrument = SOUNDFONT_INSTRUMENTS[0]
