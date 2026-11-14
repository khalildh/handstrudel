// Song → hand choreography for the iOS app's DEBUG DemoDirector.
//
// The app's Scale mode is a split wheel centred on screen:
//   • LEFT hand  = chords. Left semicircle, wedge 0 at the top, N wedges
//     (one per progression degree). Pinch to play/hold the chord.
//   • RIGHT hand = melody. Right semicircle, one octave of the scale; the
//     top of the arc is the highest note. Pinch to articulate a note.
//   • Reaching past 80% of the wheel radius enters the octave band
//     (+1 on the half of a wedge nearer the top of the arc, −1 nearer the bottom).
//
// Geometry mirrors ChordMelodyModeManager.radialVector / splitWedgeIndex /
// splitOctaveShift. If those constants change, update GEOM below.

export const GEOM = {
  radialRadiusFraction: 0.92,
  splitDeadzone: 0.36,
  octaveBand: 0.8,
  baseRadius: 0.62, // comfortably inside the base-octave band
  bandRadius: 0.9,
};

/** Wheel polar → screen-space point (0..1, top-left origin). */
function polarToScreen(angleDeg, radius, screenAspect) {
  const R = Math.min(0.5 * screenAspect, 0.5) * GEOM.radialRadiusFraction;
  const a = (angleDeg * Math.PI) / 180;
  const dx = radius * R * Math.sin(a);
  const dyUp = radius * R * Math.cos(a);
  return { x: 0.5 + dx / screenAspect, y: 0.5 - dyUp };
}

/** Where the left hand pinches for chord zone `zone` (0 = top wedge). */
export function chordPoint(zone, zoneCount, octave, screenAspect) {
  let t = (zone + 0.5) / zoneCount;
  let r = GEOM.baseRadius;
  if (octave === 1) { t = (zone + 0.25) / zoneCount; r = GEOM.bandRadius; }
  if (octave === -1) { t = (zone + 0.75) / zoneCount; r = GEOM.bandRadius; }
  return polarToScreen(360 - 180 * t, r, screenAspect);
}

/** Where the right hand pinches for scale degree `lane` (0 = root). */
export function melodyPoint(lane, laneCount, octave, screenAspect) {
  const wedge = laneCount - 1 - lane; // top of arc = highest pitch
  let t = (wedge + 0.5) / laneCount;
  let r = GEOM.baseRadius;
  if (octave === 1) { t = (wedge + 0.25) / laneCount; r = GEOM.bandRadius; }
  if (octave === -1) { t = (wedge + 0.75) / laneCount; r = GEOM.bandRadius; }
  return polarToScreen(180 * t, r, screenAspect);
}

/** A resting spot near the wheel's centre (inside the deadzone = silent hold). */
function restPoint(side, screenAspect) {
  return polarToScreen(side === 'left' ? 270 : 90, 0.18, screenAspect);
}

const ROMAN = { I: 0, II: 1, III: 2, IV: 3, V: 4, VI: 5, VII: 6 };
/** "vi", "IV", "V+" (octave up), "ii-" (octave down) → { zone, octave } */
export function parseChord(sym) {
  const m = /^([ivIV]+)([+-]?)/.exec(sym.trim());
  if (!m) throw new Error(`bad chord symbol: ${sym}`);
  const zone = ROMAN[m[1].toUpperCase()];
  if (zone === undefined) throw new Error(`bad chord symbol: ${sym}`);
  return { zone, octave: m[2] === '+' ? 1 : m[2] === '-' ? -1 : 0 };
}

/**
 * Melody tokens, space-separated, each `degree[:beats]`:
 *   "1:1 3:0.5 5:0.5"  — scale degrees 1–7 (1 = root), beats default 1
 *   "8" = root an octave up (via the octave band), "1," = an octave down
 *   "-:2" = rest for two beats
 */
export function parseMelody(str) {
  return str.trim().split(/\s+/).map((tok) => {
    const [n, b] = tok.split(':');
    const beats = b ? Number(b) : 1;
    if (n === '-' || n === 'r') return { rest: true, beats };
    let octave = 0;
    let deg = n;
    if (deg.endsWith("'")) { octave = 1; deg = deg.slice(0, -1); }
    if (deg.endsWith(',')) { octave = -1; deg = deg.slice(0, -1); }
    let d = Number(deg);
    if (d >= 8) { d -= 7; octave += 1; }
    if (!(d >= 1 && d <= 7)) throw new Error(`bad melody token: ${tok}`);
    return { lane: d - 1, octave, beats };
  });
}

/**
 * Build a DemoDirector script from a song spec.
 * Song: { name, bpm, key, scale, instrument, beatsPerChord, chords: [...],
 *         melody: "…", leadIn (s), tail (s), zoneCount, laneCount }
 */
