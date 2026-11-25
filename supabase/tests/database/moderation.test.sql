begin;
select plan(103);

-- 1 admin, 2 creator, 3-5 reporters, 6 stranger (non-admin), 7 commenter
insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-000000000001', 'admin@test.dev'),
  ('a0000000-0000-0000-0000-000000000002', 'creator@test.dev'),
  ('a0000000-0000-0000-0000-000000000003', 'r1@test.dev'),
  ('a0000000-0000-0000-0000-000000000004', 'r2@test.dev'),
  ('a0000000-0000-0000-0000-000000000005', 'r3@test.dev'),
  ('a0000000-0000-0000-0000-000000000006', 'stranger@test.dev'),
  ('a0000000-0000-0000-0000-000000000007', 'commenter@test.dev');
update public.profiles set username = 'admin',     accepted_terms_at = now() where id = 'a0000000-0000-0000-0000-000000000001';
update public.profiles set username = 'creator',   accepted_terms_at = now() where id = 'a0000000-0000-0000-0000-000000000002';
update public.profiles set username = 'rone',      accepted_terms_at = now() where id = 'a0000000-0000-0000-0000-000000000003';
update public.profiles set username = 'rtwo',      accepted_terms_at = now() where id = 'a0000000-0000-0000-0000-000000000004';
update public.profiles set username = 'rthree',    accepted_terms_at = now() where id = 'a0000000-0000-0000-0000-000000000005';
update public.profiles set username = 'stranger',  accepted_terms_at = now() where id = 'a0000000-0000-0000-0000-000000000006';
update public.profiles set username = 'commenter', accepted_terms_at = now() where id = 'a0000000-0000-0000-0000-000000000007';

-- The owner's one SQL line (run as the database owner, never through the API).
insert into moderation_internal.admins (user_id, note) values ('a0000000-0000-0000-0000-000000000001', 'owner');

-- Creator posts: v1 gets auto-hidden by reports, v2 gets hidden by the admin, v3 stays visible.
insert into public.videos (id, user_id, video_key, thumb_key, caption) values
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002',
   'videos/a0000000-0000-0000-0000-000000000002/1.mp4', 'thumbs/a0000000-0000-0000-0000-000000000002/1.jpg', 'one'),
  ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002',
   'videos/a0000000-0000-0000-0000-000000000002/2.mp4', 'thumbs/a0000000-0000-0000-0000-000000000002/2.jpg', 'two'),
  ('b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000002',
   'videos/a0000000-0000-0000-0000-000000000002/3.mp4', 'thumbs/a0000000-0000-0000-0000-000000000002/3.jpg', 'three');
insert into public.likes (user_id, video_id) values
  ('a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000002'),
  ('a0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000002'),
  ('a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000003');
insert into public.comments (id, video_id, user_id, body) values
  ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000007', 'rude words'),
  ('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000002', 'thanks all');

