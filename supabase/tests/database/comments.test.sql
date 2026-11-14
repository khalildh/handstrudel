begin;
select plan(29);

insert into auth.users (id, email) values
  ('10000000-0000-0000-0000-000000000001', 'creator@test.dev'),
  ('10000000-0000-0000-0000-000000000002', 'listener@test.dev'),
  ('10000000-0000-0000-0000-000000000003', 'third@test.dev'),
  ('10000000-0000-0000-0000-000000000004', 'fresh@test.dev');
update public.profiles set username = 'creator', accepted_terms_at = now() where id = '10000000-0000-0000-0000-000000000001';
update public.profiles set username = 'listener', accepted_terms_at = now() where id = '10000000-0000-0000-0000-000000000002';
update public.profiles set username = 'third', accepted_terms_at = now() where id = '10000000-0000-0000-0000-000000000003';

insert into public.videos (id, user_id, video_key, thumb_key) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
   'videos/10000000-0000-0000-0000-000000000001/1.mp4', 'thumbs/10000000-0000-0000-0000-000000000001/1.jpg'),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001',
   'videos/10000000-0000-0000-0000-000000000001/2.mp4', 'thumbs/10000000-0000-0000-0000-000000000001/2.jpg');

create function pg_temp.claim(uid uuid) returns text language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid)::text, true)
$$;
create function pg_temp.visible_comments() returns bigint language sql as $$
  select count(*) from public.video_comments where video_id = '20000000-0000-0000-0000-000000000001'
$$;
create function pg_temp.add_comment(message text) returns void language sql as $$
  insert into public.comments (video_id, body) values ('20000000-0000-0000-0000-000000000001', message)
$$;

set local role anon;
select throws_ok($$ select pg_temp.add_comment('Nice!') $$, '42501', null, 'guests cannot write comments');
reset role;
select pg_temp.claim('10000000-0000-0000-0000-000000000004');
set local role authenticated;
select throws_ok($$ select pg_temp.add_comment('Nice!') $$, '42501', null, 'a completed profile is required');
reset role;
select pg_temp.claim('10000000-0000-0000-0000-000000000002');
set local role authenticated;
select throws_ok($$ select pg_temp.add_comment(E' \t\n') $$, '23514', null, 'whitespace is not a comment');
select throws_ok($$ select pg_temp.add_comment(repeat('x', 301)) $$, '23514', null, 'comment length enforced');
select throws_ok($$ select pg_temp.add_comment('See https://example.com') $$, 'P0001', 'COMMENT_FILTERED', 'links are filtered');
select throws_ok($$ select pg_temp.add_comment('GO  DIE') $$, 'P0001', 'COMMENT_FILTERED', 'abusive phrases are filtered');
select throws_ok($$ insert into public.comments (video_id, body, user_id)
  values ('20000000-0000-0000-0000-000000000001', 'Hello', '10000000-0000-0000-0000-000000000001') $$,
  '42501', null, 'author cannot be spoofed');
select lives_ok($$ select pg_temp.add_comment('  Great sound!  ') $$, 'member can comment');
select is((select body from public.video_comments), 'Great sound!', 'text is trimmed on the server');
select is((select username::text from public.video_comments), 'listener', 'username belongs to the signed-in author');
reset role;

-- Store stable IDs for the reply and moderation tests.
select set_config('test.root', (select id::text from public.comments), true);
select pg_temp.claim('10000000-0000-0000-0000-000000000001');
set local role authenticated;
select throws_ok($$ insert into public.comments (video_id, parent_id, body)
  values ('20000000-0000-0000-0000-000000000002', current_setting('test.root')::uuid, 'Thanks!') $$,
  '23503', null, 'replies cannot cross videos');
select lives_ok($$ insert into public.comments (video_id, parent_id, body)
  values ('20000000-0000-0000-0000-000000000001', current_setting('test.root')::uuid, 'Thanks!') $$, 'creator can reply');
