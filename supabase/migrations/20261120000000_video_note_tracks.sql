-- "Learn to play": the notes a creator played, timed to the posted clip, so viewers can
-- practise the same part in Learn mode. Shared only together with the playable preset.
alter table public.videos add column note_track jsonb
  check (note_track is null or (
    jsonb_typeof(note_track) = 'object'
    and note_track->>'v' = '1'
    and jsonb_typeof(note_track->'notes') = 'array'
    and jsonb_array_length(note_track->'notes') between 1 and 600
    and octet_length(note_track::text) <= 32768
  ));

-- Only the screened publish path writes it; clients still have no insert or update on videos.
create or replace function public.publish_screened_video(upload_id uuid, fields jsonb, checked_attempt integer default 0)
returns void language plpgsql set search_path = '' as $$
declare owner_id uuid;
begin
  update public.pending_video_uploads set status = 'published', post_fields = null, retry_at = null
    where id = upload_id and status = 'checking' and attempt = checked_attempt returning user_id into owner_id;
  if not found then raise exception 'UPLOAD_NOT_CHECKING'; end if;

  insert into public.videos (id, user_id, video_key, thumb_key, caption, instrument, mode,
      duration_s, width, height, sound_setup, note_track, comments_enabled, backing_enabled, source_video_id)
    values (upload_id, owner_id, 'videos/' || owner_id || '/screened/' || upload_id || '.mp4',
      'thumbs/' || owner_id || '/screened/' || upload_id || '.jpg', coalesce(fields->>'caption', ''),
      fields->>'instrument', fields->>'mode', (fields->>'duration_s')::real,
      (fields->>'width')::int, (fields->>'height')::int, nullif(fields->'sound_setup', 'null'::jsonb),
      -- Notes only make sense with the preset that tells Learn mode which key and scale to use.
      case when nullif(fields->'sound_setup', 'null'::jsonb) is null then null
           else nullif(fields->'note_track', 'null'::jsonb) end,
      coalesce((fields->>'comments_enabled')::boolean, true),
      coalesce((fields->>'backing_enabled')::boolean, false), (fields->>'source_video_id')::uuid);
end;
$$;
revoke execute on function public.publish_screened_video(uuid, jsonb, integer) from public, anon, authenticated;
grant execute on function public.publish_screened_video(uuid, jsonb, integer) to service_role;

-- Feeds carry a flag; the track itself is read only when a viewer opens "Learn to play".
create or replace view public.feed_videos with (security_invoker = true) as
select v.id, v.user_id, v.video_key, v.thumb_key, v.caption, v.instrument, v.mode,
       v.duration_s, v.width, v.height, v.like_count, v.report_count, v.hidden, v.created_at,
       p.username, p.display_name, p.avatar_key,
       exists (select 1 from public.likes l where l.video_id = v.id and l.user_id = auth.uid()) as liked_by_me,
       v.sound_setup, v.comments_enabled,
       (select count(*) from public.comments c where c.video_id = v.id and not c.hidden) as comment_count,
       v.backing_enabled, source.id as source_video_id, author.username as source_username, v.view_count,
       (v.note_track is not null and v.sound_setup is not null) as has_note_track
  from public.videos v
  join public.profiles p on p.id = v.user_id
  left join public.videos source on source.id = v.source_video_id and not source.hidden
    and not public.is_blocked_between(auth.uid(), source.user_id) and not public.reported_by_me(source.id)
  left join public.profiles author on author.id = source.user_id
 where not v.hidden and p.username is not null
   and not public.is_blocked_between(auth.uid(), v.user_id) and not public.reported_by_me(v.id);

create or replace view public.following_videos with (security_invoker = true) as
select v.* from public.feed_videos v
where exists (select 1 from public.follows f where f.follower_id = (select auth.uid()) and f.followee_id = v.user_id);

create or replace view public.saved_videos with (security_invoker = true) as
select v.id, v.user_id, v.video_key, v.thumb_key, v.caption, v.instrument, v.mode, v.duration_s, v.width, v.height,
       v.like_count, v.report_count, v.hidden, v.created_at, v.username, v.display_name, v.avatar_key, v.liked_by_me,
       v.sound_setup, v.comments_enabled, v.comment_count, v.backing_enabled, v.source_video_id, v.source_username,
       b.saved_at, v.view_count, v.has_note_track
from public.video_bookmarks b
join public.feed_videos v on v.id = b.video_id
where b.user_id = (select auth.uid());

create or replace view public.weekly_challenge_entries with (security_invoker = true) as
select v.id, v.user_id, v.video_key, v.thumb_key, v.caption, v.instrument, v.mode, v.duration_s, v.width, v.height,
       v.like_count, v.report_count, v.hidden, v.created_at, v.username, v.display_name, v.avatar_key, v.liked_by_me,
       v.sound_setup, v.comments_enabled, v.comment_count, v.backing_enabled, v.source_video_id, v.source_username,
       w.id as challenge_id, v.view_count, v.has_note_track
from public.weekly_challenges w
join public.feed_videos v on v.source_video_id = w.source_video_id
where v.created_at >= w.starts_at and v.created_at < w.ends_at;
