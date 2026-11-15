begin;
select plan(9);
truncate public.homepage_download_clicks;
set local time zone 'Pacific/Honolulu';

set local role anon;
select lives_ok($$select public.record_homepage_download_click('hero')$$, 'anonymous links can count a click');
select lives_ok($$select public.record_homepage_download_click('hero')$$, 'a repeat click increments the same placement');
select throws_ok($$select public.record_homepage_download_click('unknown')$$, '22023',
  'Invalid homepage download placement', 'rejects unknown placements');
select throws_ok($$select public.record_homepage_download_click(null)$$, '22023',
  'Invalid homepage download placement', 'rejects a missing placement');
select throws_ok($$select * from public.homepage_download_clicks$$, '42501',
  'permission denied for table homepage_download_clicks', 'counts are not public');
select throws_ok($$insert into public.homepage_download_clicks values (current_date, 'footer', 999)$$, '42501',
  'permission denied for table homepage_download_clicks', 'clients cannot set counts directly');
reset role;

set local role authenticated;
select lives_ok($$select public.record_homepage_download_click('header')$$, 'authenticated requests can also count a click');
reset role;

set local role service_role;
select results_eq(
  $$select placement, clicks from public.homepage_download_clicks where day = (now() at time zone 'UTC')::date order by placement$$,
  $$values ('header', 1::bigint), ('hero', 2::bigint)$$,
  'admins see only the UTC day and placement totals');
select throws_ok($$delete from public.homepage_download_clicks$$, '42501',
  'permission denied for table homepage_download_clicks', 'the reporting role only reads counts');
reset role;

select * from finish();
rollback;
