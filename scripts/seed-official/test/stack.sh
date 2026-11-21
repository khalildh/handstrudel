#!/bin/zsh
# Isolated local Supabase stack + mock R2/Sightengine for testing the seed scripts end to end.
# Lives outside the repo (default /Volumes/PRO-G40/handstrudel-seed/stack); never touches the
# shared local stack or production.
#
#   scripts/seed-official/test/stack.sh up      # copy supabase/, start DB/auth/REST, mock, functions
#   scripts/seed-official/test/stack.sh env     # print the exports for publish.mjs / delete.mjs
#   scripts/seed-official/test/stack.sh down    # stop everything
#
# WITH_DAILY_SOUND=<git ref> also applies the daily-sound migration from that ref (PR #112),
# e.g. WITH_DAILY_SOUND=claude/daily-sound-9f343a.
set -euo pipefail
here=${0:A:h}
repo=${here:h:h:h}
root=${SEED_STACK_DIR:-/Volumes/PRO-G40/handstrudel-seed/stack}
mock_port=${MOCK_PORT:-59490}
api_port=59421
project=handstrudel-seed

up() {
  mkdir -p "$root"
  rm -rf "$root/supabase"
  rsync -a --exclude 'functions/.env' --exclude '.temp' --exclude '.branches' "$repo/supabase/" "$root/supabase/"
  if [[ -n "${WITH_DAILY_SOUND:-}" ]]; then
    git -C "$repo" show "${WITH_DAILY_SOUND}:supabase/migrations/20261121040000_daily_sound_streaks.sql" \
      > "$root/supabase/migrations/20261121040000_daily_sound_streaks.sql"
  fi
  local cfg="$root/supabase/config.toml"
  perl -0pi -e "s/^project_id = \".*\"/project_id = \"$project\"/m;
    s/(\[api\][^\[]*?port = )\d+/\${1}$api_port/s; s/(\[db\][^\[]*?port = )\d+/\${1}59422/s;
    s/shadow_port = \d+/shadow_port = 59420/; s/(\[db.pooler\][^\[]*?port = )\d+/\${1}59429/s;
    s/(\[studio\][^\[]*?port = )\d+/\${1}59423/s; s/(\[local_smtp\][^\[]*?port = )\d+/\${1}59424/s;
    s/(\[inbucket\][^\[]*?port = )\d+/\${1}59424/s;
    s/(\[analytics\][^\[]*?port = )\d+/\${1}59427/s; s/inspector_port = \d+/inspector_port = 59483/" "$cfg"
  # Each function first loads the test-only fetch redirect, then the real, unchanged code.
  mkdir -p "$root/supabase/functions/_test"
  cp "$here/redirect-deno.ts" "$root/supabase/functions/_test/redirect.ts"
  for fn in sign-upload publish-upload delete-video delete-account; do
    mv "$root/supabase/functions/$fn/index.ts" "$root/supabase/functions/$fn/real.ts"
    printf 'import "../_test/redirect.ts";\nimport "./real.ts";\n' > "$root/supabase/functions/$fn/index.ts"
  done
  cat > "$root/functions.env" <<EOF
R2_ACCOUNT_ID=localseed
R2_BUCKET=handstrudel-media
R2_ACCESS_KEY_ID=local
R2_SECRET_ACCESS_KEY=local
R2_VIDEO_STAGING_BUCKET=handstrudel-private
R2_VIDEO_STAGING_ACCESS_KEY_ID=local
R2_VIDEO_STAGING_SECRET_ACCESS_KEY=local
SIGHTENGINE_API_USER=local
SIGHTENGINE_API_SECRET=local
VIDEO_UPLOADS_ENABLED=true
MOCK_PORT=$mock_port
EOF
  # Docker's default address pools can run out with many local stacks; an explicit subnet avoids them.
  docker network inspect "supabase_network_$project" >/dev/null 2>&1 ||
    docker network create --subnet "${SEED_STACK_SUBNET:-10.231.7.0/24}" "supabase_network_$project" >/dev/null
  cd "$root"
  supabase start -x studio,realtime,storage-api,imgproxy,logflare,vector,supavisor,postgres-meta,mailpit,edge-runtime
  rm -rf "$root/mock-r2"
  MOCK_PORT=$mock_port MOCK_DIR="$root/mock-r2" nohup node "$here/mock-media.mjs" > "$root/mock.log" 2>&1 &
  echo $! > "$root/mock.pid"
  nohup supabase functions serve --env-file "$root/functions.env" --no-verify-jwt > "$root/functions.log" 2>&1 &
  echo $! > "$root/functions.pid"
  for i in {1..60}; do
    curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$api_port/functions/v1/sign-upload" | grep -q 401 && break
    sleep 2
  done
  echo "stack up: API http://127.0.0.1:$api_port, mock :$mock_port"
}

env_out() {
  cd "$root"
  local st; st=$(supabase status -o env 2>/dev/null)
  local service anon
  service=$(print -r -- "$st" | sed -n 's/^SERVICE_ROLE_KEY="\(.*\)"/\1/p')
  anon=$(print -r -- "$st" | sed -n 's/^ANON_KEY="\(.*\)"/\1/p')
  echo "export SUPABASE_URL=http://127.0.0.1:$api_port"
  echo "export SUPABASE_SERVICE_ROLE_KEY=$service"
  echo "export SUPABASE_ANON_KEY=$anon"
  echo "export MOCK_PORT=$mock_port"
  echo "export NODE_OPTIONS='--import $here/redirect-node.mjs'"
}

down() {
  cd "$root" 2>/dev/null || return 0
  for f in mock.pid functions.pid; do [[ -f $f ]] && { kill "$(cat $f)" 2>/dev/null || true; rm -f $f; }; done
  supabase stop --no-backup || true
  docker network rm "supabase_network_$project" >/dev/null 2>&1 || true
}

case ${1:-} in
  up) up ;;
  env) env_out ;;
  down) down ;;
  *) echo "usage: $0 up|env|down" >&2; exit 2 ;;
esac
