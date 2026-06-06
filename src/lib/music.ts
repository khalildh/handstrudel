export const NOTES = [
  "c2", "d2", "e2", "g2", "a2",
  "c3", "d3", "e3", "g3", "a3",
  "c4", "d4", "e4", "g4", "a4",
  "c5", "d5", "e5",
];

/** MIDI note numbers corresponding to each entry in NOTES (for signal-based playback). */
export const MIDI_NOTES = [
  36, 38, 40, 43, 45,
  48, 50, 52, 55, 57,
  60, 62, 64, 67, 69,
  72, 74, 76,
];

export const NOTE_DISPLAY = NOTES.map((n) => n[0].toUpperCase() + n.slice(1));

export const STRUCTS = [
  "x ~ x ~ x ~ x ~",
  "x ~ ~ x ~ ~ x ~",
  "x x ~ x ~ x x ~",
  "[x x x] ~ ~ ~",
  "x ~ x x ~ x ~ ~",
];

/* ── Instruments (sound source for note/melody) ────────── */

export interface Instrument {
  /** Strudel sound name passed to .s() */
  id: string;
  /** Display label in the UI */
  label: string;
}

/**
 * Curated sound list. The first group are built-in oscillator synths
 * (instant, no download). The rest are General MIDI soundfonts registered by
 * @strudel/soundfonts — their sample data lazy-loads from a CDN on first use.
 * All ids are verified against the package's `gm` registry.
 */
export const INSTRUMENTS: Instrument[] = [
  { id: "sawtooth", label: "sawtooth" },
  { id: "square", label: "square" },
  { id: "triangle", label: "triangle" },
  { id: "sine", label: "sine" },
  { id: "gm_acoustic_piano", label: "piano" },
  { id: "gm_epiano1", label: "electric piano" },
  { id: "gm_harpsichord", label: "harpsichord" },
  { id: "gm_celesta", label: "celesta" },
  { id: "gm_music_box", label: "music box" },
  { id: "gm_vibraphone", label: "vibraphone" },
  { id: "gm_marimba", label: "marimba" },
  { id: "gm_xylophone", label: "xylophone" },
  { id: "gm_kalimba", label: "kalimba" },
  { id: "gm_orchestral_harp", label: "harp" },
  { id: "gm_acoustic_guitar_nylon", label: "nylon guitar" },
  { id: "gm_acoustic_guitar_steel", label: "steel guitar" },
  { id: "gm_electric_guitar_clean", label: "electric guitar" },
  { id: "gm_acoustic_bass", label: "upright bass" },
  { id: "gm_synth_bass_1", label: "synth bass" },
  { id: "gm_violin", label: "violin" },
  { id: "gm_cello", label: "cello" },
  { id: "gm_string_ensemble_1", label: "strings" },
  { id: "gm_pizzicato_strings", label: "pizzicato" },
  { id: "gm_church_organ", label: "church organ" },
  { id: "gm_rock_organ", label: "rock organ" },
  { id: "gm_flute", label: "flute" },
  { id: "gm_pan_flute", label: "pan flute" },
  { id: "gm_trumpet", label: "trumpet" },
  { id: "gm_choir_aahs", label: "choir" },
  { id: "gm_pad_warm", label: "warm pad" },
  { id: "gm_pad_new_age", label: "new age pad" },
  { id: "gm_sitar", label: "sitar" },
];

export const DEFAULT_INSTRUMENT = "sawtooth";

const INSTRUMENT_IDS = new Set(INSTRUMENTS.map((i) => i.id));

/** Validate an instrument id, falling back to the default if unknown. */
export function resolveInstrument(id: string | undefined): string {
  return id && INSTRUMENT_IDS.has(id) ? id : DEFAULT_INSTRUMENT;
}

/** Cycle to the next instrument id in the curated list (wraps around). */
export function nextInstrument(id: string): string {
  const idx = INSTRUMENTS.findIndex((i) => i.id === id);
  return INSTRUMENTS[(idx + 1) % INSTRUMENTS.length].id;
}

