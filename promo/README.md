# Promo video factory

Automatically makes marketing videos of the **real iOS app making music**:

1. **Composes** a song (chords + melody) into hand choreography using the exact
   geometry of Scale mode's chord/melody wheel (`lib/choreo.mjs`).
2. **Builds** the Debug app and launches it in the iOS Simulator with
   `HANDSTRUDEL_DEMO_SCRIPT` set. A DEBUG-only `DemoDirector`
   (`ios/…/Engine/HandTrackingManager.swift`) feeds scripted hands into the
   normal hand pipeline instead of the camera, and the SoundFont engine renders
   offline into `audio.caf`. None of this is compiled into Release builds.
3. **Records** the Simulator screen (`simctl io recordVideo`) and syncs it to
   the app's audio using wall-clock timestamps.
4. **Edits** two cuts per video with ffmpeg + HTML-rendered graphics:
   - `*-social.mp4` — 1080×1920 for Reels / TikTok / Shorts: hook captions,
     framed footage, and an **App Store end card** (icon, “Download on the App
     Store”, search hint, and a QR code once `appStoreUrl` is set).
   - `*-appstore-preview.mp4` — 886×1920, ≤30 s, footage + app audio only, in
     the format App Store Connect accepts for iPhone app previews.
   - `*-hype.mp4` — 1080×1920 "hype" cut for short-attention feeds: neon
     background that changes colour with each chord, light rays + synthwave
     grid pulsing to the audio, the footage punching in/shaking on every chord,
     particle bursts exactly where each pinch lands, word-by-word pop-in
     captions with emoji stickers, a progress bar, and the App Store end card.
     Rendered frame-by-frame in headless Chrome (`lib/hype.mjs`), synced to the
     song's chord/note timings and the audio loudness.
   - `*-short.mp4` — ~12 s hype cut for 9–15 s placements (TikTok ads, quick
     posts): the busiest 9 s of the take, opening on a chord hit with the
     video's first caption (or `shortCaption`) and its voice line, then a 3 s
     end card. Tune with `shortSeconds` / `shortEndSeconds` in `config.json`.
   - `*-cover.jpg` / `*-hype-cover.jpg` / `*-short-cover.jpg` — thumbnails.

## Run

```bash
cd promo && npm install
node make.mjs                          # all videos in videos/
node make.mjs pocket-orchestra         # one video
node make.mjs --skip-build             # reuse the last build
node make.mjs --edit-only              # re-edit last recordings (caption/end-card tweaks, no Simulator)
node make.mjs --device "iPhone 17 Pro" # another simulator
node make.mjs --styles hype            # only the hype cut (or: clean, short)
node make.mjs --edit-only --styles short   # add ~12s cuts to existing recordings
```

Output lands in `promo/out/<video>/`. Needs Xcode, ffmpeg and Google Chrome.

## Make a new video

- **Song** — `songs/<name>.json`: `instrument` (any id from
  `SoundFontInstrument.swift`), `key`, `scale`, `bpm`, `chords` (roman numerals
  `I`…`VII`; `+`/`-` suffix = octave up/down) and `melody` (scale degrees
  `1`–`7`, `8` = octave up, `1,` = octave down, `:beats` for length, `-` = rest).
- **Video** — `videos/<name>.json`: which `song` to play plus timed `captions`
  (HTML; `<em>` text gets the brand gradient; optional `emoji` sticker for the
  hype cut). Times are seconds from the app's first note.

## Voice-over (Kokoro)

Social and hype cuts get a voice-over from [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M),
an open-weight TTS model run locally with `kokoro-js` (the ~90 MB model downloads
once from Hugging Face). The App Store preview stays music-only.

- Each caption's `say` is spoken when the caption appears; `endSay` in
  `config.json` (or per video) plays over the end card.
- Pick a voice per video with `"voice"` (e.g. `af_heart`, `af_bella`, `af_nicole`,
  `af_sky`, `am_puck`, `am_michael`), and `"voiceSpeed"` (default 1.08).
- Music is loudness-matched and ducked under the voice. Lines are cached in
  `.work/runs/voice-cache/`; a warning prints if a line outlasts its caption.
- `--no-voice` skips it, or set `"voiceover": false` in `config.json`.

## Posting calendar

`node calendar.mjs [--start YYYY-MM-DD]` writes `out/posting-calendar.csv`:
every cut scheduled 4 posts/day (`TIMES`) for TikTok, Reels and Shorts,
with captions, hashtags and YouTube titles. Phase 1 pairs hype vs short,
phase 2 clean vs app-only; each pair is `GAP_DAYS` (3) apart for A/B
comparison. Edit `TIMES`, the `PAIRS` order and `TAGS` in `calendar.mjs`.

## App Store end card

Edit `config.json`:
- `appStoreUrl` — the App Store link encoded in the end card's QR code
  (currently `https://apps.apple.com/app/id6764415289`).
- Drop Apple's official badge at `brand/app-store-badge.svg` (from Apple's
  Marketing Resources) to use it instead of the generic CTA button.
