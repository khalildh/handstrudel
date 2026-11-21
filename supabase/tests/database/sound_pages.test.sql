begin;
select plan(22);

insert into auth.users (id, email)
values ('66000000-0000-0000-0000-000000000001', 'sound-original@test.dev'),
       ('66000000-0000-0000-0000-000000000002', 'sound-taker@test.dev'),
       ('66000000-0000-0000-0000-000000000003', 'sound-viewer@test.dev'),
       ('66000000-0000-0000-0000-000000000004', 'sound-blocked@test.dev');
update public.profiles set username = 'sound_' || right(id::text, 1) where id::text like '66000000-%';

-- s1 is the original sound. s2 changes only performance settings (tempo, pad level).
-- s3 uses a different instrument. s4 is a play-along over s1 with no setup of its own.
create temp table setups (n int, setup jsonb);
insert into setups values
  (1, '{"version":1,"instrument":"rhodes","waveform":"sine","key":"C","scale":"Minor","progression":"pop","mode":"soundfont","bpm":90,"useSoundFont":true,"autoStrum":false,"padVolume":0.3,"gridOctave":3,"gridRange":2}'),
  (2, '{"version":1,"instrument":"rhodes","waveform":"saw","key":"C","scale":"Minor","progression":"pop","mode":"soundfont","bpm":120,"useSoundFont":true,"autoStrum":true,"padVolume":0.1,"gridOctave":4,"gridRange":1}'),
  (3, '{"version":1,"instrument":"grand_piano","waveform":"sine","key":"C","scale":"Minor","progression":"pop","mode":"soundfont","bpm":90,"useSoundFont":true,"autoStrum":false,"padVolume":0.3,"gridOctave":3,"gridRange":2}');

select is(public.sound_identity_hash((select setup from setups where n = 1)),
          public.sound_identity_hash((select setup from setups where n = 2)),
          'tempo, pad level, grid and strum settings do not change the sound');
select isnt(public.sound_identity_hash((select setup from setups where n = 1)),
            public.sound_identity_hash((select setup from setups where n = 3)),
            'a different instrument is a different sound');
select is(public.sound_identity_hash(null), null, 'posts without a setup have no hash');

insert into public.videos (id, user_id, video_key, thumb_key, sound_setup, backing_enabled, like_count, created_at)
values ('67000000-0000-0000-0000-000000000001', '66000000-0000-0000-0000-000000000001',
        'videos/66000000-0000-0000-0000-000000000001/a', 'thumbs/66000000-0000-0000-0000-000000000001/a',
        (select setup from setups where n = 1), true, 5, now() - interval '5 hours');
insert into public.videos (id, user_id, video_key, thumb_key, sound_setup, like_count, created_at, hidden)
values ('67000000-0000-0000-0000-000000000002', '66000000-0000-0000-0000-000000000002',
        'videos/66000000-0000-0000-0000-000000000002/b', 'thumbs/66000000-0000-0000-0000-000000000002/b',
        (select setup from setups where n = 2), 9, now() - interval '4 hours', false),
       ('67000000-0000-0000-0000-000000000003', '66000000-0000-0000-0000-000000000002',
        'videos/66000000-0000-0000-0000-000000000002/c', 'thumbs/66000000-0000-0000-0000-000000000002/c',
        (select setup from setups where n = 3), 0, now() - interval '3 hours', false),
       ('67000000-0000-0000-0000-000000000005', '66000000-0000-0000-0000-000000000002',
        'videos/66000000-0000-0000-0000-000000000002/e', 'thumbs/66000000-0000-0000-0000-000000000002/e',
        (select setup from setups where n = 1), 1, now() - interval '2 hours', true),
       ('67000000-0000-0000-0000-000000000006', '66000000-0000-0000-0000-000000000004',
        'videos/66000000-0000-0000-0000-000000000004/f', 'thumbs/66000000-0000-0000-0000-000000000004/f',
        (select setup from setups where n = 1), 2, now() - interval '1 hour', false);
insert into public.videos (id, user_id, video_key, thumb_key, source_video_id, like_count, created_at)
values ('67000000-0000-0000-0000-000000000004', '66000000-0000-0000-0000-000000000002',
        'videos/66000000-0000-0000-0000-000000000002/d', 'thumbs/66000000-0000-0000-0000-000000000002/d',
        '67000000-0000-0000-0000-000000000001', 3, now() - interval '150 minutes');

select is((select sound_id from public.videos where id = '67000000-0000-0000-0000-000000000001'),
          '67000000-0000-0000-0000-000000000001'::uuid, 'the first post starts its own sound');
select is((select sound_id from public.videos where id = '67000000-0000-0000-0000-000000000002'),
          '67000000-0000-0000-0000-000000000001'::uuid, 'a take with the same setup joins the original');
select is((select sound_id from public.videos where id = '67000000-0000-0000-0000-000000000003'),
          '67000000-0000-0000-0000-000000000003'::uuid, 'a different setup starts a new sound');
select is((select sound_id from public.videos where id = '67000000-0000-0000-0000-000000000004'),
          '67000000-0000-0000-0000-000000000001'::uuid, 'a play-along inherits its source''s sound');

