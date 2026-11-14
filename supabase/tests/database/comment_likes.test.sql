begin;
select plan(12);

insert into auth.users (id, email) values
  ('e5100000-0000-0000-0000-000000000001', 'comment-likes-author@test.dev'),
  ('e5100000-0000-0000-0000-000000000002', 'comment-likes-viewer@test.dev'),
  ('e5100000-0000-0000-0000-000000000003', 'comment-likes-other@test.dev');
update public.profiles set username = 'comment_likes_' || right(id::text, 1), accepted_terms_at = now()
where id::text like 'e5100000-%';
insert into public.videos (id, user_id, video_key, thumb_key) values
  ('e5200000-0000-0000-0000-000000000001', 'e5100000-0000-0000-0000-000000000001',
   'videos/e5100000-0000-0000-0000-000000000001/v', 'thumbs/e5100000-0000-0000-0000-000000000001/t');
insert into public.comments (id, video_id, user_id, body) values
  ('e5300000-0000-0000-0000-000000000001', 'e5200000-0000-0000-0000-000000000001',
   'e5100000-0000-0000-0000-000000000001', 'Root comment');
insert into public.comments (id, video_id, user_id, parent_id, body) values
  ('e5300000-0000-0000-0000-000000000002', 'e5200000-0000-0000-0000-000000000001',
   'e5100000-0000-0000-0000-000000000001', 'e5300000-0000-0000-0000-000000000001', 'Reply');

set local role anon;
select throws_ok($$ insert into public.comment_likes(comment_id) values ('e5300000-0000-0000-0000-000000000001') $$,
  '42501', null, 'guests cannot like a comment');
reset role;

select set_config('request.jwt.claims', '{"sub":"e5100000-0000-0000-0000-000000000002"}', true);
set local role authenticated;
select lives_ok($$ insert into public.comment_likes(comment_id) values
  ('e5300000-0000-0000-0000-000000000001'), ('e5300000-0000-0000-0000-000000000002') $$, 'member can like comments and replies');
select throws_ok($$ insert into public.comment_likes(comment_id) values ('e5300000-0000-0000-0000-000000000001') $$,
  '23505', null, 'duplicate likes do not change the count');
select is((select count(*) from public.video_comments where liked_by_me and like_count = 1), 2::bigint, 'reader sees their liked state');
reset role;

select set_config('request.jwt.claims', '{}', true);
set local role anon;
select is((select count(*) from public.video_comments where not liked_by_me and like_count = 1), 2::bigint, 'guests see only counts');
reset role;

select set_config('request.jwt.claims', '{"sub":"e5100000-0000-0000-0000-000000000003"}', true);
set local role authenticated;
select is((select count(*) from public.comment_likes), 0::bigint, 'other members cannot read private like rows');
delete from public.comment_likes where comment_id = 'e5300000-0000-0000-0000-000000000001';
select is((select like_count from public.video_comments where body = 'Root comment'), 1::bigint, 'someone else cannot remove the like');
insert into public.comment_reports (comment_id, reason) values ('e5300000-0000-0000-0000-000000000001', 'spam');
select throws_ok($$ insert into public.comment_likes(comment_id) values ('e5300000-0000-0000-0000-000000000002') $$,
  '42501', null, 'a reply in a hidden thread cannot be liked');
reset role;

select set_config('request.jwt.claims', '{"sub":"e5100000-0000-0000-0000-000000000002"}', true);
set local role authenticated;
delete from public.comment_likes where comment_id = 'e5300000-0000-0000-0000-000000000001';
select is((select like_count from public.video_comments where body = 'Root comment'), 0::bigint, 'owner can unlike');
select is((select like_count from public.video_comments where body = 'Reply'), 1::bigint, 'unlike only affects that row');
reset role;

select is((select count(*) from public.creator_activity where video_id = 'e5200000-0000-0000-0000-000000000001'), 0::bigint, 'reactions do not change legacy activity');
delete from public.comments where body = 'Root comment' and video_id = 'e5200000-0000-0000-0000-000000000001';
select is((select count(*) from public.comment_likes where comment_id in
  ('e5300000-0000-0000-0000-000000000001', 'e5300000-0000-0000-0000-000000000002')), 0::bigint, 'removing the thread cleans up likes');

select * from finish();
rollback;
