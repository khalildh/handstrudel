// Sound for web instruments through Strudel's audio engine (superdough, from
// @strudel/webaudio), with the same SoundFonts and synths the Web Studio
// registers. Notes are triggered directly: nothing from a post is evaluated as
// code. Every trigger is also announced as a `handstrudel:wheel-play` window
// event, which the browser tests listen to.

import { midiToStrudelNote } from "./rules.ts";
import type { StrudelSound } from "./sound.ts";

export interface WheelPlayDetail {
  kind: "chord" | "note";
  midi: number[];
  notes: string[];
  s: string;
  duration: number;
}

export const WHEEL_PLAY_EVENT = "handstrudel:wheel-play";

type Superdough = (value: Record<string, unknown>, t: number, duration: number) => Promise<void>;
interface AudioEngine { superdough: Superdough; context: AudioContext }

let engine: Promise<AudioEngine> | null = null;

/**
 * Load and start the audio engine. Call it synchronously from a click or tap:
 * Safari only lets audio start inside the gesture, so the AudioContext is
 * created and resumed here before the engine itself loads.
 */
export function startWheelAudio(): Promise<AudioEngine> {
  if (!engine) {
    let unlocked: AudioContext | null = null;
    try {
      unlocked = new AudioContext({ latencyHint: "interactive" });
      void unlocked.resume().catch(() => {});
    } catch {
      unlocked = null;
    }
    engine = (async () => {
      const [webaudio, soundfonts] = await Promise.all([import("@strudel/webaudio"), import("@strudel/soundfonts")]);
      if (unlocked) webaudio.setAudioContext(unlocked);
      webaudio.registerSynthSounds();
      soundfonts.registerSoundfonts();
      await webaudio.initAudio();
      const context = webaudio.getAudioContext();
      if (context.state === "suspended") await context.resume().catch(() => {});
      return { superdough: webaudio.superdough, context };
    })();
    engine.catch(() => { engine = null; });
  }
  return engine;
}

/** How long a strike rings: two beats for chords, one for notes, within sensible bounds. */
export function strikeLength(kind: "chord" | "note", bpm: number) {
  const beat = 60 / bpm;
  return kind === "chord" ? Math.min(2.4, Math.max(0.6, beat * 2)) : Math.min(1.2, Math.max(0.25, beat));
}

/** Fetch a SoundFont's samples ahead of the first note by playing it silently. */
export async function warmUpSound(sound: StrudelSound) {
  const { superdough, context } = await startWheelAudio();
  try {
    await superdough({ s: sound.s, note: 60, gain: 0, ...sound.params }, context.currentTime + 0.05, 0.05);
  } catch {
    // The real note reports its own failure.
  }
}

export async function playWheelStrike(kind: "chord" | "note", midi: number[], sound: StrudelSound, bpm: number) {
  const duration = strikeLength(kind, bpm);
  const detail: WheelPlayDetail = { kind, midi, notes: midi.map(midiToStrudelNote), s: sound.s, duration };
  window.dispatchEvent(new CustomEvent<WheelPlayDetail>(WHEEL_PLAY_EVENT, { detail }));
  const { superdough, context } = await startWheelAudio();
  const at = context.currentTime + 0.01;
  const gain = kind === "chord" ? 0.45 : 0.7;
  await Promise.all(midi.map(async (note) => {
    try {
      await superdough({ s: sound.s, note, gain, release: 0.25, ...sound.params }, at, duration);
    } catch (error) {
      console.warn("[instrument] couldn't play", sound.s, error);
    }
  }));
}
