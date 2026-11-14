begin;
select plan(17);

insert into auth.users (id, email) values
  ('51000000-0000-0000-0000-000000000001', 'discovery-creator@test.dev'),
  ('51000000-0000-0000-0000-000000000002', 'discovery-viewer@test.dev'),
  ('51000000-0000-0000-0000-000000000003', 'discovery-other@test.dev');
update public.profiles set username = 'discovery_' || right(id::text, 1) where id::text like '51000000-%';

create function pg_temp.claim(uid uuid) returns text language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid)::text, true)
$$;
create function pg_temp.clip(id uuid, author uuid, source uuid, backing boolean, published_at timestamptz) returns void
language sql as $$
  insert into public.videos (id, user_id, video_key, thumb_key, source_video_id, backing_enabled, created_at)
  values (id, author, 'videos/' || author || '/v', 'thumbs/' || author || '/t', source, backing, published_at)
$$;

select pg_temp.clip('52000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', null, true, now() - interval '1 day');
select pg_temp.clip('52000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000002', '52000000-0000-0000-0000-000000000001', false, now());
select pg_temp.clip('52000000-0000-0000-0000-000000000003', '51000000-0000-0000-0000-000000000002', '52000000-0000-0000-0000-000000000001', false, now() - interval '2 days');
insert into public.weekly_challenges (source_video_id, title, prompt, starts_at, ends_at, featured)
values ('52000000-0000-0000-0000-000000000001', 'First challenge', 'Play eight bars. Make them yours.',
        now() - interval '1 hour', now() + interval '6 days', true);

select throws_ok($$ insert into public.weekly_challenges (source_video_id, title, prompt, starts_at, ends_at, featured)
values ('52000000-0000-0000-0000-000000000002', 'Overlap', 'Prompt', now(), now() + interval '2 days', true) $$,
 '23P01', null, 'only one challenge can be featured at a time');

set local role anon;
select throws_ok($$ select * from public.saved_videos $$, '42501', null, 'guests cannot read private bookmarks');
select is((select count(*) from public.weekly_challenges), 1::bigint, 'active opted-in challenge is public');
select is((select count(*) from public.weekly_challenge_entries), 1::bigint, 'only remixes published in the window count');
reset role;

select pg_temp.claim('51000000-0000-0000-0000-000000000002');
set local role authenticated;
select lives_ok($$ insert into public.video_bookmarks (video_id) values ('52000000-0000-0000-0000-000000000001') $$,
 'member can save a public performance');
select is((select count(*) from public.saved_videos), 1::bigint, 'member can read their saved library');
select throws_ok($$ insert into public.video_bookmarks (user_id, video_id)
 values ('51000000-0000-0000-0000-000000000003', '52000000-0000-0000-0000-000000000001') $$,
 '42501', null, 'member cannot write a bookmark as someone else');
select throws_ok($$ insert into public.weekly_challenges (source_video_id, title, prompt, starts_at, ends_at)
 values ('52000000-0000-0000-0000-000000000002', 'Client', 'Prompt', now(), now() + interval '2 days') $$,
 '42501', null, 'only a curator can schedule challenges');
select pg_temp.clip('52000000-0000-0000-0000-000000000004', auth.uid(), '52000000-0000-0000-0000-000000000001',
                    false, now() + interval '10 days');
select is((select created_at from public.videos where id = '52000000-0000-0000-0000-000000000004'), now(),
          'client cannot set the publication time for a challenge entry');
reset role;

select pg_temp.claim('51000000-0000-0000-0000-000000000003');
set local role authenticated;
select is((select count(*) from public.video_bookmarks), 0::bigint, 'other members cannot see raw bookmarks');
delete from public.video_bookmarks where video_id = '52000000-0000-0000-0000-000000000001';
reset role;

select pg_temp.claim('51000000-0000-0000-0000-000000000002');
set local role authenticated;
select is((select count(*) from public.saved_videos), 1::bigint, 'other members cannot remove a bookmark');
insert into public.blocks (blocker_id, blocked_id)
values (auth.uid(), '51000000-0000-0000-0000-000000000001');
select is((select count(*) from public.saved_videos), 0::bigint, 'blocked creators disappear from Saved');
select is((select count(*) from public.weekly_challenges), 0::bigint, 'a blocked source hides the challenge');
select lives_ok($$ delete from public.video_bookmarks where video_id = '52000000-0000-0000-0000-000000000001' $$,
 'owner can unsave even if the source is blocked');
select is((select count(*) from public.video_bookmarks), 0::bigint, 'owner deletion persists');
reset role;

update public.videos set backing_enabled = false where id = '52000000-0000-0000-0000-000000000001';
select set_config('request.jwt.claims', '{}', true);
set local role anon;
select is((select count(*) from public.weekly_challenges), 0::bigint, 'revoked backing source hides challenge');
select is((select count(*) from public.weekly_challenge_entries), 0::bigint, 'revocation hides challenge entries from the pilot');
reset role;

select * from finish();
rollback;
