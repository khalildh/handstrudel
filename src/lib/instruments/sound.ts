// A post's sound (`sound_setup`, written by iOS `SoundSetup`) resolved for the
// web wheel: key, scale, progression, tempo, voicing and the Strudel sound
// that best matches the iOS instrument. Instruments never choose any of this.

import { CHORD_PROGRESSIONS, IOS_KEY_SEMITONES, IOS_SCALE_INTERVALS } from "../music-data.generated.ts";
import type { ChordVoicing } from "./rules.ts";

/** A Strudel/superdough sound plus any synth parameters that shape it. */
export interface StrudelSound {
  /** Name passed to `s`, e.g. "gm_piano" or "sawtooth". */
  s: string;
  /** Extra superdough controls (envelope, FM). */
  params?: Record<string, number>;
  /** Why this isn't an exact match, when it isn't. */
  approximation?: string;
}

export interface WheelSound {
  keyName: string;
  key: number;
  scaleName: string;
  scale: number[];
  progressionName: string;
  /** Scale degree for each chord wedge, top of the arc first. */
  degrees: number[];
  bpm: number;
  /** The sound's own voicing, when it sets one; otherwise the wheel's default applies. */
  voicing?: ChordVoicing;
  /** iOS mode the post was recorded in, e.g. "scalechordmelody". */
  mode: string | null;
  sound: StrudelSound;
  /** Human label for the sound ("Grand Piano", "Saw"). */
  soundLabel: string;
}

/**
 * iOS SoundFont ids (`SOUNDFONT_INSTRUMENTS`) to @strudel/soundfonts names.
 * Both follow General MIDI program order, so each id maps to the same program.
 * The Strudel set has a single acoustic piano for GM programs 0–3, so Bright
 * Piano, Electric Grand and Honky-tonk play `gm_piano`. Everything else is exact.
 */
