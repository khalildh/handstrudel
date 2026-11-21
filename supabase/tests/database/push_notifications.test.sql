begin;
select plan(41);

insert into auth.users (id, email) values
  ('a7000000-0000-0000-0000-000000000001', 'push-alice@test.dev'),
  ('a7000000-0000-0000-0000-000000000002', 'push-bob@test.dev'),
  ('a7000000-0000-0000-0000-000000000003', 'push-cara@test.dev'),
  ('a7000000-0000-0000-0000-000000000004', 'push-dan@test.dev'),
  ('a7000000-0000-0000-0000-000000000005', 'push-eve@test.dev');
update public.profiles set username = 'push_' || right(id::text, 1), accepted_terms_at = now()
where id::text like 'a7000000-%';

create function pg_temp.as_user(uid text) returns text language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid)::text, true)
$$;
create function pg_temp.queued(recipient text, k text) returns bigint language sql as $$
  select count(*) from public.notifications where recipient_id = recipient::uuid and kind = k
$$;

-- Alice, Cara and Eve have devices; Dan has none. Bob registers his own below.
insert into public.device_tokens (token, user_id, environment) values
  (repeat('a1', 32), 'a7000000-0000-0000-0000-000000000001', 'production'),
  (repeat('c3', 32), 'a7000000-0000-0000-0000-000000000003', 'production'),
  (repeat('e5', 32), 'a7000000-0000-0000-0000-000000000005', 'production');
insert into public.videos (id, user_id, video_key, thumb_key, backing_enabled) values
  ('a7100000-0000-0000-0000-000000000001', 'a7000000-0000-0000-0000-000000000001',
   'videos/a7000000-0000-0000-0000-000000000001/v', 'thumbs/a7000000-0000-0000-0000-000000000001/t', true);

-- ------------------------------------------------------------ access
set local role anon;
select throws_ok($$ select * from public.notifications $$, '42501', null, 'guests cannot read the queue');
select throws_ok($$ select * from public.device_tokens $$, '42501', null, 'guests cannot read device tokens');
select throws_ok($$ select public.register_device_token(repeat('b2', 32), 'production') $$, '42501', null,
                 'guests cannot register tokens');
reset role;

select pg_temp.as_user('a7000000-0000-0000-0000-000000000002');
set local role authenticated;
select throws_ok($$ select * from public.notifications $$, '42501', null, 'members cannot read the queue');
select throws_ok($$ select public.claim_push_notifications() $$, '42501', null, 'members cannot claim pushes');
select throws_ok($$ insert into public.device_tokens (token, user_id, environment)
                    values (repeat('b2', 32), auth.uid(), 'production') $$, '42501', null,
                 'tokens are only written through register_device_token');
select lives_ok($$ select public.register_device_token(upper(repeat('b2', 32)), 'production') $$, 'Bob registers a device');
select is((select count(*) from public.device_tokens), 1::bigint, 'Bob sees only his own token');
select is((select token from public.device_tokens), repeat('b2', 32), 'tokens are stored lowercase');
select throws_ok($$ select public.register_device_token('not-a-token', 'production') $$, '23514', null,
                 'malformed tokens are rejected');
select throws_ok($$ select public.register_device_token(repeat('b2', 32), 'staging') $$, '23514', null,
                 'unknown environments are rejected');
delete from public.device_tokens where token = repeat('a1', 32);
reset role;
select is((select count(*) from public.device_tokens where token = repeat('a1', 32)), 1::bigint,
          'members cannot delete someone else''s token');

-- A device handed to another account moves with it.
select pg_temp.as_user('a7000000-0000-0000-0000-000000000004');
set local role authenticated;
select public.register_device_token(repeat('b2', 32), 'sandbox');
reset role;
select is((select user_id from public.device_tokens where token = repeat('b2', 32)),
          'a7000000-0000-0000-0000-000000000004'::uuid, 'a re-registered token moves to the new account');
