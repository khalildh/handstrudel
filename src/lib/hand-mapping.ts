import { MusicParams, PARAM_MAP } from "./music";

/* ── Axis Definitions ────────────────────────────────── */

export interface AxisDef {
  key: string;
  label: string;
  icon: string;
  basic: boolean;
  invert: boolean;
}

export const AXIS_DEFS: AxisDef[] = [
  { key: "y",          label: "Y pos",       icon: "↕",  basic: true,  invert: true  },
  { key: "x",          label: "X pos",       icon: "↔",  basic: true,  invert: true  },
  { key: "spread",     label: "spread",      icon: "✋", basic: true,  invert: false },
  { key: "pinch",      label: "pinch",       icon: "🤏", basic: false, invert: false },
  { key: "fist",       label: "fist",        icon: "✊", basic: false, invert: false },
  { key: "rotation",   label: "rotation",    icon: "🔄", basic: false, invert: false },
  { key: "thumbCurl",  label: "thumb curl",  icon: "👍", basic: false, invert: false },
  { key: "indexCurl",  label: "index curl",  icon: "☝",  basic: false, invert: false },
  { key: "middleCurl", label: "middle curl", icon: "🖕", basic: false, invert: false },
  { key: "ringCurl",   label: "ring curl",   icon: "💍", basic: false, invert: false },
  { key: "pinkyCurl",  label: "pinky curl",  icon: "🤞", basic: false, invert: false },
];

export const AXIS_MAP: Record<string, AxisDef> = Object.fromEntries(
  AXIS_DEFS.map((d) => [d.key, d]),
);

/* ── Hand Data ───────────────────────────────────────── */

export interface HandData {
  x: number;
  y: number;
  spread: number;
  pinch: number;
  fist: number;
  rotation: number;
  thumbCurl: number;
  indexCurl: number;
  middleCurl: number;
  ringCurl: number;
  pinkyCurl: number;
  lm: HandLandmark[];
  [key: string]: number | HandLandmark[];
}

export interface HandsState {
  left: HandData | null;
  right: HandData | null;
}

/* ── Mapping Config ──────────────────────────────────── */

export interface MappingConfig {
  left:  Record<string, string>;
  right: Record<string, string>;
}

export const DEFAULT_MAPPING: MappingConfig = {
  left:  { y: "noteIdx", x: "lpf",  spread: "reverb" },
  right: { y: "gain",    x: "bpm",  spread: "delay" },
};

export const DEFAULT_HYDRA_MAPPING: MappingConfig = {
  left:  { y: "none", x: "none", spread: "none" },
  right: { y: "none", x: "none", spread: "none" },
};

export const DEFAULT_ADVANCED_MAPPING: MappingConfig = {
  left: {
    y: "noteIdx", x: "lpf", spread: "reverb",
    pinch: "crush", fist: "shape", rotation: "pan",
    thumbCurl: "none", indexCurl: "none", middleCurl: "none",
    ringCurl: "none", pinkyCurl: "none",
  },
  right: {
    y: "gain", x: "bpm", spread: "delay",
    pinch: "hpf", fist: "attack", rotation: "release",
    thumbCurl: "none", indexCurl: "none", middleCurl: "none",
    ringCurl: "none", pinkyCurl: "none",
  },
};

export const DEFAULT_ADVANCED_HYDRA_MAPPING: MappingConfig = {
  left: {
    y: "none", x: "none", spread: "none",
    pinch: "none", fist: "none", rotation: "none",
    thumbCurl: "none", indexCurl: "none", middleCurl: "none",
    ringCurl: "none", pinkyCurl: "none",
  },
  right: {
    y: "none", x: "none", spread: "none",
    pinch: "none", fist: "none", rotation: "none",
    thumbCurl: "none", indexCurl: "none", middleCurl: "none",
    ringCurl: "none", pinkyCurl: "none",
  },
};

/* ── Mapping Logic ───────────────────────────────────── */

function scaleAxis(raw: number, paramId: string, invert: boolean): number {
  const def = PARAM_MAP[paramId];
  if (!def) return 0;
  const t = invert ? 1 - raw : raw;
  return def.min + t * (def.max - def.min);
}

/** Axes whose value triggers a gesture instead of mapping to a param. */
function getGestureAxes(
  config: MappingConfig,
  trigger: string,
): { side: "left" | "right"; axisKey: string }[] {
  const result: { side: "left" | "right"; axisKey: string }[] = [];
  for (const side of ["left", "right"] as const) {
    for (const [axisKey, paramId] of Object.entries(config[side])) {
      if (paramId === trigger) result.push({ side, axisKey });
    }
  }
  return result;
}

export function getSaveAxes(config: MappingConfig) {
  return getGestureAxes(config, "save");
}

export function getInstrumentAxes(config: MappingConfig) {
  return getGestureAxes(config, "instrument");
}

export function mapHandsToParams(
  hands: HandsState,
  params: MusicParams,
  config: MappingConfig,
): void {
  for (const side of ["left", "right"] as const) {
    const hand = hands[side];
    if (!hand) continue;
    for (const [axisKey, paramId] of Object.entries(config[side])) {
      if (paramId === "none" || paramId === "save" || paramId === "instrument") continue;
      const axisDef = AXIS_MAP[axisKey];
      if (!axisDef) continue;
      const raw = hand[axisKey];
      if (typeof raw !== "number") continue;
      params[paramId] = scaleAxis(raw, paramId, axisDef.invert);
    }
  }
}
