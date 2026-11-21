-- Daily sound picking, take counting and streaks.  Run: supabase test db
begin;
select plan(80);

-- Fixed weeks in the future so tests never depend on today's date: d(0) is a Monday (UTC).
create function pg_temp.d(n int) returns date language sql as $$
  select (date_trunc('week', now() at time zone 'UTC'))::date + 28 + n
$$;
create function pg_temp.at(n int, t text) returns timestamptz language sql as $$
  select (pg_temp.d(n)::text || ' ' || t)::timestamp at time zone 'UTC'
$$;
create function pg_temp.setup(instrument text, key text, scale text default 'Major', progression text default 'pop')
returns jsonb language sql as $$
  select jsonb_build_object('version', 1, 'instrument', instrument, 'waveform', 'sine', 'key', key, 'scale', scale,
    'progression', progression, 'mode', 'scalechordmelody', 'bpm', 96, 'useSoundFont', true, 'autoStrum', false,
    'padVolume', 0.3, 'gridOctave', 3, 'gridRange', 2)
$$;
-- A screened post. `reserved` is when sign-upload reserved it; `published` when screening finished.
create function pg_temp.post(id uuid, owner uuid, setup jsonb, published timestamptz, reserved timestamptz default null,
                             likes int default 0, source uuid default null, screened boolean default true)
returns void language plpgsql as $$
begin
  if reserved is not null then
    insert into public.pending_video_uploads (id, user_id, video_bytes, thumb_bytes, status, created_at)
      values (id, owner, 100, 20, 'published', reserved);
  end if;
  insert into public.videos (id, user_id, video_key, thumb_key, sound_setup, created_at, like_count, source_video_id)
    values (id, owner,
      'videos/' || owner || case when screened then '/screened/' else '/' end || id || '.mp4',
      'thumbs/' || owner || '/screened/' || id || '.jpg', setup, published, likes, source);
end
$$;
create function pg_temp.act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;
create function pg_temp.state(uid uuid, n int, t text) returns jsonb language sql as $$
  select daily_internal.streak_state(uid, pg_temp.at(n, t))
$$;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'alice@test.dev'),
  ('00000000-0000-0000-0000-0000000000b1', 'bob@test.dev'),
  ('00000000-0000-0000-0000-0000000000c1', 'cara@test.dev'),
  ('00000000-0000-0000-0000-0000000000d1', 'dan@test.dev'),
  ('00000000-0000-0000-0000-0000000000e1', 'eve@test.dev');
update public.profiles set username = 'alice' where id = '00000000-0000-0000-0000-0000000000a1';
update public.profiles set username = 'bob'   where id = '00000000-0000-0000-0000-0000000000b1';
update public.profiles set username = 'cara'  where id = '00000000-0000-0000-0000-0000000000c1';
update public.profiles set username = 'dan'   where id = '00000000-0000-0000-0000-0000000000d1';
update public.profiles set username = 'eve'   where id = '00000000-0000-0000-0000-0000000000e1';

-- ------------------------------------------------------------ free sounds
select ok(daily_internal.is_free_sound(pg_temp.setup('grand_piano', 'C')), 'a free piano sound is free');
select ok(not daily_internal.is_free_sound(pg_temp.setup('bright_piano', 'C')), 'a Pro instrument is locked');
select ok(not daily_internal.is_free_sound(pg_temp.setup('grand_piano', 'C', 'Lydian')), 'a Pro scale is locked');
select ok(not daily_internal.is_free_sound(pg_temp.setup('grand_piano', 'C', 'Major', 'pop_rock')), 'a Pro progression is locked');
select ok(not daily_internal.is_free_sound(pg_temp.setup('grand_piano', 'C') || '{"scale":{"name":"Mine","intervals":[0,3,7]}}'),
  'a custom scale is locked');
select ok(daily_internal.is_free_sound(pg_temp.setup('grand_piano', 'C') || '{"progression":"custom","customDegrees":[0,3,4]}'),
  'a typed-in progression is free');
