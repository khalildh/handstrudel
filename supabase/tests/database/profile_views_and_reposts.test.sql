begin;
select plan(12);

insert into auth.users (id, email) values
  ('73000000-0000-4000-8000-000000000001', 'profile-views-author@test.dev'),
  ('73000000-0000-4000-8000-000000000002', 'profile-views-listener@test.dev'),
  ('73000000-0000-4000-8000-000000000003', 'profile-views-other@test.dev');
update public.profiles set username = 'view_artist_' || right(id::text, 1) where id::text like '73000000-%';

insert into public.videos (id, user_id, video_key, thumb_key, view_count, hidden)
select ('74000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  '73000000-0000-4000-8000-000000000001',
  'videos/73000000-0000-4000-8000-000000000001/' || n || '.mp4',
  'thumbs/73000000-0000-4000-8000-000000000001/' || n || '.jpg',
  2, n = 14
from generate_series(1, 14) n;

set local role anon;
select is((select views_received from public.public_creators where username = 'view_artist_1'),
  26::bigint, 'profile totals include all 13 visible posts, not just one page');
select is((select views_received from public.public_creators where username = 'view_artist_2'),
  0::bigint, 'an artist with no posts has zero views');
select throws_ok($$select * from public.my_reposted_videos$$, '42501', null, 'guests cannot read personal reposts');
select is(public.record_video_view('74000000-0000-4000-8000-000000000001', '74000000-0000-4000-8000-000000000099'),
  3::bigint, 'a qualified view updates the original clip');
select is((select views_received from public.public_creators where username = 'view_artist_1'),
  27::bigint, 'the profile total reflects the new view');
reset role;

select set_config('request.jwt.claims', '{"sub":"73000000-0000-4000-8000-000000000002"}', true);
set local role authenticated;
select is((select reposted_by_me from public.set_video_repost('74000000-0000-4000-8000-000000000001', true)),
  true, 'listener reposts the original');
select results_eq(
  $$select username::text, view_count, activity_at >= created_at from public.my_reposted_videos$$,
  $$values ('view_artist_1'::text, 3::bigint, true)$$, 'the repost tab retains the original artist, views and repost date');
select is((select views_received from public.public_creators where username = 'view_artist_2'),
  0::bigint, 'reposting does not claim the original artist views');
reset role;

select set_config('request.jwt.claims', '{"sub":"73000000-0000-4000-8000-000000000003"}', true);
set local role authenticated;
select is((select count(*) from public.my_reposted_videos), 0::bigint, 'another account cannot see the listener repost history');
reset role;

update public.videos set hidden = true where id = '74000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claims', '{"sub":"73000000-0000-4000-8000-000000000002"}', true);
set local role authenticated;
select is((select count(*) from public.my_reposted_videos), 0::bigint, 'moderated clips are removed from the repost tab');
select is((select views_received from public.public_creators where username = 'view_artist_1'),
  24::bigint, 'moderated clips are removed from the total');
reset role;

delete from public.videos where id = '74000000-0000-4000-8000-000000000002';
select is((select views_received from public.public_creators where username = 'view_artist_1'),
  22::bigint, 'deleted clips no longer contribute to the total');

select * from finish();
rollback;