select pg_temp.as_user('a7000000-0000-0000-0000-000000000004');
set local role authenticated;
delete from public.device_tokens where token = repeat('b2', 32);
reset role;
select is((select count(*) from public.device_tokens where token = repeat('b2', 32)), 0::bigint,
          'members can remove their own token on sign-out');
insert into public.device_tokens (token, user_id, environment)
values (repeat('b2', 32), 'a7000000-0000-0000-0000-000000000002', 'production');

-- ------------------------------------------------------------ preferences
select pg_temp.as_user('a7000000-0000-0000-0000-000000000002');
set local role authenticated;
select throws_ok($$ insert into public.notification_preferences (user_id, likes)
                    values ('a7000000-0000-0000-0000-000000000001', false) $$, '42501', null,
                 'members cannot change someone else''s preferences');
select lives_ok($$ insert into public.notification_preferences (likes) values (false) $$,
                'members save their own preferences');
reset role;

-- ------------------------------------------------------------ comments
select pg_temp.as_user('a7000000-0000-0000-0000-000000000001');
set local role authenticated;
insert into public.comments (video_id, body) values ('a7100000-0000-0000-0000-000000000001', 'my own note');
insert into public.blocks (blocker_id, blocked_id) values (auth.uid(), 'a7000000-0000-0000-0000-000000000003');
reset role;
select is(pg_temp.queued('a7000000-0000-0000-0000-000000000001', 'comment'), 0::bigint, 'own comments are silent');

select pg_temp.as_user('a7000000-0000-0000-0000-000000000002');
set local role authenticated;
insert into public.comments (video_id, body) values ('a7100000-0000-0000-0000-000000000001', 'great take');
reset role;
select is(pg_temp.queued('a7000000-0000-0000-0000-000000000001', 'comment'), 1::bigint, 'a comment queues a push');

-- ------------------------------------------------------------ likes
insert into public.likes (user_id, video_id) values
  ('a7000000-0000-0000-0000-000000000001', 'a7100000-0000-0000-0000-000000000001'),
  ('a7000000-0000-0000-0000-000000000003', 'a7100000-0000-0000-0000-000000000001');
select is(pg_temp.queued('a7000000-0000-0000-0000-000000000001', 'like'), 0::bigint,
          'self likes and likes from blocked accounts are silent');
insert into public.likes (user_id, video_id) values
  ('a7000000-0000-0000-0000-000000000002', 'a7100000-0000-0000-0000-000000000001'),
  ('a7000000-0000-0000-0000-000000000004', 'a7100000-0000-0000-0000-000000000001'),
  ('a7000000-0000-0000-0000-000000000005', 'a7100000-0000-0000-0000-000000000001');
select is(pg_temp.queued('a7000000-0000-0000-0000-000000000001', 'like'), 1::bigint, 'likes on one post share a batch');
select is((select cardinality(actor_ids) from public.notifications where kind = 'like'), 3, 'the batch counts each liker');
delete from public.likes where user_id = 'a7000000-0000-0000-0000-000000000005';
insert into public.likes (user_id, video_id) values ('a7000000-0000-0000-0000-000000000005', 'a7100000-0000-0000-0000-000000000001');
select is((select cardinality(actor_ids) from public.notifications where kind = 'like'), 3, 'unlike and like again counts once');

-- ------------------------------------------------------------ claim
create temporary table claimed on commit drop as select * from public.claim_push_notifications(100, 'production');
select is((select count(*) from claimed), 2::bigint, 'the comment and the like batch are due');
select is((select actor_count from claimed where kind = 'like'), 3, 'like pushes report the batch size');
select is((select actor_username from claimed where kind = 'like'), 'push_5', 'the latest liker leads the text');
select is((select comment_body from claimed where kind = 'comment'), 'great take', 'comment pushes carry the comment');
select is((select tokens from claimed where kind = 'like'), array[repeat('a1', 32)], 'pushes go to the recipient''s devices');
select is((select count(*) from public.notifications where status = 'sending'), 2::bigint, 'claimed rows are marked as sending');
select is((select count(*) from public.claim_push_notifications(100, 'production')), 0::bigint, 'claimed rows are not sent twice');
update public.notifications set status = 'sent', sent_at = now() where status = 'sending';