/* ── Parameter definitions ───────────────────────────── */

export interface ParamDef {
  id: string;
  label: string;
  strudelKey: string;
  min: number;
  max: number;
  default: number;
  format: (v: number) => string;
  toCode: (v: number) => string;
  hlClass: string;
}

export const PARAM_DEFS: ParamDef[] = [
  {
    id: "noteIdx",
    label: "pitch",
    strudelKey: "note",
    min: 0,
    max: NOTES.length - 1,
    default: 10,
    format: (v) => NOTE_DISPLAY[Math.max(0, Math.min(NOTES.length - 1, Math.round(v)))],
    toCode: (v) => `"${NOTES[Math.max(0, Math.min(NOTES.length - 1, Math.round(v)))]}"`,
    hlClass: "c-str",
  },
  {
    id: "gain",
    label: "volume",
    strudelKey: "gain",
    min: 0.03,
    max: 0.9,
    default: 0.55,
    format: (v) => v.toFixed(2),
    toCode: (v) => v.toFixed(2),
    hlClass: "c-nr",
  },
  {
    id: "lpf",
    label: "filter",
    strudelKey: "lpf",
    min: 120,
    max: 6120,
    default: 3000,
    format: (v) => Math.round(v) + "hz",
    toCode: (v) => String(Math.round(v)),
    hlClass: "c-nl",
  },
  {
    id: "hpf",
    label: "hi-pass",
    strudelKey: "hpf",
    min: 20,
    max: 4000,
    default: 2000,
    format: (v) => Math.round(v) + "hz",
    toCode: (v) => String(Math.round(v)),
    hlClass: "c-nl",
  },
  {
    id: "reverb",
    label: "reverb",
    strudelKey: "room",
    min: 0,
    max: 0.9,
    default: 0.2,
    format: (v) => v.toFixed(2),
    toCode: (v) => v.toFixed(2),
    hlClass: "c-nl",
  },
  {
    id: "bpm",
    label: "tempo",
    strudelKey: "cpm",
    min: 50,
    max: 205,
    default: 120,
    format: (v) => Math.round(v) + " bpm",
    toCode: (v) => (v / 4).toFixed(1),
    hlClass: "c-nr",
  },
  {
    id: "delay",
    label: "delay",
    strudelKey: "delay",
    min: 0,
    max: 0.55,
    default: 0.12,
    format: (v) => v.toFixed(2),
    toCode: (v) => v.toFixed(2),
    hlClass: "c-nr",
  },
  {
    id: "pan",
    label: "pan",
    strudelKey: "pan",
    min: 0,
    max: 1,
    default: 0.5,
    format: (v) => v.toFixed(2),
    toCode: (v) => v.toFixed(2),
    hlClass: "c-nr",
  },
  {
    id: "crush",
    label: "crush",
    strudelKey: "crush",
    min: 1,
    max: 16,
    default: 8,
    format: (v) => Math.round(v).toString(),
    toCode: (v) => String(Math.round(v)),
    hlClass: "c-nl",
  },
  {
    id: "shape",
    label: "shape",
    strudelKey: "shape",
    min: 0,
    max: 0.9,
    default: 0,
    format: (v) => v.toFixed(2),
    toCode: (v) => v.toFixed(2),
    hlClass: "c-nr",
  },
  {
    id: "attack",
    label: "attack",
    strudelKey: "attack",
    min: 0.001,
    max: 0.5,
    default: 0.01,
    format: (v) => v.toFixed(3),
    toCode: (v) => v.toFixed(3),
    hlClass: "c-nr",
  },
  {
    id: "release",
    label: "release",
    strudelKey: "release",
    min: 0.01,
    max: 1.0,
    default: 0.1,
    format: (v) => v.toFixed(2),
    toCode: (v) => v.toFixed(2),
    hlClass: "c-nr",
  },
];

/* ── Hydra visual parameter definitions ─────────────── */