select set_config('test.reply', (select id::text from public.video_comments where parent_id is not null), true);
select throws_ok($$ insert into public.comments (video_id, parent_id, body)
  values ('20000000-0000-0000-0000-000000000001', current_setting('test.reply')::uuid, 'Nested') $$,
  'P0001', 'COMMENT_THREAD_UNAVAILABLE', 'only one reply level');
reset role;

select set_config('request.jwt.claims', '{}', true);
set local role anon;
select is(pg_temp.visible_comments(), 2::bigint, 'guests can read comments and replies');
select is((select comment_count from public.feed_videos where id = '20000000-0000-0000-0000-000000000001'),
          2::bigint, 'feed count includes replies');
reset role;

select pg_temp.claim('10000000-0000-0000-0000-000000000003');
set local role authenticated;
select throws_ok($$ select public.delete_video_comment(current_setting('test.root')::uuid) $$,
                 'P0001', 'COMMENT_NOT_FOUND', 'unrelated viewer cannot delete comments');
insert into public.blocks (blocker_id, blocked_id)
values ('10000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002');
select is(pg_temp.visible_comments(), 0::bigint, 'a blocked author and replies in their thread are hidden');
delete from public.blocks where blocker_id = '10000000-0000-0000-0000-000000000003';
insert into public.comment_reports (comment_id, reason) values (current_setting('test.root')::uuid, 'harassment');
select is(pg_temp.visible_comments(), 0::bigint, 'reporter no longer sees the thread');
select throws_ok($$ select count(*) from public.comment_reports $$, '42501', null, 'reports are private');
reset role;

select pg_temp.claim('10000000-0000-0000-0000-000000000001');
set local role authenticated;
update public.videos set comments_enabled = false where id = '20000000-0000-0000-0000-000000000001';
select is(pg_temp.visible_comments(), 0::bigint, 'turning off comments hides the thread');
select throws_ok($$ select pg_temp.add_comment('Still there?') $$, '42501', null, 'cannot post on a disabled thread');
update public.videos set comments_enabled = true where id = '20000000-0000-0000-0000-000000000001';
select lives_ok($$ select public.delete_video_comment(current_setting('test.root')::uuid) $$, 'creator can delete comments on their video');
select is(pg_temp.visible_comments(), 0::bigint, 'deleting a root also deletes its replies');
reset role;

select pg_temp.claim('10000000-0000-0000-0000-000000000002');
set local role authenticated;
select lives_ok($$ select pg_temp.add_comment('One') $$, 'a second comment can be posted');
select set_config('test.moderated', (select id::text from public.video_comments), true);
select pg_temp.add_comment('Two');
select pg_temp.add_comment('Three');
select pg_temp.add_comment('Four');
select throws_ok($$ select pg_temp.add_comment('Five') $$, 'P0001', 'COMMENT_RATE_LIMITED',
                 'five successful posts per minute, even after a deletion');
select throws_ok($$ insert into public.comment_reports (comment_id, reason)
  values (current_setting('test.moderated')::uuid, 'spam') $$, '42501', null, 'authors cannot report themselves');
select lives_ok($$ select public.delete_video_comment(id) from public.video_comments where body = 'Four' $$,
                'authors can delete their own comments');
reset role;

set local role authenticated;
select pg_temp.claim('10000000-0000-0000-0000-000000000001');
insert into public.comment_reports (comment_id, reason) values (current_setting('test.moderated')::uuid, 'spam');
select pg_temp.claim('10000000-0000-0000-0000-000000000003');
insert into public.comment_reports (comment_id, reason) values (current_setting('test.moderated')::uuid, 'spam');
select throws_ok($$ insert into public.comment_reports (comment_id, reason)
  values (current_setting('test.moderated')::uuid, 'spam') $$, '42501', null,
  'the same viewer cannot report a comment twice');
select pg_temp.claim('10000000-0000-0000-0000-000000000004');
insert into public.comment_reports (comment_id, reason) values (current_setting('test.moderated')::uuid, 'spam');
reset role;
select set_config('request.jwt.claims', '{}', true);
set local role anon;
select is((select count(*) from public.video_comments where id = current_setting('test.moderated')::uuid),
          0::bigint, 'three distinct reports hide a comment from the public');

select * from finish();
rollback;
