#!/usr/bin/env bash
# Seeds a LOCAL Supabase stack for the daily sound end-to-end UI test
# (testDailySoundEndToEndAgainstLocalSupabase). Refuses any non-local API URL.
#
#   API_URL=http://127.0.0.1:54321 SERVICE_ROLE_KEY=<local service_role JWT> \
#   DB_CONTAINER=supabase_db_<project_id> scripts/daily-sound-e2e-seed.sh > /tmp/daily-e2e.env
#
# It uses the real paths: `schedule_daily_sound` makes the creator's post today's sound, and a
# second account's take goes through `reserve_video_upload` + `publish_screened_video`.
# The viewer gets six earlier credited days with a gap three days ago, so their take today
# only reaches a 7-day streak if the weekly freeze bridges the gap.
# The sound is random so a previous run's studio state can't satisfy the test.
# Prints KEY=VALUE lines for the test runner (prefix them with TEST_RUNNER_).
set -euo pipefail
: "${API_URL:?}" "${SERVICE_ROLE_KEY:?}" "${DB_CONTAINER:?}"
case "$API_URL" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *) echo "Refusing to seed $API_URL: local stacks only." >&2; exit 1 ;;
esac

sql() { docker exec -i "$DB_CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 -qAt "$@"; }
create_user() {
  curl -sf "$API_URL/auth/v1/admin/users" -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    -H "Content-Type: application/json" -d "{\"email\":\"$1\",\"email_confirm\":true}" |
    python3 -c 'import json, sys; print(json.load(sys.stdin)["id"])'
}
pick() { local items=("$@"); echo "${items[RANDOM % ${#items[@]}]}"; }

run=$(date +%s | tail -c 7)
email="daily-e2e-$run@example.test"
creator_name="e2e_maker_$run"; taker_name="e2e_taker_$run"; viewer_name="e2e_viewer_$run"
creator=$(create_user "daily-e2e-maker-$run@example.test")
taker=$(create_user "daily-e2e-taker-$run@example.test")
viewer=$(create_user "$email")

instrument=$(pick "grand_piano:Grand Piano" "electric_piano_1:Rhodes EP" "nylon_guitar:Nylon Guitar" "clean_guitar:Clean Guitar" \
  "acoustic_bass:Upright Bass" "violin:Violin" "strings:Strings Ensemble" "choir:Choir Aahs")
key=$(pick C Db D Eb E F Gb G Ab A Bb B)
scale=$(pick Major Minor Dorian)
progression=$(pick pop sad_pop fifties jazz blues minor_vamp)
title="E2E sound $run"
setup="{\"version\":1,\"instrument\":\"${instrument%%:*}\",\"waveform\":\"sine\",\"key\":\"$key\",\"scale\":\"$scale\",\"progression\":\"$progression\",\"mode\":\"scalechordmelody\",\"bpm\":92,\"useSoundFont\":true,\"autoStrum\":false,\"padVolume\":0.3,\"gridOctave\":3,\"gridRange\":2}"

sql >/dev/null <<SQL
update public.profiles set username = '$creator_name', accepted_terms_at = now() where id = '$creator';
update public.profiles set username = '$taker_name', accepted_terms_at = now() where id = '$taker';
update public.profiles set username = '$viewer_name', display_name = 'Daily Player', accepted_terms_at = now() where id = '$viewer';
insert into public.videos (id, user_id, video_key, thumb_key, caption, sound_setup, created_at, like_count, backing_enabled)
  values (gen_random_uuid(), '$creator', 'videos/$creator/screened/source.mp4', 'thumbs/$creator/screened/source.jpg',
          'Source for the daily sound', '$setup', now() - interval '2 days', 3, true)
  returning id as source_id \gset
-- Local reruns only: start today over. (Production days with takes can't be rescheduled.)
delete from public.daily_sounds where day = (now() at time zone 'UTC')::date;
select day from public.schedule_daily_sound((now() at time zone 'UTC')::date, :'source_id', '$title', 'Seeded for the end-to-end test.');

insert into public.daily_streak_days (user_id, day, credited_at)
  select '$viewer', (now() at time zone 'UTC')::date - n, now() - n * interval '1 day' from unnest(array[7, 6, 5, 4, 2, 1]) n;
select daily_internal.rebuild_streak('$viewer', (now() at time zone 'UTC')::date - 1, now() - interval '1 day');

set role service_role;
select public.reserve_video_upload('$taker', 100, 20) as upload_id \gset
update public.pending_video_uploads set status = 'checking' where id = :'upload_id';
select public.publish_screened_video(:'upload_id', '{"duration_s":8,"width":720,"height":1280,"caption":"Seeded take","sound_setup":$setup}', 0);
reset role;
SQL

echo "HANDSTRUDEL_DAILY_E2E_EMAIL=$email"
echo "HANDSTRUDEL_DAILY_E2E_VIEWER_ID=$viewer"
echo "HANDSTRUDEL_DAILY_E2E_TITLE=$title"
echo "HANDSTRUDEL_DAILY_E2E_CREATOR=$creator_name"
echo "HANDSTRUDEL_DAILY_E2E_TAKER=$taker_name"
echo "HANDSTRUDEL_DAILY_E2E_INSTRUMENT=${instrument#*:}"
echo "HANDSTRUDEL_DAILY_E2E_KEY=$key"
echo "HANDSTRUDEL_DAILY_E2E_SETUP=$setup"
