begin;
select plan(20);

-- 1 = original creator, 2 = replier, 3 = viewer, 4 = second replier
insert into auth.users (id, email) values
  ('71000000-0000-0000-0000-000000000001', 'reply-author@test.dev'),
  ('71000000-0000-0000-0000-000000000002', 'reply-taker@test.dev'),
  ('71000000-0000-0000-0000-000000000003', 'reply-viewer@test.dev'),
  ('71000000-0000-0000-0000-000000000004', 'reply-second@test.dev');
update public.profiles set username = 'replier_' || right(id::text, 1) where id::text like '71000000-%';

insert into public.videos (id, user_id, video_key, thumb_key, sound_setup, created_at) values
  ('72000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001', 'videos/71000000-0000-0000-0000-000000000001/1', 'thumbs/71000000-0000-0000-0000-000000000001/1',
   '{"v":1}'::jsonb, now() - interval '2 days'),
  ('72000000-0000-0000-0000-000000000009', '71000000-0000-0000-0000-000000000001', 'videos/71000000-0000-0000-0000-000000000001/9', 'thumbs/71000000-0000-0000-0000-000000000001/9',
   null, now() - interval '2 days');
update public.videos set hidden = true where id = '72000000-0000-0000-0000-000000000009';

-- A take published through the screened path keeps its reply target.
insert into public.pending_video_uploads (id, user_id, video_bytes, thumb_bytes, status, attempt)
values ('72000000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000002', 10, 10, 'checking', 1);
set local role service_role;
select lives_ok($$select public.publish_screened_video('72000000-0000-0000-0000-000000000002',
  '{"caption":"my take","duration_s":3,"width":720,"height":1280,"reply_to_id":"72000000-0000-0000-0000-000000000001"}'::jsonb, 1)$$,
  'the service publishes a reply');
reset role;
select is((select reply_to_id from public.videos where id = '72000000-0000-0000-0000-000000000002'),
  '72000000-0000-0000-0000-000000000001'::uuid, 'the published take links to the post it answers');

insert into public.videos (id, user_id, video_key, thumb_key, reply_to_id) values
  ('72000000-0000-0000-0000-000000000003', '71000000-0000-0000-0000-000000000004', 'videos/71000000-0000-0000-0000-000000000004/3', 'thumbs/71000000-0000-0000-0000-000000000004/3',
   '72000000-0000-0000-0000-000000000001'),
  ('72000000-0000-0000-0000-000000000004', '71000000-0000-0000-0000-000000000002', 'videos/71000000-0000-0000-0000-000000000002/4', 'thumbs/71000000-0000-0000-0000-000000000002/4',
   '72000000-0000-0000-0000-000000000009'),
  ('72000000-0000-0000-0000-000000000005', '71000000-0000-0000-0000-000000000002', 'videos/71000000-0000-0000-0000-000000000002/5', 'thumbs/71000000-0000-0000-0000-000000000002/5',
   '72000000-0000-0000-0000-000000000005');
select is((select reply_to_id from public.videos where id = '72000000-0000-0000-0000-000000000004'),
  null::uuid, 'a reply to a hidden post is posted without the link');
select is((select reply_to_id from public.videos where id = '72000000-0000-0000-0000-000000000005'),
  null::uuid, 'a post cannot answer itself');

insert into public.blocks (blocker_id, blocked_id)
values ('71000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000003');
insert into public.videos (id, user_id, video_key, thumb_key, reply_to_id) values
  ('72000000-0000-0000-0000-000000000006', '71000000-0000-0000-0000-000000000003', 'videos/71000000-0000-0000-0000-000000000003/6', 'thumbs/71000000-0000-0000-0000-000000000003/6',
   '72000000-0000-0000-0000-000000000001');
delete from public.blocks where blocker_id = '71000000-0000-0000-0000-000000000001';
select is((select reply_to_id from public.videos where id = '72000000-0000-0000-0000-000000000006'),
  null::uuid, 'a blocked creator cannot attach a reply');

set local role anon;
select results_eq(
  $$select reply_to_username::text, reply_count from public.feed_videos where id = '72000000-0000-0000-0000-000000000002'$$,
  $$values ('replier_1'::text, 0::bigint)$$, 'guests see the reply label');
