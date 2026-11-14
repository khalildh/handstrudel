-- RLS + trigger tests for the accounts/feed schema.  Run: supabase test db
begin;
select plan(18);

-- Two users (the auth trigger creates their profile rows).
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@test.dev'),
  ('00000000-0000-0000-0000-00000000000b', 'b@test.dev'),
  ('00000000-0000-0000-0000-00000000000c', 'c@test.dev');
update public.profiles set username = 'alice' where id = '00000000-0000-0000-0000-00000000000a';
update public.profiles set username = 'bob'   where id = '00000000-0000-0000-0000-00000000000b';
update public.profiles set username = 'cara'  where id = '00000000-0000-0000-0000-00000000000c';

select is((select count(*)::int from public.profiles), 3, 'signup trigger creates profiles');

create function pg_temp.act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  set local role authenticated;
$$;

-- Alice posts a video.
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
insert into public.videos (id, user_id, video_key, thumb_key, caption, like_count)
values ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000a',
        'videos/00000000-0000-0000-0000-00000000000a/v1.mp4',
        'thumbs/00000000-0000-0000-0000-00000000000a/v1.jpg', 'hello', 999);
select is((select like_count from public.videos where id = '11111111-1111-1111-1111-111111111111'), 0,
          'clients cannot seed counters');
select is((select sound_setup from public.feed_videos where id = '11111111-1111-1111-1111-111111111111'),
          null::jsonb, 'setups are not shared by default');
select throws_ok($$ update public.videos set sound_setup = '[1]' $$,
                 '23514', null, 'setups must be JSON objects');
update public.videos set sound_setup = '{"version":1,"instrument":"violin"}';

select throws_ok($$ insert into public.videos (user_id, video_key, thumb_key)
                    values ('00000000-0000-0000-0000-00000000000b',
                            'videos/00000000-0000-0000-0000-00000000000b/x.mp4',
                            'thumbs/00000000-0000-0000-0000-00000000000b/x.jpg') $$,
                 '42501', null, 'cannot post as someone else');

select throws_ok($$ insert into public.videos (user_id, video_key, thumb_key)
                    values ('00000000-0000-0000-0000-00000000000a', 'videos/someone-else/x.mp4', 'thumbs/x.jpg') $$,
                 '23514', null, 'object keys must be under own folder');

-- Bob likes it; can't delete it.
reset role;
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into public.likes (user_id, video_id) values ('00000000-0000-0000-0000-00000000000b', '11111111-1111-1111-1111-111111111111');
select is((select like_count from public.videos where id = '11111111-1111-1111-1111-111111111111'), 1, 'like trigger counts');
select is((select liked_by_me from public.feed_videos where id = '11111111-1111-1111-1111-111111111111'), true, 'feed shows liked_by_me');

delete from public.videos where id = '11111111-1111-1111-1111-111111111111';
reset role;
select is((select count(*)::int from public.videos), 1, 'other users cannot delete a video');

-- Anonymous users can read the feed.
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is((select count(*)::int from public.feed_videos), 1, 'anon can read feed');
select is((select sound_setup->>'instrument' from public.feed_videos), 'violin', 'opted-in sound is public');
select throws_ok($$ select count(*) from public.reports $$, '42501', null, 'anon cannot read reports');
reset role;

-- Blocking hides content both ways.
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
insert into public.blocks (blocker_id, blocked_id) values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000c');
reset role;
select pg_temp.act_as('00000000-0000-0000-0000-00000000000c');
select is((select count(*)::int from public.feed_videos), 0, 'blocked user does not see blocker''s videos');
select is((select count(*)::int from public.blocks), 0, 'blocks are private to the blocker');
reset role;

-- A reporter stops seeing the post right away (before it's hidden for everyone).
select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
insert into public.reports (reporter_id, video_id, reason)
  values ('00000000-0000-0000-0000-00000000000b', '11111111-1111-1111-1111-111111111111', 'spam');
select is((select count(*)::int from public.feed_videos), 0, 'reporter no longer sees the reported post');
reset role;

-- Three reports hide a video; the author still sees it.
insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000000d', 'd@test.dev');
insert into public.reports (reporter_id, video_id, reason) values
  ('00000000-0000-0000-0000-00000000000c', '11111111-1111-1111-1111-111111111111', 'spam'),
  ('00000000-0000-0000-0000-00000000000d', '11111111-1111-1111-1111-111111111111', 'spam');
select is((select hidden from public.videos where id = '11111111-1111-1111-1111-111111111111'), true, '3 reports hide a video');

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b');
select is((select count(*)::int from public.feed_videos), 0, 'hidden video leaves the feed');
reset role;
select pg_temp.act_as('00000000-0000-0000-0000-00000000000a');
select is((select count(*)::int from public.videos), 1, 'author still sees own hidden video');
reset role;

select * from finish();
rollback;
