# Make your own instrument (AI, 1.0.3)

A player types what they want ("huge zones I can hit without looking"), Claude designs an instrument *file*, and the wheel plays it straight away. They can refine it ("bigger zones"), regenerate it, and save it to My instruments (on the device and in their account).

## Rules the feature keeps

- **Structure, never music.** A generated instrument only describes layout, zone roles, gestures and look, in the format of `shared/instruments/schema.json`. Key, scale, progression, voicing, sound and tempo stay the player's settings. If a prompt implies music ("a sad piano in D minor"), the instrument gets only the structure and look; the music comes back separately as `suggested_music` (`{key, scale, bpm}`), which the player can apply with one tap. Sound suggestions ("make it a marimba") aren't offered yet.
- **Data only (Guideline 2.5.2).** The model returns JSON, which the function validates and the app loads with `InstrumentSpec.load`, exactly like a bundled file. Nothing is executed.
- **Disclosure (Guideline 5.1.2(i)).** Before the first prompt is sent, a one-time consent card says that Claude, by Anthropic, designs the instrument, that only the typed words are sent, and that prompts are kept for abuse review. Generated instruments carry `"ai_generated": true` and show a **Made with AI** label.

## How a generation works

`supabase/functions/generate-instrument/index.ts` (signed-in users only) runs `generateInstrument()` from `supabase/functions/_shared/instrument-ai/generate.ts`:

1. **Prompt checks:** it must be 1–300 characters and pass the moderation filter (`moderation.ts`). Blocked prompts are logged but don't use quota.
2. **Quota:** `claim_instrument_generation()` atomically counts today's (UTC) generations against the player's tier limit and records a pending row. The tier comes from RevenueCat (`plus_features` gives plus, `pro` gives pro). Without `REVENUECAT_SECRET_KEY`, or if the lookup fails, everyone is free.
3. **Seed:** the closest library instrument (hint words like "big" or "arpeggio", then shared words), or for a refine the player's current instrument.
4. **Model:** `claude-haiku-5-5` (override with `ANTHROPIC_INSTRUMENT_MODEL`), structured JSON output (`output_config.format`) using a schema derived from `schema.json`, with thinking off and low effort to keep it under about 3 s. The system prompt is built only from the schema and the seed files, so it is byte-stable and cacheable.
5. **Validation** (`validate.ts`): the schema exactly (no repairs), playability rules per surface type (v1: the octave rim at least 0.25 outside the rest hole), a 16 KB size limit, music leaks (unknown music fields; a key, scale or tempo in the name or description), and moderation of the name and description (slurs, links, brands).
6. **Repair:** if validation fails, the model gets one retry with the errors listed. If that also fails, or the model is down or refuses, the player gets the seed back (`status: "fallback"`) instead of an error screen. A failed refine keeps the current instrument.
7. **Log:** `finish_instrument_generation()` stores the result, suggestion, issues, attempts, latency, tokens and estimated cost.

Response: `{ instrument, suggested_music, status: ok|repaired|fallback, ai_generated, seed_id, attempts, latency_ms, quota }`. Errors: 400 (prompt missing or too long), 401 (signed out), 422 `prompt_blocked`, 429 `quota_exceeded`.

### Following the format

The generator doesn't hard-code version 1 fields. `scripts/instrument-ai/sync-assets.mjs` copies `schema.json` and `library/*.json` into `assets.generated.ts` (Edge Functions can't read files outside `supabase/functions`). After the format or the library changes, run `npm run sync:instrument-ai`; the Node tests and CI fail while the copy is stale. When a new surface type needs cross-field rules, add them to `PLAYABILITY_RULES` in `validate.ts`. Until then, the schema alone checks that surface.

## Moderation

