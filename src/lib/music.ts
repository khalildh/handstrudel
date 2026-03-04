export const NOTES = [
  "c2", "d2", "e2", "g2", "a2",
  "c3", "d3", "e3", "g3", "a3",
  "c4", "d4", "e4", "g4", "a4",
  "c5", "d5", "e5",
];

export const NOTE_DISPLAY = NOTES.map((n) => n[0].toUpperCase() + n.slice(1));

export const STRUCTS = [
  "x ~ x ~ x ~ x ~",
  "x ~ ~ x ~ ~ x ~",
  "x x ~ x ~ x x ~",
  "[x x x] ~ ~ ~",
  "x ~ x x ~ x ~ ~",
];

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

export const PARAM_MAP: Record<string, ParamDef> = Object.fromEntries(
  PARAM_DEFS.map((d) => [d.id, d]),
);

export type MusicParams = Record<string, number>;

/** Collect the set of unique param IDs from the mapping config, excluding noteIdx and bpm. */
function extraParamIds(config: { left: Record<string, string>; right: Record<string, string> }): string[] {
  const ids = new Set<string>();
  for (const v of Object.values(config.left)) ids.add(v);
  for (const v of Object.values(config.right)) ids.add(v);
  ids.delete("noteIdx");
  ids.delete("bpm");
  return Array.from(ids);
}

export function buildCode(
  p: MusicParams,
  structIdx: number,
  config: { left: Record<string, string>; right: Record<string, string> },
): string {
  const ni = Math.max(0, Math.min(NOTES.length - 1, Math.round(p.noteIdx ?? 10)));
  const note = NOTES[ni];
  const cpm = ((p.bpm ?? 120) / 4).toFixed(1);
  const st = STRUCTS[structIdx];

  let code = `note("${note}").s("sawtooth").struct("${st}").cpm(${cpm})`;

  for (const id of extraParamIds(config)) {
    const def = PARAM_MAP[id];
    if (!def) continue;
    code += `.${def.strudelKey}(${def.toCode(p[id] ?? def.default)})`;
  }

  return code;
}

export function buildCodeHL(
  p: MusicParams,
  structIdx: number,
  config: { left: Record<string, string>; right: Record<string, string> },
): string {
  const ni = Math.max(0, Math.min(NOTES.length - 1, Math.round(p.noteIdx ?? 10)));
  const note = NOTES[ni];
  const cpm = ((p.bpm ?? 120) / 4).toFixed(1);
  const st = STRUCTS[structIdx];

  const lines: string[] = [
    `<span class="c-fn">note</span>(<span class="c-str">"${note}"</span>)`,
    `<span style="padding-left:12px" class="c-dot">.</span><span class="c-fn">s</span>(<span class="c-str">"sawtooth"</span>)`,
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
