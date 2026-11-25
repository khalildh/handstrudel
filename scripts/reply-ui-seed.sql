-- LOCAL ONLY. Seeds a post and a reply published through the real screened path, for
-- HandStrudelUITests.testLocalBackendCountsAndShowsAPublishedReply. Undo with reply-ui-seed-cleanup.sql.
-- docker exec -i supabase_db_handstrudel-social psql -U postgres -v ON_ERROR_STOP=1 < scripts/reply-ui-seed.sql
begin;
insert into auth.users (id, email) values
  ('7a000000-0000-0000-0000-000000000001', 'reply-ui-original@test.dev'),
  ('7a000000-0000-0000-0000-000000000002', 'reply-ui-taker@test.dev');
update public.profiles set username = 'original_maker' where id = '7a000000-0000-0000-0000-000000000001';
update public.profiles set username = 'take_replier' where id = '7a000000-0000-0000-0000-000000000002';

insert into public.videos (id, user_id, video_key, thumb_key, caption, instrument, sound_setup, duration_s, width, height, created_at)
values ('7b000000-0000-0000-0000-000000000001', '7a000000-0000-0000-0000-000000000001',
  'videos/7a000000-0000-0000-0000-000000000001/original.mp4', 'thumbs/7a000000-0000-0000-0000-000000000001/original.jpg',
  'Answer my loop', 'Grand Piano',
  '{"version":1,"instrument":"grand_piano","waveform":"sine","key":"D","scale":"Minor","progression":"free","mode":"soundfont","bpm":96,"useSoundFont":true,"autoStrum":false,"padVolume":0.3,"gridOctave":3,"gridRange":2}',
  4, 720, 1280, now() - interval '1 hour');

-- The reply goes through the same function publish-upload calls after screening.
insert into public.pending_video_uploads (id, user_id, video_bytes, thumb_bytes, status, attempt)
values ('7b000000-0000-0000-0000-000000000002', '7a000000-0000-0000-0000-000000000002', 10, 10, 'checking', 1);
set local role service_role;
select public.publish_screened_video('7b000000-0000-0000-0000-000000000002',
  '{"caption":"My answer","instrument":"Grand Piano","duration_s":4,"width":720,"height":1280,"reply_to_id":"7b000000-0000-0000-0000-000000000001"}'::jsonb, 1);
reset role;
commit;

-- What a signed-out viewer gets from the feed view.
set role anon;
select id, caption, reply_to_id, reply_to_username, reply_count from public.feed_videos
where id::text like '7b000000-%' order by created_at;
reset role;
