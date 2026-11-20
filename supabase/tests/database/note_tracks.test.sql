-- "Learn to play" note tracks: stored only through screened publication, with the preset.
begin;
select plan(11);

insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000000a', 'notes@test.dev');
update public.profiles set username = 'maya' where id = '00000000-0000-0000-0000-00000000000a';
insert into public.pending_video_uploads (id, user_id, video_bytes, thumb_bytes, status) values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000a', 100, 20, 'checking'),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-00000000000a', 100, 20, 'checking'),
  ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-00000000000a', 100, 20, 'checking');

set local role service_role;
select lives_ok($$ select public.publish_screened_video('11111111-1111-1111-1111-111111111111',
  '{"duration_s":7,"width":720,"height":1560,"sound_setup":{"version":1},
    "note_track":{"v":1,"notes":[{"t":0,"d":0.5,"m":60},{"t":0.5,"d":1,"m":64,"c":true}]}}') $$,
  'a post with its preset publishes with notes');
select lives_ok($$ select public.publish_screened_video('22222222-2222-2222-2222-222222222222',
  '{"duration_s":7,"width":720,"height":1560,"sound_setup":null,
    "note_track":{"v":1,"notes":[{"t":0,"d":0.5,"m":60}]}}') $$,
  'a post without a preset still publishes');
select throws_ok($$ select public.publish_screened_video('33333333-3333-3333-3333-333333333333',
  '{"duration_s":7,"width":720,"height":1560,"sound_setup":{"version":1},"note_track":{"v":2,"notes":[]}}') $$,
  '23514', null, 'a malformed track is rejected by the column check');
reset role;

select is((select note_track->'notes'->1->>'m' from public.videos where id = '11111111-1111-1111-1111-111111111111'),
  '64', 'notes are stored with the post');
select is((select note_track from public.videos where id = '22222222-2222-2222-2222-222222222222'),
  null, 'notes are dropped when the preset is not shared');

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is((select has_note_track from public.feed_videos where id = '11111111-1111-1111-1111-111111111111'),
  true, 'the feed flags posts with notes');
select is((select has_note_track from public.feed_videos where id = '22222222-2222-2222-2222-222222222222'),
  false, 'the feed flags posts without notes');
select is((select jsonb_array_length(note_track->'notes') from public.videos
            where id = '11111111-1111-1111-1111-111111111111'),
  2, 'anyone who can see the post can load its notes');
reset role;

select throws_ok($$ update public.videos set note_track = jsonb_build_object('v', 1, 'notes',
    (select jsonb_agg(jsonb_build_object('t', 0, 'd', 1, 'm', 60)) from generate_series(1, 601)))
  where id = '11111111-1111-1111-1111-111111111111' $$,
  '23514', null, 'a track over 600 notes is rejected');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select throws_ok($$ update public.videos set note_track = null where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501', null, 'owners cannot rewrite notes directly');
select is((select has_note_track from public.feed_videos where id = '11111111-1111-1111-1111-111111111111'),
  true, 'the signed-in feed sees the same flag');
reset role;

select * from finish();
rollback;