export function composeScript(song, { screenAspect }) {
  const spb = 60 / song.bpm;
  const zoneCount = song.zoneCount ?? 7;
  const laneCount = song.laneCount ?? 7;
  const leadIn = song.leadIn ?? 0.8;
  const tail = song.tail ?? 1.0;
  const travel = Math.min(0.28, spb * 0.6); // seconds spent moving to a target
  const press = 0.06;   // pinch close/open time
  const gap = 0.07;     // release before the next articulation

  const left = [];
  const right = [];
  const push = (arr, t, p, pinch, visible = true) =>
    arr.push({ t: +t.toFixed(4), x: +p.x.toFixed(4), y: +p.y.toFixed(4), pinch, visible });

  // Hands enter from off-screen edges.
  const enterL = { x: -0.15, y: 0.62 };
  const enterR = { x: 1.15, y: 0.62 };
  push(left, 0, enterL, 0);
  push(right, 0, enterR, 0);

  // ---- chords (left hand)
  const chordEvents = [];
  let t = leadIn;
  const bpc = song.beatsPerChord ?? 4;
  for (const c of song.chords) {
    const sym = typeof c === 'string' ? c : c.chord;
    const beats = typeof c === 'string' ? bpc : c.beats ?? bpc;
    chordEvents.push({ ...parseChord(sym), start: t, dur: beats * spb });
    t += beats * spb;
  }
  let endT = t;

  const events = { chords: [], notes: [] };
  for (const [i, ev] of chordEvents.entries()) {
    const p = chordPoint(ev.zone, zoneCount, ev.octave, screenAspect);
    events.chords.push({ t: +ev.start.toFixed(4), dur: +ev.dur.toFixed(4), zone: ev.zone, octave: ev.octave, x: +p.x.toFixed(4), y: +p.y.toFixed(4) });
    const arrive = ev.start - press;
    const depart = i === 0 ? Math.max(0.05, arrive - travel * 2) : arrive - travel;
    push(left, depart, left.length ? lastPos(left) : p, 0);
    push(left, arrive, p, 0);
    push(left, ev.start, p, 1);
    const releaseAt = ev.start + ev.dur - gap - press;
    push(left, releaseAt, p, 1);
    push(left, releaseAt + press, p, 0);
  }

  // ---- melody (right hand)
  if (song.melody) {
    const notes = parseMelody(song.melody);
    let mt = leadIn + (song.melodyOffsetBeats ?? 0) * spb;
    let first = true;
    for (const n of notes) {
      const dur = n.beats * spb;
      if (!n.rest) {
        const p = melodyPoint(n.lane, laneCount, n.octave, screenAspect);
        events.notes.push({ t: +mt.toFixed(4), dur: +dur.toFixed(4), lane: n.lane, octave: n.octave, x: +p.x.toFixed(4), y: +p.y.toFixed(4) });
        const arrive = mt - press;
        const tr = Math.min(travel, Math.max(0.03, dur * 0.45));
        const depart = first ? Math.max(0.05, arrive - travel * 2) : arrive - tr;
        if (!first && depart < lastT(right)) {
          // Back-to-back notes: squeeze the travel into what time we have.
        }
        push(right, Math.max(depart, lastT(right) + 0.001), right.length ? lastPos(right) : p, 0);
        push(right, Math.max(arrive, lastT(right) + 0.001), p, 0);
        push(right, Math.max(mt, lastT(right) + 0.001), p, 1);
        const holdEnd = mt + Math.max(press, dur - gap - press);
        push(right, holdEnd, p, 1);
        push(right, holdEnd + Math.min(press, gap), p, 0);
        first = false;
      }
      mt += dur;
    }
    endT = Math.max(endT, mt);
  }

  // Ease hands back toward rest, then out.
  const finish = endT + 0.2;
  push(left, finish, restPoint('left', screenAspect), 0);
  if (right.length > 1) push(right, Math.max(finish, lastT(right) + 0.01), restPoint('right', screenAspect), 0);
  const duration = finish + tail;

  return {
    name: song.name,
    duration: +duration.toFixed(3),
    startDelay: song.startDelay ?? 2.5,
    instrument: song.instrument,
    key: song.key,
    scale: song.scale,
    left: monotonic(left),
    right: monotonic(right),
    // Not read by the app — used by the hype editor to sync visuals.
    bpm: song.bpm,
    events,
  };
}

function lastT(arr) { return arr.length ? arr[arr.length - 1].t : 0; }
function lastPos(arr) { const k = arr[arr.length - 1]; return { x: k.x, y: k.y }; }
function monotonic(arr) {
  const out = [];
  for (const k of arr) {
    if (out.length && k.t <= out[out.length - 1].t) k.t = +(out[out.length - 1].t + 0.001).toFixed(4);
    out.push(k);
  }
  return out;
}
