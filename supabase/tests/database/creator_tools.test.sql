begin;
select plan(23);

insert into auth.users (id, email) values
  ('30000000-0000-0000-0000-000000000001', 'source@test.dev'),
  ('30000000-0000-0000-0000-000000000002', 'player@test.dev'),
  ('30000000-0000-0000-0000-000000000003', 'other@test.dev');
update public.profiles
set username = 'user_' || right(id::text, 1), accepted_terms_at = now()
where id::text like '30000000-%';

create function pg_temp.claim(uid uuid) returns text language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid)::text, true)
$$;
create function pg_temp.post(id uuid, source uuid, enabled boolean) returns void language sql as $$
  insert into public.videos (id, user_id, video_key, thumb_key, source_video_id, backing_enabled)
  values (id, auth.uid(), 'videos/' || auth.uid() || '/v.mp4', 'thumbs/' || auth.uid() || '/t.jpg', source, enabled)
$$;
create function pg_temp.comment(body text, parent uuid default null) returns void language sql as $$
  insert into public.comments (video_id, parent_id, body)
  values ('40000000-0000-0000-0000-000000000001', parent, body)
$$;

select pg_temp.claim('30000000-0000-0000-0000-000000000001');
set local role authenticated;
select pg_temp.post('40000000-0000-0000-0000-000000000001', null, false);
select pg_temp.comment('A note from the creator');
select is((select count(*) from public.activity_inbox), 0::bigint, 'self activity is not notified');
reset role;

select pg_temp.claim('30000000-0000-0000-0000-000000000002');
set local role authenticated;
select pg_temp.comment('Nice sound');
select set_config('test.listener_comment', (select id::text from public.video_comments where body = 'Nice sound'), true);
select is((select count(*) from public.activity_inbox), 0::bigint, 'sender cannot read the creator inbox');
select throws_ok($$ select pg_temp.post('40000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000001', false) $$,
                 'P0001', 'BACKING_UNAVAILABLE', 'cannot credit a source that has not opted in');
insert into public.follows (follower_id, followee_id) values (auth.uid(), '30000000-0000-0000-0000-000000000001');
select is((select count(*) from public.following_videos), 1::bigint, 'following contains followed creator');
select is((select username::text from public.public_creators where id = '30000000-0000-0000-0000-000000000001'),
          'user_1', 'creator profile is available');
reset role;

select pg_temp.claim('30000000-0000-0000-0000-000000000001');
set local role authenticated;
select is((select kind from public.activity_inbox), 'comment', 'video creator gets a comment');
select is((select read_at from public.activity_inbox), null::timestamptz, 'new activity is unread');
select set_config('test.activity_item', (select id::text from public.activity_inbox), true);
select public.mark_creator_activity_read(current_setting('test.activity_item')::uuid);
select ok((select read_at is not null from public.activity_inbox), 'recipient can mark read');
select pg_temp.comment('Thank you', current_setting('test.listener_comment')::uuid);
update public.videos set backing_enabled = true where id = '40000000-0000-0000-0000-000000000001';
reset role;

select pg_temp.claim('30000000-0000-0000-0000-000000000002');
set local role authenticated;
select is((select kind from public.activity_inbox), 'reply', 'comment author gets a reply');
select set_config('test.reply_activity', (select id::text from public.activity_inbox), true);
select lives_ok($$ select pg_temp.post('40000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000001', false) $$,
                'creator opt-in permits an attributed post');
select is((select source_username::text from public.feed_videos where id = '40000000-0000-0000-0000-000000000002'), 'user_1',
          'credit uses the original creator username');
select throws_ok($$ update public.videos set source_video_id = null where id = '40000000-0000-0000-0000-000000000002' $$,
                 '42501', null, 'uploader cannot erase credit');
select throws_ok($$ update public.videos set backing_enabled = true where id = '40000000-0000-0000-0000-000000000002' $$,
                 'P0001', 'BACKING_REMIX_NOT_REUSABLE', 'remixes cannot grant reuse of the original audio');
select is((select count(*) from public.following_videos), 1::bigint, 'unfollowed posts are excluded');
reset role;

select pg_temp.claim('30000000-0000-0000-0000-000000000003');
set local role authenticated;
select is((select count(*) from public.activity_inbox), 0::bigint, 'third party cannot read others activity');
select public.mark_creator_activity_read(current_setting('test.reply_activity')::uuid);
reset role;
select is((select read_at from public.creator_activity where id = current_setting('test.reply_activity')::uuid),
          null::timestamptz, 'third party cannot mark activity read');

select pg_temp.claim('30000000-0000-0000-0000-000000000001');
set local role authenticated;
update public.videos set backing_enabled = false where id = '40000000-0000-0000-0000-000000000001';
reset role;
select pg_temp.claim('30000000-0000-0000-0000-000000000002');
set local role authenticated;
select throws_ok($$ select pg_temp.post('40000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000001', false) $$,
                 'P0001', 'BACKING_UNAVAILABLE', 'revocation stops new posts');
select ok((select source_video_id is not null from public.feed_videos where id = '40000000-0000-0000-0000-000000000002'),
          'revocation preserves existing credit');
insert into public.blocks (blocker_id, blocked_id) values (auth.uid(), '30000000-0000-0000-0000-000000000001');
select is((select count(*) from public.activity_inbox), 0::bigint, 'blocking hides notifications from that actor');
select is((select count(*) from public.following_videos), 0::bigint, 'blocking hides followed videos');
select is((select count(*) from public.public_creators where id = '30000000-0000-0000-0000-000000000001'), 0::bigint,
          'blocked creator profiles are excluded');
reset role;

select pg_temp.claim('30000000-0000-0000-0000-000000000001');
set local role authenticated;
delete from public.videos where id = '40000000-0000-0000-0000-000000000001';
reset role;
select pg_temp.claim('30000000-0000-0000-0000-000000000002');
set local role authenticated;
select is((select source_video_id from public.feed_videos where id = '40000000-0000-0000-0000-000000000002'),
          null::uuid, 'source deletion removes the link');
select throws_ok($$ update public.videos set backing_enabled = true where id = '40000000-0000-0000-0000-000000000002' $$,
                 'P0001', 'BACKING_REMIX_NOT_REUSABLE', 'source deletion does not grant rights to sublicense its audio');
reset role;

select * from finish();
rollback;