create function pg_temp.as_user(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;
create function pg_temp.as_admin() returns void language sql as $$
  select pg_temp.as_user('a0000000-0000-0000-0000-000000000001')
$$;
create function pg_temp.as_stranger() returns void language sql as $$
  select pg_temp.as_user('a0000000-0000-0000-0000-000000000006')
$$;
-- What a signed-in stranger sees.
create function pg_temp.feed_has(video uuid) returns boolean language sql as $$
  select exists (select 1 from public.feed_videos where id = video)
$$;
create function pg_temp.creator_likes() returns bigint language sql as $$
  select likes_received from public.public_creators where username = 'creator'
$$;
create function pg_temp.comment_count() returns bigint language sql as $$
  select comment_count from public.feed_videos where id = 'b0000000-0000-0000-0000-000000000003'
$$;
create function pg_temp.comment_visible(comment uuid) returns boolean language sql as $$
  select exists (select 1 from public.video_comments where id = comment)
$$;
create function pg_temp.actions(act text, target uuid) returns bigint language sql as $$
  select count(*) from moderation_internal.actions
   where action = act and target_id = target and admin_id = 'a0000000-0000-0000-0000-000000000001'
$$;
create function pg_temp.queue_state(kind text, target uuid) returns text language sql as $$
  select state from public.moderation_queue('all', 'newest') where target_kind = kind and target_id = target
$$;

-- ------------------------------------------------ non-admins are refused everywhere
select pg_temp.as_stranger();
select is(public.is_moderator(), false, 'a regular account is not a moderator');
select throws_ok($$ select * from public.moderation_queue() $$, '42501', 'NOT_ADMIN', 'non-admin: queue');
select throws_ok($$ select * from public.moderation_item_reports('post', 'b0000000-0000-0000-0000-000000000001') $$,
  '42501', 'NOT_ADMIN', 'non-admin: item reports');
select throws_ok($$ select * from public.moderation_video_media('b0000000-0000-0000-0000-000000000001') $$,
  '42501', 'NOT_ADMIN', 'non-admin: hidden media keys');
select throws_ok($$ select public.moderation_hide('post', 'b0000000-0000-0000-0000-000000000003') $$,
  '42501', 'NOT_ADMIN', 'non-admin: hide');
select throws_ok($$ select public.moderation_restore('post', 'b0000000-0000-0000-0000-000000000003') $$,
  '42501', 'NOT_ADMIN', 'non-admin: restore');
select throws_ok($$ select public.moderation_dismiss_reports('post', 'b0000000-0000-0000-0000-000000000003') $$,
  '42501', 'NOT_ADMIN', 'non-admin: dismiss');
select throws_ok($$ select public.moderation_ban_user('a0000000-0000-0000-0000-000000000002') $$,
  '42501', 'NOT_ADMIN', 'non-admin: ban');
select throws_ok($$ select public.moderation_unban_user('a0000000-0000-0000-0000-000000000002') $$,
  '42501', 'NOT_ADMIN', 'non-admin: unban');
select throws_ok($$ select * from public.moderation_log() $$, '42501', 'NOT_ADMIN', 'non-admin: audit log');
select throws_ok($$ select * from public.moderation_report_digest(now() - interval '1 day') $$,
  '42501', null, 'clients cannot call the digest hook');
select throws_ok($$ select public.account_is_banned('a0000000-0000-0000-0000-000000000002') $$,
  '42501', null, 'clients cannot look up other accounts'' bans');
reset role;

set local role anon;
select throws_ok($$ select * from public.moderation_queue() $$, '42501', null, 'guests: queue');
select throws_ok($$ select public.moderation_hide('post', 'b0000000-0000-0000-0000-000000000003') $$,
  '42501', null, 'guests: hide');
select throws_ok($$ select public.moderation_ban_user('a0000000-0000-0000-0000-000000000002') $$,
  '42501', null, 'guests: ban');
select throws_ok($$ select * from public.moderation_log() $$, '42501', null, 'guests: audit log');
reset role;

select is((select count(*) from moderation_internal.actions), 0::bigint, 'refused calls changed nothing');
select is((select count(*) from public.videos where hidden), 0::bigint, 'refused calls hid nothing');

-- ------------------------------------------------ the admin flag can't be set through the API
select hasnt_column('public', 'profiles', 'is_admin', 'profiles carry no client-editable admin flag');
select pg_temp.as_stranger();
select throws_ok($$ insert into moderation_internal.admins (user_id) values ('a0000000-0000-0000-0000-000000000006') $$,
  '42501', null, 'a user cannot make themselves an admin');
select throws_ok($$ update moderation_internal.admins set user_id = 'a0000000-0000-0000-0000-000000000006' $$,
  '42501', null, 'a user cannot take over an admin row');
select throws_ok($$ select * from moderation_internal.admins $$, '42501', null, 'the admin list is private');
select throws_ok($$ delete from moderation_internal.bans $$, '42501', null, 'a user cannot lift bans');
select throws_ok($$ insert into moderation_internal.actions (admin_id, action, target_kind, target_id)
                    values ('a0000000-0000-0000-0000-000000000006', 'hide', 'post', 'b0000000-0000-0000-0000-000000000001') $$,
  '42501', null, 'a user cannot forge audit entries');
select is(public.is_moderator(), false, 'still not a moderator');
reset role;
select pg_temp.as_user('a0000000-0000-0000-0000-000000000002');
select throws_ok($$ update public.videos set admin_hidden_at = null, ban_hidden = false
                    where id = 'b0000000-0000-0000-0000-000000000001' $$,
  '42501', null, 'owners cannot clear moderation columns');
reset role;
set local role anon;
select throws_ok($$ insert into moderation_internal.admins (user_id) values ('a0000000-0000-0000-0000-000000000006') $$,
  '42501', null, 'guests cannot make admins');
reset role;
select is((select count(*) from moderation_internal.admins), 1::bigint, 'only the owner is an admin');
select pg_temp.as_admin();
select is(public.is_moderator(), true, 'the owner is a moderator');
reset role;

-- ------------------------------------------------ reports and the queue
select pg_temp.as_user('a0000000-0000-0000-0000-000000000003');
select throws_ok($$ insert into public.reports (reporter_id, video_id, reason, reviewed_at)
                    values ('a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 'spam', now()) $$,
  '42501', null, 'a report cannot arrive already reviewed');
insert into public.reports (reporter_id, video_id, reason)
  values ('a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 'spam');
insert into public.comment_reports (comment_id, reason) values ('c0000000-0000-0000-0000-000000000001', 'harassment');
reset role;
select pg_temp.as_user('a0000000-0000-0000-0000-000000000004');
insert into public.reports (reporter_id, video_id, reason)
  values ('a0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 'harassment');
reset role;
select pg_temp.as_user('a0000000-0000-0000-0000-000000000005');
insert into public.reports (reporter_id, video_id, reason)
  values ('a0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000001', 'spam');
insert into public.reports (reporter_id, video_id, reason)
  values ('a0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000002', 'other');
reset role;

select is((select hidden from public.videos where id = 'b0000000-0000-0000-0000-000000000001'), true,
  'three reports still auto-hide a post');

select pg_temp.as_admin();
select results_eq(
  $$ select target_kind, target_id, open_reports, total_reports, state
       from public.moderation_queue('open', 'most') $$,
  $$ values ('post'::text, 'b0000000-0000-0000-0000-000000000001'::uuid, 3::bigint, 3::bigint, 'auto_hidden'::text),
            ('post', 'b0000000-0000-0000-0000-000000000002'::uuid, 1::bigint, 1::bigint, 'visible'),
            ('comment', 'c0000000-0000-0000-0000-000000000001'::uuid, 1::bigint, 1::bigint, 'visible') $$,
  'the queue lists reported posts and comments, most reported first');
select is((select reasons from public.moderation_queue('open', 'most') where target_id = 'b0000000-0000-0000-0000-000000000001'),
  array['harassment', 'spam'], 'the queue summarises distinct report reasons');
select is((select author_username || ':' || body from public.moderation_queue() where target_id = 'c0000000-0000-0000-0000-000000000001'),
  'commenter:rude words', 'comments show their author and text');
select is((select thumb_key from public.moderation_queue() where target_id = 'b0000000-0000-0000-0000-000000000002'),
  'thumbs/a0000000-0000-0000-0000-000000000002/2.jpg', 'posts carry their thumbnail key');
select is((select count(*) from public.moderation_item_reports('post', 'b0000000-0000-0000-0000-000000000001')),
  3::bigint, 'the detail lists every report');
select is((select video_key from public.moderation_video_media('b0000000-0000-0000-0000-000000000001')),
  'videos/a0000000-0000-0000-0000-000000000002/1.mp4', 'admins can load media of hidden posts');
select throws_ok($$ select public.moderation_hide('post', 'b0000000-0000-0000-0000-00000000dead') $$,
  'P0002', 'MODERATION_TARGET_NOT_FOUND', 'unknown targets are refused');
select throws_ok($$ select * from public.moderation_queue('nope') $$, '22023', 'MODERATION_BAD_FILTER', 'bad filters are refused');
reset role;

-- ------------------------------------------------ hide / restore a post
select pg_temp.as_stranger();
select is(pg_temp.feed_has('b0000000-0000-0000-0000-000000000002'), true, 'v2 starts in the feed');
select is(pg_temp.creator_likes(), 3::bigint, 'v2 likes count toward the creator');
reset role;

select pg_temp.as_admin();
select lives_ok($$ select public.moderation_hide('post', 'b0000000-0000-0000-0000-000000000002', 'off-topic') $$, 'admin hides v2');
select is(pg_temp.queue_state('post', 'b0000000-0000-0000-0000-000000000002'), 'admin_hidden', 'the queue shows it hidden by an admin');
select is((select count(*) from public.moderation_queue('open') where target_id = 'b0000000-0000-0000-0000-000000000002'),
  0::bigint, 'hiding resolves its open reports');
reset role;

select pg_temp.as_stranger();
select is(pg_temp.feed_has('b0000000-0000-0000-0000-000000000002'), false, 'a hidden post leaves the feed');
select is(pg_temp.creator_likes(), 1::bigint, 'and stops counting toward profile likes');
select is((select count(*) from public.videos where id = 'b0000000-0000-0000-0000-000000000002'), 0::bigint,
  'and cannot be read directly');
reset role;
select is(public.can_play_screened_media('b0000000-0000-0000-0000-000000000002',
  'videos/a0000000-0000-0000-0000-000000000002/2.mp4'), false, 'the media worker refuses it');

select pg_temp.as_admin();
select lives_ok($$ select public.moderation_restore('post', 'b0000000-0000-0000-0000-000000000002') $$, 'admin restores v2');
select is(pg_temp.queue_state('post', 'b0000000-0000-0000-0000-000000000002'), 'visible', 'the queue shows it visible');
reset role;
select pg_temp.as_stranger();
select is(pg_temp.feed_has('b0000000-0000-0000-0000-000000000002'), true, 'a restored post is back in the feed');
select is(pg_temp.creator_likes(), 3::bigint, 'and counts toward likes again');
reset role;

-- An auto-hidden post comes back when restored, and needs three fresh reports to hide again.
select pg_temp.as_admin();
select lives_ok($$ select public.moderation_restore('post', 'b0000000-0000-0000-0000-000000000001') $$, 'admin restores auto-hidden v1');
reset role;
select pg_temp.as_stranger();
select is(pg_temp.feed_has('b0000000-0000-0000-0000-000000000001'), true, 'v1 is public again');
insert into public.reports (reporter_id, video_id, reason)
  values ('a0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000001', 'spam');
reset role;
select is((select hidden from public.videos where id = 'b0000000-0000-0000-0000-000000000001'), false,
  'reviewed reports no longer count toward auto-hide');
select is((select report_count from public.videos where id = 'b0000000-0000-0000-0000-000000000001'), 4,
  'the lifetime report count keeps growing');

-- Dismiss resolves reports without changing visibility.
select pg_temp.as_admin();
select lives_ok($$ select public.moderation_dismiss_reports('post', 'b0000000-0000-0000-0000-000000000001', 'not spam') $$,
  'admin dismisses the new report');
select is((select count(*) from public.moderation_queue('open') where target_id = 'b0000000-0000-0000-0000-000000000001'),
  0::bigint, 'dismissed reports leave the open queue');
select is(pg_temp.queue_state('post', 'b0000000-0000-0000-0000-000000000001'), 'visible', 'dismissing keeps it visible');
reset role;

-- ------------------------------------------------ hide / restore a comment
select pg_temp.as_stranger();
select is(pg_temp.comment_count(), 2::bigint, 'both comments count');
reset role;
select pg_temp.as_admin();
select lives_ok($$ select public.moderation_hide('comment', 'c0000000-0000-0000-0000-000000000001', 'harassment') $$, 'admin hides a comment');
reset role;
select pg_temp.as_stranger();
select is(pg_temp.comment_visible('c0000000-0000-0000-0000-000000000001'), false, 'a hidden comment leaves the thread');
select is(pg_temp.comment_count(), 1::bigint, 'and the comment count');
reset role;
select pg_temp.as_admin();
select lives_ok($$ select public.moderation_restore('comment', 'c0000000-0000-0000-0000-000000000001') $$, 'admin restores the comment');
reset role;
select pg_temp.as_stranger();
select is(pg_temp.comment_visible('c0000000-0000-0000-0000-000000000001'), true, 'a restored comment is back');
select is(pg_temp.comment_count(), 2::bigint, 'and counted');
reset role;

-- ------------------------------------------------ bans
-- Reservations made before the ban (the service holds them while screening).
insert into public.pending_video_uploads (id, user_id, video_bytes, thumb_bytes, status) values
  ('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 100, 10, 'checking'),
  ('d0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002', 100, 10, 'checking');

select pg_temp.as_admin();
select lives_ok($$ select public.moderation_hide('post', 'b0000000-0000-0000-0000-000000000002', 'before the ban') $$,
  'v2 is hidden by an admin before the ban');
select throws_ok($$ select public.moderation_ban_user('a0000000-0000-0000-0000-000000000001') $$,
  'P0001', 'CANNOT_BAN_ADMIN', 'admins cannot be banned');
select lives_ok($$ select public.moderation_ban_user('a0000000-0000-0000-0000-000000000002', 'repeat spam') $$, 'admin bans the creator');
select is(pg_temp.queue_state('post', 'b0000000-0000-0000-0000-000000000003'), 'banned', 'the ban hid the visible post');
select is(pg_temp.queue_state('post', 'b0000000-0000-0000-0000-000000000002'), 'admin_hidden', 'admin-hidden posts keep their state');
select is((select bool_and(author_banned) from public.moderation_queue('all') where author_username = 'creator'), true,
  'the queue marks the author banned');
select throws_ok($$ select public.moderation_restore('post', 'b0000000-0000-0000-0000-000000000003') $$,
  'P0001', 'AUTHOR_BANNED', 'a banned author''s post comes back only by unbanning');
reset role;

select pg_temp.as_stranger();
select is((select count(*) from public.feed_videos where username = 'creator'), 0::bigint, 'every post of a banned account leaves the feed');
select is(pg_temp.comment_visible('c0000000-0000-0000-0000-000000000002'), false, 'and every comment');
select is((select count(*) from public.public_creators where username = 'creator'), 0::bigint, 'and the profile leaves creator lookups');
reset role;

select pg_temp.as_user('a0000000-0000-0000-0000-000000000002');
select is(public.my_account_banned(), true, 'a banned account can tell it is banned');
select throws_ok($$ insert into public.comments (video_id, body) values ('b0000000-0000-0000-0000-000000000001', 'hi') $$,
  'P0001', 'ACCOUNT_BANNED', 'a banned account cannot comment');
reset role;

set local role service_role;
select throws_ok($$ select public.publish_screened_video('d0000000-0000-0000-0000-000000000001', '{"caption":"x"}'::jsonb, 0) $$,
  'P0001', 'ACCOUNT_BANNED', 'publish_screened_video refuses a banned account');
select throws_ok($$ select public.reserve_video_upload('a0000000-0000-0000-0000-000000000002', 100, 10) $$,
  'P0001', 'ACCOUNT_BANNED', 'a banned account cannot reserve an upload');
select is(public.account_is_banned('a0000000-0000-0000-0000-000000000002'), true, 'the upload functions can check a ban');
reset role;
select is((select status from public.pending_video_uploads where id = 'd0000000-0000-0000-0000-000000000001'), 'checking',
  'the refused publish rolled back');

select pg_temp.as_admin();
select lives_ok($$ select public.moderation_unban_user('a0000000-0000-0000-0000-000000000002', 'appeal accepted') $$, 'admin unbans');
select throws_ok($$ select public.moderation_unban_user('a0000000-0000-0000-0000-000000000002') $$,
  'P0001', 'NOT_BANNED', 'unbanning twice is refused');
reset role;

set local role service_role;
select lives_ok($$ select public.publish_screened_video('d0000000-0000-0000-0000-000000000002', '{"caption":"back"}'::jsonb, 0) $$,
  'an unbanned account can publish again');
select isnt(public.reserve_video_upload('a0000000-0000-0000-0000-000000000002', 100, 10), null, 'and reserve uploads');
reset role;

select pg_temp.as_stranger();
select is(pg_temp.feed_has('b0000000-0000-0000-0000-000000000003'), true, 'the ban-hidden post is back');
select is(pg_temp.feed_has('d0000000-0000-0000-0000-000000000002'), true, 'the new post is public');
select is(pg_temp.feed_has('b0000000-0000-0000-0000-000000000002'), false, 'the admin-hidden post stays hidden');
select is(pg_temp.comment_visible('c0000000-0000-0000-0000-000000000002'), true, 'the ban-hidden comment is back');
select is((select count(*) from public.public_creators where username = 'creator'), 1::bigint, 'the profile is back');
reset role;
select pg_temp.as_user('a0000000-0000-0000-0000-000000000002');
select lives_ok($$ insert into public.comments (video_id, body) values ('b0000000-0000-0000-0000-000000000001', 'hello again') $$,
  'an unbanned account can comment');
reset role;

-- ------------------------------------------------ audit log
select is(pg_temp.actions('hide', 'b0000000-0000-0000-0000-000000000002'), 2::bigint, 'each post hide is logged');
select is(pg_temp.actions('restore', 'b0000000-0000-0000-0000-000000000002'), 1::bigint, 'post restore is logged');
select is(pg_temp.actions('restore', 'b0000000-0000-0000-0000-000000000001'), 1::bigint, 'auto-hidden restore is logged');
select is(pg_temp.actions('dismiss', 'b0000000-0000-0000-0000-000000000001'), 1::bigint, 'dismiss is logged');
select is(pg_temp.actions('hide', 'c0000000-0000-0000-0000-000000000001')
          + pg_temp.actions('restore', 'c0000000-0000-0000-0000-000000000001'), 2::bigint, 'comment hide and restore are logged');
select is(pg_temp.actions('ban', 'a0000000-0000-0000-0000-000000000002'), 1::bigint, 'the ban is logged');
select is(pg_temp.actions('unban', 'a0000000-0000-0000-0000-000000000002'), 1::bigint, 'the unban is logged');
select is((select count(*) from moderation_internal.actions), 9::bigint, 'every action was logged once and refused ones not at all');
select is((select note from moderation_internal.actions where action = 'ban'), 'repeat spam', 'notes are kept');

select pg_temp.as_admin();
select results_eq(
  $$ select admin_username, action, target_kind, target_username, note from public.moderation_log(2) $$,
  $$ values ('admin'::text, 'unban'::text, 'user'::text, 'creator'::text, 'appeal accepted'::text),
            ('admin', 'ban', 'user', 'creator', 'repeat spam') $$,
  'the audit log reads newest first with admin, action, target and note');
reset role;

set local role service_role;
select is((select new_reports from public.moderation_report_digest(now() - interval '1 day')), 6::bigint,
  'the digest hook counts new reports');
reset role;

select * from finish();
rollback;
