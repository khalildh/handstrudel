begin;
select plan(11);

insert into auth.users (id, email)
values ('64000000-0000-0000-0000-000000000001', 'engagement-owner@test.dev'),
       ('64000000-0000-0000-0000-000000000002', 'engagement-listener@test.dev');
update public.profiles set username = 'engagement_' || right(id::text, 1) where id::text like '64000000-%';

insert into public.videos (id, user_id, video_key, thumb_key, backing_enabled, hidden, source_video_id)
select ('65000000-0000-0000-0000-00000000000' || n)::uuid, '64000000-0000-0000-0000-000000000001',
       'videos/64000000-0000-0000-0000-000000000001/v' || n,
       'thumbs/64000000-0000-0000-0000-000000000001/t' || n,
       n = 1, n = 3, case when n > 1 then '65000000-0000-0000-0000-000000000001'::uuid end
from generate_series(1, 3) n;

insert into public.video_bookmarks (video_id, user_id)
values ('65000000-0000-0000-0000-000000000001', '64000000-0000-0000-0000-000000000002');

set local role anon;
select results_eq(
  $$select * from public.video_engagement('65000000-0000-0000-0000-000000000001')$$,
  $$values (1::bigint, 0::bigint, 1::bigint)$$,
  'public counts include private save totals and only visible remixes');
select throws_ok($$select * from public.video_bookmarks$$, '42501', null, 'guests cannot see who saved');
select throws_ok($$select * from public.video_share_totals$$, '42501', null, 'the underlying share table stays private');
select lives_ok($$select public.record_video_share('65000000-0000-0000-0000-000000000001')$$, 'guest can report a completed share');
select is((select shares from public.video_engagement('65000000-0000-0000-0000-000000000001')), 1::bigint, 'the share increments');
select lives_ok($$select public.record_video_share('65000000-0000-0000-0000-000000000003')$$, 'hidden posts ignore share reports');
select is((select count(*) from public.video_engagement('65000000-0000-0000-0000-000000000003')), 0::bigint, 'hidden posts expose no counts');
reset role;

select set_config('request.jwt.claims', '{"sub":"64000000-0000-0000-0000-000000000002"}', true);
set local role authenticated;
select lives_ok($$select public.set_video_bookmark('65000000-0000-0000-0000-000000000001', false)$$, 'viewer can remove the bookmark');
select is((select saves from public.video_engagement('65000000-0000-0000-0000-000000000001')), 0::bigint, 'removing it updates the public total');
insert into public.blocks (blocker_id, blocked_id) values (auth.uid(), '64000000-0000-0000-0000-000000000001');
select is((select count(*) from public.video_engagement('65000000-0000-0000-0000-000000000001')), 0::bigint, 'blocked creators expose no counts to the viewer');
reset role;
select is((select count(*) from public.video_share_totals), 1::bigint, 'only visible share events write a total');

select * from finish();
rollback;
