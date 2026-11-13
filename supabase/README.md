# HandStrudel backend (Supabase + Cloudflare R2)

Accounts, profiles, posts, likes, follows, reports and blocks live in Supabase
Postgres (`migrations/`). Video and thumbnail files live in Cloudflare R2,
served from `media.handstrudel.com` (Cloudflare-cached custom domain; CSAM Scanning Tool on). R2 has no egress fees, and egress is what
a video feed costs.

## Layout
- `migrations/20261113000000_accounts_feed.sql`: tables, triggers (like counts, auto-hide after 3 reports), RLS, and the `feed_videos` view.
- `tests/database/feed.test.sql`: pgTAP tests for RLS and triggers. Run them with `supabase test db`.
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
