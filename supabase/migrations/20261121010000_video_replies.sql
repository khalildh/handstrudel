-- "Reply with a take": a reply is a normal post that names the post it answers.
-- Unlike a play-along (`source_video_id`), a reply needs no backing permission: it reuses
-- the original's playable preset, not its audio, so the two links stay separate.
alter table public.videos add column reply_to_id uuid references public.videos(id) on delete set null;
create index videos_reply_to on public.videos (reply_to_id, created_at desc, id desc) where reply_to_id is not null;

-- Whether `parent` can currently be shown as the post `replier` answered: visible, from a
-- finished profile, not blocked either way and not reported by the replier.
create function public.reply_target_available(parent uuid, replier uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.videos v join public.profiles p on p.id = v.user_id
    where v.id = parent and not v.hidden and p.username is not null
      and not public.is_blocked_between(replier, v.user_id)
      and not exists (select 1 from public.reports r where r.video_id = v.id and r.reporter_id = replier)
  )
$$;
revoke all on function public.reply_target_available(uuid, uuid) from public, anon, authenticated;
grant execute on function public.reply_target_available(uuid, uuid) to service_role;

-- Screened posts are published by the service, so the owner, not auth.uid(), decides.
-- A take is still worth posting if its target went away while it was being checked,
-- so an unavailable target drops the link instead of failing the whole post.
create function public.validate_video_reply() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.reply_to_id is not null and (
    new.reply_to_id = new.id or not public.reply_target_available(new.reply_to_id, new.user_id)
  ) then
    new.reply_to_id := null;
  end if;
  return new;
end
$$;
create trigger validate_video_reply before insert on public.videos
for each row execute function public.validate_video_reply();
-- Clients never write videos directly (publish_screened_video does), and the column-level
-- update grant from creator_tools does not include reply_to_id, so the link is write-once.

-- Push notifications hook here: `after insert on public.videos ... when (new.reply_to_id is not null)`
-- fires once per published reply, after this trigger has dropped unavailable targets.
-- The recipient is the parent's owner: (select user_id from public.videos where id = new.reply_to_id).

create or replace function public.publish_screened_video(upload_id uuid, fields jsonb, checked_attempt integer default 0)
returns void language plpgsql set search_path = '' as $$
declare owner_id uuid;
begin
  update public.pending_video_uploads set status = 'published', post_fields = null, retry_at = null
    where id = upload_id and status = 'checking' and attempt = checked_attempt returning user_id into owner_id;
  if not found then raise exception 'UPLOAD_NOT_CHECKING'; end if;

  insert into public.videos (id, user_id, video_key, thumb_key, caption, instrument, mode,
      duration_s, width, height, sound_setup, note_track, comments_enabled, backing_enabled, source_video_id,
      reply_to_id)
    values (upload_id, owner_id, 'videos/' || owner_id || '/screened/' || upload_id || '.mp4',
      'thumbs/' || owner_id || '/screened/' || upload_id || '.jpg', coalesce(fields->>'caption', ''),
      fields->>'instrument', fields->>'mode', (fields->>'duration_s')::real,
      (fields->>'width')::int, (fields->>'height')::int, nullif(fields->'sound_setup', 'null'::jsonb),
      -- Notes only make sense with the preset that tells Learn mode which key and scale to use.
      case when nullif(fields->'sound_setup', 'null'::jsonb) is null then null
           else nullif(fields->'note_track', 'null'::jsonb) end,
      coalesce((fields->>'comments_enabled')::boolean, true),
      coalesce((fields->>'backing_enabled')::boolean, false), (fields->>'source_video_id')::uuid,
      (fields->>'reply_to_id')::uuid);
end;
$$;
revoke execute on function public.publish_screened_video(uuid, jsonb, integer) from public, anon, authenticated;
grant execute on function public.publish_screened_video(uuid, jsonb, integer) to service_role;

-- Feeds label replies and count visible replies. A link is shown only while both sides are
-- visible to the viewer and the two creators haven't blocked each other since.
create or replace view public.feed_videos with (security_invoker = true) as
select v.id, v.user_id, v.video_key, v.thumb_key, v.caption, v.instrument, v.mode,
       v.duration_s, v.width, v.height, v.like_count, v.report_count, v.hidden, v.created_at,
       p.username, p.display_name, p.avatar_key,
       exists (select 1 from public.likes l where l.video_id = v.id and l.user_id = auth.uid()) as liked_by_me,
       v.sound_setup, v.comments_enabled,
       (select count(*) from public.comments c where c.video_id = v.id and not c.hidden) as comment_count,
       v.backing_enabled, source.id as source_video_id, author.username as source_username, v.view_count,
       (v.note_track is not null and v.sound_setup is not null) as has_note_track,
       parent.id as reply_to_id, parent_author.username as reply_to_username,
       (select count(*) from public.videos r join public.profiles rp on rp.id = r.user_id
         where r.reply_to_id = v.id and not r.hidden and rp.username is not null
           and not public.is_blocked_between(auth.uid(), r.user_id) and not public.reported_by_me(r.id)
           and not public.is_blocked_between(r.user_id, v.user_id)) as reply_count
  from public.videos v
  join public.profiles p on p.id = v.user_id
  left join public.videos source on source.id = v.source_video_id and not source.hidden
    and not public.is_blocked_between(auth.uid(), source.user_id) and not public.reported_by_me(source.id)
  left join public.profiles author on author.id = source.user_id
  left join public.videos parent on parent.id = v.reply_to_id and not parent.hidden
    and not public.is_blocked_between(auth.uid(), parent.user_id) and not public.reported_by_me(parent.id)
    and not public.is_blocked_between(parent.user_id, v.user_id)
    and exists (select 1 from public.profiles pp where pp.id = parent.user_id and pp.username is not null)
  left join public.profiles parent_author on parent_author.id = parent.user_id
 where not v.hidden and p.username is not null
   and not public.is_blocked_between(auth.uid(), v.user_id) and not public.reported_by_me(v.id);

-- Views that expand `feed_videos.*` keep the columns they were created with; rebuild the
-- Following feeds so replies are labelled there too.
create or replace view public.following_videos with (security_invoker = true) as
select v.* from public.feed_videos v
where exists (select 1 from public.follows f where f.follower_id = (select auth.uid()) and f.followee_id = v.user_id);
revoke all on public.following_videos from public, anon, authenticated;
grant select on public.following_videos to authenticated;

drop view public.following_activity_videos;
create view public.following_activity_videos with (security_invoker = true) as
select v.*, a.activity_at, a.reposted_by_id, a.reposted_by
from public.following_video_activity() a join public.feed_videos v on v.id = a.video_id;
revoke all on public.following_activity_videos from public, anon, authenticated;
grant select on public.following_activity_videos to authenticated;

drop view public.my_reposted_videos;
create view public.my_reposted_videos with (security_invoker = true) as
select v.*, a.activity_at
from public.my_video_repost_activity() a join public.feed_videos v on v.id = a.video_id;
revoke all on public.my_reposted_videos from public, anon, authenticated;
grant select on public.my_reposted_videos to authenticated;