select ok(daily_internal.is_free_sound(pg_temp.setup('x', 'C') || '{"useSoundFont":false,"waveform":"kalimba"}'),
  'a free synth uses the waveform, not the inactive soundfont');
select ok(not daily_internal.is_free_sound(pg_temp.setup('grand_piano', 'C') || '{"bpm":900}'), 'an unplayable setup is never picked');
select is(daily_internal.sound_signature(pg_temp.setup('grand_piano', 'C') || '{"bpm":140,"mode":"radialchordmelody"}'),
  daily_internal.sound_signature(pg_temp.setup('grand_piano', 'C')), 'tempo and mode do not change the sound');

-- -------------------------------------------------------------- picking
select pg_temp.post('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', pg_temp.setup('grand_piano', 'C'), pg_temp.at(-65, '12:00'), likes => 10);
select pg_temp.post('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000c1', pg_temp.setup('bright_piano', 'C'), pg_temp.at(-65, '12:00'), likes => 100);
select pg_temp.post('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000c1', pg_temp.setup('violin', 'E'), pg_temp.at(-65, '12:00'), likes => 50);
update public.videos set hidden = true where id = '10000000-0000-0000-0000-000000000003';
select pg_temp.post('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000c1', pg_temp.setup('choir', 'F'), pg_temp.at(-65, '12:00'), likes => 40);
update public.videos set report_count = 1 where id = '10000000-0000-0000-0000-000000000004';
select pg_temp.post('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-0000000000a1', pg_temp.setup('nylon_guitar', 'D'), pg_temp.at(-65, '12:00'), likes => 20);
select pg_temp.post('10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-0000000000c1', pg_temp.setup('strings', 'G'), pg_temp.at(-65, '12:00'), likes => 15);
select pg_temp.post('10000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-0000000000c1', pg_temp.setup('nylon_guitar', 'D'), pg_temp.at(-65, '12:00'), likes => 30);
select pg_temp.post('10000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-0000000000e1', pg_temp.setup('acoustic_bass', 'A'), pg_temp.at(-100, '12:00'), likes => 999);

select is((daily_internal.ensure_daily_sound(pg_temp.d(-60))).video_id, '10000000-0000-0000-0000-000000000007'::uuid,
  'the most popular recent free sound wins, skipping Pro, hidden and reported posts');
select is((daily_internal.ensure_daily_sound(pg_temp.d(-60))).source, 'auto', 'an unscheduled day is picked automatically');
select is((select count(*)::int from public.daily_sounds where day = pg_temp.d(-60)), 1, 'asking again keeps the same pick');
select is((daily_internal.ensure_daily_sound(pg_temp.d(-59))).video_id, '10000000-0000-0000-0000-000000000001'::uuid,
  'the next day skips the same sound from another post and rotates to a creator not featured this week');
select is((daily_internal.ensure_daily_sound(pg_temp.d(-58))).video_id, '10000000-0000-0000-0000-000000000006'::uuid,
  'a creator featured this week is still picked when nobody else is left');
select is((daily_internal.ensure_daily_sound(pg_temp.d(-57))).video_id, '10000000-0000-0000-0000-000000000008'::uuid,
  'an older post is used before repeating a sound within 30 days');
select is((daily_internal.ensure_daily_sound(pg_temp.d(-56))).signature, daily_internal.sound_signature(pg_temp.setup('nylon_guitar', 'D')),
  'with nothing new left, the least recently featured sound returns');

-- --------------------------------------------------------------- streaks
-- Alice's featured clip allows play-along; every streak day below features its sound.
select pg_temp.post('20000000-0000-0000-0000-0000000000f0', '00000000-0000-0000-0000-0000000000a1', pg_temp.setup('grand_piano', 'Eb'), pg_temp.at(-2, '12:00'));
update public.videos set backing_enabled = true where id = '20000000-0000-0000-0000-0000000000f0';
insert into public.daily_sounds (day, video_id, creator_id, sound_setup, signature, source)
  select pg_temp.d(i), '20000000-0000-0000-0000-0000000000f0', '00000000-0000-0000-0000-0000000000a1',
         pg_temp.setup('grand_piano', 'Eb'), daily_internal.sound_signature(pg_temp.setup('grand_piano', 'Eb')), 'scheduled'
  from generate_series(0, 20) i;

