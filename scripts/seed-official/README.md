# Official @handstrudel seed content

25 short performances posted by an official **@handstrudel** account ("HandStrudel"), so the
1.0.2 social features have something to show on day one: the daily sound, sound pages, take
replies and play-along challenges.

- **21 free sounds** (Grand Piano, Rhodes EP, Nylon Guitar, Clean Guitar, Upright Bass, Violin,
  Strings Ensemble, Choir Aahs in Major, Minor or Dorian), so any player can tap *Play this sound*.
- **4 Pro sounds** (Vibraphone, Marimba, Kalimba, Trumpet) that show the Pro unlock.
- A **21-day daily-sound schedule** using only the free sounds.

Each post is a 720×1280 (9:16) recording of the real app playing in Scale mode, 18–30 s, with
the app's own audio and no captions or voice-over. Every post carries the `sound_setup` and
Learn-to-play `note_track` the app itself exported for that take, plus play-along enabled.

| File | What it is |
|---|---|
| `posts.json` | The posts: slug, song, caption, and the daily-sound day/title/note. |
| `render.mjs` | Renders the videos with the iOS Simulator (`promo/` pipeline). |
| `publish.mjs` | Creates or reuses @handstrudel, publishes the posts, schedules the daily sounds. |
| `delete.mjs` | Undo: unschedules and deletes the seed posts (optionally the account). |
| `schedule-sql.mjs`, `schedule.sql` | The daily-sound schedule as one SQL statement, for the SQL editor. |
| `test/` | Local end-to-end test kit (isolated stack, mock R2 and Sightengine). Not for production. |

The rendered media are **not in git**. They live on the external drive:
`/Volumes/PRO-G40/handstrudel-seed/media/<slug>/{video.mp4, thumb.jpg, post.json}`
(override with `SEED_MEDIA_DIR`). A contact sheet is at
`/Volumes/PRO-G40/handstrudel-seed/contact-sheet.jpg`.

## Before you publish

1. Deploy 1.0.2's migrations and Edge Functions first. The posts work without the newer
   migrations, but the daily-sound schedule needs PR #112's migration (see below).
2. Pick the email the official account signs in with (it receives no mail from this script),
   e.g. an address you control. If @handstrudel already exists, its own email is used and
   `SEED_OFFICIAL_EMAIL` is ignored.
3. Pick the first daily-sound day, a UTC date that is today or later (e.g. the day 1.0.2 ships).

Use a shell where the service-role key is not saved to history:

```bash
export SUPABASE_URL=https://eygrtqbtbhktptphqdnn.supabase.co
read -s SUPABASE_SERVICE_ROLE_KEY && export SUPABASE_SERVICE_ROLE_KEY
export SEED_OFFICIAL_EMAIL=official@example.com
```

The scripts refuse to touch the production project unless you add `--production`.

## 1. Dry run

```bash
node scripts/seed-official/publish.mjs --production --dry-run --start-date 2026-12-01
```

This writes nothing. It prints the account it would create (or the existing one it would use),
each post with its sound, length, size and caption, which posts would be skipped as already
published, and each daily-sound day.

## 2. Publish

```bash
node scripts/seed-official/publish.mjs --production --start-date 2026-12-01
```

For each post it calls `sign-upload`, PUTs the video and thumbnail to R2 with the signed URLs,
and calls `publish-upload`, then waits for screening, exactly like the app. Posts appear in feeds
only after Sightengine clears them.

- **The first run publishes 20 posts.** The server allows 20 uploads per account per 24 hours.
  Run the same command again a day later to publish the last 5 and schedule their days. The
  first 20 cover daily-sound days 1–16 and the 4 Pro posts; the last 5 cover days 17–21.
- **Re-running is safe.** Published posts (matched by caption on @handstrudel) and posts still
  in screening are skipped. Days already scheduled with the same post are skipped, past days
  are skipped, and a day you scheduled with something else is left alone unless you pass
  `--replace-schedule`.
- `--only slug,slug` limits a run to some posts.
- If screening *holds* a clip, the script says so; look at `pending_video_uploads` in the
  dashboard before retrying.

