create table public.creator_activity (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid not null references public.profiles(id) on delete cascade,
  video_id uuid not null references public.videos(id) on delete cascade,
  comment_id uuid not null references public.comments(id) on delete cascade,
  kind text not null check (kind in ('comment', 'reply')),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  unique (recipient_id, comment_id)
);
create index creator_activity_inbox on public.creator_activity (recipient_id, created_at desc, id desc);
create index creator_activity_comment on public.creator_activity (comment_id);
alter table public.creator_activity enable row level security;
revoke all on public.creator_activity from public, anon, authenticated;
grant select on public.creator_activity to authenticated;
grant all on public.creator_activity to service_role;
create policy "read your visible activity" on public.creator_activity for select to authenticated
using (recipient_id = (select auth.uid()) and exists (
  select 1 from public.comments c where c.id = comment_id
));

create function comment_internal.notify_comment() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.creator_activity (recipient_id, actor_id, video_id, comment_id, kind)
  select recipients.recipient, new.user_id, new.video_id, new.id, recipients.kind
  from (
    select v.user_id as recipient, 'comment' as kind from public.videos v where v.id = new.video_id
    union all
    select c.user_id, 'reply' from public.comments c where c.id = new.parent_id
  ) recipients
  where recipients.recipient <> new.user_id
    and not public.is_blocked_between(recipients.recipient, new.user_id)
  order by recipients.kind desc
  on conflict (recipient_id, comment_id) do nothing;
  return null;
end
$$;
revoke all on function comment_internal.notify_comment() from public, anon, authenticated;
create trigger notify_comment after insert on public.comments
for each row execute function comment_internal.notify_comment();

create function public.mark_creator_activity_read(target_item uuid) returns void
language sql security definer set search_path = '' as $$
  update public.creator_activity set read_at = now()
  where recipient_id = (select auth.uid()) and id = target_item and read_at is null
$$;
revoke all on function public.mark_creator_activity_read(uuid) from public, anon;
grant execute on function public.mark_creator_activity_read(uuid) to authenticated;

create view public.activity_inbox with (security_invoker = true) as
select a.id, a.video_id, a.comment_id, a.kind, a.created_at, a.read_at, p.username, c.body
from public.creator_activity a
join public.profiles p on p.id = a.actor_id
join public.comments c on c.id = a.comment_id;
grant select on public.activity_inbox to authenticated;

alter table public.videos add column backing_enabled boolean not null default false;
alter table public.videos add column source_video_id uuid references public.videos(id) on delete set null;
create index videos_source_id on public.videos (source_video_id) where source_video_id is not null;

create function public.validate_backing_permission() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' and new.source_video_id is not null then
    if not exists (
      select 1 from public.videos v
      where v.id = new.source_video_id and not v.hidden and v.backing_enabled
        and not public.is_blocked_between(auth.uid(), v.user_id) and not public.reported_by_me(v.id)
    ) then
      raise exception 'BACKING_UNAVAILABLE' using errcode = 'P0001';
    end if;
  end if;
  if new.source_video_id is not null and new.backing_enabled then
    raise exception 'BACKING_REMIX_NOT_REUSABLE' using errcode = 'P0001';
  end if;
  return new;
end
$$;
create trigger validate_backing_permission before insert or update of backing_enabled on public.videos
for each row execute function public.validate_backing_permission();

-- Attribution is assigned at publication and can only be cleared by the source's FK.
revoke update on public.videos from authenticated;
grant update (caption, instrument, mode, duration_s, width, height, sound_setup, comments_enabled, backing_enabled)
on public.videos to authenticated;

create or replace view public.feed_videos with (security_invoker = true) as
select v.id, v.user_id, v.video_key, v.thumb_key, v.caption, v.instrument, v.mode,
       v.duration_s, v.width, v.height, v.like_count, v.report_count, v.hidden, v.created_at,
       p.username, p.display_name, p.avatar_key,
       exists (select 1 from public.likes l where l.video_id = v.id and l.user_id = auth.uid()) as liked_by_me,
       v.sound_setup, v.comments_enabled,
       (select count(*) from public.comments c where c.video_id = v.id and not c.hidden) as comment_count,
       v.backing_enabled, source.id as source_video_id, author.username as source_username
  from public.videos v
  join public.profiles p on p.id = v.user_id
  left join public.videos source on source.id = v.source_video_id and not source.hidden
    and not public.is_blocked_between(auth.uid(), source.user_id) and not public.reported_by_me(source.id)
  left join public.profiles author on author.id = source.user_id
 where not v.hidden and p.username is not null
   and not public.is_blocked_between(auth.uid(), v.user_id) and not public.reported_by_me(v.id);

create view public.following_videos with (security_invoker = true) as
select v.* from public.feed_videos v
where exists (select 1 from public.follows f where f.follower_id = (select auth.uid()) and f.followee_id = v.user_id);
revoke all on public.following_videos from public, anon, authenticated;
grant select on public.following_videos to authenticated;

create view public.public_creators with (security_invoker = true) as
select p.id, p.username, p.display_name from public.profiles p
where p.username is not null and not public.is_blocked_between(auth.uid(), p.id);
grant select on public.public_creators to anon, authenticated;
