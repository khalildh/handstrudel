/**
 * Jev director — the "what next?" layer above the 60fps mapping loop.
 *
 * The hot path (hand axis → param → Strudel signal) stays exactly as it was:
 * it is continuous control, not a decision, and a 70–500ms round trip has no
 * place in a 16ms frame budget. What this layer replaces is the part of the app
 * that was blind to the performance — the struct pattern that rotated
 * round-robin every 8 seconds, and the instrument gesture that walked the
 * INSTRUMENTS array in index order.
 *
 * Timing: at each rotation boundary we apply the decision fetched during the
 * *previous* window and immediately ask for the next one. That gives Jev a full
 * 8 seconds of slack, so its latency is never on anyone's critical path. If the
 * answer is late, missing, or the network is down, the caller falls back to the
 * original round-robin — the feature can only ever add, never stall.
 */

import { askJev, jevReady, sampleChoice, JevError, type JevAnswer, type JevChoice, type JevConfig } from "./jev";
import { HandsState } from "./hand-mapping";
import { INSTRUMENTS, MusicParams, NOTE_DISPLAY, PARAM_MAP } from "./music";
import { NOTES, STRUCTS } from "./music-data.generated";

/* ── Struct labels ───────────────────────────────────── */

/**
 * Human-readable names for the patterns in STRUCTS, so Jev has something
 * semantic to choose between rather than mini-notation. Index-aligned; anything
 * beyond the list falls back to the raw pattern (STRUCTS is generated from
 * shared/music-config.json and can grow).
 */
const STRUCT_LABELS = [
  "steady pulse — even eighths, no surprises",
  "sparse — off-beat and dotted, lots of air",
  "busy — dense and driving",
  "burst — a triplet flurry, then silence",
  "loose — irregular, shuffling",
];

function structLabel(i: number): string {
  return STRUCT_LABELS[i] ?? `pattern ${i + 1} (${STRUCTS[i]})`;
}

const STRUCT_OPTIONS = STRUCTS.map((_, i) => structLabel(i));
const INSTRUMENT_OPTIONS = INSTRUMENTS.map((i) => i.label);

/* ── Gesture accumulation ────────────────────────────── */

/** Normalise a param to 0–1 within its declared range. */
function norm(id: string, v: number | undefined): number {
  const def = PARAM_MAP[id];
  if (!def || v === undefined) return 0;
  const t = (v - def.min) / (def.max - def.min);
  return t < 0 ? 0 : t > 1 ? 1 : t;
}

const r2 = (v: number) => Math.round(v * 100) / 100;

interface Accum {
  frames: number;
  leftFrames: number;
  rightFrames: number;
  motion: number;
  sumNote: number;
  minNote: number;
  maxNote: number;
  sumBpm: number;
  sumGain: number;
  sumBright: number;
  sumSpace: number;
  sumGrit: number;
  prevNote: number;
  prevBright: number;
  prevGain: number;
  havePrev: boolean;
}

function emptyAccum(): Accum {
  return {
    frames: 0, leftFrames: 0, rightFrames: 0, motion: 0,
    sumNote: 0, minNote: Infinity, maxNote: -Infinity,
    sumBpm: 0, sumGain: 0, sumBright: 0, sumSpace: 0, sumGrit: 0,
    prevNote: 0, prevBright: 0, prevGain: 0, havePrev: false,
  };
}

/** Summary of one window, sent to Jev as application state. */
export interface JevGestureState {
  hands: "none" | "left" | "right" | "both";
  motion: "still" | "drifting" | "moving" | "dancing";
  pitch_center: string;
  pitch_span_steps: number;
  tempo_bpm: number;
  loudness: number;
  brightness: number;
  space: number;
  grit: number;
  current_pattern: string;
  current_sound: string;
  recent_patterns: string[];
  recent_sounds: string[];
}

function motionBand(perFrame: number): JevGestureState["motion"] {
  if (perFrame < 0.002) return "still";
  if (perFrame < 0.008) return "drifting";
  if (perFrame < 0.02) return "moving";
  return "dancing";
}

/* ── Status (for the sidebar) ────────────────────────── */

