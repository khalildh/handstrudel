-- Instruments that travel with posts: storage and validation, credit (copy / remix), the
-- "Allow remixes" toggle, remix counts and chains, moderation, and My instruments RLS.
begin;
select plan(47);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'ana@test.dev'),
  ('00000000-0000-0000-0000-0000000000b2', 'ben@test.dev'),
  ('00000000-0000-0000-0000-0000000000c3', 'cy@test.dev'),
  ('00000000-0000-0000-0000-0000000000d4', 'di@test.dev'),
  ('00000000-0000-0000-0000-0000000000e5', 'eve@test.dev');
update public.profiles set username = 'ana' where id = '00000000-0000-0000-0000-0000000000a1';
update public.profiles set username = 'ben' where id = '00000000-0000-0000-0000-0000000000b2';
update public.profiles set username = 'cyd' where id = '00000000-0000-0000-0000-0000000000c3';
update public.profiles set username = 'dia' where id = '00000000-0000-0000-0000-0000000000d4';
update public.profiles set username = 'eve' where id = '00000000-0000-0000-0000-0000000000e5';

create temp table spec (name text primary key, body jsonb);
insert into spec values
  ('wide', '{"format":"handstrudel.instrument","format_version":1,"id":"ana.wide","name":"Wide Wheel",
     "surface":{"type":"split_wheel","radius":1,"rest_radius":0.26,"octave_band_radius":0.7},
     "chords":{"side":"left"},"notes":{"source":"scale_one_octave","octave_band":true,"highlight_chord_tones":true}}'),
  ('wide-remix', '{"format":"handstrudel.instrument","format_version":1,"id":"ana.wide.remix-1","name":"Wide Wheel (remix)",
     "surface":{"type":"split_wheel","radius":0.9,"rest_radius":0.3,"octave_band_radius":0.7},
     "chords":{"side":"right"},"notes":{"source":"scale_one_octave","octave_band":true}}'),
  ('remix-of-remix', '{"format":"handstrudel.instrument","format_version":1,"id":"ana.wide.remix-2","name":"Wider",
     "surface":{"type":"split_wheel","radius":0.8,"rest_radius":0.3,"octave_band_radius":0.7},
     "chords":{"side":"right"},"notes":{"source":"chord_tones_three_octaves","octave_band":false}}'),
  ('closed', '{"format":"handstrudel.instrument","format_version":1,"id":"ben.closed","name":"Closed Wheel",
     "surface":{"type":"split_wheel","radius":1,"rest_radius":0.36,"octave_band_radius":0.8},
     "chords":{"side":"left"},"notes":{"source":"chord_tones_three_octaves","octave_band":false}}'),
  ('closed-edit', '{"format":"handstrudel.instrument","format_version":1,"id":"ben.closed.edit","name":"Closed Wheel 2",
     "surface":{"type":"split_wheel","radius":0.9,"rest_radius":0.36,"octave_band_radius":0.8},
     "chords":{"side":"left"},"notes":{"source":"chord_tones_three_octaves","octave_band":false}}'),
  ('ai', '{"format":"handstrudel.instrument","format_version":1,"id":"ai.orb","name":"  Orb  ","ai_generated":true,
     "surface":{"type":"split_wheel","radius":1,"rest_radius":0.36,"octave_band_radius":0.8},
     "chords":{"side":"left"},"notes":{"source":"scale_one_octave","octave_band":true}}'),
  ('v2', '{"format":"handstrudel.instrument","format_version":2,"id":"future.pads","name":"Pads",
     "surface":{"type":"pad_grid","rows":4}}');
grant select on spec to anon, authenticated;

insert into public.pending_video_uploads (id, user_id, video_bytes, thumb_bytes, status)
select id::uuid, owner::uuid, 100, 20, 'checking' from (values
  ('a0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1'),
  ('b0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b2'),
  ('c0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c3'),
  ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000d4'),
  ('d0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000d4'),
  ('b0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000b2'),
  ('c0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000c3'),
  ('d0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000d4'),
  ('a0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a1'),
  ('a0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000a1'),
  ('a0000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000a1'),
  ('a0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-0000000000a1'),
  ('a0000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-0000000000a1'),
  ('a0000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-0000000000a1')
) as uploads(id, owner);

