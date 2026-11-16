create table public.video_share_totals (
  video_id uuid primary key references public.videos(id) on delete cascade,
  shares bigint not null check (shares > 0)
);
alter table public.video_share_totals enable row level security;
revoke all on public.video_share_totals from public, anon, authenticated;

create function public.video_engagement(target_video uuid)
returns table (saves bigint, shares bigint, remixes bigint)
language sql stable security definer set search_path = ''
as $$
  select
    (select count(*) from public.video_bookmarks b where b.video_id = v.id),
    coalesce((select t.shares from public.video_share_totals t where t.video_id = v.id), 0),
    (select count(*) from public.feed_videos remix where remix.source_video_id = v.id)
  from public.feed_videos v
  where v.id = target_video;
$$;

create function public.record_video_share(target_video uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  -- Lock against concurrent takedowns without blocking normal public reads.
  perform 1 from public.videos v
    where v.id = target_video and not v.hidden
      and exists (select 1 from public.feed_videos f where f.id = v.id)
    for share;
  if not found then return; end if;

  insert into public.video_share_totals as total (video_id, shares) values (target_video, 1)
  on conflict (video_id) do update set shares = total.shares + 1;
end;
$$;

revoke all on function public.video_engagement(uuid), public.record_video_share(uuid) from public;
grant execute on function public.video_engagement(uuid), public.record_video_share(uuid) to anon, authenticated;