export const SOUNDFONT_SOUNDS: Record<string, string> = {
  grand_piano: "gm_piano",
  bright_piano: "gm_piano",
  electric_grand: "gm_piano",
  honky_tonk: "gm_piano",
  electric_piano_1: "gm_epiano1",
  electric_piano_2: "gm_epiano2",
  harpsichord: "gm_harpsichord",
  clavinet: "gm_clavinet",
  celesta: "gm_celesta",
  glockenspiel: "gm_glockenspiel",
  music_box: "gm_music_box",
  vibraphone: "gm_vibraphone",
  marimba: "gm_marimba",
  xylophone: "gm_xylophone",
  tubular_bells: "gm_tubular_bells",
  dulcimer: "gm_dulcimer",
  drawbar_organ: "gm_drawbar_organ",
  percussive_organ: "gm_percussive_organ",
  rock_organ: "gm_rock_organ",
  church_organ: "gm_church_organ",
  reed_organ: "gm_reed_organ",
  accordion: "gm_accordion",
  harmonica: "gm_harmonica",
  tango_accordion: "gm_bandoneon",
  nylon_guitar: "gm_acoustic_guitar_nylon",
  steel_guitar: "gm_acoustic_guitar_steel",
  jazz_guitar: "gm_electric_guitar_jazz",
  clean_guitar: "gm_electric_guitar_clean",
  muted_guitar: "gm_electric_guitar_muted",
  overdrive_guitar: "gm_overdriven_guitar",
  distortion_guitar: "gm_distortion_guitar",
  guitar_harmonics: "gm_guitar_harmonics",
  acoustic_bass: "gm_acoustic_bass",
  fingered_bass: "gm_electric_bass_finger",
  picked_bass: "gm_electric_bass_pick",
  fretless_bass: "gm_fretless_bass",
  slap_bass_1: "gm_slap_bass_1",
  slap_bass_2: "gm_slap_bass_2",
  synth_bass_1: "gm_synth_bass_1",
  synth_bass_2: "gm_synth_bass_2",
  violin: "gm_violin",
  viola: "gm_viola",
  cello: "gm_cello",
  contrabass: "gm_contrabass",
  tremolo_strings: "gm_tremolo_strings",
  pizzicato: "gm_pizzicato_strings",
  harp: "gm_orchestral_harp",
  timpani: "gm_timpani",
  strings: "gm_string_ensemble_1",
  strings_slow: "gm_string_ensemble_2",
  synth_strings_1: "gm_synth_strings_1",
  synth_strings_2: "gm_synth_strings_2",
  choir: "gm_choir_aahs",
  voice_oohs: "gm_voice_oohs",
  synth_voice: "gm_synth_choir",
  orchestra_hit: "gm_orchestra_hit",
  trumpet: "gm_trumpet",
  trombone: "gm_trombone",
  tuba: "gm_tuba",
  muted_trumpet: "gm_muted_trumpet",
  french_horn: "gm_french_horn",
  brass_section: "gm_brass_section",
  synth_brass_1: "gm_synth_brass_1",
  synth_brass_2: "gm_synth_brass_2",
  soprano_sax: "gm_soprano_sax",
  alto_sax: "gm_alto_sax",
  tenor_sax: "gm_tenor_sax",
  baritone_sax: "gm_baritone_sax",
  oboe: "gm_oboe",
  english_horn: "gm_english_horn",
  bassoon: "gm_bassoon",
  clarinet: "gm_clarinet",
  piccolo: "gm_piccolo",
  flute: "gm_flute",
  recorder: "gm_recorder",
  pan_flute: "gm_pan_flute",
  blown_bottle: "gm_blown_bottle",
  shakuhachi: "gm_shakuhachi",
  whistle: "gm_whistle",
  ocarina: "gm_ocarina",
  lead_square: "gm_lead_1_square",
  lead_saw: "gm_lead_2_sawtooth",
  lead_calliope: "gm_lead_3_calliope",
  lead_chiff: "gm_lead_4_chiff",
  lead_charang: "gm_lead_5_charang",
  lead_voice: "gm_lead_6_voice",
  lead_fifths: "gm_lead_7_fifths",
  lead_bass_lead: "gm_lead_8_bass_lead",
  pad_new_age: "gm_pad_new_age",
  warm_pad: "gm_pad_warm",
  pad_polysynth: "gm_pad_poly",
  pad_choir: "gm_pad_choir",
  pad_bowed: "gm_pad_bowed",
  pad_metallic: "gm_pad_metallic",
  pad_halo: "gm_pad_halo",
  pad_sweep: "gm_pad_sweep",
  fx_rain: "gm_fx_rain",
  fx_soundtrack: "gm_fx_soundtrack",
  fx_crystal: "gm_fx_crystal",
  fx_atmosphere: "gm_fx_atmosphere",
  fx_brightness: "gm_fx_brightness",
  fx_goblins: "gm_fx_goblins",
  fx_echoes: "gm_fx_echoes",
  fx_sci_fi: "gm_fx_sci_fi",
  sitar: "gm_sitar",
  banjo: "gm_banjo",
  shamisen: "gm_shamisen",
  koto: "gm_koto",
  kalimba: "gm_kalimba",
  bagpipe: "gm_bagpipe",
  fiddle: "gm_fiddle",
  shanai: "gm_shanai",
  tinkle_bell: "gm_tinkle_bell",
  agogo: "gm_agogo",
  steel_drums: "gm_steel_drums",
  woodblock: "gm_woodblock",
  taiko: "gm_taiko_drum",
  melodic_tom: "gm_melodic_tom",
  synth_drum: "gm_synth_drum",
  reverse_cymbal: "gm_reverse_cymbal",
  fret_noise: "gm_guitar_fret_noise",
  breath_noise: "gm_breath_noise",
  seashore: "gm_seashore",
  bird_tweet: "gm_bird_tweet",
  telephone: "gm_telephone",
  helicopter: "gm_helicopter",
  applause: "gm_applause",
  gunshot: "gm_gunshot",
};