-- A post whose own setup differs still inherits from the clip it played along with.
insert into public.videos (id, user_id, video_key, thumb_key, sound_setup, source_video_id)
values ('67000000-0000-0000-0000-000000000007', '66000000-0000-0000-0000-000000000003',
        'videos/66000000-0000-0000-0000-000000000003/g', 'thumbs/66000000-0000-0000-0000-000000000003/g',
        (select setup from setups where n = 3), '67000000-0000-0000-0000-000000000001');
select is((select sound_id from public.videos where id = '67000000-0000-0000-0000-000000000007'),
          '67000000-0000-0000-0000-000000000001'::uuid, 'the backing clip wins over the take''s own setup');
delete from public.videos where id = '67000000-0000-0000-0000-000000000007';

update public.videos set sound_id = '67000000-0000-0000-0000-000000000003'
 where id = '67000000-0000-0000-0000-000000000002';
select is((select sound_id from public.videos where id = '67000000-0000-0000-0000-000000000002'),
          '67000000-0000-0000-0000-000000000001'::uuid, 'a post''s sound never changes after publication');

-- Viewer 3 blocks creator 4.
insert into public.blocks (blocker_id, blocked_id)
values ('66000000-0000-0000-0000-000000000003', '66000000-0000-0000-0000-000000000004');

set local role anon;
select results_eq(
  $$select sound_id, take_count, original_video_id from public.sound_summary('67000000-0000-0000-0000-000000000002')$$,
  $$values ('67000000-0000-0000-0000-000000000001'::uuid, 4::bigint, '67000000-0000-0000-0000-000000000001'::uuid)$$,
  'guests see the original and every visible take, without hidden ones');
select results_eq(
  $$select id from public.sound_takes where sound_id = '67000000-0000-0000-0000-000000000001'
    order by like_count desc, id desc$$,
  $$values ('67000000-0000-0000-0000-000000000002'::uuid), ('67000000-0000-0000-0000-000000000001'::uuid),
           ('67000000-0000-0000-0000-000000000004'::uuid), ('67000000-0000-0000-0000-000000000006'::uuid)$$,
  'Top sorts by likes');
select results_eq(
  $$select id from public.sound_takes where sound_id = '67000000-0000-0000-0000-000000000001'
    and (like_count < 3 or (like_count = 3 and id < '67000000-0000-0000-0000-000000000004'))
    order by like_count desc, id desc limit 1$$,
  $$values ('67000000-0000-0000-0000-000000000006'::uuid)$$,
  'Top pages with a (like_count, id) cursor');
select results_eq(
  $$select id from public.sound_takes where sound_id = '67000000-0000-0000-0000-000000000001'
    order by created_at desc, id desc limit 2$$,
  $$values ('67000000-0000-0000-0000-000000000006'::uuid), ('67000000-0000-0000-0000-000000000004'::uuid)$$,
  'Recent sorts newest first');
select is((select count(*) from public.sound_summary('67000000-0000-0000-0000-000000000005')), 0::bigint,
          'a hidden post opens no sound page');
select results_eq(
  $$select video_id, take_count from public.sound_take_counts(array[
      '67000000-0000-0000-0000-000000000001', '67000000-0000-0000-0000-000000000003',
      '67000000-0000-0000-0000-000000000005']::uuid[]) order by video_id$$,
  $$values ('67000000-0000-0000-0000-000000000001'::uuid, 4::bigint), ('67000000-0000-0000-0000-000000000003'::uuid, 1::bigint)$$,
  'feed counts skip hidden posts');
select throws_ok($$select * from public.sound_identities$$, '42501', null, 'the setup registry stays private');
select throws_ok($$select public.resolve_sound_id(gen_random_uuid(), null, null)$$, '42501', null,
                 'clients cannot resolve sounds themselves');
reset role;

select set_config('request.jwt.claims', '{"sub":"66000000-0000-0000-0000-000000000003"}', true);
set local role authenticated;
select is((select take_count from public.sound_summary('67000000-0000-0000-0000-000000000001')), 3::bigint,
          'takes by a creator the viewer blocked are not counted');
select is((select count(*) from public.sound_takes where user_id = '66000000-0000-0000-0000-000000000004'), 0::bigint,
          'and are not listed');
insert into public.reports (reporter_id, video_id, reason)
values (auth.uid(), '67000000-0000-0000-0000-000000000002', 'spam');
select is((select take_count from public.sound_summary('67000000-0000-0000-0000-000000000001')), 2::bigint,
          'posts the viewer reported drop out too');
reset role;

-- When the original is taken down the sound survives without it.
update public.videos set hidden = true where id = '67000000-0000-0000-0000-000000000001';
select set_config('request.jwt.claims', '', true);
set local role anon;
select results_eq(
  $$select take_count, original_video_id from public.sound_summary('67000000-0000-0000-0000-000000000002')$$,
  $$values (3::bigint, null::uuid)$$,
  'a hidden original is neither counted nor named');
reset role;
insert into public.videos (id, user_id, video_key, thumb_key, sound_setup)
values ('67000000-0000-0000-0000-000000000008', '66000000-0000-0000-0000-000000000003',
        'videos/66000000-0000-0000-0000-000000000003/h', 'thumbs/66000000-0000-0000-0000-000000000003/h',
        (select setup from setups where n = 1));
select is((select sound_id from public.videos where id = '67000000-0000-0000-0000-000000000008'),
          '67000000-0000-0000-0000-000000000001'::uuid, 'new takes keep joining a sound whose original is hidden');

select * from finish();
rollback;
