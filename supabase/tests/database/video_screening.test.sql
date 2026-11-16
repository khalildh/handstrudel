begin;
select plan(23);

insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000000a', 'upload@test.dev');
insert into public.pending_video_uploads (id, user_id, video_bytes, thumb_bytes) values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000a', 100, 20);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select throws_ok($$ select * from public.pending_video_uploads $$, '42501', null, 'reservations are not exposed to clients');
select throws_ok($$ select public.reserve_video_upload('00000000-0000-0000-0000-00000000000a', 100, 20) $$,
  '42501', null, 'clients cannot reserve outside the upload endpoint');
select throws_ok($$ select public.publish_screened_video('11111111-1111-1111-1111-111111111111', '{}') $$,
  '42501', null, 'clients cannot call the publication RPC');
select throws_ok($$ select * from public.expired_video_uploads() $$, '42501', null, 'clients cannot read the cleanup queue');
reset role;

set local role anon;
select is(public.can_play_screened_media('11111111-1111-1111-1111-111111111111',
  'videos/00000000-0000-0000-0000-00000000000a/screened/11111111-1111-1111-1111-111111111111.mp4'),
  false, 'a reserved clip cannot play via its direct media key');
reset role;

set local role service_role;
select throws_ok($$ select public.publish_screened_video('11111111-1111-1111-1111-111111111111', '{}') $$,
  'P0001', 'UPLOAD_NOT_CHECKING', 'reserved upload cannot publish');
update public.pending_video_uploads set status = 'held' where id = '11111111-1111-1111-1111-111111111111';
select throws_ok($$ select public.publish_screened_video('11111111-1111-1111-1111-111111111111', '{}') $$,
  'P0001', 'UPLOAD_NOT_CHECKING', 'held upload cannot publish');
update public.pending_video_uploads set status = 'checking', attempt = 2 where id = '11111111-1111-1111-1111-111111111111';
select throws_ok($$ select public.publish_screened_video('11111111-1111-1111-1111-111111111111', '{}', 1) $$,
  'P0001', 'UPLOAD_NOT_CHECKING', 'an expired attempt cannot publish over a retry');
select lives_ok($$ select public.publish_screened_video('11111111-1111-1111-1111-111111111111',
  '{"duration_s":10,"width":720,"height":1280,"caption":"test","comments_enabled":false,"sound_setup":null,"created_at":"2070-01-01"}', 2) $$,
  'service can publish a checked upload');
select is((select status from public.pending_video_uploads where id = '11111111-1111-1111-1111-111111111111'),
  'published', 'publication updates status in the same transaction');
select throws_ok($$ select public.publish_screened_video('11111111-1111-1111-1111-111111111111', '{}', 2) $$,
  'P0001', 'UPLOAD_NOT_CHECKING', 'a completed upload cannot publish twice');
reset role;
select is((select video_key from public.videos where id = '11111111-1111-1111-1111-111111111111'),
  'videos/00000000-0000-0000-0000-00000000000a/screened/11111111-1111-1111-1111-111111111111.mp4', 'server generates the private media key');
select is((select comments_enabled from public.videos where id = '11111111-1111-1111-1111-111111111111'),
  false, 'publication preserves per-post controls');
select is((select created_at from public.videos where id = '11111111-1111-1111-1111-111111111111'),
  now(), 'publication ignores client-provided post time');

set local role anon;
select is(public.can_play_screened_media('11111111-1111-1111-1111-111111111111',
  'videos/00000000-0000-0000-0000-00000000000a/screened/11111111-1111-1111-1111-111111111111.mp4'),
  true, 'an approved clip plays without an account');
select is(public.can_play_screened_media('11111111-1111-1111-1111-111111111111',
  'thumbs/00000000-0000-0000-0000-00000000000a/screened/11111111-1111-1111-1111-111111111111.jpg'),
  true, 'its approved thumbnail is also public');
select is(public.can_play_screened_media('11111111-1111-1111-1111-111111111111',
  'videos/00000000-0000-0000-0000-00000000000b/screened/11111111-1111-1111-1111-111111111111.mp4'),
  false, 'approval does not authorize a mismatched key');
reset role;

update public.videos set hidden = true where id = '11111111-1111-1111-1111-111111111111';
update public.pending_video_uploads set created_at = now() - interval '2 days';
insert into public.pending_video_uploads (id, user_id, video_bytes, thumb_bytes, status, created_at, check_started_at) values
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-00000000000a', 100, 20, 'checking', now() - interval '2 days', now()),
  ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-00000000000a', 100, 20, 'held', now() - interval '2 days', now()),
  ('44444444-4444-4444-4444-444444444444', '00000000-0000-0000-0000-00000000000a', 100, 20, 'reserved', now(), null);
select is(public.can_play_screened_media('11111111-1111-1111-1111-111111111111',
  'videos/00000000-0000-0000-0000-00000000000a/screened/11111111-1111-1111-1111-111111111111.mp4'),
  false, 'hidden media is denied immediately even for the media service');
select is(public.can_play_screened_media('33333333-3333-3333-3333-333333333333',
  'videos/00000000-0000-0000-0000-00000000000a/screened/33333333-3333-3333-3333-333333333333.mp4'),
  false, 'held uploads cannot play');
select results_eq('select id from public.expired_video_uploads()',
  $$ values ('33333333-3333-3333-3333-333333333333'::uuid) $$,
  'only an old abandoned upload is eligible for cleanup');

delete from auth.users where id = '00000000-0000-0000-0000-00000000000a';
select is(public.can_play_screened_media('11111111-1111-1111-1111-111111111111',
  'thumbs/00000000-0000-0000-0000-00000000000a/screened/11111111-1111-1111-1111-111111111111.jpg'),
  false, 'deleted account media is denied');
select is((select count(*)::int from public.expired_video_uploads()
  where id = '11111111-1111-1111-1111-111111111111'), 1, 'deleted account media remains eligible for cleanup');
select is((select count(*)::int from public.videos), 0, 'taking down the account removes its published clip');

select * from finish();
rollback;