const NO_EXACT_PIANO = new Set(["bright_piano", "electric_grand", "honky_tonk"]);

/**
 * iOS synth "waveforms" (`WAVEFORMS` in EngineController.swift) to Strudel.
 * Oscillators match. iOS's bundled sampled instruments map to the closest
 * General MIDI SoundFont; its custom synths to a superdough synth with similar
 * shaping. `approximation` notes every one that isn't the same sound.
 */
export const WAVEFORM_SOUNDS: Record<string, StrudelSound> = {
  sawtooth: { s: "sawtooth" },
  square: { s: "square" },
  triangle: { s: "triangle" },
  sine: { s: "sine" },
  pluck: { s: "triangle", params: { attack: 0.002, decay: 0.25, sustain: 0, release: 0.1 }, approximation: "plucked synth: short triangle" },
  supersaw: { s: "supersaw" },
  pulse: { s: "pulse" },
  fm: { s: "sine", params: { fmi: 3, fmh: 3.5, decay: 0.8, sustain: 0.1 }, approximation: "FM bell: superdough FM sine" },
  piano: { s: "gm_piano" },
  epiano: { s: "gm_epiano1" },
  organ: { s: "gm_drawbar_organ" },
  pipeorgan: { s: "gm_church_organ" },
  strings: { s: "gm_string_ensemble_1" },
  sax: { s: "gm_alto_sax" },
  marimba: { s: "gm_marimba" },
  kalimba: { s: "gm_kalimba" },
  flute: { s: "gm_flute" },
  bells: { s: "gm_tubular_bells" },
  steinway: { s: "gm_piano", approximation: "Steinway sample: GM piano" },
  folkharp: { s: "gm_orchestral_harp", approximation: "folk harp: GM orchestral harp" },
  clavisynth: { s: "gm_clavinet" },
  organ8: { s: "gm_drawbar_organ", approximation: "8' organ: GM drawbar organ" },
  pipeorgan_loud: { s: "gm_church_organ", approximation: "loud pipe organ: GM church organ" },
  harmonica: { s: "gm_harmonica" },
  vibraphone: { s: "gm_vibraphone" },
  tubularbells: { s: "gm_tubular_bells" },
  xylophone: { s: "gm_xylophone" },
  balafon: { s: "gm_marimba", approximation: "balafon: GM marimba" },
  handchimes: { s: "gm_celesta", approximation: "handchimes: GM celesta" },
  dantranh: { s: "gm_koto", approximation: "đàn tranh: GM koto (both long zithers)" },
  ocarina: { s: "gm_ocarina" },
  recorder_soprano: { s: "gm_recorder" },
  recorder_tenor: { s: "gm_recorder", approximation: "tenor recorder: GM recorder" },
  recorder_bass: { s: "gm_recorder", approximation: "bass recorder: GM recorder" },
  saxello: { s: "gm_soprano_sax", approximation: "saxello: GM soprano sax" },
  sax_vib: { s: "gm_tenor_sax", approximation: "sax with vibrato: GM tenor sax" },
  psaltery: { s: "gm_dulcimer", approximation: "psaltery: GM dulcimer" },
  kalimba2: { s: "gm_kalimba", approximation: "second kalimba sample: GM kalimba" },
};

const DEFAULT_SOUND: StrudelSound = { s: "gm_piano" };

const titleCase = (id: string) => id.split("_").map((part) => part[0]?.toUpperCase() + part.slice(1)).join(" ");

