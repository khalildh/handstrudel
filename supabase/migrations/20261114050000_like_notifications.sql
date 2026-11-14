create table public.like_activity_groups (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  video_id uuid not null references public.videos(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  read_through timestamptz,
  unique nulls not distinct (recipient_id, video_id, comment_id)
);
create index like_activity_groups_video on public.like_activity_groups (video_id);
create index like_activity_groups_comment on public.like_activity_groups (comment_id);

create table public.like_activity_members (
  group_id uuid not null references public.like_activity_groups(id) on delete cascade,
  actor_id uuid not null references public.profiles(id) on delete cascade,
  video_like_id uuid,
  comment_like_id uuid,
  created_at timestamptz not null default clock_timestamp(),
  primary key (group_id, actor_id),
  check (num_nonnulls(video_like_id, comment_like_id) = 1),
  foreign key (actor_id, video_like_id) references public.likes(user_id, video_id) on delete cascade,
  foreign key (actor_id, comment_like_id) references public.comment_likes(user_id, comment_id) on delete cascade
);
create index like_activity_members_video on public.like_activity_members (actor_id, video_like_id) where video_like_id is not null;
create index like_activity_members_comment on public.like_activity_members (actor_id, comment_like_id) where comment_like_id is not null;

alter table public.like_activity_groups enable row level security;
alter table public.like_activity_members enable row level security;
revoke all on public.like_activity_groups, public.like_activity_members from public, anon, authenticated;
grant select on public.like_activity_groups, public.like_activity_members to authenticated;
grant all on public.like_activity_groups, public.like_activity_members to service_role;

create policy "read your like groups on visible posts" on public.like_activity_groups for select to authenticated
using (recipient_id = (select auth.uid())
  and exists (select 1 from public.feed_videos v where v.id = video_id)
  and (comment_id is null or exists (select 1 from public.video_comments c where c.id = comment_id)));
create policy "read your visible like actors" on public.like_activity_members for select to authenticated
using (not public.is_blocked_between((select auth.uid()), actor_id)
  and exists (select 1 from public.like_activity_groups g where g.id = group_id));

create function comment_internal.notify_like() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  recipient uuid;
  video uuid;
  comment uuid;
  activity_group uuid;
begin
  if tg_table_name = 'likes' then
    select v.user_id, v.id into recipient, video from public.videos v
    where v.id = new.video_id and not v.hidden;
  else
    select c.user_id, c.video_id, c.id into recipient, video, comment
    from public.comments c join public.videos v on v.id = c.video_id
    where c.id = new.comment_id and not c.hidden and not v.hidden and v.comments_enabled;
  end if;
  if recipient is null or recipient = new.user_id or public.is_blocked_between(recipient, new.user_id) then
    return null;
  end if;

  insert into public.like_activity_groups as g (recipient_id, video_id, comment_id)
  values (recipient, video, comment)
  on conflict (recipient_id, video_id, comment_id) do update set recipient_id = excluded.recipient_id
  returning g.id into activity_group;

  insert into public.like_activity_members (group_id, actor_id, video_like_id, comment_like_id)
  values (activity_group, new.user_id, case when comment is null then video end, comment)
  on conflict (group_id, actor_id) do nothing;
  return null;
end
$$;
revoke all on function comment_internal.notify_like() from public, anon, authenticated;
create trigger notify_video_like after insert on public.likes
for each row execute function comment_internal.notify_like();
create trigger notify_comment_like after insert on public.comment_likes
for each row execute function comment_internal.notify_like();

-- Keep the original view unchanged for clients that only decode comment and reply kinds.
create view public.activity_inbox_v2 with (security_invoker = true) as
select a.id, a.video_id, a.comment_id, a.kind, a.created_at, a.read_at, a.username, a.body,
       null::bigint as like_count
from public.activity_inbox a
union all
select g.id, g.video_id, g.comment_id,
       case when g.comment_id is null then 'video_like'
            when c.parent_id is null then 'comment_like' else 'reply_like' end,
       latest.created_at, case when g.read_through >= latest.created_at then g.read_through end,
       latest.username, coalesce(c.body, v.caption), latest.like_count
from public.like_activity_groups g
join public.feed_videos v on v.id = g.video_id
left join public.video_comments c on c.id = g.comment_id
cross join lateral (
  select m.created_at, p.username, count(*) over () as like_count
  from public.like_activity_members m join public.profiles p on p.id = m.actor_id
  where m.group_id = g.id and p.username is not null
  order by m.created_at desc, m.actor_id desc
  limit 1
) latest
where g.comment_id is null or c.id is not null;
revoke all on public.activity_inbox_v2 from public, anon, authenticated;
grant select on public.activity_inbox_v2 to authenticated;

create function public.mark_like_activity_read(target_item uuid, seen_at timestamptz) returns void
language sql security definer set search_path = '' as $$
  update public.like_activity_groups
  set read_through = greatest(read_through, least(seen_at, clock_timestamp()))
  where recipient_id = (select auth.uid()) and id = target_item and seen_at is not null
$$;
revoke all on function public.mark_like_activity_read(uuid, timestamptz) from public, anon;
grant execute on function public.mark_like_activity_read(uuid, timestamptz) to authenticated;
