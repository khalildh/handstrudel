-- 1.0.2 crash visibility and growth-funnel counters. Both are opt-in on the device
-- (Account > Usage Analytics) and carry no account or device identifiers.

-- ---------------------------------------------------------------------------
-- Funnel events: daily totals, as before, with an optional allow-listed detail
-- (the product for purchases, the notification type for opened pushes).
-- ---------------------------------------------------------------------------

alter table public.app_usage_daily add column detail text not null default '';
alter table public.app_usage_daily drop constraint app_usage_daily_pkey;
alter table public.app_usage_daily add primary key (day, event, detail);

alter table public.app_usage_daily drop constraint app_usage_daily_event_check;
alter table public.app_usage_daily add constraint app_usage_daily_event_check check (event in (
  'active_day', 'return_day', 'first_note', 'recording_started', 'recording_saved', 'recording_posted',
  'locked_sound_tapped', 'locked_sound_unlocked',
  'store_viewed', 'purchase_started', 'purchase_completed', 'restore_tapped',
  'invite_link_shared', 'invite_code_redeemed', 'invited_first_post',
  'reply_started', 'reply_posted', 'challenge_link_shared', 'challenge_link_opened',
  'daily_sound_opened', 'daily_take_posted', 'streak_extended',
  'sound_page_opened', 'play_this_sound_tapped',
  'notification_opened',
  'first_post_published'
));

-- The one allow-list both the database and the app test against (see AppAnalyticsFunnelTests).
-- Events with details must send one of their listed values; every other event sends none.
create function public.app_usage_event_detail_ok(p_event text, p_detail text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case
    when p_event in ('purchase_started', 'purchase_completed')
      then p_detail in ('pro', 'plus_monthly', 'plus_yearly')
    when p_event = 'notification_opened'
      then p_detail in (
        -- push_notifications.kind (remix … challenge), the daily-sound pushes, and 'other'.
        'remix', 'take_reply', 'like', 'comment', 'following_post', 'challenge',
        'daily_sound', 'streak_at_risk', 'other'
      )
    else p_detail is null
  end
$$;

-- The old single-argument function is replaced by one whose detail defaults to null, so
-- 1.0.1 clients calling with only p_event keep working through PostgREST.
drop function public.record_app_usage_event(text);

create function public.record_app_usage_event(p_event text, p_detail text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_event is null or p_event not in (
    'active_day', 'return_day', 'first_note', 'recording_started', 'recording_saved', 'recording_posted',
    'locked_sound_tapped', 'locked_sound_unlocked',
    'store_viewed', 'purchase_started', 'purchase_completed', 'restore_tapped',
    'invite_link_shared', 'invite_code_redeemed', 'invited_first_post',
    'reply_started', 'reply_posted', 'challenge_link_shared', 'challenge_link_opened',
    'daily_sound_opened', 'daily_take_posted', 'streak_extended',
    'sound_page_opened', 'play_this_sound_tapped',
    'notification_opened',
    'first_post_published'
  ) then
    raise exception 'Invalid app usage event' using errcode = '22023';
  end if;
  if not coalesce(public.app_usage_event_detail_ok(p_event, p_detail), false) then
    raise exception 'Invalid app usage event detail' using errcode = '22023';
  end if;

  insert into public.app_usage_daily as counter (day, event, detail, events)
  values ((current_timestamp at time zone 'UTC')::date, p_event, coalesce(p_detail, ''), 1)
  on conflict (day, event, detail) do update set events = counter.events + 1;
end;
$$;

revoke all on function public.record_app_usage_event(text, text) from public;
grant execute on function public.record_app_usage_event(text, text) to anon, authenticated;
revoke all on function public.app_usage_event_detail_ok(text, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Crash and hang diagnostics from MetricKit (MXDiagnosticPayload).
-- Insert-only for the app; read only by the service role (reports, dashboard).
-- ---------------------------------------------------------------------------

create table public.app_diagnostics (
  id bigint generated always as identity primary key,
  received_at timestamptz not null default now(),
  kind text not null check (kind in ('crash', 'hang', 'cpu_exception', 'disk_write_exception', 'app_launch')),
  platform text not null default 'ios' check (platform in ('ios')),
  app_version text not null check (app_version ~ '^[0-9A-Za-z.\-]{1,32}$'),
  build text not null check (build ~ '^[0-9A-Za-z.\-]{1,32}$'),
  os_version text not null check (char_length(os_version) between 1 and 64),
  device_model text not null check (char_length(device_model) between 1 and 64),
  -- A short human-readable label from the payload (exception type, signal, hang length).
  summary text check (char_length(summary) <= 200),
  truncated boolean not null default false,
  payload jsonb not null check (jsonb_typeof(payload) = 'object' and octet_length(payload::text) <= 65536)
);

create index app_diagnostics_received_idx on public.app_diagnostics (received_at desc);
create index app_diagnostics_version_idx on public.app_diagnostics (app_version, build, kind);

alter table public.app_diagnostics enable row level security;
revoke all on public.app_diagnostics from public, anon, authenticated, service_role;

-- The app may only add rows, and only the columns it owns; id and received_at are the server's.
grant insert (kind, platform, app_version, build, os_version, device_model, summary, truncated, payload)
  on public.app_diagnostics to anon, authenticated;
create policy app_diagnostics_insert on public.app_diagnostics
  for insert to anon, authenticated with check (true);

-- Reports run with the service role (scripts/diagnostics-report.mjs). No client role has select,
-- so PostgREST inserts must use `Prefer: return=minimal`.
-- TODO(admin flag): when the moderation-tools admin helper lands, add
--   grant select on public.app_diagnostics to authenticated;
--   create policy app_diagnostics_admin_read on public.app_diagnostics for select to authenticated
--     using (<admin check>);
grant select, delete on public.app_diagnostics to service_role;
