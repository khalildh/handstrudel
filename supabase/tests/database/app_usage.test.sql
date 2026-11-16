begin;
select plan(9);
truncate public.app_usage_daily;
set local time zone 'Pacific/Honolulu';

set local role anon;
select lives_ok($$select public.record_app_usage_event('active_day')$$, 'anonymous requests can count an active day');
select lives_ok($$select public.record_app_usage_event('active_day')$$, 'repeat events increment the daily total');
select lives_ok($$select public.record_app_usage_event('first_note')$$, 'each event gets its own count');
select throws_ok($$select public.record_app_usage_event('unknown')$$, '22023',
  'Invalid app usage event', 'rejects unknown event names');
select throws_ok($$select public.record_app_usage_event(null)$$, '22023',
  'Invalid app usage event', 'rejects a missing event');
select throws_ok($$select * from public.app_usage_daily$$, '42501',
  'permission denied for table app_usage_daily', 'counts are not public');
select throws_ok($$insert into public.app_usage_daily values (current_date, 'active_day', 999)$$, '42501',
  'permission denied for table app_usage_daily', 'clients cannot set totals directly');
reset role;

set local role service_role;
select results_eq(
  $$select event, events from public.app_usage_daily where day = (now() at time zone 'UTC')::date order by event$$,
  $$values ('active_day', 2::bigint), ('first_note', 1::bigint)$$,
  'the reporting role sees only UTC daily totals');
select throws_ok($$delete from public.app_usage_daily$$, '42501',
  'permission denied for table app_usage_daily', 'the reporting role can only read counts');
reset role;

select * from finish();
rollback;
