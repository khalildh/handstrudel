# Browser checks

Run `npm ci`, `npx playwright install chromium --only-shell`, then `npm run test:web`.
Playwright launches a local Next.js server. Public feed and media requests are fulfilled by the test, so it does not need Supabase credentials or create live posts.

`fixture.mp4` is a silent 0.8-second color clip generated with FFmpeg. The tests use real HTML video playback to exercise the media `ended` and `error` events.
