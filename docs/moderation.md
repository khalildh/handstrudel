# Moderation

Admins review reported posts and comments in the app: **Profile → ⚙︎ → Moderation**. The entry only
appears for admin accounts; every moderation RPC checks the caller is an admin in the database.

## Make your account an admin

Admins live in `moderation_internal.admins`, a private schema the API doesn't expose and no client role
can write. Run this once in the Supabase SQL editor (it uses the service role), with the email you sign in with:

```sql
insert into moderation_internal.admins (user_id, note) select id, 'owner' from auth.users where email = 'you@example.com';
```

Remove an admin with `delete from moderation_internal.admins where user_id = '<uuid>';`.

## What the actions do

| Action | Effect |
| --- | --- |
| Hide | Hides a post or comment (`hidden = true`, `admin_hidden_at`). Its open reports are marked reviewed. |
| Restore | Makes it public again and marks its reports reviewed. Refused while the author is banned. |
| Dismiss reports | Marks open reports reviewed without changing visibility. |
| Ban | Hides every visible post and comment by the account (`ban_hidden`), removes it from creator lookups, and refuses new uploads, posts and comments with `ACCOUNT_BANNED`. |
| Unban | Lifts the ban and brings back exactly what the ban hid. Items hidden by reports or an admin stay hidden. |

Every action is written to `moderation_internal.actions` (admin, action, target, author, note, time) and shown
in the app's **Audit log**.

Auto-hide still triggers at three reports, but only unreviewed reports count, so content an admin restored needs
three fresh reports to be hidden again.

Hidden content stays out of the feed, following feeds, saved/challenge lists, sound pages (`sound_takes` reads
`feed_videos`), comment threads and counts, profile like/view totals, and the clip-media worker, because they
all check the existing `hidden` flags. Owners still see their own hidden posts on their profile.

## Reviewing hidden clips

The public clip-media worker refuses hidden posts. The `moderation-media` Edge Function returns 15-minute signed
R2 URLs for admins (it calls `moderation_video_media` with the admin's own JWT). Deploy it with the other functions:

```sh
supabase functions deploy moderation-media
```

## Daily digest hook

Nothing sends a digest yet. A scheduled job or the push sender can call (service role only):

```sql
select * from public.moderation_report_digest(now() - interval '1 day');
```

It returns new post/comment reports since then, open items and auto-hidden items; notify each row of
`moderation_internal.admins` when `new_reports > 0`.

## Local UI test

`ModerationUITests` runs against a local stack (Auth, REST and Mailpit; sign-in codes are read from Mailpit) and
skips without one. Use a copy of `supabase/` with its own `project_id` and ports so the shared stack isn't touched,
and raise `[auth.rate_limit] email_sent` there (the default allows 2 sign-in emails an hour):

```sh
cd <copy>   # the folder that holds the copied supabase/
supabase start -x realtime,storage-api,imgproxy,studio,edge-runtime,logflare,vector,supavisor,postgres-meta
<repo>/scripts/moderation-ui-fixture.sh | grep TEST_RUNNER > runner.env
cd <repo>/ios/HandStrudel
env $(cat <copy>/runner.env | xargs) xcodebuild test -project HandStrudel.xcodeproj -scheme HandStrudel \
  -destination 'platform=iOS Simulator,name=<your simulator>' -only-testing:HandStrudelUITests/ModerationUITests
```

Rerun the fixture script before each run: the admin test hides the seeded post.
