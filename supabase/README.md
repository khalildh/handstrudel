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
- `migrations/20261121030000_invite_rewards.sql`: personal invite codes, one redemption per new account, the reward queue (`invite_reward_grants`) filled by a trigger on an invited account's first screened post, and private abuse signals in the `invite_internal` schema. See [Invite rewards](#invite-rewards).
- `functions/grant-invite-rewards`: grants queued rewards through RevenueCat. `publish-upload` also tries right after publishing.
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
2. Set function secrets with `supabase secrets set --env-file functions/.env`, then deploy with `supabase functions deploy sign-upload publish-upload delete-video delete-account profile-avatar grant-invite-rewards`.
3. Auth providers:
   - **Apple:** add the bundle ID `com.handstrudel.app` as a client ID (native sign-in needs no Services ID or key).
   - **Email:** enable it, and change the "Magic Link" email template to include `{{ .Token }}`, so users get a 6-digit code for the in-app code entry.
4. Cloudflare:
   - Create the R2 bucket `handstrudel-media`, plus an API token with Object Read & Write.
   - Connect the custom domain `media.handstrudel.com` (the zone must be on Cloudflare).
   - Add a CORS rule allowing `PUT` (only needed for web clients).
5. Put the project URL and anon key into `ios/HandStrudel/HandStrudel/Social/SocialConfig.swift`. Social features stay hidden until those values are filled in.

## Comment moderation
Before enabling public comments, assign a reviewer to check `public.comment_reports` in the Supabase dashboard and monitor the community support inbox. Reports are never visible to clients. Three reports from distinct accounts hide a comment and its replies; moderators can set `comments.hidden` to hide or restore a comment after reviewing it. The server checks links and configured harmful phrases in `comment_internal.blocked_patterns` before posting. Treat this as a starter filter, not a replacement for review.

## Creator tools rollout
Bookmarks (including the Saved library) and comment/reply notifications require the creator tools migrations. Verify the linked project and run `supabase migration list --remote` before deploying. If the original accounts/feed migration was applied manually, first confirm its tables, policies, triggers, and functions already exist. Only then use `supabase migration repair --remote --status applied 20261113000000` to reconcile the history. Do not rerun the initial schema on a database with live accounts and posts.

After the moderation reviewer is assigned, preview the remaining changes with `supabase db push --remote --dry-run --skip-vault`. The pending migrations enable public comments and replies, creator profiles, Following, the private notification inbox and bookmarks, and support for the weekly challenge. Apply only after reviewing that list. Verify with two test accounts: save and reopen a post, confirm the other account cannot read the bookmark, then leave a comment and confirm that only the recipient sees its notification. The rollout does not send push notifications.

## Weekly play-along pilot
Choose a source clip with the creator's approval and with play-along already enabled. In the dashboard, add a row to `public.weekly_challenges` with its video ID, a short title and prompt, a one-week UTC window, and `featured = true`. Only one featured window can be active at a time. During the window, attributed public takes on that source appear automatically. Leave the table empty to keep the pilot hidden; revoking the source's opt-in also hides the challenge.

## Optional app usage metrics
In the project SQL Editor, view UTC daily totals with:

```sql
select day, event, events from public.app_usage_daily order by day desc, event;
```

`active_day` counts one foreground day per opted-in install. `return_day` counts an active day after any earlier observed day on the same install; it is not a Day 1 or Day 7 cohort. `first_note` counts once per opted-in install. Recording events count successful starts, completed private drafts, and posts confirmed by the app. These are best-effort client signals, not exact totals or user histories.

## iOS Universal Links
Deploy the site with `public/.well-known/apple-app-site-association` and `vercel.json`, and verify the file returns HTTPS 200 with JSON and no redirect. Enable Associated Domains for the iOS app ID in Apple's developer portal, then rebuild with a matching provisioning profile and test a `https://handstrudel.com/watch?v=…` link from Messages on a physical iPhone. The website remains the fallback.

## Invite rewards
Each account has an invite link, `https://handstrudel.com/invite?c=<CODE>`. Posts shared by their creator also carry it as `&invite=<CODE>`. When a new account enters the code and then publishes a first take that passes screening, the trigger queues 7 days of HandStrudel+ for both people. The queue is granted through RevenueCat's promotional API (`plus_features` and `pro`, `duration=weekly`). `pro` is also granted so 1.0.1 clients, which only check `pro`, unlock Pro sounds too.

Rules enforced by `redeem_invite_code`. Anti-abuse is intentionally light, at the owner's request:
- No self-invites.
- One introducer per account, recorded once.
- Before the account's first post, since that post is what triggers the reward.
- One reward per redemption, granted idempotently.
- At most `invite_reward_limit()` (10) rewarded weeks per inviter. That function is the single place to change the cap. Friends can still join past the cap: they get their own week and still count as intros.
- The introducer can be named by code (link, typed or pasted) or by picking their @username. The same rules apply to both.

Intro tracker: every redemption counts toward the inviter's tally, with no cap. A trigger stores milestone badges in `invite_milestones` at 1, 5, 10 and 25 intros (Spark, Bandleader, Connector, Headliner). These are kept once earned. `intro_stats(profile_id)` is public and returns only the count and the highest badge. `my_intros()` lists your own intros, and `my_introducer()` returns who introduced you. Both lists are visible only to the two people involved.

Setup:
1. Apply the migration with `supabase db push` after reviewing `supabase db push --dry-run`.
2. In RevenueCat, create a secret API key (v1, `sk_…`) for the project. Then run `supabase secrets set REVENUECAT_SECRET_KEY=sk_…`. Without it, rewards stay queued and nothing is lost.
3. Deploy with `supabase functions deploy grant-invite-rewards publish-upload`.
4. Optional retry sweep: set `INVITE_WORKER_TOKEN`, then schedule a `POST` to `grant-invite-rewards` with the header `X-Invite-Worker-Token`. The app already retries each time its owner opens it.

Monitor stuck grants with:

```sql
select status, count(*), max(last_error) from public.invite_reward_grants group by status;
```