export interface JevStatus {
  phase: "off" | "idle" | "asking" | "ok" | "error";
  message: string;
  patternChoice: string | null;
  patternConfidence: number;
  instrumentId: string | null;
  instrumentLabel: string | null;
  instrumentConfidence: number;
  latencyMs: number;
  calls: number;
}

export const IDLE_JEV_STATUS: JevStatus = {
  phase: "off",
  message: "off",
  patternChoice: null,
  patternConfidence: 0,
  instrumentId: null,
  instrumentLabel: null,
  instrumentConfidence: 0,
  latencyMs: 0,
  calls: 0,
};

/* ── Director ────────────────────────────────────────── */

export interface JevDirector {
  /** Cheap per-frame accumulation. Called from the 60fps loop. */
  sample(hands: HandsState, smoothed: MusicParams): void;
  /** The struct index Jev picked for this window, or null to round-robin. */
  takeStruct(): number | null;
  /** Latest suggested instrument id, or null. Never applied automatically. */
  suggestedInstrument(): string | null;
  /** Close the window, then prefetch the decision for the next one. */
  beginWindow(currentStructIdx: number, currentInstrument: string): void;
  status(): JevStatus;
  setConfig(cfg: JevConfig): void;
  dispose(): void;
}

const HISTORY = 3;