-- Another like within the hour waits for the next window.
delete from public.likes where user_id = 'a7000000-0000-0000-0000-000000000002';
insert into public.likes (user_id, video_id) values ('a7000000-0000-0000-0000-000000000002', 'a7100000-0000-0000-0000-000000000001');
select ok((select send_after >= now() + interval '59 minutes' from public.notifications
           where kind = 'like' and status = 'pending'), 'at most one like push per post per hour');

-- ------------------------------------------------------------ new posts
insert into public.follows (follower_id, followee_id) values
  ('a7000000-0000-0000-0000-000000000005', 'a7000000-0000-0000-0000-000000000002'),
  ('a7000000-0000-0000-0000-000000000001', 'a7000000-0000-0000-0000-000000000002'),
  ('a7000000-0000-0000-0000-000000000004', 'a7000000-0000-0000-0000-000000000002');
insert into public.videos (id, user_id, video_key, thumb_key, source_video_id) values
  ('a7100000-0000-0000-0000-000000000002', 'a7000000-0000-0000-0000-000000000002',
   'videos/a7000000-0000-0000-0000-000000000002/v', 'thumbs/a7000000-0000-0000-0000-000000000002/t',
   'a7100000-0000-0000-0000-000000000001');
select is(pg_temp.queued('a7000000-0000-0000-0000-000000000001', 'remix'), 1::bigint, 'a play-along notifies the source creator');
select is(pg_temp.queued('a7000000-0000-0000-0000-000000000001', 'following_post'), 0::bigint,
          'the source creator gets one push for the post, not two');
select is(pg_temp.queued('a7000000-0000-0000-0000-000000000005', 'following_post'), 1::bigint, 'followers hear about new posts');
select is(pg_temp.queued('a7000000-0000-0000-0000-000000000004', 'following_post'), 0::bigint, 'accounts without devices are skipped');

select push_internal.notify_take_reply('a7100000-0000-0000-0000-000000000002', 'a7100000-0000-0000-0000-000000000001');
select is((select kind from public.notifications where dedupe_key = 'video:a7100000-0000-0000-0000-000000000002'
           and recipient_id = 'a7000000-0000-0000-0000-000000000001'), 'take_reply',
          'a take reply replaces the queued play-along push');

-- Things that change before sending are rechecked.
insert into public.notification_preferences (user_id, take_replies) values ('a7000000-0000-0000-0000-000000000001', false);
truncate claimed;
insert into claimed select * from public.claim_push_notifications(100, 'production');
select is((select array_agg(kind order by kind) from claimed), array['following_post'],
          'pushes turned off after queueing are skipped');
select is((select count(*) from public.notifications where status = 'skipped'), 1::bigint, 'skipped pushes are logged');

-- ------------------------------------------------------------ weekly challenge
update public.notifications set status = 'sent' where status = 'sending';
insert into public.weekly_challenges (id, source_video_id, title, prompt, starts_at, ends_at, featured) values
  ('a7200000-0000-0000-0000-000000000001', 'a7100000-0000-0000-0000-000000000001', 'Lo-fi week', 'Play along',
   now() - interval '1 minute', now() + interval '7 days', true);
truncate claimed;
insert into claimed select * from public.claim_push_notifications(100, 'production');
select is((select count(*) from claimed where kind = 'challenge'), 2::bigint,
          'a started challenge reaches devices except its creator and accounts they blocked');
select is((select challenge_title from claimed where kind = 'challenge' limit 1), 'Lo-fi week', 'challenge pushes carry the title');
select is((select count(*) from public.claim_push_notifications(100, 'production')), 0::bigint, 'challenges are announced once');

-- ------------------------------------------------------------ account deletion
delete from auth.users where id = 'a7000000-0000-0000-0000-000000000005';
select is((select count(*) from public.device_tokens where token = repeat('e5', 32)), 0::bigint,
          'deleting an account removes its devices');

select * from finish();
rollback;