export const HYDRA_PARAM_DEFS: ParamDef[] = [
  {
    id: "hFreq", label: "osc freq", strudelKey: "",
    min: 2, max: 60, default: 10,
    format: (v) => v.toFixed(1), toCode: (v) => v.toFixed(1), hlClass: "c-nr",
  },
  {
    id: "hSync", label: "osc sync", strudelKey: "",
    min: 0, max: 1, default: 0.1,
    format: (v) => v.toFixed(2), toCode: (v) => v.toFixed(2), hlClass: "c-nr",
  },
  {
    id: "hKaleid", label: "kaleid", strudelKey: "",
    min: 1, max: 12, default: 3,
    format: (v) => Math.round(v).toString(), toCode: (v) => String(Math.round(v)), hlClass: "c-nr",
  },
  {
    id: "hRotate", label: "rotate", strudelKey: "",
    min: 0, max: 3.14, default: 0,
    format: (v) => v.toFixed(2), toCode: (v) => v.toFixed(2), hlClass: "c-nr",
  },
  {
    id: "hColorama", label: "colorama", strudelKey: "",
    min: 0, max: 0.5, default: 0.05,
    format: (v) => v.toFixed(3), toCode: (v) => v.toFixed(3), hlClass: "c-nr",
  },
  {
    id: "hBright", label: "bright", strudelKey: "",
    min: 0, max: 2, default: 1,
    format: (v) => v.toFixed(2), toCode: (v) => v.toFixed(2), hlClass: "c-nr",
  },
  {
    id: "hPixel", label: "pixelate", strudelKey: "",
    min: 2, max: 200, default: 200,
    format: (v) => Math.round(v).toString(), toCode: (v) => String(Math.round(v)), hlClass: "c-nr",
  },
  {
    id: "hModulate", label: "modulate", strudelKey: "",
    min: 0, max: 0.15, default: 0.02,
    format: (v) => v.toFixed(3), toCode: (v) => v.toFixed(3), hlClass: "c-nr",
  },
  {
    id: "hScale", label: "scale", strudelKey: "",
    min: 0.5, max: 3, default: 1,
    format: (v) => v.toFixed(2), toCode: (v) => v.toFixed(2), hlClass: "c-nr",
  },
  {
    id: "hSaturate", label: "saturate", strudelKey: "",
    min: 0, max: 4, default: 1,
    format: (v) => v.toFixed(2), toCode: (v) => v.toFixed(2), hlClass: "c-nr",
  },
];

export const HYDRA_IDS = new Set(HYDRA_PARAM_DEFS.map((d) => d.id));

export const PARAM_MAP: Record<string, ParamDef> = Object.fromEntries(
  [...PARAM_DEFS, ...HYDRA_PARAM_DEFS].map((d) => [d.id, d]),
);

export type MusicParams = Record<string, number>;

/** Collect the set of unique music param IDs from the mapping config, excluding noteIdx, bpm, and hydra params. */
function extraParamIds(config: { left: Record<string, string>; right: Record<string, string> }): string[] {
  const ids = new Set<string>();
  for (const v of Object.values(config.left)) ids.add(v);
  for (const v of Object.values(config.right)) ids.add(v);
  ids.delete("noteIdx");
  ids.delete("bpm");
  for (const hid of HYDRA_IDS) ids.delete(hid);
  return Array.from(ids);
}

export function buildCode(
  p: MusicParams,
  structIdx: number,
  config: { left: Record<string, string>; right: Record<string, string> },
  instrument: string = DEFAULT_INSTRUMENT,
): string {
  const ni = Math.max(0, Math.min(NOTES.length - 1, Math.round(p.noteIdx ?? 10)));
  const note = NOTES[ni];
  const cpm = ((p.bpm ?? 120) / 4).toFixed(1);
  const st = STRUCTS[structIdx];
  const inst = resolveInstrument(instrument);

  let code = `note("${note}").s("${inst}").struct("${st}").cpm(${cpm})`;

  for (const id of extraParamIds(config)) {
    const def = PARAM_MAP[id];
    if (!def) continue;
    code += `.${def.strudelKey}(${def.toCode(p[id] ?? def.default)})`;
  }

  return code;
}