/** The Strudel sound for a post: its SoundFont when it used one, otherwise its synth. */
export function resolveStrudelSound(setup: { useSoundFont?: unknown; instrument?: unknown; waveform?: unknown }): {
  sound: StrudelSound; label: string;
} {
  if (setup.useSoundFont === true && typeof setup.instrument === "string" && Object.hasOwn(SOUNDFONT_SOUNDS, setup.instrument)) {
    const id = setup.instrument;
    return {
      sound: NO_EXACT_PIANO.has(id)
        ? { s: SOUNDFONT_SOUNDS[id], approximation: `${titleCase(id)}: GM piano (no separate Strudel sample)` }
        : { s: SOUNDFONT_SOUNDS[id] },
      label: titleCase(id),
    };
  }
  if (typeof setup.waveform === "string" && Object.hasOwn(WAVEFORM_SOUNDS, setup.waveform)) {
    return { sound: WAVEFORM_SOUNDS[setup.waveform], label: titleCase(setup.waveform) };
  }
  return { sound: DEFAULT_SOUND, label: "Piano" };
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

/** A built-in scale name or an iOS custom scale ({ name, intervals }). */
function resolveScale(value: unknown): { name: string; intervals: number[] } | null {
  if (typeof value === "string") {
    const intervals = IOS_SCALE_INTERVALS.get(value);
    if (!intervals) return null;
    return { name: value === "Pentatonic" ? "Major Pentatonic" : value === "Blues" ? "Minor Blues" : value, intervals };
  }
  if (!isRecord(value)) return null;
  const { name, intervals } = value;
  if (typeof name !== "string" || !name || name.trim() !== name || Array.from(name).length > 40 ||
      /[\u0000-\u001f\u007f-\u009f]/.test(name)) return null;
  if (!Array.isArray(intervals) || intervals.length < 3 || intervals.length > 12 || intervals[0] !== 0 ||
      !intervals.every((n, i) => Number.isInteger(n) && n < 12 && (i === 0 || n > intervals[i - 1]))) return null;
  return { name, intervals: intervals as number[] };
}

function resolveProgression(setup: Record<string, unknown>): { name: string; degrees: number[] } {
  const free = CHORD_PROGRESSIONS.get("free")!;
  if (setup.progression === "custom") {
    const degrees = setup.customDegrees;
    if (Array.isArray(degrees) && degrees.length >= 1 && degrees.length <= 64 &&
        degrees.every((d) => Number.isInteger(d) && d >= 0 && d <= 6)) {
      return { name: "Custom", degrees: degrees as number[] };
    }
    return { name: free.name, degrees: free.degrees };
  }
  const preset = typeof setup.progression === "string" ? CHORD_PROGRESSIONS.get(setup.progression) : undefined;
  return preset ?? { name: free.name, degrees: free.degrees };
}

/**
 * Read a post's `sound_setup` defensively (it is untrusted data). Anything
 * missing or invalid falls back to C Major, the Free layout, 100 BPM and piano.
 */
export function resolveWheelSound(value: unknown): WheelSound {
  const setup = isRecord(value) && value.version === 1 ? value : {};
  const keyName = typeof setup.key === "string" && IOS_KEY_SEMITONES.has(setup.key) ? setup.key : "C";
  const scale = resolveScale(setup.scale) ?? { name: "Major", intervals: IOS_SCALE_INTERVALS.get("Major")! };
  const progression = resolveProgression(setup);
  const bpm = typeof setup.bpm === "number" && setup.bpm >= 20 && setup.bpm <= 400 ? setup.bpm : 100;
  // iOS writes `chordVoicing` only when the player chose something other than the wheel's default.
  const voicing = setup.chordVoicing === "triad" || setup.chordVoicing === "seventh" ? setup.chordVoicing : undefined;
  const { sound, label } = resolveStrudelSound(setup);
  return {
    keyName, key: IOS_KEY_SEMITONES.get(keyName)!, scaleName: scale.name, scale: [...scale.intervals],
    progressionName: progression.name, degrees: [...progression.degrees], bpm, voicing,
    mode: typeof setup.mode === "string" ? setup.mode : null, sound, soundLabel: label,
  };
}
