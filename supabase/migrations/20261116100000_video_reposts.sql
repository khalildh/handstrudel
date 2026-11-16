create table public.video_reposts (
  user_id uuid not null references public.profiles(id) on delete cascade,
  video_id uuid not null references public.videos(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, video_id)
);
create index video_reposts_video_idx on public.video_reposts(video_id);
alter table public.video_reposts enable row level security;
revoke all on public.video_reposts from public, anon, authenticated;

create function public.video_engagement_v2(target_video uuid)
returns table (saves bigint, shares bigint, remixes bigint, reposts bigint, reposted_by_me boolean)
language sql stable security definer set search_path = '' as $$
  select stats.saves, stats.shares, stats.remixes,
         (select count(*) from public.video_reposts r where r.video_id = target_video),
         exists (select 1 from public.video_reposts r where r.video_id = target_video and r.user_id = (select auth.uid()))
  from public.video_engagement(target_video) stats;
$$;

create function public.set_video_repost(target_video uuid, repost boolean)
returns table (saves bigint, shares bigint, remixes bigint, reposts bigint, reposted_by_me boolean)
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if actor is null or repost is null then
    raise exception 'REPOST_NOT_AVAILABLE' using errcode = '42501';
  end if;
  if repost then
    perform 1 from public.videos v where v.id = target_video and not v.hidden and v.user_id <> actor
      and exists (select 1 from public.profiles p where p.id = actor and p.username is not null)
      and exists (select 1 from public.feed_videos f where f.id = v.id)
    for share;
    if not found then
      raise exception 'REPOST_NOT_AVAILABLE' using errcode = '42501';
    end if;
    insert into public.video_reposts (user_id, video_id) values (actor, target_video) on conflict do nothing;
  else
    delete from public.video_reposts r where r.user_id = actor and r.video_id = target_video;
  end if;
  return query select * from public.video_engagement_v2(target_video);
end;
$$;

-- Return only activity metadata here. The invoker view below reads the clip
-- itself with the viewer's normal RLS, including its comment count.
create function public.following_video_activity()
returns table (video_id uuid, activity_at timestamptz, reposted_by_id uuid, reposted_by text)
language sql stable security definer set search_path = '' as $$
  with followed as (
    select p.id, p.username from public.follows f
    join public.profiles p on p.id = f.followee_id
    where f.follower_id = (select auth.uid()) and p.username is not null
      and not public.is_blocked_between((select auth.uid()), p.id)
  ), activity as (
    select v.id as clip_id, v.created_at as happened_at, null::uuid as actor, null::text as handle
    from followed f join public.videos v on v.user_id = f.id
    union all
    select r.video_id, r.created_at, f.id, f.username
    from followed f join public.video_reposts r on r.user_id = f.id
  )
  select distinct on (a.clip_id) a.clip_id, a.happened_at, a.actor, a.handle
  from activity a
  join public.feed_videos v on v.id = a.clip_id
  order by a.clip_id, a.happened_at desc, a.actor desc nulls last;
$$;

create view public.following_activity_videos with (security_invoker = true) as
select v.*, a.activity_at, a.reposted_by_id, a.reposted_by
from public.following_video_activity() a join public.feed_videos v on v.id = a.video_id;

revoke all on function public.video_engagement_v2(uuid), public.set_video_repost(uuid, boolean),
  public.following_video_activity() from public, anon, authenticated;
grant execute on function public.video_engagement_v2(uuid) to anon, authenticated;
grant execute on function public.set_video_repost(uuid, boolean), public.following_video_activity() to authenticated;
revoke all on public.following_activity_videos from public, anon, authenticated;
grant select on public.following_activity_videos to authenticated;