/** Check if any hydra params are mapped in the config. */
export function hasHydraMapping(config: { left: Record<string, string>; right: Record<string, string> }): boolean {
  for (const v of Object.values(config.left)) if (HYDRA_IDS.has(v)) return true;
  for (const v of Object.values(config.right)) if (HYDRA_IDS.has(v)) return true;
  return false;
}

/** Hydra code driven by mapped hand parameter values. */
export function buildHydraCode(p: MusicParams): string {
  const freq = p.hFreq ?? 10;
  const sync = p.hSync ?? 0.1;
  const kaleid = Math.round(p.hKaleid ?? 3);
  const rot = p.hRotate ?? 0;
  const colorama = p.hColorama ?? 0.05;
  const bright = p.hBright ?? 1;
  const pixel = Math.round(p.hPixel ?? 200);
  const mod = p.hModulate ?? 0.02;
  const scale = p.hScale ?? 1;
  const sat = p.hSaturate ?? 1;

  let code = `osc(${freq.toFixed(1)},${sync.toFixed(2)},1.5)`;
  if (kaleid > 1) code += `.kaleid(${kaleid})`;
  if (rot > 0.01) code += `.rotate(${rot.toFixed(3)})`;
  if (scale !== 1) code += `.scale(${scale.toFixed(2)})`;
  if (pixel < 190) code += `.pixelate(${pixel},${pixel})`;
  code += `.color(1,1,1)`;
  if (bright !== 1) code += `.brightness(${bright.toFixed(2)})`;
  if (sat !== 1) code += `.saturate(${sat.toFixed(2)})`;
  if (colorama > 0.01) code += `.colorama(${colorama.toFixed(3)})`;
  if (mod > 0.005) code += `.modulate(noise(3),${mod.toFixed(3)})`;
  code += `.out()`;
  return code;
}

/** Syntax-highlighted HTML for live hydra code display. */
export function buildHydraCodeHL(p: MusicParams): string {
  const freq = p.hFreq ?? 10;
  const sync = p.hSync ?? 0.1;
  const kaleid = Math.round(p.hKaleid ?? 3);
  const rot = p.hRotate ?? 0;
  const colorama = p.hColorama ?? 0.05;
  const bright = p.hBright ?? 1;
  const pixel = Math.round(p.hPixel ?? 200);
  const mod = p.hModulate ?? 0.02;
  const scale = p.hScale ?? 1;
  const sat = p.hSaturate ?? 1;

  const pad = `<span style="padding-left:12px" class="c-dot">.</span>`;
  const lines: string[] = [
    `<span class="c-fn">osc</span>(<span class="c-nr">${freq.toFixed(1)}</span>,<span class="c-nr">${sync.toFixed(2)}</span>,<span class="c-nr">1.5</span>)`,
  ];
  if (kaleid > 1) lines.push(`${pad}<span class="c-fn">kaleid</span>(<span class="c-nr">${kaleid}</span>)`);
  if (rot > 0.01) lines.push(`${pad}<span class="c-fn">rotate</span>(<span class="c-nr">${rot.toFixed(3)}</span>)`);
  if (scale !== 1) lines.push(`${pad}<span class="c-fn">scale</span>(<span class="c-nr">${scale.toFixed(2)}</span>)`);
  if (pixel < 190) lines.push(`${pad}<span class="c-fn">pixelate</span>(<span class="c-nr">${pixel}</span>,<span class="c-nr">${pixel}</span>)`);
  lines.push(`${pad}<span class="c-fn">color</span>(<span class="c-nr">1</span>,<span class="c-nr">1</span>,<span class="c-nr">1</span>)`);
  if (bright !== 1) lines.push(`${pad}<span class="c-fn">brightness</span>(<span class="c-nr">${bright.toFixed(2)}</span>)`);
  if (sat !== 1) lines.push(`${pad}<span class="c-fn">saturate</span>(<span class="c-nr">${sat.toFixed(2)}</span>)`);
  if (colorama > 0.01) lines.push(`${pad}<span class="c-fn">colorama</span>(<span class="c-nr">${colorama.toFixed(3)}</span>)`);
  if (mod > 0.005) lines.push(`${pad}<span class="c-fn">modulate</span>(<span class="c-fn">noise</span>(<span class="c-nr">3</span>),<span class="c-nr">${mod.toFixed(3)}</span>)`);
  lines.push(`${pad}<span class="c-fn">out</span>()<span class="c-cursor"></span>`);
  return lines.join("\n");
}