-- Monday: first take.
select pg_temp.post('30000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000000b1', pg_temp.setup('grand_piano', 'Eb') || '{"bpm":120}', pg_temp.at(0, '12:01'), pg_temp.at(0, '12:00'));
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 0, '13:00')->>'current')::int, 1, 'a matching take starts a streak');
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 0, '13:00')->>'posted_today')::boolean, true, 'the day shows as done');
-- Tuesday 23:59:59: screening finishes after midnight, but the take was submitted before it.
select pg_temp.post('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b1', pg_temp.setup('grand_piano', 'Eb'), pg_temp.at(2, '00:03'), pg_temp.at(1, '23:59:59'));
select is((select day from public.daily_sound_takes where video_id = '30000000-0000-0000-0000-000000000001'), pg_temp.d(1),
  'a take submitted just before midnight counts for that day even when published after it');
select pg_temp.post('30000000-0000-0000-0000-0000000001b1', '00000000-0000-0000-0000-0000000000b1', pg_temp.setup('grand_piano', 'Eb'), pg_temp.at(1, '10:01'), pg_temp.at(1, '10:00'));
select is((select count(*)::int from public.daily_streak_days where user_id = '00000000-0000-0000-0000-0000000000b1'), 2,
  'a second take on the same day does not count twice');
select is((select count(*)::int from public.daily_sound_takes where day = pg_temp.d(1)), 2, 'both takes still appear for the day');
-- Wednesday 00:00:00 belongs to Wednesday.
select pg_temp.post('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000b1', pg_temp.setup('grand_piano', 'Eb'), pg_temp.at(2, '00:01'), pg_temp.at(2, '00:00:00'));
select is((select day from public.daily_sound_takes where video_id = '30000000-0000-0000-0000-000000000002'), pg_temp.d(2),
  'a take submitted at midnight counts for the new day');
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 2, '12:00')->>'current')::int, 3, 'three days in a row');
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 2, '12:00')->'badges'), '[3]'::jsonb, 'the 3-day badge is earned');
-- A take that only finished screening the next morning is too late.
select pg_temp.post('30000000-0000-0000-0000-0000000001c2', '00000000-0000-0000-0000-0000000000b1', pg_temp.setup('grand_piano', 'Eb'), pg_temp.at(3, '06:00'), pg_temp.at(2, '10:00'));
select ok(not exists (select 1 from public.daily_sound_takes where video_id = '30000000-0000-0000-0000-0000000001c2'),
  'a take published more than six hours after its day ends does not count');

-- Thursday is missed. On Friday morning the week's freeze is holding the streak.
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 4, '09:00')->>'current')::int, 3, 'a single missed day does not reset the streak');
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 4, '09:00')->'freeze_covering'), jsonb_build_array(pg_temp.d(3)),
  'the freeze shows which day it covers');
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 4, '09:00')->>'freeze_available')::boolean, false, 'that uses this week''s freeze');
select pg_temp.post('30000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000b1', pg_temp.setup('grand_piano', 'Eb'), pg_temp.at(4, '12:01'), pg_temp.at(4, '12:00'));
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 4, '13:00')->>'current')::int, 4, 'posting after the freeze continues the streak');
select is((select covered_day from public.daily_streak_freezes where user_id = '00000000-0000-0000-0000-0000000000b1'), pg_temp.d(3),
  'the used freeze is recorded');
