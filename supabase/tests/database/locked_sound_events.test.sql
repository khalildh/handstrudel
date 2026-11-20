-- Opt-in counters for Pro sounds opened from the feed.
begin;
select plan(4);
truncate public.app_usage_daily;

set local role anon;
select lives_ok($$select public.record_app_usage_event('locked_sound_tapped')$$,
  'counts a locked sound opened from the feed');
select lives_ok($$select public.record_app_usage_event('locked_sound_unlocked')$$,
  'counts a sound unlocked from its unlock screen');
select lives_ok($$select public.record_app_usage_event('recording_posted')$$,
  'existing events still count');
reset role;

set local role service_role;
select results_eq(
  $$select event, events from public.app_usage_daily order by event$$,
  $$values ('locked_sound_tapped', 1::bigint), ('locked_sound_unlocked', 1::bigint), ('recording_posted', 1::bigint)$$,
  'each event keeps its own daily total');
reset role;

select * from finish();
rollback;
