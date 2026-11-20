/** The notes behind "Learn to play": a small, well-formed track or nothing. */
export function noteTrack(input: unknown) {
  if (!input || typeof input !== "object" || Array.isArray(input)) return null;
  const track = input as Record<string, unknown>;
  const notes = track.notes;
  if (track.v !== 1 || !Array.isArray(notes) || notes.length < 1 || notes.length > 600) return null;
  const valid = notes.every((n) => {
    if (!n || typeof n !== "object" || Array.isArray(n)) return false;
    const { t, d, m, c } = n as Record<string, unknown>;
    return typeof t === "number" && Number.isFinite(t) && t >= 0 && t <= 60 &&
      typeof d === "number" && Number.isFinite(d) && d > 0 && d <= 60 &&
      typeof m === "number" && Number.isInteger(m) && m >= 0 && m <= 127 &&
      (c === undefined || c === null || typeof c === "boolean");
  });
  if (!valid) return null;
  const clean = {
    v: 1,
    notes: notes.map((n) => {
      const { t, d, m, c } = n as { t: number; d: number; m: number; c?: boolean | null };
      return c === true ? { t, d, m, c: true } : { t, d, m };
    }),
  };
  return new TextEncoder().encode(JSON.stringify(clean)).length <= 32768 ? clean : null;
}