-- Saturday is missed too: the freeze is spent, so Sunday shows the streak ended.
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 5, '23:59')->>'current')::int, 4, 'the streak is alive until the day rolls over');
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 5, '23:59')->>'ends_at')::timestamptz, pg_temp.at(6, '00:00'),
  'it ends at the next UTC midnight');
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 6, '00:00')->>'current')::int, 0, 'a second missed day in a week resets it at rollover');
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 6, '00:00')->>'best')::int, 4, 'the best streak is kept');

-- The next Monday to Sunday: seven days in a row unlock the theme loan.
select pg_temp.post(('30000000-0000-0000-0000-0000000000' || lpad(i::text, 2, '0'))::uuid, '00000000-0000-0000-0000-0000000000b1',
  pg_temp.setup('grand_piano', 'Eb'), pg_temp.at(i, '08:01'), pg_temp.at(i, '08:00'))
  from generate_series(7, 12) i;
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 12, '09:00')->>'current')::int, 6, 'a new streak restarts from one');
select ok(not exists (select 1 from public.daily_theme_grants where user_id = '00000000-0000-0000-0000-0000000000b1'), 'no theme before day seven');
select pg_temp.post('30000000-0000-0000-0000-000000000013', '00000000-0000-0000-0000-0000000000b1', pg_temp.setup('grand_piano', 'Eb'), pg_temp.at(13, '08:01'), pg_temp.at(13, '08:00'));
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 13, '09:00')->'badges'), '[3, 7]'::jsonb, 'the 7-day badge is earned');
select is((select theme_id from public.daily_theme_grants where user_id = '00000000-0000-0000-0000-0000000000b1'), 'fire_ice',
  'day seven lends a HandStrudel+ hand theme');
select is((select expires_at - starts_at from public.daily_theme_grants where user_id = '00000000-0000-0000-0000-0000000000b1'),
  interval '7 days', 'for one week');
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 13, '09:00')->'theme_grant'->>'theme_id'), 'fire_ice',
  'the active loan is part of the streak');
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 21, '09:00')->'theme_grant'), 'null'::jsonb, 'and expires after the week');

-- Time zones: days are UTC, whatever the session or device zone.
set local timezone = 'America/New_York';
select is(daily_internal.day_of(pg_temp.at(14, '00:30')), pg_temp.d(14), 'day boundaries ignore the session time zone');
select pg_temp.post('30000000-0000-0000-0000-000000000014', '00000000-0000-0000-0000-0000000000b1', pg_temp.setup('grand_piano', 'Eb'), pg_temp.at(14, '00:31'), pg_temp.at(14, '00:30'));
select is((select day from public.daily_streak_days where video_id = '30000000-0000-0000-0000-000000000014'), pg_temp.d(14),
  'a take at 7:30 pm in New York counts for the next UTC day');
reset timezone;
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 14, '12:00')->>'current')::int, 8, 'the streak continues to eight');

-- Deleting a counted post keeps the day but removes the take.
delete from public.videos where id = '30000000-0000-0000-0000-000000000014';
select ok(not exists (select 1 from public.daily_sound_takes where video_id = '30000000-0000-0000-0000-000000000014'), 'a deleted take leaves the list');
select ok(exists (select 1 from public.daily_streak_days where user_id = '00000000-0000-0000-0000-0000000000b1' and day = pg_temp.d(14)),
  'the credited day stays after the post is deleted');
select is((pg_temp.state('00000000-0000-0000-0000-0000000000b1', 14, '12:00')->>'current')::int, 8, 'and so does the streak');

-- What counts as a take.
select pg_temp.post('30000000-0000-0000-0000-000000000015', '00000000-0000-0000-0000-0000000000b1', pg_temp.setup('violin', 'Eb'), pg_temp.at(15, '09:01'), pg_temp.at(15, '09:00'));
select ok(not exists (select 1 from public.daily_sound_takes where video_id = '30000000-0000-0000-0000-000000000015'), 'a different sound does not count');
select pg_temp.post('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', pg_temp.setup('violin', 'B'), pg_temp.at(15, '09:01'), pg_temp.at(15, '09:00'),
  source => '20000000-0000-0000-0000-0000000000f0');
