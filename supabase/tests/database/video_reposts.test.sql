begin;
select plan(16);

insert into auth.users (id, email) values
  ('66000000-0000-0000-0000-000000000001', 'repost-author@test.dev'),
  ('66000000-0000-0000-0000-000000000002', 'repost-friend@test.dev'),
  ('66000000-0000-0000-0000-000000000003', 'repost-follower@test.dev'),
  ('66000000-0000-0000-0000-000000000004', 'repost-stranger@test.dev');
update public.profiles set username = 'repost_' || right(id::text, 1) where id::text like '66000000-%';

insert into public.videos (id, user_id, video_key, thumb_key, hidden, created_at)
select ('67000000-0000-0000-0000-00000000000' || n)::uuid, '66000000-0000-0000-0000-000000000001',
       'videos/66000000-0000-0000-0000-000000000001/v' || n,
       'thumbs/66000000-0000-0000-0000-000000000001/t' || n,
       n = 2, now() - interval '1 day'
from generate_series(1, 2) n;

insert into public.follows (follower_id, followee_id)
values ('66000000-0000-0000-0000-000000000003', '66000000-0000-0000-0000-000000000002');

set local role anon;
select throws_ok($$select public.set_video_repost('67000000-0000-0000-0000-000000000001', true)$$,
  '42501', null, 'guests cannot repost');
select is((select reposts from public.video_engagement_v2('67000000-0000-0000-0000-000000000001')),
  0::bigint, 'public count starts at zero');
reset role;

select set_config('request.jwt.claims', '{"sub":"66000000-0000-0000-0000-000000000001"}', true);
set local role authenticated;
select throws_ok($$select public.set_video_repost('67000000-0000-0000-0000-000000000001', true)$$,
  '42501', 'REPOST_NOT_AVAILABLE', 'cannot repost your own clip');
reset role;

select set_config('request.jwt.claims', '{"sub":"66000000-0000-0000-0000-000000000002"}', true);
set local role authenticated;
select throws_ok($$select public.set_video_repost('67000000-0000-0000-0000-000000000002', true)$$,
  '42501', 'REPOST_NOT_AVAILABLE', 'hidden clips cannot be reposted');
select results_eq(
  $$select reposts, reposted_by_me from public.set_video_repost('67000000-0000-0000-0000-000000000001', true)$$,
  $$values (1::bigint, true)$$, 'repost updates count and viewer state');
select is((select reposts from public.set_video_repost('67000000-0000-0000-0000-000000000001', true)),
  1::bigint, 'repeating the write is idempotent');
select throws_ok($$select * from public.video_reposts$$, '42501', null, 'raw repost relationships are private');
reset role;

select set_config('request.jwt.claims', '{"sub":"66000000-0000-0000-0000-000000000004"}', true);
set local role authenticated;
select is((select count(*) from public.following_activity_videos), 0::bigint, 'non-followers do not receive the clip');
select is((select reposted_by_me from public.video_engagement_v2('67000000-0000-0000-0000-000000000001')),
  false, 'viewer state is not shared between accounts');
reset role;

select set_config('request.jwt.claims', '{"sub":"66000000-0000-0000-0000-000000000003"}', true);
set local role authenticated;
select results_eq(
  $$select username::text, reposted_by, activity_at > created_at from public.following_activity_videos$$,
  $$values ('repost_1'::text, 'repost_2'::text, true)$$, 'followers see the original clip attributed to the reposter');
insert into public.follows (follower_id, followee_id)
values (auth.uid(), '66000000-0000-0000-0000-000000000001');
select is((select count(*) from public.following_activity_videos), 1::bigint, 'direct follows and reposts deduplicate');
insert into public.blocks (blocker_id, blocked_id)
values (auth.uid(), '66000000-0000-0000-0000-000000000002');
select is((select reposted_by from public.following_activity_videos), null::text, 'blocking removes repost attribution');
reset role;

update public.videos set hidden = true where id = '67000000-0000-0000-0000-000000000001';
set local role authenticated;
select is((select count(*) from public.following_video_activity()), 0::bigint, 'moderated clips disappear from Following');
select is((select count(*) from public.video_engagement_v2('67000000-0000-0000-0000-000000000001')),
  0::bigint, 'moderated clips do not expose repost totals');
reset role;
update public.videos set hidden = false where id = '67000000-0000-0000-0000-000000000001';

select set_config('request.jwt.claims', '{"sub":"66000000-0000-0000-0000-000000000002"}', true);
set local role authenticated;
select results_eq(
  $$select reposts, reposted_by_me from public.set_video_repost('67000000-0000-0000-0000-000000000001', false)$$,
  $$values (0::bigint, false)$$, 'undo resets count and viewer state');
reset role;
select is((select count(*) from public.video_reposts), 0::bigint, 'undo removes the relationship');

select * from finish();
rollback;
