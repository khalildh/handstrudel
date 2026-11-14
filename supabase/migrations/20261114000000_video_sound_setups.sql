alter table public.videos
  add column sound_setup jsonb
  check (sound_setup is null or (
    jsonb_typeof(sound_setup) = 'object' and octet_length(sound_setup::text) <= 4096
  ));

-- Preserve the existing view column order and visibility rules for older clients.
create or replace view public.feed_videos with (security_invoker = true) as
select v.id, v.user_id, v.video_key, v.thumb_key, v.caption, v.instrument, v.mode,
       v.duration_s, v.width, v.height, v.like_count, v.report_count, v.hidden, v.created_at,
       p.username, p.display_name, p.avatar_key,
       exists (select 1 from public.likes l where l.video_id = v.id and l.user_id = auth.uid()) as liked_by_me,
       v.sound_setup
  from public.videos v
  join public.profiles p on p.id = v.user_id
 where not v.hidden
   and p.username is not null
   and not public.is_blocked_between(auth.uid(), v.user_id)
   and not public.reported_by_me(v.id);
