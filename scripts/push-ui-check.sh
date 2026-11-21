#!/bin/bash
# End-to-end push checks in the Simulator against the LOCAL Supabase stack (never production).
#   scripts/push-ui-check.sh <simulator-udid> [api-url] [derived-data-path]
# Seeds two test accounts and a post, runs HandStrudelUITests/PushNotificationUITests, and sends
# `xcrun simctl push` whenever the test writes a request to the signal file.
set -euo pipefail
cd "$(dirname "$0")/.."

UDID=${1:?simulator UDID}
API=${2:-http://127.0.0.1:54321}
DERIVED=${3:-}
DB_CONTAINER=supabase_db_$(sed -n 's/^project_id = "\(.*\)"/\1/p' supabase/config.toml)
WORK=$(mktemp -d)
cleanup() {
  kill "${WATCHER:-}" 2>/dev/null || true
  PREFS=$(cat "$WORK/prefs-path" 2>/dev/null || true)
  if [ -n "${PREFS:-}" ]; then
    for key in SUPABASE_URL SUPABASE_ANON_KEY; do
      xcrun simctl spawn "$UDID" defaults delete "$PREFS" "$key" 2>/dev/null || true
    done
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

eval "$(supabase status -o env 2>/dev/null | grep -E '^(ANON_KEY|SERVICE_ROLE_KEY)=')"
VIEWER=a7e00000-0000-0000-0000-000000000001
AUTHOR=a7e00000-0000-0000-0000-000000000002
VIDEO=a7e10000-0000-0000-0000-000000000001
CAPTION="Push check performance"
COMMENT="Push check comment"

docker exec -i "$DB_CONTAINER" psql -v ON_ERROR_STOP=1 -qU postgres >/dev/null <<SQL
delete from auth.users where id in ('$VIEWER', '$AUTHOR');
insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new)
values ('$VIEWER', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'push-ui-viewer@test.dev', now(),
        '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
       ('$AUTHOR', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'push-ui-author@test.dev', now(),
        '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '');
update public.profiles set username = 'push_ui_viewer', accepted_terms_at = now() where id = '$VIEWER';
update public.profiles set username = 'push_ui_author', accepted_terms_at = now() where id = '$AUTHOR';
insert into public.videos (id, user_id, video_key, thumb_key, caption)
values ('$VIDEO', '$AUTHOR', 'videos/$AUTHOR/push-check.mp4', 'thumbs/$AUTHOR/push-check.jpg', '$CAPTION');
insert into public.comments (video_id, user_id, body) values ('$VIDEO', '$VIEWER', '$COMMENT');
SQL

# Answer the test's push requests: "watch" or "comments", with the same payload shape send-push builds.
SIGNAL="$WORK/push-request"
(
  while true; do
    if [ -f "$SIGNAL" ]; then
      kind=$(cat "$SIGNAL"); rm -f "$SIGNAL"
      # A notification tap launches the app without the test's launch environment; DEBUG builds
      # also read the endpoint from the app's defaults, so the cold launch uses the local stack too.
      PREFS="$(xcrun simctl get_app_container "$UDID" com.handstrudel.app data)/Library/Preferences/com.handstrudel.app"
      echo "$PREFS" > "$WORK/prefs-path"
      xcrun simctl spawn "$UDID" defaults write "$PREFS" SUPABASE_URL "$API"
      xcrun simctl spawn "$UDID" defaults write "$PREFS" SUPABASE_ANON_KEY "$ANON_KEY"
      case "$kind" in
        watch) body="@push_ui_viewer liked your post. push-check-watch" ;;
        *) body="@push_ui_viewer commented: push-check-comments" ;;
      esac
      cat > "$WORK/payload.apns" <<JSON
{"Simulator Target Bundle":"com.handstrudel.app","aps":{"alert":{"title":"HandStrudel","body":"$body"},"sound":"default"},
 "link":"handstrudel://$kind/$VIDEO","kind":"$kind"}
JSON
      xcrun simctl push "$UDID" com.handstrudel.app "$WORK/payload.apns"
    fi
    sleep 0.5
  done
) & WATCHER=$!

cd ios/HandStrudel
TEST_RUNNER_PUSH_UI_SUPABASE_URL="$API" TEST_RUNNER_PUSH_UI_ANON_KEY="$ANON_KEY" \
TEST_RUNNER_PUSH_UI_SERVICE_KEY="$SERVICE_ROLE_KEY" TEST_RUNNER_PUSH_UI_EMAIL=push-ui-viewer@test.dev \
TEST_RUNNER_PUSH_UI_USER_ID="$VIEWER" TEST_RUNNER_PUSH_UI_SIGNAL_FILE="$SIGNAL" \
TEST_RUNNER_PUSH_UI_CAPTION="$CAPTION" TEST_RUNNER_PUSH_UI_COMMENT="$COMMENT" \
xcodebuild test -project HandStrudel.xcodeproj -scheme HandStrudel -destination "id=$UDID" \
  -only-testing:HandStrudelUITests/PushNotificationUITests ${DERIVED:+-derivedDataPath "$DERIVED"} \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=
