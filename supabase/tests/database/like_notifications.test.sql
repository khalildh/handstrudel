begin;
select plan(17);

insert into auth.users (id, email) values
  ('f5100000-0000-0000-0000-000000000001', 'like-inbox-author@test.dev'),
  ('f5100000-0000-0000-0000-000000000002', 'like-inbox-listener@test.dev'),
  ('f5100000-0000-0000-0000-000000000003', 'like-inbox-other@test.dev');
update public.profiles set username = 'like_inbox_' || right(id::text, 1), accepted_terms_at = now()
where id::text like 'f5100000-%';
insert into public.videos (id, user_id, video_key, thumb_key) values
  ('f5200000-0000-0000-0000-000000000001', 'f5100000-0000-0000-0000-000000000001',
   'videos/f5100000-0000-0000-0000-000000000001/v', 'thumbs/f5100000-0000-0000-0000-000000000001/t');
insert into public.comments (id, video_id, user_id, body) values
  ('f5300000-0000-0000-0000-000000000001', 'f5200000-0000-0000-0000-000000000001',
   'f5100000-0000-0000-0000-000000000001', 'Root');
insert into public.comments (id, video_id, user_id, parent_id, body) values
  ('f5300000-0000-0000-0000-000000000002', 'f5200000-0000-0000-0000-000000000001',
   'f5100000-0000-0000-0000-000000000001', 'f5300000-0000-0000-0000-000000000001', 'Reply');

set local role anon;
select throws_ok($$ select * from public.activity_inbox_v2 $$, '42501', null, 'guests cannot read notifications');
reset role;

select set_config('request.jwt.claims', '{"sub":"f5100000-0000-0000-0000-000000000001"}', true);
set local role authenticated;
insert into public.likes (user_id, video_id) values (auth.uid(), 'f5200000-0000-0000-0000-000000000001');
select is((select count(*) from public.activity_inbox_v2), 0::bigint, 'self likes are silent');
reset role;

select set_config('request.jwt.claims', '{"sub":"f5100000-0000-0000-0000-000000000002"}', true);
set local role authenticated;
insert into public.likes (user_id, video_id) values (auth.uid(), 'f5200000-0000-0000-0000-000000000001');
insert into public.comment_likes (comment_id) values
  ('f5300000-0000-0000-0000-000000000001'), ('f5300000-0000-0000-0000-000000000002');
select is((select count(*) from public.activity_inbox_v2), 0::bigint, 'the liker cannot read the recipient inbox');
reset role;

select set_config('request.jwt.claims', '{"sub":"f5100000-0000-0000-0000-000000000001"}', true);
set local role authenticated;
select is((select count(*) from public.activity_inbox), 0::bigint, 'legacy clients do not receive new kinds');
select is((select count(*) from public.activity_inbox_v2 where read_at is null and like_count = 1), 3::bigint, 'each liked target starts unread');
select is((select comment_id from public.activity_inbox_v2 where kind = 'reply_like'), 'f5300000-0000-0000-0000-000000000002'::uuid, 'reply like links to the exact reply');
select set_config('test.like_group', (select id::text from public.activity_inbox_v2 where kind = 'video_like'), true);
select set_config('test.seen_at', (select created_at::text from public.activity_inbox_v2 where kind = 'video_like'), true);
select public.mark_like_activity_read(current_setting('test.like_group')::uuid, current_setting('test.seen_at')::timestamptz);
select is((select count(*) from public.activity_inbox_v2 where read_at is not null), 1::bigint, 'marking one group read leaves the others unread');
reset role;

select set_config('request.jwt.claims', '{"sub":"f5100000-0000-0000-0000-000000000003"}', true);
set local role authenticated;
insert into public.likes (user_id, video_id) values (auth.uid(), 'f5200000-0000-0000-0000-000000000001');
select public.mark_like_activity_read(current_setting('test.like_group')::uuid, clock_timestamp());
reset role;

select set_config('request.jwt.claims', '{"sub":"f5100000-0000-0000-0000-000000000001"}', true);
set local role authenticated;
select is((select count(*) from public.activity_inbox_v2 where kind = 'video_like'), 1::bigint, 'two video likes are one group');
select is((select like_count from public.activity_inbox_v2 where kind = 'video_like'), 2::bigint, 'group count excludes the self like');
select is((select username::text from public.activity_inbox_v2 where kind = 'video_like'), 'like_inbox_3', 'latest visible liker leads the group');
select public.mark_like_activity_read(current_setting('test.like_group')::uuid, current_setting('test.seen_at')::timestamptz);
select is((select count(*) from public.activity_inbox_v2 where kind = 'video_like' and read_at is null), 1::bigint, 'a stale or foreign read cannot clear a newer like');
insert into public.blocks (blocker_id, blocked_id) values (auth.uid(), 'f5100000-0000-0000-0000-000000000003');
select is((select like_count from public.activity_inbox_v2 where kind = 'video_like'), 1::bigint, 'blocked likers do not appear in the group');
delete from public.blocks where blocker_id = auth.uid();
reset role;

select set_config('request.jwt.claims', '{"sub":"f5100000-0000-0000-0000-000000000003"}', true);
set local role authenticated;
delete from public.likes where user_id = auth.uid() and video_id = 'f5200000-0000-0000-0000-000000000001';
reset role;

select set_config('request.jwt.claims', '{"sub":"f5100000-0000-0000-0000-000000000001"}', true);
set local role authenticated;
select is((select like_count from public.activity_inbox_v2 where kind = 'video_like'), 1::bigint, 'unlike removes the actor from the group');
select is((select count(*) from public.activity_inbox_v2 where kind = 'video_like' and read_at is not null), 1::bigint, 'unlike restores the prior read state');
update public.videos set comments_enabled = false where id = 'f5200000-0000-0000-0000-000000000001';
select is((select count(*) from public.activity_inbox_v2), 1::bigint, 'disabled comments hide comment likes, not video likes');
update public.videos set comments_enabled = true where id = 'f5200000-0000-0000-0000-000000000001';
select public.delete_video_comment('f5300000-0000-0000-0000-000000000001');
select is((select count(*) from public.activity_inbox_v2), 1::bigint, 'deleting the thread removes both comment-like groups');
reset role;

select set_config('request.jwt.claims', '{"sub":"f5100000-0000-0000-0000-000000000002"}', true);
set local role authenticated;
delete from public.likes where user_id = auth.uid() and video_id = 'f5200000-0000-0000-0000-000000000001';
reset role;
select set_config('request.jwt.claims', '{"sub":"f5100000-0000-0000-0000-000000000001"}', true);
set local role authenticated;
select is((select count(*) from public.activity_inbox_v2), 0::bigint, 'groups disappear when every outside like is removed');
reset role;

select * from finish();
rollback;