select is((select reply_count from public.feed_videos where id = '72000000-0000-0000-0000-000000000001'),
  2::bigint, 'guests see the visible reply count');
reset role;

select set_config('request.jwt.claims', '{"sub":"71000000-0000-0000-0000-000000000003"}', true);
set local role authenticated;
select results_eq(
  $$select id from public.feed_videos where reply_to_id = '72000000-0000-0000-0000-000000000001' order by id$$,
  $$values ('72000000-0000-0000-0000-000000000002'::uuid), ('72000000-0000-0000-0000-000000000003'::uuid)$$,
  'replies are listed from the feed view');
select throws_ok($$update public.videos set reply_to_id = null where id = '72000000-0000-0000-0000-000000000006'$$,
  '42501', null, 'clients cannot rewrite a reply link');
select throws_ok($$select public.reply_target_available('72000000-0000-0000-0000-000000000001', auth.uid())$$,
  '42501', null, 'the availability helper is internal');
reset role;
insert into public.blocks (blocker_id, blocked_id)
values ('71000000-0000-0000-0000-000000000003', '71000000-0000-0000-0000-000000000004');
set local role authenticated;
select is((select reply_count from public.feed_videos where id = '72000000-0000-0000-0000-000000000001'),
  1::bigint, 'replies from blocked creators are not counted');
reset role;
delete from public.blocks where blocker_id = '71000000-0000-0000-0000-000000000003';
insert into public.reports (video_id, reporter_id, reason)
values ('72000000-0000-0000-0000-000000000003', '71000000-0000-0000-0000-000000000003', 'spam');
set local role authenticated;
select is((select reply_count from public.feed_videos where id = '72000000-0000-0000-0000-000000000001'),
  1::bigint, 'replies you reported are not counted');
reset role;
insert into public.reports (video_id, reporter_id, reason)
values ('72000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000003', 'spam');
set local role authenticated;
select results_eq(
  $$select reply_to_id, reply_to_username::text from public.feed_videos where id = '72000000-0000-0000-0000-000000000002'$$,
  $$values (null::uuid, null::text)$$, 'a reply to a post you reported is not labelled with it');
reset role;
delete from public.reports where reporter_id = '71000000-0000-0000-0000-000000000003';

update public.videos set hidden = true where id = '72000000-0000-0000-0000-000000000003';
set local role anon;
select is((select reply_count from public.feed_videos where id = '72000000-0000-0000-0000-000000000001'),
  1::bigint, 'moderated replies are not counted');
reset role;

-- The original creator blocks a replier after the fact: the link and the count go away.
insert into public.blocks (blocker_id, blocked_id)
values ('71000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000002');
set local role anon;
select is((select reply_count from public.feed_videos where id = '72000000-0000-0000-0000-000000000001'),
  0::bigint, 'a later block between creators removes the reply from the count');
select is((select reply_to_id from public.feed_videos where id = '72000000-0000-0000-0000-000000000002'),
  null::uuid, 'a later block between creators removes the reply label');
reset role;
delete from public.blocks where blocker_id = '71000000-0000-0000-0000-000000000001';

update public.videos set hidden = true where id = '72000000-0000-0000-0000-000000000001';
set local role anon;
select is((select reply_to_id from public.feed_videos where id = '72000000-0000-0000-0000-000000000002'),
  null::uuid, 'a hidden original is not shown as the reply target');
select is((select count(*) from public.feed_videos where id = '72000000-0000-0000-0000-000000000002'),
  1::bigint, 'the reply itself stays in the feed');
reset role;

delete from public.videos where id = '72000000-0000-0000-0000-000000000001';
select is((select reply_to_id from public.videos where id = '72000000-0000-0000-0000-000000000002'),
  null::uuid, 'deleting the original keeps the reply as a normal post');

select set_config('request.jwt.claims', '{"sub":"71000000-0000-0000-0000-000000000002"}', true);
set local role authenticated;
select ok((select count(*) from public.my_reposted_videos where reply_count is not null) = 0,
  'rebuilt repost views expose reply columns');
reset role;

select * from finish();
rollback;