`moderation.ts` is a deliberately simple, documented filter, not a replacement for review:
- Text is normalized: lower case, accents stripped, look-alike characters mapped (`0→o`, `1→i`, `3→e`, `4→a`, `5→s`, `7→t`, `@→a`, `$→s`), and non-letters collapsed.
- Slurs match as whole words, and slurs of 5+ letters also match with spaces removed. Harassment phrases ("kill yourself", …) match as whole-word phrases. Either one blocks the prompt.
- Brand and trademark names are allowed in prompts but never in a generated name or description, and nor are links. Those go back to the model as repair errors.
- Reviewers read `public.instrument_generations` (status `blocked`, plus `issues`) and extend the lists.

## Quotas (remote config)

| Key | Default | Meaning |
|---|---|---|
| `ai_instruments.enabled` | `false` | Shows the ✨ button on the Scale/Split wheel. In Debug builds it can be forced on with Settings → Play → "Make an instrument (AI)" or `--force-ai-instruments`. |
| `ai_instruments.daily_limit_free` | 5 | Generations per UTC day (refines count). 0 turns generation off for that tier. |
| `ai_instruments.daily_limit_pro` | 25 | |
| `ai_instruments.daily_limit_plus` | 50 | |

The server reads the highest-priority enabled `app_config` row for `all` or `ios`. Rollout percentages and app versions don't apply server-side.

## Data

Migration `20261123010000_ai_instruments.sql`:
- `instrument_generations`: one row per request (prompt, seed, result, suggestion, issues, attempts, latency, tokens, cost, tier). With RLS, players read only their own rows, and only the service role writes, through `claim_…`, `finish_…` and `log_blocked_instrument_prompt`.
- `my_instruments`: saved instruments `(user_id, id, body, prompt)`. Owners can read and write their own rows. Built-in ids are reserved, the body id must match the row, bodies are capped at 16 KB, and each player can keep up to 200. The app re-validates every body with `InstrumentSpec.load` when it reads them back.

Rows cascade when the account is deleted.

## Setup (not done yet)

1. `supabase db push` (after reviewing with `--dry-run`).
2. Set `ANTHROPIC_API_KEY` (and optionally `REVENUECAT_SECRET_KEY`, `ANTHROPIC_INSTRUMENT_MODEL`) with `supabase secrets set`; see `supabase/functions/.env.example`. **The key is not set yet.**
3. `supabase functions deploy generate-instrument`.
4. Run the real-model evals (below), then turn on `ai_instruments.enabled` with a rollout percentage.

## Evals

`scripts/instrument-evals/prompts.json` holds 100 prompts: simple, genre, abstract, adversarial (prompt injection, brands, out-of-range values, abuse) and music-only requests, which must produce a suggestion and must not leak music.

```bash
npm run test:instrument-ai                                   # offline: generator + eval runner tests (mocked model)
node scripts/instrument-evals/run.ts --mock                  # offline eval run (CI)
ANTHROPIC_API_KEY=… node scripts/instrument-evals/run.ts --out report.json          # real model, in-process
HANDSTRUDEL_EVAL_JWT=… node scripts/instrument-evals/run.ts --function-url https://<ref>.supabase.co/functions/v1/generate-instrument
```

The runner re-validates every output and reports schema validity, playability, hard and soft music leaks, moderation misses, first-try/repair/fallback rates, blocked prompts, expectations met per category, p50/p95 latency and cost. It exits non-zero unless every answer is valid and playable, with no music leaks, moderation misses or errors. `--function-url` uses the test account's daily quota.

## iOS

- `Models/AIInstrument.swift`: client, response decoding through the loader, consent flag, examples.
- `Models/MyInstruments.swift`: saved instruments (a local file plus `my_instruments`, pulled after sign-in).
- `Views/MakeInstrumentPanel.swift`: the panel shown over the bottom of the play screen (consent, prompt and chips, generating state, result with the Made with AI label, suggestion, refine, regenerate, save).
- `Engine/MIDIProbe.swift` (DEBUG, `--uitesting` only): counts started notes for UI tests.
- Tests: `AIInstrumentTests` (unit) and `AIInstrumentUITests` (Simulator, against a loopback mock of the function and table).
