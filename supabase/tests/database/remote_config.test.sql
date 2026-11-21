begin;
select plan(31);
truncate public.app_config restart identity;
truncate public.instrument_catalog;

-- Rows as an admin (service role) would write them.
set local role service_role;
insert into public.app_config (key, value, platform, min_app_version, max_app_version, rollout_percent, priority, enabled, note) values
  ('feed.enabled',      'false',          'all',     null,    null,    100, 0, true,  'secret admin note'),  -- 1
  ('feed.page_size',    '15',             'ios',     null,    null,    100, 0, true,  null),                 -- 2
  ('feed.page_size',    '25',             'android', null,    null,    100, 0, true,  null),                 -- 3
  ('store.pro_title',   '"Old"',          'all',     null,    '1.0.2', 100, 0, true,  null),                 -- 4
  ('store.pro_title',   '"New"',          'all',     '1.0.3', null,    100, 0, true,  null),                 -- 5
  ('store.pro_note',    '"Off"',          'all',     null,    null,    100, 5, false, null),                 -- 6
  ('store.pro_note',    '"Low"',          'all',     null,    null,    100, 0, true,  null),                 -- 7
  ('store.pro_note',    '"High"',         'all',     null,    null,     50, 1, true,  null),                 -- 8
  ('update.message',    '"Older"',        'all',     null,    null,    100, 0, true,  null),                 -- 9
  ('update.message',    '"Newest wins"', 'all',     null,    null,    100, 0, true,  null);                 -- 10
select lives_ok($$update public.app_config set rollout_percent = 100 where id = 9$$, 'the service role edits rows');
reset role;

-- Clients can't touch the tables.
set local role anon;
select throws_ok($$select * from public.app_config$$, '42501', 'permission denied for table app_config', 'anon cannot read the table (notes stay private)');
select throws_ok($$insert into public.app_config (key, value) values ('feed.enabled', 'false')$$, '42501',
  'permission denied for table app_config', 'anon cannot write config');
select throws_ok($$select * from public.instrument_catalog$$, '42501', 'permission denied for table instrument_catalog',
  'anon cannot read the catalog table');
select throws_ok($$select public.app_config_resolve('ios', '1.0.3', 'x')$$, '42501',
  'permission denied for function app_config_resolve', 'the preview is admin-only');
reset role;

set local role authenticated;
select throws_ok($$update public.app_config set value = 'true'$$, '42501', 'permission denied for table app_config',
  'signed-in users cannot change config');
select throws_ok($$delete from public.instrument_catalog$$, '42501', 'permission denied for table instrument_catalog',
  'signed-in users cannot change the catalog');
reset role;

-- Targeting, as anon.
set local role anon;
select results_eq(
  $$select id, key from public.app_config_for('ios', '1.0.3')$$,
  $$values (1::bigint, 'feed.enabled'), (2::bigint, 'feed.page_size'), (8::bigint, 'store.pro_note'), (7::bigint, 'store.pro_note'),
           (5::bigint, 'store.pro_title'), (10::bigint, 'update.message'), (9::bigint, 'update.message')$$,
  'iOS 1.0.3: platform and version filtered, disabled rows dropped, priority then newest first');
select results_eq(
  $$select id from public.app_config_for('android', '1.0.2') where key in ('feed.page_size', 'store.pro_title')$$,
  $$values (3::bigint), (4::bigint)$$,
  'Android 1.0.2 gets its own page size and the max-version row (bounds are inclusive)');
select results_eq(
  $$select id from public.app_config_for('web', '1.0') where key = 'store.pro_title'$$,
  $$values (4::bigint)$$,
  '1.0 compares as 1.0.0');
select is((select count(*) from public.app_config_for('ios', '1.0.10') where key = 'store.pro_title' and id = 5), 1::bigint,
  '1.0.10 is newer than 1.0.3 (numeric, not text, comparison)');
select is((select value from public.app_config_for('ios', '1.0.3') where key = 'feed.enabled'), 'false'::jsonb,
  'values come back as JSON');
select throws_ok($$select * from public.app_config_for('windows', '1.0.3')$$, '22023', 'Invalid platform', 'rejects unknown platforms');
select throws_ok($$select * from public.app_config_for('ios', '1.0-beta')$$, '22023', 'Invalid app version', 'rejects bad versions');
select throws_ok($$select * from public.app_config_for('ios', null)$$, '22023', 'Invalid app version', 'rejects a missing version');
reset role;

