-- Crash diagnostics are insert-only for the app; funnel events follow one allow-list.
begin;
select plan(26);
truncate public.app_usage_daily;
truncate public.app_diagnostics;

-- Funnel events -------------------------------------------------------------
set local role anon;
select lives_ok($$select public.record_app_usage_event('store_viewed')$$, 'counts a store view');
select lives_ok($$select public.record_app_usage_event('purchase_started', 'plus_yearly')$$,
  'counts a purchase start with its product');
select lives_ok($$select public.record_app_usage_event(p_event => 'purchase_completed', p_detail => 'pro')$$,
  'counts a completed purchase with its product (named arguments, as PostgREST sends them)');
select lives_ok($$select public.record_app_usage_event(p_event => 'first_note')$$,
  '1.0.1 clients that only send p_event still count');
select lives_ok($$select public.record_app_usage_event('notification_opened', 'take_reply')$$,
  'counts an opened notification with its type');
select throws_ok($$select public.record_app_usage_event('purchase_completed')$$, '22023',
  'Invalid app usage event detail', 'purchases need a product');
select throws_ok($$select public.record_app_usage_event('purchase_completed', 'com.handstrudel.pro')$$, '22023',
  'Invalid app usage event detail', 'only the short product names are accepted');
select throws_ok($$select public.record_app_usage_event('store_viewed', 'someone@example.com')$$, '22023',
  'Invalid app usage event detail', 'events without details reject free text');
select throws_ok($$select public.record_app_usage_event('notification_opened', 'free text')$$, '22023',
  'Invalid app usage event detail', 'notification types are allow-listed');
select throws_ok($$select public.record_app_usage_event('first_note_played')$$, '22023',
  'Invalid app usage event', 'unknown events are still rejected');
select throws_ok($$select public.app_usage_event_detail_ok('store_viewed', null)$$, '42501',
  'permission denied for function app_usage_event_detail_ok', 'the allow-list helper is internal');

select lives_ok($$select public.record_app_usage_event(e) from unnest(array[
  'active_day', 'return_day', 'first_note', 'recording_started', 'recording_saved', 'recording_posted',
  'locked_sound_tapped', 'locked_sound_unlocked', 'store_viewed', 'restore_tapped',
  'invite_link_shared', 'invite_code_redeemed', 'invited_first_post',
  'reply_started', 'reply_posted', 'challenge_link_shared', 'challenge_link_opened',
  'daily_sound_opened', 'daily_take_posted', 'streak_extended',
  'sound_page_opened', 'play_this_sound_tapped', 'first_post_published']) e$$,
  'every event without a detail is on the allow-list');
reset role;

set local role authenticated;
select lives_ok($$select public.record_app_usage_event('store_viewed')$$, 'signed-in requests count too');
reset role;

set local role service_role;
select results_eq(
  $$select event, detail, events from public.app_usage_daily
    where event in ('store_viewed', 'purchase_started', 'purchase_completed', 'notification_opened')
    order by event, detail$$,
  $$values ('notification_opened', 'take_reply', 1::bigint), ('purchase_completed', 'pro', 1::bigint),
           ('purchase_started', 'plus_yearly', 1::bigint), ('store_viewed', '', 3::bigint)$$,
  'each event and detail keeps its own daily total');
reset role;

-- Diagnostics ---------------------------------------------------------------
set local role anon;
select lives_ok($$insert into public.app_diagnostics (kind, app_version, build, os_version, device_model, summary, payload)
  values ('crash', '1.0.2', '17', 'iPhone OS 26.1 (23B85)', 'iPhone17,1', 'EXC_BAD_ACCESS / SIGSEGV',
          '{"diagnosticMetaData": {"signal": 11}}')$$,
  'the app can upload a crash');
select throws_ok($$select * from public.app_diagnostics$$, '42501',
  'permission denied for table app_diagnostics', 'anonymous clients cannot read diagnostics');
select throws_ok($$update public.app_diagnostics set summary = 'x'$$, '42501',
  'permission denied for table app_diagnostics', 'anonymous clients cannot change diagnostics');
select throws_ok($$delete from public.app_diagnostics$$, '42501',
  'permission denied for table app_diagnostics', 'anonymous clients cannot delete diagnostics');
select throws_ok($$insert into public.app_diagnostics (received_at, kind, app_version, build, os_version, device_model, payload)
  values ('2020-01-01', 'crash', '1.0.2', '17', 'iOS', 'iPhone', '{}')$$, '42501',
  'permission denied for table app_diagnostics', 'the server sets received_at');
select throws_ok($$insert into public.app_diagnostics (kind, app_version, build, os_version, device_model, payload)
  values ('crash', '1.0.2', '17', 'iOS', 'iPhone', jsonb_build_object('blob', repeat('x', 70000)))$$, '23514',
  null, 'payloads over 64 KB are rejected');
select throws_ok($$insert into public.app_diagnostics (kind, app_version, build, os_version, device_model, payload)
  values ('screenshot', '1.0.2', '17', 'iOS', 'iPhone', '{}')$$, '23514',
  null, 'only MetricKit diagnostic kinds are accepted');
select throws_ok($$insert into public.app_diagnostics (kind, app_version, build, os_version, device_model, payload)
  values ('hang', '1.0.2 <script>', '17', 'iOS', 'iPhone', '{}')$$, '23514',
  null, 'versions are short version strings');
reset role;

set local role authenticated;
select lives_ok($$insert into public.app_diagnostics (kind, app_version, build, os_version, device_model, payload)
  values ('hang', '1.0.2', '17', 'iPhone OS 26.1', 'iPhone17,1', '{}')$$,
  'signed-in clients can upload too');
select throws_ok($$select count(*) from public.app_diagnostics$$, '42501',
  'permission denied for table app_diagnostics', 'signed-in users cannot read diagnostics');
reset role;

set local role service_role;
select results_eq(
  $$select kind, app_version, summary from public.app_diagnostics order by id$$,
  $$values ('crash', '1.0.2', 'EXC_BAD_ACCESS / SIGSEGV'), ('hang', '1.0.2', null)$$,
  'the service role reads every upload');
reset role;

select is(
  (select count(*)::int from pg_policies where tablename = 'app_diagnostics' and cmd <> 'INSERT'),
  0, 'there is no read, update or delete policy for client roles');

select * from finish();
rollback;