select ok(exists (select 1 from public.daily_sound_takes where video_id = '40000000-0000-0000-0000-000000000001'), 'playing along with the featured clip counts');
select pg_temp.post('40000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000c1', pg_temp.setup('grand_piano', 'Eb'), pg_temp.at(16, '09:01'),
  screened => false);
select ok(not exists (select 1 from public.daily_sound_takes where video_id = '40000000-0000-0000-0000-000000000002'), 'an unscreened upload never counts');

-- Notification hook: a live streak with no take today, close to rollover.
select is((select count(*)::int from public.daily_streaks_at_risk(interval '3 hours', pg_temp.at(15, '22:00'))
           where user_id = '00000000-0000-0000-0000-0000000000b1'), 1, 'a streak ending within three hours is reported');
select is((select freeze_would_cover from public.daily_streaks_at_risk(interval '3 hours', pg_temp.at(15, '22:00'))
           where user_id = '00000000-0000-0000-0000-0000000000b1'), true, 'with whether this week''s freeze would save it');
select is((select count(*)::int from public.daily_streaks_at_risk(interval '3 hours', pg_temp.at(15, '12:00'))
           where user_id = '00000000-0000-0000-0000-0000000000b1'), 0, 'not earlier in the day');

-- ------------------------------------------------------- visibility in the payload
-- Day 15 takes: Cara's play-along (visible), Dan's take (Bob blocks Dan), Cara's hidden take.
select pg_temp.post('40000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000d1', pg_temp.setup('grand_piano', 'Eb'), pg_temp.at(15, '10:01'), pg_temp.at(15, '10:00'));
select pg_temp.post('40000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000c1', pg_temp.setup('grand_piano', 'Eb'), pg_temp.at(15, '11:01'), pg_temp.at(15, '11:00'));
update public.videos set hidden = true where id = '40000000-0000-0000-0000-000000000004';
insert into public.blocks (blocker_id, blocked_id) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000d1'),
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1');

select set_config('request.jwt.claims', '', true);
select is((daily_internal.daily_payload(pg_temp.at(15, '12:00'))->>'take_count')::int, 2, 'signed out: hidden takes are not counted');
select is((daily_internal.daily_payload(pg_temp.at(15, '12:00'))->'streak'), 'null'::jsonb, 'signed out: no streak');
select is((daily_internal.daily_payload(pg_temp.at(15, '12:00'))->'sound'->'video'->>'username'), 'alice', 'the featured creator is shown');
select pg_temp.act_as('00000000-0000-0000-0000-0000000000b1');
select is((daily_internal.daily_payload(pg_temp.at(15, '12:00'))->>'take_count')::int, 1, 'takes by blocked accounts are left out');
select is(jsonb_array_length(daily_internal.daily_payload(pg_temp.at(15, '12:00'))->'takes'), 1, 'from the list too');
select is((daily_internal.daily_payload(pg_temp.at(15, '12:00'))->'streak'->>'current')::int, 8, 'signed in: the caller''s streak');
select pg_temp.act_as('00000000-0000-0000-0000-0000000000c1');
select is((daily_internal.daily_payload(pg_temp.at(15, '12:00'))->'sound'->'video'), 'null'::jsonb,
  'a blocked featured creator is hidden');
select ok((daily_internal.daily_payload(pg_temp.at(15, '12:00'))->'sound'->'setup') is not null, 'but the sound stays playable');
select set_config('request.jwt.claims', '', true);

-- ------------------------------------------------------------- permissions
set local role anon;
select is((public.daily_sound_today()->>'day')::date, (now() at time zone 'UTC')::date, 'anyone can read today''s sound');
select is((public.daily_streak_profile('Bob')->>'best')::int, 8, 'profiles show the best streak');
select is((public.daily_streak_profile('Bob')->'badges'), '[3, 7]'::jsonb, 'and badges');
reset role;
select pg_temp.act_as('00000000-0000-0000-0000-0000000000b1');
set local role authenticated;
select throws_ok($$ select * from public.daily_streak_days $$, '42501', null, 'streak rows are not exposed to clients');
select throws_ok($$ insert into public.daily_streak_days (user_id, day) values (auth.uid(), current_date) $$, '42501', null,
  'clients cannot credit a day');