/** Build code using signal() for all params — evaluated once per struct change, params update via __hp global. */
export function buildSignalCode(
  structIdx: number,
  config: { left: Record<string, string>; right: Record<string, string> },
  instrument: string = DEFAULT_INSTRUMENT,
): string {
  const st = STRUCTS[structIdx];
  const inst = resolveInstrument(instrument);

  let code = `note(signal(() => __hp._midi)).s("${inst}").struct("${st}").cpm(signal(() => __hp._cpm))`;

  for (const id of extraParamIds(config)) {
    const def = PARAM_MAP[id];
    if (!def) continue;
    code += `.${def.strudelKey}(signal(() => __hp.${id}))`;
  }

  return code;
}

/** Key for detecting when structural re-eval is needed (only rhythm pattern changes). */
export function getStructuralKey(structIdx: number): string {
  return String(structIdx);
}

/** Update the global __hp object with current smoothed param values (zero-cost, no re-eval). */
export function updateSignalParams(
  p: MusicParams,
  config: { left: Record<string, string>; right: Record<string, string> },
): void {
  const hp = (globalThis as Record<string, unknown>).__hp as Record<string, number> | undefined;
  if (!hp) return;
  const ni = Math.max(0, Math.min(NOTES.length - 1, Math.round(p.noteIdx ?? 10)));
  hp._midi = MIDI_NOTES[ni];
  hp._cpm = (p.bpm ?? 120) / 4;
  for (const id of extraParamIds(config)) {
    const def = PARAM_MAP[id];
    if (def) hp[id] = p[id] ?? def.default;
  }
}

export function buildCodeHL(
  p: MusicParams,
  structIdx: number,
  config: { left: Record<string, string>; right: Record<string, string> },
  instrument: string = DEFAULT_INSTRUMENT,
): string {
  const ni = Math.max(0, Math.min(NOTES.length - 1, Math.round(p.noteIdx ?? 10)));
  const note = NOTES[ni];
  const cpm = ((p.bpm ?? 120) / 4).toFixed(1);
  const st = STRUCTS[structIdx];
  const inst = resolveInstrument(instrument);

  const lines: string[] = [
    `<span class="c-fn">note</span>(<span class="c-str">"${note}"</span>)`,
    `<span style="padding-left:12px" class="c-dot">.</span><span class="c-fn">s</span>(<span class="c-str">"${inst}"</span>)`,
    `<span style="padding-left:12px" class="c-dot">.</span><span class="c-fn">struct</span>(<span class="c-str">"${st}"</span>)`,
    `<span style="padding-left:12px" class="c-dot">.</span><span class="c-fn">cpm</span>(<span class="c-nr">${cpm}</span>)`,
  ];

  const extras = extraParamIds(config);
  for (let i = 0; i < extras.length; i++) {
    const def = PARAM_MAP[extras[i]];
    if (!def) continue;
    const val = def.toCode(p[extras[i]] ?? def.default);
    const cursor = i === extras.length - 1 ? '<span class="c-cursor"></span>' : "";
    lines.push(
      `<span style="padding-left:12px" class="c-dot">.</span><span class="c-fn">${def.strudelKey}</span>(<span class="${def.hlClass}">${val}</span>)${cursor}`,
    );
  }

  // Ensure cursor is on the last line if no extras
  if (extras.length === 0) {
    lines[lines.length - 1] += '<span class="c-cursor"></span>';
  }

  return lines.join("\n");
}