create function pg_temp.post(upload text, instrument text, source text default null, allow boolean default null)
returns void language sql as $$
  select public.publish_screened_video(upload::uuid, jsonb_strip_nulls(jsonb_build_object(
    'duration_s', 7, 'width', 720, 'height', 1560,
    'sound_setup', '{"version":1,"key":"D"}'::jsonb,
    'instrument_spec', (select body from spec where name = instrument),
    'instrument_source_id', source, 'instrument_remixes_allowed', allow)), 0)
$$;

-- ---------------------------------------------------------------- storing and validation
select lives_ok($$ select pg_temp.post('a0000000-0000-0000-0000-000000000001', 'wide') $$,
  'a take publishes with its instrument');
select is((select instrument_spec from public.videos where id = 'a0000000-0000-0000-0000-000000000001'),
  (select body from spec where name = 'wide'), 'the instrument file is stored as posted');
select is((select instrument_kind from public.videos where id = 'a0000000-0000-0000-0000-000000000001'),
  'own', 'an instrument without a source is the poster''s own');
select is((select sound_setup->>'key' from public.videos where id = 'a0000000-0000-0000-0000-000000000001'),
  'D', 'the sound stays in sound_setup, separate from the instrument');
select is((select sound_setup ? 'surface' from public.videos where id = 'a0000000-0000-0000-0000-000000000001'),
  false, 'the sound does not contain the instrument');

select lives_ok($$ select public.publish_screened_video('a0000000-0000-0000-0000-000000000002',
  '{"duration_s":7,"width":720,"height":1560}', 0) $$, 'a take without an instrument still publishes');
select is((select (instrument_spec, instrument_kind, instrument_remixes_allowed)::text from public.videos
            where id = 'a0000000-0000-0000-0000-000000000002'), '(,,t)', 'no instrument, no kind');

select throws_ok($$ select public.publish_screened_video('a0000000-0000-0000-0000-000000000003',
  jsonb_build_object('duration_s', 7, 'width', 720, 'height', 1560, 'instrument_spec',
    (select jsonb_set(body, '{id}', '"Has Spaces!"') from spec where name = 'wide')), 0) $$,
  '23514', null, 'an instrument with an invalid id is rejected');
select throws_ok($$ select public.publish_screened_video('a0000000-0000-0000-0000-000000000003',
  jsonb_build_object('duration_s', 7, 'width', 720, 'height', 1560, 'instrument_spec',
    (select jsonb_set(body, '{surface,type}', '"hexagon_grid"') from spec where name = 'wide')), 0) $$,
  '23514', null, 'a version-1 surface outside the vocabulary is rejected');
select throws_ok($$ select public.publish_screened_video('a0000000-0000-0000-0000-000000000003',
  jsonb_build_object('duration_s', 7, 'width', 720, 'height', 1560, 'instrument_spec',
    (select jsonb_set(body, '{padding}', to_jsonb(repeat('x', 21000))) from spec where name = 'wide')), 0) $$,
  '23514', null, 'an instrument over the size cap is rejected');

select is(public.instrument_spec_issue((select body from spec where name = 'wide')), null, 'a valid file has no issue');
select is(public.instrument_spec_issue((select jsonb_set(body, '{format}', '"other"') from spec where name = 'wide')),
  'unsupported_format', 'another format is rejected');
select is(public.instrument_spec_issue((select jsonb_set(body, '{name}', '"   "') from spec where name = 'wide')),
  'name_missing', 'an empty name is rejected');
select is(public.instrument_spec_issue((select jsonb_set(body, '{format_version}', '0') from spec where name = 'wide')),
  'unsupported_version', 'version 0 is rejected');
select is(public.instrument_spec_issue((select jsonb_set(body, '{surface,radius}', '3.5') from spec where name = 'wide')),
  null, 'out-of-range values are left for the loader to repair');
select is(public.instrument_spec_issue('[]'::jsonb), 'malformed', 'a non-object is rejected');

select lives_ok($$ select pg_temp.post('a0000000-0000-0000-0000-000000000004', 'v2') $$,
  'a newer format version is stored for newer apps');
