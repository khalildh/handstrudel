#!/usr/bin/env bash
# Seeds a LOCAL Supabase stack for the moderation UI tests
# (HandStrudelUITests.testModeration*). Never point this at production.
#
#   cd <dir with supabase/>  &&  scripts/moderation-ui-fixture.sh
#
# Needs `supabase status` for that directory (API, service key, Mailpit) and the
# stack's db container. Creates:
#   moderator@example.test  username "moderator", an admin
#   member@example.test     username "member", not an admin
#   a visible post by "reported_creator" captioned "Moderation target clip" with one open report
#   an older visible post by "member" captioned "Moderation control clip"
# then prints the TEST_RUNNER_* variables to pass to xcodebuild.
set -euo pipefail

status=$(supabase status -o env)
value() { printf '%s\n' "$status" | sed -n "s/^$1=\"\{0,1\}\([^\"]*\)\"\{0,1\}$/\1/p"; }
api=$(value API_URL); service=$(value SERVICE_ROLE_KEY); anon=$(value ANON_KEY); mail=$(value MAILPIT_URL)
case "$api" in http://127.0.0.1:*|http://localhost:*) ;; *) echo "refusing non-local API $api" >&2; exit 1 ;; esac
project=$(sed -n 's/^project_id = "\(.*\)"/\1/p' supabase/config.toml)
db="supabase_db_${project}"

user() {
  curl -fsS -X POST "$api/auth/v1/admin/users" -H "apikey: $service" -H "Authorization: Bearer $service" \
    -H 'Content-Type: application/json' --data "{\"email\":\"$1\",\"email_confirm\":true}" >/dev/null || true
}
user moderator@example.test
user member@example.test
user reported@example.test
user reporter@example.test

docker exec -i "$db" psql -v ON_ERROR_STOP=1 -q -U postgres -d postgres <<'SQL'
delete from public.videos where caption in ('Moderation target clip', 'Moderation control clip');
delete from moderation_internal.actions;
with u as (select id, email from auth.users where email like '%@example.test')
update public.profiles p set accepted_terms_at = now(),
  username = case u.email when 'moderator@example.test' then 'moderator' when 'member@example.test' then 'member'
                          when 'reported@example.test' then 'reported_creator' else 'fixture_reporter' end
from u where p.id = u.id;
insert into moderation_internal.admins (user_id, note)
  select id, 'ui test' from auth.users where email = 'moderator@example.test' on conflict do nothing;
delete from moderation_internal.admins where user_id = (select id from auth.users where email = 'member@example.test');
insert into public.videos (id, user_id, video_key, thumb_key, caption, duration_s, width, height)
  select 'e0000000-0000-0000-0000-000000000001', id,
         'videos/' || id || '/screened/e0000000-0000-0000-0000-000000000001.mp4',
         'thumbs/' || id || '/screened/e0000000-0000-0000-0000-000000000001.jpg',
         'Moderation target clip', 5, 720, 1280
    from auth.users where email = 'reported@example.test';
-- An older visible post, so the feed visibly loads once the target is gone.
insert into public.videos (id, user_id, video_key, thumb_key, caption, duration_s, width, height, created_at)
  select 'e0000000-0000-0000-0000-000000000002', id,
         'videos/' || id || '/screened/e0000000-0000-0000-0000-000000000002.mp4',
         'thumbs/' || id || '/screened/e0000000-0000-0000-0000-000000000002.jpg',
         'Moderation control clip', 5, 720, 1280, now() - interval '1 hour'
    from auth.users where email = 'member@example.test';
insert into public.reports (reporter_id, video_id, reason)
  select id, 'e0000000-0000-0000-0000-000000000001', 'spam' from auth.users where email = 'reporter@example.test';
SQL

echo "TEST_RUNNER_HANDSTRUDEL_MODERATION_SUPABASE_URL=$api"
echo "TEST_RUNNER_HANDSTRUDEL_MODERATION_ANON_KEY=$anon"
echo "TEST_RUNNER_HANDSTRUDEL_MODERATION_MAILPIT_URL=$mail"