select throws_ok($$ select * from public.daily_theme_grants $$, '42501', null, 'theme loans are server-side');
select throws_ok($$ select public.schedule_daily_sound(current_date + 1, '10000000-0000-0000-0000-000000000001') $$, '42501', null,
  'only the owner schedules sounds');
select throws_ok($$ select * from public.daily_streaks_at_risk() $$, '42501', null, 'the notification hook is service-only');
reset role;

-- ------------------------------------------------------------------ admin
select set_config('test.d15', pg_temp.d(15)::text, true), set_config('test.d25', pg_temp.d(25)::text, true),
       set_config('test.d26', pg_temp.d(26)::text, true);
set local role service_role;
select throws_ok($$ select public.schedule_daily_sound((now() at time zone 'UTC')::date - 1, '10000000-0000-0000-0000-000000000001') $$,
  'P0001', 'DAILY_SOUND_IN_PAST', 'past days cannot be rescheduled');
select throws_ok($$ select public.schedule_daily_sound(current_setting('test.d25')::date, '10000000-0000-0000-0000-000000000002') $$,
  'P0001', 'DAILY_SOUND_NEEDS_PRO', 'a Pro sound needs an explicit override');
select is((public.schedule_daily_sound(current_setting('test.d25')::date, '10000000-0000-0000-0000-000000000002', 'Bright keys', null, true)).source,
  'scheduled', 'the owner can schedule a post for a date');
select throws_ok($$ select public.schedule_daily_sound(current_setting('test.d15')::date, '10000000-0000-0000-0000-000000000001') $$,
  'P0001', 'DAILY_SOUND_HAS_TAKES', 'a day with counted takes cannot change');
select throws_ok($$ select public.schedule_daily_sound(current_setting('test.d26')::date, '10000000-0000-0000-0000-000000000003') $$,
  'P0001', 'DAILY_SOUND_VIDEO_UNAVAILABLE', 'hidden posts cannot be scheduled');
reset role;

-- ------------------------------------------- real path, at the real current time
-- The owner schedules today's sound, then a take goes through the same functions the upload
-- endpoints call: reserve (sign-upload), then publish after screening (publish-upload).
set local role service_role;
select is((public.schedule_daily_sound((now() at time zone 'UTC')::date, '10000000-0000-0000-0000-000000000001', 'Real path')).source,
  'scheduled', 'the owner schedules a post for today, replacing the automatic pick');
select set_config('test.upload', public.reserve_video_upload('00000000-0000-0000-0000-0000000000e1', 100, 20)::text, true);
update public.pending_video_uploads set status = 'checking' where id = current_setting('test.upload')::uuid;
select lives_ok(format($$ select public.publish_screened_video(%L, %L, 0) $$, current_setting('test.upload'),
  jsonb_build_object('duration_s', 8, 'width', 720, 'height', 1280, 'caption', 'my take',
                     'sound_setup', pg_temp.setup('grand_piano', 'C') || '{"bpm":130}')), 'the screened take publishes');
reset role;
select pg_temp.act_as('00000000-0000-0000-0000-0000000000e1');
set local role authenticated;
select is((public.daily_sound_today()->'sound'->>'title'), 'Real path', 'the scheduled sound is today''s sound');
select ok((public.daily_sound_today()->'takes') @> jsonb_build_array(jsonb_build_object('id', current_setting('test.upload'))),
  'the published take is in today''s takes');
select is((public.daily_sound_today()->'streak'->>'current')::int, 1, 'publishing the take starts the poster''s streak');
select is((public.daily_sound_today()->'streak'->>'posted_today')::boolean, true, 'and marks today as done');
reset role;
select set_config('request.jwt.claims', '', true);

select * from finish();
rollback;
