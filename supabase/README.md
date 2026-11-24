# HandStrudel backend (Supabase + Cloudflare R2)

Accounts, profiles, posts, likes, follows, reports and blocks live in Supabase
Postgres (`migrations/`). New videos and thumbnails live in private Cloudflare
R2 and are served by `clips.handstrudel.com` only while the post is public.
Legacy clips and profile photos keep using `media.handstrudel.com`.

## Layout
- `migrations/20261113000000_accounts_feed.sql`: tables, triggers (like counts, auto-hide after 3 reports), RLS, and the `feed_videos` view.
- `migrations/20261114000000_video_sound_setups.sql`: optional public sound setup metadata on posts; existing posts have no setup.
- `migrations/20261114010000_video_comments.sql`: text comments, one-level replies, per-post controls, filtering, rate limits, and private reports.
- `migrations/20261114020000_creator_tools.sql`: private comment/reply activity inbox, public profiles, Following, and creator-approved backing audio.
- `migrations/20261114020100_keep_remix_reuse_restricted.sql`: prevents remixes from being opted in as new backing tracks, even after their source is deleted.
- `migrations/20261114030000_bookmarks_and_weekly_challenges.sql`: private saved performances and a manually curated play-along challenge.
- `migrations/20261114030100_use_server_challenge_submission_time.sql`: uses server publication time for challenge eligibility.
- `migrations/20261114030200_match_challenges_to_their_source.sql`: checks that a challenge's own source is publicly visible and opted in.
- `migrations/20261114040000_comment_likes.sql`: one reaction per account per comment or reply, with public counts and private reaction rows.
- `migrations/20261114050000_like_notifications.sql`: groups new likes by video, comment, or reply in the private in-app inbox. No historical backfill or push alerts. Older clients keep the comment/reply inbox.
- `migrations/20261114060000_profile_avatars.sql`: exposes avatar keys on public creator profiles and restricts writes to the server.
- `migrations/20261120000000_video_note_tracks.sql`: "Learn to play" note tracks (`videos.note_track`, at most 600 notes / 32 KB), written only by screened publication and only with a shared sound setup; feeds expose `has_note_track`.
- `migrations/20261120010000_locked_sound_events.sql`: adds opt-in daily counters for Pro sounds opened from the feed (`locked_sound_tapped`) and unlocked from that screen (`locked_sound_unlocked`).
- `migrations/20261121000000_push_notifications.sql`: push notifications. `device_tokens` (each account manages only its own), `notification_preferences` (per type, all on by default), and the `notifications` queue/log, filled by triggers on new posts, play-alongs, comments, likes (batched to one push per post per hour), and weekly challenges when their window opens. A pg_cron job wakes `send-push` every minute when something is due. Take replies call `push_internal.notify_take_reply(reply_video, replied_to_video)` from their own trigger.
- `functions/send-push`: drains the queue through APNs (token-based .p8 auth, ES256 JWT, HTTP/2), skips blocked pairs, turned-off types and your own actions, and deletes tokens APNs reports as gone (410 or `BadDeviceToken`).
- `migrations/20261121040000_daily_sound_streaks.sql`: the daily sound, its takes, posting streaks with a weekly freeze, streak badges and the 7-day hand theme loan. See [Daily sound](#daily-sound).
- `tests/database/feed.test.sql`: pgTAP tests for RLS and triggers. Run them with `supabase test db`.
- `tests/database/comments.test.sql`: pgTAP tests for comment permissions, thread visibility, and moderation.
- `functions/sign-upload` and `functions/publish-upload`: reserve a private R2 upload and publish only after Sightengine clears the video and thumbnail. Set up the private bucket, secrets, and cutover using the [video upload release checklist](../docs/video-upload-release.md).
- `functions/delete-video`: deletes one of the caller's own videos and its R2 files.
- `functions/delete-account`: deletes the caller's R2 files and auth user, and the user's rows cascade. Required by App Store Guideline 5.1.1(v).
- `functions/profile-avatar`: authenticates photo changes, validates and re-encodes square JPEGs, and replaces or removes the user's public R2 avatar. Deploy the migration and this function before shipping the upload UI. Previously shared avatar URLs may remain in CDN caches until they expire.

## Local development
```bash
supabase start          # Docker; prints the local API URL + anon key
supabase test db        # run the RLS tests
cp functions/.env.example functions/.env   # fill in R2 credentials
supabase functions serve
```
To use the local stack, set `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `MEDIA_BASE_URL` and `CLIP_MEDIA_BASE_URL` in the Xcode scheme's environment. DEBUG builds read them in `Social/SocialConfig.swift`.

## Production setup (one time)
1. Create the Supabase project, then `supabase link --project-ref <ref>` and `supabase db push`.
2. Set function secrets with `supabase secrets set --env-file functions/.env`, then deploy with `supabase functions deploy sign-upload publish-upload delete-video delete-account profile-avatar`.
3. Auth providers:
   - **Apple:** add the bundle ID `com.handstrudel.app` as a client ID (native sign-in needs no Services ID or key).
   - **Email:** enable it, and change the "Magic Link" email template to include `{{ .Token }}`, so users get a 6-digit code for the in-app code entry.
4. Cloudflare:
   - Create the R2 bucket `handstrudel-media`, plus an API token with Object Read & Write.
   - Connect the custom domain `media.handstrudel.com` (the zone must be on Cloudflare).
   - Add a CORS rule allowing `PUT` (only needed for web clients).
5. Put the project URL and anon key into `ios/HandStrudel/HandStrudel/Social/SocialConfig.swift`. Social features stay hidden until those values are filled in.

## Push notifications setup (one time)
Do these in order. Nothing is sent until step 4 is done.

1. **APNs key (Apple Developer portal):** in Certificates, Identifiers & Profiles → Keys, create a key with **Apple Push Notifications service (APNs)** enabled (environment: Sandbox & Production; scope: team). Download `AuthKey_<KEY_ID>.p8` (it can be downloaded only once) and note the Key ID. Then in Identifiers → `com.handstrudel.app`, enable **Push Notifications** and regenerate the app's provisioning profiles so they carry `aps-environment`.
2. **Function secrets:** generate a dispatch secret with `openssl rand -hex 32`, then:
   ```bash
   supabase secrets set APNS_KEY_ID=<KEY_ID> APNS_TEAM_ID=TVAG3T3Y65 APNS_BUNDLE_ID=com.handstrudel.app APNS_ENV=production PUSH_DISPATCH_SECRET=<secret>
   supabase secrets set APNS_PRIVATE_KEY="$(cat AuthKey_<KEY_ID>.p8)"
   ```
   `APNS_ENV=production` delivers to App Store and TestFlight installs. Use `sandbox` to test with builds run from Xcode; the app records which environment each token belongs to, and the function only sends to tokens that match.
3. **Migration and function:** preview with `supabase db push --dry-run`, apply with `supabase db push`, then `supabase functions deploy send-push` (its `verify_jwt = false` is in `config.toml`; it checks `PUSH_DISPATCH_SECRET` instead).
4. **Turn on the cron wake-up:** in the SQL Editor, store the function URL and the same secret in Vault:
   ```sql
   select vault.create_secret('https://eygrtqbtbhktptphqdnn.supabase.co/functions/v1/send-push', 'push_dispatch_url');
   select vault.create_secret('<secret>', 'push_dispatch_secret');
   ```
   Until both exist, the `send-push-notifications` cron job does nothing.
5. **Check:** sign in on a device, post or follow someone, and allow notifications. Confirm a row in `public.device_tokens`, have a second account like the post, and watch `public.notifications` move from `pending` to `sent` within a minute. Failures keep the APNs reason in `last_error`; `select * from cron.job_run_details order by start_time desc limit 5` shows the wake-ups.

## Comment moderation
Before enabling public comments, assign a reviewer to check `public.comment_reports` in the Supabase dashboard and monitor the community support inbox. Reports are never visible to clients. Three reports from distinct accounts hide a comment and its replies; moderators can set `comments.hidden` to hide or restore a comment after reviewing it. The server checks links and configured harmful phrases in `comment_internal.blocked_patterns` before posting. Treat this as a starter filter, not a replacement for review.

## Creator tools rollout
Bookmarks (including the Saved library) and comment/reply notifications require the creator tools migrations. Verify the linked project and run `supabase migration list --remote` before deploying. If the original accounts/feed migration was applied manually, first confirm its tables, policies, triggers, and functions already exist. Only then use `supabase migration repair --remote --status applied 20261113000000` to reconcile the history. Do not rerun the initial schema on a database with live accounts and posts.

After the moderation reviewer is assigned, preview the remaining changes with `supabase db push --remote --dry-run --skip-vault`. The pending migrations enable public comments and replies, creator profiles, Following, the private notification inbox and bookmarks, and support for the weekly challenge. Apply only after reviewing that list. Verify with two test accounts: save and reopen a post, confirm the other account cannot read the bookmark, then leave a comment and confirm that only the recipient sees its notification. The rollout does not send push notifications.

## Weekly play-along pilot
Choose a source clip with the creator's approval and with play-along already enabled. In the dashboard, add a row to `public.weekly_challenges` with its video ID, a short title and prompt, a one-week UTC window, and `featured = true`. Only one featured window can be active at a time. During the window, attributed public takes on that source appear automatically. Leave the table empty to keep the pilot hidden; revoking the source's opt-in also hides the challenge.

## Daily sound
One sound is featured per **UTC day** (00:00 to 00:00 UTC, for everyone). The Music home shows it with a countdown, today's takes and the player's streak.

**Picking.** If the owner scheduled a post for the day, that post's sound is used. Otherwise the first request of the day picks one automatically: a visible, unreported post with a shared playable preset that a player without Pro can open (the allowlist in the migration's `FREE SOUND VALUES` block, checked against the app catalog by `DailySoundTests`). Posts from the last 30 days come first, then creators not featured in the past week, then sounds not featured recently, then likes, views and remixes. A sound (same instrument, key, scale and progression) is not repeated within 30 days unless nothing else is left. The day keeps a copy of the sound, so it stays playable if the post is later deleted. If the post is hidden or its creator is blocked, the card shows the sound without the creator.

**Schedule a sound** (SQL Editor, or any service-role connection). Find the post's ID in `public.videos`; it needs a shared playable preset:

```sql
-- Feature a post on a UTC date (today or later). Title (≤ 60 chars) and note (≤ 240) are optional.
select * from public.schedule_daily_sound('2026-12-01', '<video uuid>', 'Night Drive', 'Keep the left hand on the root.');
-- A Pro-only sound is refused unless you opt in; free players would see "Unlock".
select * from public.schedule_daily_sound('2026-12-02', '<video uuid>', p_allow_pro => true);
-- Remove a future schedule (the day then picks automatically).
select public.unschedule_daily_sound('2026-12-01');
-- What's coming up and what ran.
select day, source, title, video_id from public.daily_sounds order by day desc limit 30;
```

Scheduling replaces an automatic pick for today only while nobody has posted a take yet (`DAILY_SOUND_HAS_TAKES`). Past days can't change.

**Takes.** A screened post counts as a take when its upload was reserved during the day's window (server time, from `sign-upload`) and it either shares the same sound (tempo, mode and mix may differ) or plays along with the featured post. A take submitted just before midnight still counts for that day if screening finishes within six hours. The card lists visible takes only: hidden posts, posts the viewer reported, and blocked accounts are left out.

**Streaks.** One take per day extends the streak. One freeze per ISO week (Monday to Sunday, UTC) covers a single missed day; two missed days in the same week reset it. Deleting or hiding a take after it counted keeps the credited day (`daily_streak_days`); a moderator can delete that row to remove it. Badges are earned once at 3, 7 and 30 days. Reaching 7 also lends one HandStrudel+ hand theme for 7 days (`daily_theme_grants`, rotating through the five premium themes). The app only times the loan from the server's grant. No device clock is involved.

**Push notification hooks** (service role only; nothing sends notifications yet):
- `select * from public.daily_sound_live();` at 00:00 UTC returns the new day's sound (picking it if needed) for a "Today's sound is live" push.
- `select * from public.daily_streaks_at_risk(interval '3 hours');` returns players with a live streak and no take today whose deadline is within the interval, with `ends_at` and `freeze_would_cover` (true when missing today would only use this week's freeze).

## Optional app usage metrics
In the project SQL Editor, view UTC daily totals with:

```sql
select day, event, events from public.app_usage_daily order by day desc, event;
```

`active_day` counts one foreground day per opted-in install. `return_day` counts an active day after any earlier observed day on the same install; it is not a Day 1 or Day 7 cohort. `first_note` counts once per opted-in install. Recording events count successful starts, completed private drafts, and posts confirmed by the app. These are best-effort client signals, not exact totals or user histories.

## iOS Universal Links
Deploy the site with `public/.well-known/apple-app-site-association` and `vercel.json`, and verify the file returns HTTPS 200 with JSON and no redirect. Enable Associated Domains for the iOS app ID in Apple's developer portal, then rebuild with a matching provisioning profile and test a `https://handstrudel.com/watch?v=…` link from Messages on a physical iPhone. The website remains the fallback.
