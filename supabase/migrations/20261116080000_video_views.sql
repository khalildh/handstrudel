alter table public.videos add column view_count bigint not null default 0 check (view_count >= 0);

create table public.video_view_receipts (
  video_id uuid not null references public.videos(id) on delete cascade,
  viewed_on date not null,
  receipt uuid not null,
  primary key (video_id, viewed_on, receipt)
);
alter table public.video_view_receipts enable row level security;
revoke all on public.video_view_receipts from public, anon, authenticated;

create or replace view public.feed_videos with (security_invoker = true) as
select v.id, v.user_id, v.video_key, v.thumb_key, v.caption, v.instrument, v.mode,
       v.duration_s, v.width, v.height, v.like_count, v.report_count, v.hidden, v.created_at,
       p.username, p.display_name, p.avatar_key,
       exists (select 1 from public.likes l where l.video_id = v.id and l.user_id = auth.uid()) as liked_by_me,
       v.sound_setup, v.comments_enabled,
       (select count(*) from public.comments c where c.video_id = v.id and not c.hidden) as comment_count,
       v.backing_enabled, source.id as source_video_id, author.username as source_username, v.view_count
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
       b.saved_at, v.view_count
from public.video_bookmarks b
join public.feed_videos v on v.id = b.video_id
where b.user_id = (select auth.uid());

create or replace view public.weekly_challenge_entries with (security_invoker = true) as
select v.id, v.user_id, v.video_key, v.thumb_key, v.caption, v.instrument, v.mode, v.duration_s, v.width, v.height,
       v.like_count, v.report_count, v.hidden, v.created_at, v.username, v.display_name, v.avatar_key, v.liked_by_me,
       v.sound_setup, v.comments_enabled, v.comment_count, v.backing_enabled, v.source_video_id, v.source_username,
       w.id as challenge_id, v.view_count
from public.weekly_challenges w
join public.feed_videos v on v.source_video_id = w.source_video_id
where v.created_at >= w.starts_at and v.created_at < w.ends_at;

create function public.record_video_view(target_video uuid, watch_receipt uuid)
returns bigint
language plpgsql security definer set search_path = ''
as $$
declare
  current_day date := (now() at time zone 'UTC')::date;
  total bigint;
begin
  if watch_receipt is null then return null; end if;

  -- Serialize on the post so a hide/delete and a duplicate receipt cannot race the increment.
  select v.view_count into total from public.videos v
  where v.id = target_video and not v.hidden
    and exists (select 1 from public.feed_videos f where f.id = v.id)
  for update;
  if not found then return null; end if;

  insert into public.video_view_receipts (video_id, viewed_on, receipt)
    values (target_video, current_day, watch_receipt) on conflict do nothing;
  if found then
    update public.videos set view_count = view_count + 1
      where id = target_video returning view_count into total;
    -- Keep today's deduplication receipts; they carry no user or device identifier.
    delete from public.video_view_receipts where video_id = target_video and viewed_on < current_day;
  end if;
  return total;
end;
$$;

revoke all on function public.record_video_view(uuid, uuid) from public;
grant execute on function public.record_video_view(uuid, uuid) to anon, authenticated;
