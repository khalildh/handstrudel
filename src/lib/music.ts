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

export interface MusicParams {
  noteIdx: number;
  gain: number;
  lpf: number;
  reverb: number;
  bpm: number;
  delay: number;
}

export function buildCode(p: MusicParams, structIdx: number): string {
  const ni = Math.max(0, Math.min(NOTES.length - 1, Math.round(p.noteIdx)));
  const note = NOTES[ni];
  const cpm = (p.bpm / 4).toFixed(1);
  const gain = p.gain.toFixed(2);
  const lpf = Math.round(p.lpf);
  const room = p.reverb.toFixed(2);
  const del = p.delay.toFixed(2);
  const st = STRUCTS[structIdx];
  return `note("${note}").s("sawtooth").struct("${st}").cpm(${cpm}).gain(${gain}).lpf(${lpf}).room(${room}).delay(${del})`;
}

export function buildCodeHL(p: MusicParams, structIdx: number): string {
  const ni = Math.max(0, Math.min(NOTES.length - 1, Math.round(p.noteIdx)));
  const note = NOTES[ni];
  const cpm = (p.bpm / 4).toFixed(1);
  const gain = p.gain.toFixed(2);
  const lpf = Math.round(p.lpf);
  const room = p.reverb.toFixed(2);
  const del = p.delay.toFixed(2);
  const st = STRUCTS[structIdx];
  return [
    `<span class="c-fn">note</span>(<span class="c-str">"${note}"</span>)`,
    `<span style="padding-left:12px" class="c-dot">.</span><span class="c-fn">s</span>(<span class="c-str">"sawtooth"</span>)`,
    `<span style="padding-left:12px" class="c-dot">.</span><span class="c-fn">struct</span>(<span class="c-str">"${st}"</span>)`,
    `<span style="padding-left:12px" class="c-dot">.</span><span class="c-fn">cpm</span>(<span class="c-nr">${cpm}</span>)`,
    `<span style="padding-left:12px" class="c-dot">.</span><span class="c-fn">gain</span>(<span class="c-nr">${gain}</span>)`,
    `<span style="padding-left:12px" class="c-dot">.</span><span class="c-fn">lpf</span>(<span class="c-nl">${lpf}</span>)`,
    `<span style="padding-left:12px" class="c-dot">.</span><span class="c-fn">room</span>(<span class="c-nl">${room}</span>)`,
    `<span style="padding-left:12px" class="c-dot">.</span><span class="c-fn">delay</span>(<span class="c-nr">${del}</span>)<span class="c-cursor"></span>`,
  ].join("\n");
}