select lives_ok($$ select pg_temp.post('a0000000-0000-0000-0000-000000000005', 'ai') $$,
  'an AI-generated instrument publishes');
select is((select instrument_ai_generated from public.videos where id = 'a0000000-0000-0000-0000-000000000005'),
  true, 'the AI marker in the file is flagged on the post');

-- ---------------------------------------------------------------- credit: copies and remixes
select pg_temp.post('b0000000-0000-0000-0000-000000000001', 'wide', 'a0000000-0000-0000-0000-000000000001');
select is((select (instrument_kind, instrument_source_id)::text from public.videos where id = 'b0000000-0000-0000-0000-000000000001'),
  '(copy,a0000000-0000-0000-0000-000000000001)', 'playing it unchanged credits the post that made it');

select pg_temp.post('c0000000-0000-0000-0000-000000000001', 'wide-remix', 'a0000000-0000-0000-0000-000000000001');
select is((select (instrument_kind, instrument_source_id)::text from public.videos where id = 'c0000000-0000-0000-0000-000000000001'),
  '(remix,a0000000-0000-0000-0000-000000000001)', 'an edited copy is a remix of its source');

select pg_temp.post('d0000000-0000-0000-0000-000000000001', 'wide', 'b0000000-0000-0000-0000-000000000001');
select is((select (instrument_kind, instrument_source_id)::text from public.videos where id = 'd0000000-0000-0000-0000-000000000001'),
  '(copy,a0000000-0000-0000-0000-000000000001)', 'a copy of a copy still credits the maker');

select pg_temp.post('d0000000-0000-0000-0000-000000000002', 'remix-of-remix', 'c0000000-0000-0000-0000-000000000001');
select is((select (instrument_kind, instrument_source_id)::text from public.videos where id = 'd0000000-0000-0000-0000-000000000002'),
  '(remix,c0000000-0000-0000-0000-000000000001)', 'a remix of a remix points at the remix');

select pg_temp.post('a0000000-0000-0000-0000-000000000006', 'wide', '99999999-9999-9999-9999-999999999999');
select is((select (instrument_kind, instrument_source_id)::text from public.videos where id = 'a0000000-0000-0000-0000-000000000006'),
  '(copy,)', 'an unknown source is never credited to the poster');

-- ---------------------------------------------------------------- Allow remixes
select pg_temp.post('b0000000-0000-0000-0000-000000000002', 'closed', null, false);
select is((select instrument_remixes_allowed from public.videos where id = 'b0000000-0000-0000-0000-000000000002'),
  false, 'the creator can turn remixes off');
select pg_temp.post('c0000000-0000-0000-0000-000000000002', 'closed-edit', 'b0000000-0000-0000-0000-000000000002');
select is((select instrument_spec from public.videos where id = 'c0000000-0000-0000-0000-000000000002'),
  null, 'a remix of a no-remix instrument does not keep the instrument');
select pg_temp.post('d0000000-0000-0000-0000-000000000003', 'closed', 'b0000000-0000-0000-0000-000000000002', true);
select is((select (instrument_kind, instrument_remixes_allowed)::text from public.videos where id = 'd0000000-0000-0000-0000-000000000003'),
  '(copy,f)', 'playing a no-remix instrument is allowed and keeps it closed to remixes');

-- ---------------------------------------------------------------- feeds, counts and chains
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is((select (has_instrument, instrument_spec_name, instrument_kind, instrument_remix_count)::text
             from public.feed_videos where id = 'a0000000-0000-0000-0000-000000000001'),
  '(t,"Wide Wheel",own,1)', 'the feed shows the chip and one remix on the original');
select is((select (instrument_source_username, instrument_remix_count)::text
             from public.feed_videos where id = 'b0000000-0000-0000-0000-000000000001'),
  '(ana,1)', 'a copy credits @ana and shows the original''s remix count');
select is((select (instrument_spec_name, instrument_ai_generated)::text
             from public.feed_videos where id = 'a0000000-0000-0000-0000-000000000005'),
  '(Orb,t)', 'the feed trims the name and flags AI instruments');
