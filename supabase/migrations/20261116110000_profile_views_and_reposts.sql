create or replace view public.public_creators with (security_invoker = true) as
select p.id, p.username, p.display_name, p.avatar_key, totals.likes_received, totals.views_received
from public.profiles p
cross join lateral (
  select coalesce(sum(v.like_count), 0) as likes_received,
         coalesce(sum(v.view_count), 0)::bigint as views_received
  from public.videos v
  where v.user_id = p.id and not v.hidden
) totals
where p.username is not null and not public.is_blocked_between(auth.uid(), p.id);

-- Keep the underlying repost relationships private. Return only the caller's
-- visible clips, then load their full metadata with the normal feed RLS.
create function public.my_video_repost_activity()
returns table (video_id uuid, activity_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select r.video_id, r.created_at
  from public.video_reposts r
  where r.user_id = (select auth.uid())
    and exists (select 1 from public.feed_videos v where v.id = r.video_id);
$$;

create view public.my_reposted_videos with (security_invoker = true) as
select v.*, a.activity_at
from public.my_video_repost_activity() a join public.feed_videos v on v.id = a.video_id;

revoke all on function public.my_video_repost_activity() from public, anon, authenticated;
grant execute on function public.my_video_repost_activity() to authenticated;
revoke all on public.my_reposted_videos from public, anon, authenticated;
grant select on public.my_reposted_videos to authenticated;
