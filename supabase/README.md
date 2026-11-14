# HandStrudel backend (Supabase + Cloudflare R2)

Accounts, profiles, posts, likes, follows, reports and blocks live in Supabase
Postgres (`migrations/`). Video and thumbnail files live in Cloudflare R2,
served from `media.handstrudel.com` (Cloudflare-cached custom domain; CSAM Scanning Tool on). R2 has no egress fees, and egress is what
a video feed costs.

## Layout
- `migrations/20261113000000_accounts_feed.sql`: tables, triggers (like counts, auto-hide after 3 reports), RLS, and the `feed_videos` view.
- `migrations/20261114000000_video_sound_setups.sql`: optional public sound setup metadata on posts; existing posts have no setup.
- `migrations/20261114010000_video_comments.sql`: text comments, one-level replies, per-post controls, filtering, rate limits, and private reports.
- `migrations/20261114020000_creator_tools.sql`: private comment/reply activity inbox, public profiles, Following, and creator-approved backing audio.
- `migrations/20261114020100_keep_remix_reuse_restricted.sql`: prevents remixes from being opted in as new backing tracks, even after their source is deleted.
- `migrations/20261114030000_bookmarks_and_weekly_challenges.sql`: private saved performances and a manually curated play-along challenge.
- `migrations/20261114030100_use_server_challenge_submission_time.sql`: uses server publication time for challenge eligibility.
- `migrations/20261114030200_match_challenges_to_their_source.sql`: checks that a challenge's own source is publicly visible and opted in.
- `tests/database/feed.test.sql`: pgTAP tests for RLS and triggers. Run them with `supabase test db`.
- `tests/database/comments.test.sql`: pgTAP tests for comment permissions, thread visibility, and moderation.
- `functions/sign-upload`: presigned R2 PUT URLs for a new post. It checks the caller's JWT and username, limits each user to 20 posts a day, and caps uploads at 15 MB.
- `functions/delete-video`: deletes one of the caller's own videos and its R2 files.
- `functions/delete-account`: deletes the caller's R2 files and auth user, and the user's rows cascade. Required by App Store Guideline 5.1.1(v).

## Local development
```bash
supabase start          # Docker; prints the local API URL + anon key
supabase test db        # run the RLS tests
cp functions/.env.example functions/.env   # fill in R2 credentials
supabase functions serve
```
To use the local stack, set `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `MEDIA_BASE_URL` in the Xcode scheme's environment. DEBUG builds read them in `Social/SocialConfig.swift`.

## Production setup (one time)
1. Create the Supabase project, then `supabase link --project-ref <ref>` and `supabase db push`.
2. Set function secrets with `supabase secrets set --env-file functions/.env`, then deploy with `supabase functions deploy sign-upload delete-video delete-account`.
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

## Weekly play-along pilot
Choose a source clip with the creator's approval and with play-along already enabled. In the dashboard, add a row to `public.weekly_challenges` with its video ID, a short title and prompt, a one-week UTC window, and `featured = true`. Only one featured window can be active at a time. During the window, attributed public takes on that source appear automatically. Leave the table empty to keep the pilot hidden; revoking the source's opt-in also hides the challenge.

## iOS Universal Links
Deploy the site with `public/.well-known/apple-app-site-association` and `vercel.json`, and verify the file returns HTTPS 200 with JSON and no redirect. Enable Associated Domains for the iOS app ID in Apple's developer portal, then rebuild with a matching provisioning profile and test a `https://handstrudel.com/watch?v=…` link from Messages on a physical iPhone. The website remains the fallback.