select is((select has_instrument from public.feed_videos where id = 'a0000000-0000-0000-0000-000000000002'),
  false, 'posts without an instrument have no chip');
select results_eq($$ select username from public.instrument_remix_chain('d0000000-0000-0000-0000-000000000002') $$,
  array['dia', 'cyd', 'ana'], 'the remix chain leads back to the original');
select is((select instrument_spec->>'id' from public.videos where id = 'a0000000-0000-0000-0000-000000000001'),
  'ana.wide', 'anyone who can see the post can load its instrument');
select is(public.instrument_reuse_allowed('b0000000-0000-0000-0000-000000000002'), false,
  'a no-remix instrument cannot be kept');
reset role;

-- Moderation: a hidden remix leaves counts and chains; a blocked maker loses the credit line.
update public.videos set hidden = true where id = 'c0000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e5","role":"authenticated"}', true);
select is((select instrument_remix_count from public.feed_videos where id = 'a0000000-0000-0000-0000-000000000001'),
  0, 'hidden remixes are not counted');
select results_eq($$ select username from public.instrument_remix_chain('d0000000-0000-0000-0000-000000000002') $$,
  array['dia'], 'the chain stops at a hidden post');
reset role;
insert into public.blocks (blocker_id, blocked_id) values
  ('00000000-0000-0000-0000-0000000000e5', '00000000-0000-0000-0000-0000000000a1');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e5","role":"authenticated"}', true);
select is((select (instrument_kind, instrument_source_id, instrument_source_username)::text
             from public.feed_videos where id = 'b0000000-0000-0000-0000-000000000001'),
  '(copy,,)', 'credit to a blocked creator is left out, not moved to the poster');
select is(public.instrument_reuse_allowed('a0000000-0000-0000-0000-000000000001'), false,
  'a blocked creator''s instrument cannot be kept');

-- ---------------------------------------------------------------- My instruments
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select lives_ok($$ insert into public.my_instruments (id, spec, kind, source_video_id)
  values ('f0000000-0000-0000-0000-000000000001', (select body from spec where name = 'wide'), 'saved',
          'a0000000-0000-0000-0000-000000000001') $$, 'a player keeps an instrument from a post');
select lives_ok($$ insert into public.my_instruments (id, spec, kind)
  values ('f0000000-0000-0000-0000-000000000002', (select body from spec where name = 'ai'), 'imported') $$,
  'a player imports a file');
select is((select ai_generated from public.my_instruments where id = 'f0000000-0000-0000-0000-000000000002'),
  true, 'kept AI instruments stay flagged');
reset role;
-- Ben keeps Di's no-remix copy only through the toggle check.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c3","role":"authenticated"}', true);
select throws_ok($$ insert into public.my_instruments (id, spec, kind, source_video_id)
  values ('f0000000-0000-0000-0000-000000000003', (select body from spec where name = 'closed'), 'saved',
          'b0000000-0000-0000-0000-000000000002') $$,
  '42501', null, 'an instrument with remixes off cannot be saved');
select throws_ok($$ insert into public.my_instruments (id, spec, kind, source_video_id)
  values ('f0000000-0000-0000-0000-000000000004', (select body from spec where name = 'closed-edit'), 'remixed',
          'd0000000-0000-0000-0000-000000000003') $$,
  '42501', null, 'nor remixed through a copy that inherited the setting');
select is((select count(*)::int from public.my_instruments), 0, 'players only see their own instruments');
select throws_ok($$ insert into public.my_instruments (id, user_id, spec, kind)
  values ('f0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-0000000000b2',
          (select body from spec where name = 'wide'), 'created') $$,
  '42501', null, 'nobody writes into someone else''s instruments');
select throws_ok($$ insert into public.my_instruments (id, spec, kind)
  values ('f0000000-0000-0000-0000-000000000006', '{"format":"handstrudel.instrument"}', 'created') $$,
  '23514', null, 'invalid files are not stored');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select throws_ok($$ update public.my_instruments set kind = 'created' where id = 'f0000000-0000-0000-0000-000000000001' $$,
  '42501', null, 'where an instrument came from cannot be rewritten');
reset role;

select * from finish();
rollback;