-- Shared fixtures: buckets and versions.
select results_eq(
  $$select public.app_config_bucket(k, i) from (values
      ('feed.enabled', '00000000-0000-4000-8000-000000000000'),
      ('feed.enabled', '2F6C9A7E-1B4D-4C11-9E0A-5D2B7C3E8F10'),
      ('feed.enabled', '2f6c9a7e-1b4d-4c11-9e0a-5d2b7c3e8f10'),
      ('feed.page_size', 'A1B2C3D4-E5F6-4711-8899-AABBCCDDEEFF'),
      ('feed.page_size', 'FFFFFFFF-FFFF-4FFF-BFFF-FFFFFFFFFFFF'),
      ('store.pro_note', '2F6C9A7E-1B4D-4C11-9E0A-5D2B7C3E8F10'),
      ('store.pro_note', 'FFFFFFFF-FFFF-4FFF-BFFF-FFFFFFFFFFFF')) as t(k, i)$$,
  $$values (65), (69), (90), (58), (23), (52), (99)$$,
  'buckets match shared/remote-config/fixtures/buckets.json');
select results_eq(
  $$select public.app_version_parts(v) from (values ('1'), ('1.0'), ('1.0.3'), ('10.20.30'), (''), ('1.0.3.4'), ('1.0-beta'), ('v1.0'), ('1..2')) as t(v)$$,
  $$values ('{1,0,0}'::int[]), ('{1,0,0}'), ('{1,0,3}'), ('{10,20,30}'), (null), (null), (null), (null), (null)$$,
  'version parsing matches shared/remote-config/fixtures/versions.json');

-- Admin preview applies the rollout. Row 8 ("High", 50%) wins for bucket 43, row 7 for bucket 52.
set local role service_role;
select is(public.app_config_resolve('ios', '1.0.3', '00000000-0000-4000-8000-000000000000')->>'store.pro_note', 'High',
  'an install inside the rollout gets the higher-priority row');
select is(public.app_config_resolve('ios', '1.0.3', '2F6C9A7E-1B4D-4C11-9E0A-5D2B7C3E8F10')->>'store.pro_note', 'Low',
  'an install outside it falls through to the next row');
select is(public.app_config_resolve('ios', '1.0.3', 'anything')->>'update.message', 'Newest wins', 'ties go to the newest row');
reset role;

-- Row checks.
select throws_ok($$insert into public.app_config (key, value) values ('Feed Enabled', 'true')$$, '23514', null, 'rejects bad keys');
select throws_ok($$insert into public.app_config (key, value, min_app_version) values ('feed.enabled', 'true', '1.0-beta')$$, '23514', null,
  'rejects bad version bounds');
select throws_ok($$insert into public.app_config (key, value, min_app_version, max_app_version) values ('feed.enabled', 'true', '1.1', '1.0.9')$$,
  '23514', null, 'rejects min above max');
select throws_ok($$insert into public.app_config (key, value, rollout_percent) values ('feed.enabled', 'true', 101)$$, '23514', null,
  'rejects rollouts over 100%');

-- Instrument catalog.
set local role service_role;
insert into public.instrument_catalog (id, format_version, body, platform, min_app_version, published, sort_order) values
  ('community.b', 1, '{"format":"handstrudel.instrument","format_version":1,"id":"community.b","name":"B"}', 'all', null, true, 2),
  ('community.a', 1, '{"format":"handstrudel.instrument","format_version":1,"id":"community.a","name":"A"}', 'ios', '1.0.3', true, 1),
  ('community.hidden', 1, '{"format":"handstrudel.instrument","format_version":1,"id":"community.hidden","name":"H"}', 'all', null, false, 0),
  ('community.future', 2, '{"format":"handstrudel.instrument","format_version":2,"id":"community.future","name":"F"}', 'all', null, true, 0),
  ('community.web', 1, '{"format":"handstrudel.instrument","format_version":1,"id":"community.web","name":"W"}', 'web', null, true, 0);
reset role;

set local role anon;
select results_eq($$select id from public.instrument_catalog_for('ios', '1.0.3', 1)$$, $$values ('community.a'), ('community.b')$$,
  'published, platform-matched, current-format files in sort order');
select results_eq($$select id from public.instrument_catalog_for('ios', '1.0.2', 1)$$, $$values ('community.b')$$,
  'min app version applies');
select is((select count(*) from public.instrument_catalog_for('ios', '1.0.3', 2) where id = 'community.future'), 1::bigint,
  'an app that reads format 2 gets format 2 files');
select is((select body::jsonb->>'name' from public.instrument_catalog_for('ios', '1.0.3', 1) where id = 'community.b'), 'B',
  'bodies come back as JSON text');
reset role;

select throws_ok($$insert into public.instrument_catalog (id, format_version, body) values
  ('builtin.scale-wheel', 1, '{"format_version":1,"id":"builtin.scale-wheel"}')$$, '23514', null, 'the builtin. prefix is reserved for bundled files');
select throws_ok($$insert into public.instrument_catalog (id, format_version, body) values
  ('community.x', 1, '{"format_version":1,"id":"community.y"}')$$, '23514', null, 'the body id must match the row');
select throws_ok($$insert into public.instrument_catalog (id, format_version, body) values
  ('community.x', 1, '{"format_version":2,"id":"community.x"}')$$, '23514', null, 'the body version must match the row');

select * from finish();
rollback;
