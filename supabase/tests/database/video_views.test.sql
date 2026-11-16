begin;
select plan(11);

insert into auth.users (id, email)
values ('61000000-0000-0000-0000-000000000001', 'view-creator@test.dev'),
       ('61000000-0000-0000-0000-000000000002', 'view-listener@test.dev');
update public.profiles set username = 'view_creator'
where id = '61000000-0000-0000-0000-000000000001';

insert into public.videos (id, user_id, video_key, thumb_key, hidden)
select ('62000000-0000-0000-0000-00000000000' || n)::uuid,
       '61000000-0000-0000-0000-000000000001',
       'videos/61000000-0000-0000-0000-000000000001/v' || n,
       'thumbs/61000000-0000-0000-0000-000000000001/t' || n, n = 2
from generate_series(1, 2) n;

set local role anon;
select is(public.record_video_view('62000000-0000-0000-0000-000000000001',
  '63000000-0000-0000-0000-000000000001'), 1::bigint, 'a watch increments a visible clip');
select is(public.record_video_view('62000000-0000-0000-0000-000000000001',
  '63000000-0000-0000-0000-000000000001'), 1::bigint, 'replay of a receipt does not increment');
select is(public.record_video_view('62000000-0000-0000-0000-000000000001',
  '63000000-0000-0000-0000-000000000002'), 2::bigint, 'a distinct receipt increments');
select is((select view_count from public.feed_videos where id = '62000000-0000-0000-0000-000000000001'),
  2::bigint, 'feed exposes the total');
select is(public.record_video_view('62000000-0000-0000-0000-000000000002',
  '63000000-0000-0000-0000-000000000003'), null::bigint, 'hidden posts cannot be counted');
select is(public.record_video_view('62000000-0000-0000-0000-000000000003',
  '63000000-0000-0000-0000-000000000003'), null::bigint, 'nonexistent posts cannot be counted');
select is(public.record_video_view('62000000-0000-0000-0000-000000000001', null),
  null::bigint, 'a receipt is required');
select throws_ok($$select * from public.video_view_receipts$$, '42501', null, 'receipts are private');
reset role;

select set_config('request.jwt.claims', '{"sub":"61000000-0000-0000-0000-000000000001"}', true);
set local role authenticated;
select throws_ok($$update public.videos set view_count = 900$$, '42501', null, 'owners cannot edit view counts');
reset role;

select set_config('request.jwt.claims', '{"sub":"61000000-0000-0000-0000-000000000002"}', true);
set local role authenticated;
select is(public.record_video_view('62000000-0000-0000-0000-000000000001',
  '63000000-0000-0000-0000-000000000003'), 3::bigint, 'a signed-in viewer can count a watch');
insert into public.blocks (blocker_id, blocked_id) values (auth.uid(), '61000000-0000-0000-0000-000000000001');
select is(public.record_video_view('62000000-0000-0000-0000-000000000001',
  '63000000-0000-0000-0000-000000000004'), null::bigint, 'a blocked creator is unavailable to this viewer');
reset role;

select * from finish();
rollback;
