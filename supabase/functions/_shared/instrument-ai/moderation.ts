// A deliberately simple text filter for instrument prompts and generated
// names/descriptions. It is a first line, not a replacement for review: every
// generation is logged (public.instrument_generations) for abuse review.
//
// How it works:
// 1. Text is normalized: lowercased, accents stripped, common look-alike
//    characters mapped (0→o, 1→i, 3→e, 4→a, 5→s, 7→t, @→a, $→s), and every
//    run of non-letters collapsed to one space.
// 2. BLOCKED_TERMS (slurs) match as whole words in the normalized text and,
//    for terms of 5+ letters, also inside the text with all spaces removed
//    (catches "f a g g o t"-style spacing).
// 3. HARASSMENT_PHRASES match as whole-word phrases.
// 4. Links and web addresses are never allowed in a name or description.
// 5. BRAND_NAMES match as whole-word phrases. Brands are allowed in a prompt
//    ("drum pads like an 808 machine") but never in an instrument's name or
//    description, since a shared instrument must not look like an official
//    product. Artists, songs and franchises can't all be listed; reviewers
//    use the generation log to extend this list.
//
// Lists are lowercase and already normalized. Add terms with the same rules.

const BLOCKED_TERMS = [
  "nigger", "nigga", "faggot", "fag", "retard", "retarded", "tranny", "kike", "spic", "chink", "gook",
  "wetback", "coon", "dyke", "paki", "raghead", "towelhead", "beaner", "slut", "whore", "cunt",
  "nazi", "hitler", "heil", "kkk",
];

const HARASSMENT_PHRASES = [
  "kill yourself", "kill urself", "kys", "go die", "die in a fire", "neck yourself", "should die",
  "hang yourself", "slit your", "rape", "gas the",
];

export const BRAND_NAMES = [
  "yamaha", "roland", "korg", "moog", "fender", "gibson", "steinway", "casio", "akai", "novation",
  "native instruments", "ableton", "arturia", "teenage engineering", "elektron", "behringer", "nord",
  "apple", "garageband", "logic pro", "spotify", "tiktok", "instagram", "youtube", "soundcloud",
  "nintendo", "mario", "zelda", "pokemon", "sega", "playstation", "xbox", "minecraft", "fortnite", "roblox",
  "disney", "pixar", "marvel", "star wars", "harry potter", "nike", "adidas", "coca cola", "pepsi",
  "google", "microsoft", "samsung", "sony", "tesla", "netflix", "strudel", "launchpad", "maschine", "mpc",
  "minimoog", "stratocaster", "les paul",
];

export function normalize(text: string): string {
  return text
    .normalize("NFKD").replace(/\p{M}/gu, "")
    .toLowerCase()
    .replace(/[0@4$5137!|]/g, (c) => ({ "0": "o", "@": "a", "4": "a", "$": "s", "5": "s", "1": "i", "3": "e", "7": "t", "!": "i", "|": "i" })[c] ?? c)
    .replace(/[^a-z]+/g, " ")
    .trim();
}

function containsPhrase(normalized: string, phrase: string) {
  return ` ${normalized} `.includes(` ${phrase} `);
}

function firstBlockedTerm(normalized: string): string | null {
  const compact = normalized.replace(/ /g, "");
  for (const term of BLOCKED_TERMS) {
    if (containsPhrase(normalized, term)) return term;
    if (term.length >= 5 && compact.includes(term)) return term;
  }
  return null;
}

export type ModerationResult = { ok: true } | { ok: false; reason: "slur" | "harassment"; term: string };

/** Checks a player's prompt (or refine instruction) before it is sent anywhere. */
export function moderatePrompt(text: string): ModerationResult {
  const normalized = normalize(text);
  const slur = firstBlockedTerm(normalized);
  if (slur) return { ok: false, reason: "slur", term: slur };
  const phrase = HARASSMENT_PHRASES.find((p) => containsPhrase(normalized, p));
  if (phrase) return { ok: false, reason: "harassment", term: phrase };
  return { ok: true };
}

export function brandIn(text: string): string | null {
  const normalized = normalize(text);
  return BRAND_NAMES.find((brand) => containsPhrase(normalized, brand)) ?? null;
}

/** Problems with a generated instrument's visible text, phrased so they can be
 *  fed back to the model for a repair. */
export function moderateInstrumentText(fields: Record<string, unknown>): string[] {
  const errors: string[] = [];
  for (const [field, value] of Object.entries(fields)) {
    if (typeof value !== "string") continue;
    const verdict = moderatePrompt(value);
    if (!verdict.ok) errors.push(`${field}: contains blocked language; write a neutral ${field}`);
    if (/https?:\/\/|www\.|\b[a-z0-9-]+\.(?:com|net|org|io|app|ly|gg|xyz|example)\b/i.test(value)) {
      errors.push(`${field}: contains a link or web address; remove it`);
    }
    const brand = brandIn(value);
    if (brand) errors.push(`${field}: contains the brand or trademark "${brand}"; use an original ${field}`);
  }
  return errors;
}