export function createJevDirector(initial: JevConfig): JevDirector {
  let cfg = initial;
  let accum = emptyAccum();
  let pendingStruct: number | null = null;
  let suggested: string | null = null;
  let recentPatterns: string[] = [];
  let recentSounds: string[] = [];
  let generation = 0;
  let disposed = false;

  let status: JevStatus = {
    phase: jevReady(cfg) ? "idle" : "off",
    message: jevReady(cfg) ? "waiting for first window" : "off",
    patternChoice: null,
    patternConfidence: 0,
    instrumentId: null,
    instrumentLabel: null,
    instrumentConfidence: 0,
    latencyMs: 0,
    calls: 0,
  };

  function summarize(structIdx: number, instrumentId: string): JevGestureState {
    const n = Math.max(1, accum.frames);
    const inst = INSTRUMENTS.find((i) => i.id === instrumentId);
    const noteAvg = accum.sumNote / n;
    const noteIdx = Math.max(0, Math.min(NOTES.length - 1, Math.round(noteAvg)));
    const span =
      accum.maxNote >= accum.minNote ? Math.round(accum.maxNote - accum.minNote) : 0;

    return {
      hands:
        accum.leftFrames > n * 0.2 && accum.rightFrames > n * 0.2 ? "both"
        : accum.leftFrames > n * 0.2 ? "left"
        : accum.rightFrames > n * 0.2 ? "right"
        : "none",
      motion: motionBand(accum.motion / n),
      pitch_center: NOTE_DISPLAY[noteIdx],
      pitch_span_steps: span,
      tempo_bpm: Math.round(accum.sumBpm / n),
      loudness: r2(accum.sumGain / n),
      brightness: r2(accum.sumBright / n),
      space: r2(accum.sumSpace / n),
      grit: r2(accum.sumGrit / n),
      current_pattern: structLabel(structIdx),
      current_sound: inst?.label ?? instrumentId,
      recent_patterns: recentPatterns,
      recent_sounds: recentSounds,
    };
  }

  function buildQuestions(): JevChoice[] {
    // These two are independent, so they go in one request and are answered in
    // parallel. Both are conditioned on the same state, which is what keeps the
    // pair coherent without either being able to see the other's answer.
    return [
      {
        id: "pattern",
        question:
          "A musician is playing a live instrument with hand gestures in front of a webcam. " +
          "The state describes what their hands and the sound have been doing for the last 8 seconds. " +
          "Which rhythmic pattern should the melody switch to now, so the music answers how they are playing?",
        options: STRUCT_OPTIONS,
      },
      {
        id: "sound",
        question:
          "Same performance. Which instrument would best suit the way they are playing right now? " +
          "Prefer a sound that fits the movement, tempo, brightness and register described in the state.",
        options: INSTRUMENT_OPTIONS,
      },
    ];
  }

  function applyResult(
    answers: Record<string, JevAnswer>,
    latencyMs: number,
    currentSoundLabel: string,
  ): void {
    const pattern = answers.pattern;
    if (pattern) {
      // Sample the nucleus rather than taking the argmax, and down-weight what
      // just played — otherwise a steady performance parks on one pattern.
      const picked = sampleChoice(pattern, { avoid: recentPatterns, nucleus: 0.9 });
      const idx = STRUCT_OPTIONS.indexOf(picked);
      if (idx >= 0) {
        pendingStruct = idx;
        status.patternChoice = picked.split(" — ")[0];
        status.patternConfidence = pattern.confidence;
      }
    }

    const sound = answers.sound;
    if (sound) {
      // Avoid the current sound so the instrument gesture always does something.
      const picked = sampleChoice(sound, { avoid: [currentSoundLabel], nucleus: 0.9 });
      const inst = INSTRUMENTS.find((i) => i.label === picked);
      if (inst) {
        suggested = inst.id;
        status.instrumentId = inst.id;
        status.instrumentLabel = inst.label;
        status.instrumentConfidence = sound.confidence;
      }
    }

    status.phase = "ok";
    status.latencyMs = latencyMs;
    status.calls += 1;
    status.message = `${latencyMs}ms`;
  }

  return {
    sample(hands, smoothed) {
      if (!jevReady(cfg) || disposed) return;
      const a = accum;
      a.frames += 1;
      if (hands.left) a.leftFrames += 1;
      if (hands.right) a.rightFrames += 1;

      const note = smoothed.noteIdx ?? 10;
      const bright = norm("lpf", smoothed.lpf);
      const gain = norm("gain", smoothed.gain);

      if (a.havePrev) {
        a.motion +=
          Math.abs(note - a.prevNote) / Math.max(1, NOTES.length - 1) +
          Math.abs(bright - a.prevBright) +
          Math.abs(gain - a.prevGain);
      }
      a.prevNote = note;
      a.prevBright = bright;
      a.prevGain = gain;
      a.havePrev = true;

      a.sumNote += note;
      if (note < a.minNote) a.minNote = note;
      if (note > a.maxNote) a.maxNote = note;
      a.sumBpm += smoothed.bpm ?? 120;
      a.sumGain += gain;
      a.sumBright += bright;
      a.sumSpace += (norm("reverb", smoothed.reverb) + norm("delay", smoothed.delay)) / 2;
      a.sumGrit += (norm("shape", smoothed.shape) + norm("crush", smoothed.crush)) / 2;
    },

    takeStruct() {
      const s = pendingStruct;
      pendingStruct = null;
      return s;
    },

    suggestedInstrument() {
      return suggested;
    },

    beginWindow(currentStructIdx, currentInstrument) {
      if (disposed) return;
      if (!jevReady(cfg)) {
        accum = emptyAccum();
        status = { ...status, phase: "off", message: "off" };
        return;
      }

      const state = summarize(currentStructIdx, currentInstrument);
      const currentSoundLabel = state.current_sound;
      accum = emptyAccum();

      recentPatterns = [state.current_pattern, ...recentPatterns].slice(0, HISTORY);
      recentSounds = [currentSoundLabel, ...recentSounds].slice(0, HISTORY);

      // Anything that arrives after the next window opens is stale and dropped.
      const gen = ++generation;
      status = { ...status, phase: "asking" };

      askJev(cfg, state as unknown as Record<string, unknown>, buildQuestions())
        .then((res) => {
          if (disposed || gen !== generation) return;
          applyResult(res.answers, res.latencyMs, currentSoundLabel);
        })
        .catch((e: unknown) => {
          if (disposed || gen !== generation) return;
          status = {
            ...status,
            phase: "error",
            message: e instanceof JevError ? e.message : "request failed",
          };
        });
    },

    status() {
      return { ...status };
    },

    setConfig(next) {
      cfg = next;
      if (!jevReady(cfg)) {
        pendingStruct = null;
        suggested = null;
        generation += 1; // drop anything in flight
        status = { ...status, phase: "off", message: "off", patternChoice: null, instrumentLabel: null };
      } else if (status.phase === "off") {
        status = { ...status, phase: "idle", message: "waiting for next window" };
      }
    },

    dispose() {
      disposed = true;
    },
  };
}