A new account gets the username, display name and `accepted_terms_at` set (you are accepting
the community terms on the official account's behalf, as the app asks every poster to).

### Daily-sound schedule

- If PR #112's migration (`schedule_daily_sound`) is on the server, `publish.mjs` schedules each
  day directly.
- If it is not deployed yet, `publish.mjs` writes
  `/Volumes/PRO-G40/handstrudel-seed/daily-schedule-<start>.sql` instead. After #112 is deployed,
  run that file (or `schedule.sql` here, after editing the start date on its first line) in the
  Supabase SQL editor, or re-run `publish.mjs` with the same `--start-date`. It schedules every
  published seed post whose day is today or later and is not already scheduled.
- Regenerate `schedule.sql` for another date with
  `node scripts/seed-official/schedule-sql.mjs --start-date 2026-12-01`.

## Undo

```bash
node scripts/seed-official/delete.mjs --production --dry-run
node scripts/seed-official/delete.mjs --production
```

It unschedules the seed posts' upcoming daily sounds (today's sound stays once anyone has posted
a take), then deletes each seed post through `delete-video`, which removes the row and both R2
files. Only posts whose caption is in `posts.json` are touched. `--only slug,slug` deletes some.
Add `--delete-account` to also delete @handstrudel via `delete-account`; it refuses if the
account has posted anything that is not a seed post.

Takes, replies and play-alongs that other players made stay; their link to a deleted post
becomes empty, as for any deleted post.

## Adding more seed posts later

1. Write a song in `promo/songs/<slug>.json` (format in `promo/README.md`). For a free sound use a
   free instrument (`grand_piano`, `electric_piano_1`, `nylon_guitar`, `clean_guitar`,
   `acoustic_bass`, `violin`, `strings`, `choir`) and a free scale (Major, Minor, Dorian,
   Pentatonic, Blues). Keep it 15–30 s: 32 beats at 70–120 BPM works.
2. Add an entry to `posts.json` with a unique caption (max 150 characters; the caption is how
   re-runs recognise the post, so do not edit captions of published posts). Add `daily`
   with the next `day` number, a `title` (max 60) and a `note` (max 240) to schedule it.
3. Render it: `node scripts/seed-official/render.mjs <slug>` (add `--skip-build` to reuse the
   last build). Check `/Volumes/PRO-G40/handstrudel-seed/media/<slug>/video.mp4`.
4. Dry run, then publish, as above. Only the new post is uploaded.

## Rendering

```bash
node scripts/seed-official/render.mjs --device "iPhone 16e"   # all posts
node scripts/seed-official/render.mjs sunday-piano --skip-build
```

It builds the Debug app, then for each song launches it with a DemoDirector script, records the
screen, and cuts the post from the recording plus the app's offline SoundFont capture
(`promo/lib/edit.mjs` `renderPost`). The DEBUG-only DemoDirector also writes the take's
`sound_setup.json`, `note_track.json` and draft labels, which become the post's metadata.
Build products and recordings stay under `/Volumes/PRO-G40/handstrudel-seed/media/.work`.

## Testing locally

`test/stack.sh` runs an isolated Supabase stack (`handstrudel-seed`, ports 594xx) from a copy
of `supabase/` outside the repo, a mock R2 + Sightengine + clips server, and the real Edge
Functions with a test-only fetch redirect. Nothing reaches production or Cloudflare.

```bash
WITH_DAILY_SOUND=claude/daily-sound-9f343a scripts/seed-official/test/stack.sh up
eval "$(scripts/seed-official/test/stack.sh env)"
export SEED_OFFICIAL_EMAIL=official@handstrudel.test
node scripts/seed-official/publish.mjs --dry-run --start-date 2026-11-22
node scripts/seed-official/publish.mjs --start-date 2026-11-22
NODE_OPTIONS= node scripts/seed-official/test/verify.mjs --expect 20
node scripts/seed-official/delete.mjs
scripts/seed-official/test/stack.sh down
```
