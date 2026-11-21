-- Seed for testFeedSoundPageAgainstLocalSupabase. Load into a throwaway local stack only:
--   psql "$DB_URL" -f scripts/sound-pages-ui-seed.sql
-- One sound (Rhodes EP, Eb Minor) with 30 visible takes: the original (50 likes, oldest)
-- and take_01..take_29 (take N has N likes and was posted N hours ago, so Top and
-- Recent orders differ and both cross the 24-row page). take_05 is a play-along of the
-- original. Two more takes must never show: a hidden one and one by an account
-- without a handle, both with more likes than anything visible.
begin;
insert into auth.users (id, email)
select ('68000000-0000-0000-0000-0000000000' || lpad(n::text, 2, '0'))::uuid, 'sound-ui-' || n || '@test.dev'
from generate_series(0, 31) n;
update public.profiles set username = case right(id::text, 2)
    when '00' then 'originalist' when '31' then null else 'take_' || right(id::text, 2) end
  where id::text like '68000000-%';

create temp table rhodes as select '{"version":1,"instrument":"electric_piano_1","waveform":"sine","key":"Eb","scale":"Minor","progression":"pop","mode":"soundfont","bpm":92,"useSoundFont":true,"autoStrum":false,"padVolume":0.3,"gridOctave":3,"gridRange":2}'::jsonb as setup;

insert into public.videos (id, user_id, video_key, thumb_key, caption, instrument, sound_setup, backing_enabled, like_count, created_at)
select '69000000-0000-0000-0000-000000000000', '68000000-0000-0000-0000-000000000000',
       'videos/68000000-0000-0000-0000-000000000000/o.mp4', 'thumbs/68000000-0000-0000-0000-000000000000/o.jpg',
       'The original', 'Rhodes EP', setup, true, 50, now() - interval '40 hours' from rhodes;

-- take N: N likes, N hours old. Tempo varies, which doesn't change the sound.
insert into public.videos (id, user_id, video_key, thumb_key, caption, instrument, sound_setup, like_count, created_at, source_video_id, hidden)
select ('69000000-0000-0000-0000-0000000000' || lpad(n::text, 2, '0'))::uuid,
       u, 'videos/' || u || '/t.mp4', 'thumbs/' || u || '/t.jpg',
       case when n = 30 then 'Hidden take' when n = 31 then 'No handle take' else 'Take ' || n end,
       'Rhodes EP', jsonb_set(r.setup, '{bpm}', to_jsonb(80 + n)),
       case when n >= 30 then 99 + n else n end, now() - make_interval(hours => n),
       case when n = 5 then '69000000-0000-0000-0000-000000000000'::uuid end, n = 30
from generate_series(1, 31) n, rhodes r,
     lateral (select ('68000000-0000-0000-0000-0000000000' || lpad(n::text, 2, '0'))::uuid as u) owner;
commit;
