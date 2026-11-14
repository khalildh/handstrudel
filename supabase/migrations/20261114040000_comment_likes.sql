alter table public.comments add column like_count bigint not null default 0 check (like_count >= 0);
grant select (like_count) on public.comments to anon, authenticated;

create table public.comment_likes (
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  comment_id uuid not null references public.comments(id) on delete cascade,
  primary key (user_id, comment_id)
);
create index comment_likes_comment on public.comment_likes (comment_id);
alter table public.comment_likes enable row level security;
revoke all on public.comment_likes from public, anon, authenticated;
grant select, delete on public.comment_likes to authenticated;
grant insert (comment_id) on public.comment_likes to authenticated;
grant all on public.comment_likes to service_role;

create policy "see own comment likes" on public.comment_likes for select to authenticated
using (user_id = (select auth.uid()));
create policy "like visible comments as self" on public.comment_likes for insert to authenticated
with check (user_id = (select auth.uid()) and exists (
  select 1 from public.comments c where c.id = comment_id
));
create policy "remove own comment likes" on public.comment_likes for delete to authenticated
using (user_id = (select auth.uid()));

create function comment_internal.update_like_count() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    update public.comments set like_count = like_count + 1 where id = new.comment_id;
  else
    update public.comments set like_count = like_count - 1 where id = old.comment_id;
  end if;
  return null;
end
$$;
revoke all on function comment_internal.update_like_count() from public, anon, authenticated;
create trigger count_comment_like after insert or delete on public.comment_likes
for each row execute function comment_internal.update_like_count();

create function comment_internal.liked_comment(target_comment uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.comment_likes l
    where l.user_id = (select auth.uid()) and l.comment_id = target_comment
  )
$$;
revoke all on function comment_internal.liked_comment(uuid) from public, anon, authenticated;
grant execute on function comment_internal.liked_comment(uuid) to anon, authenticated;

-- Keep the original view columns and existing comment visibility rules.
create or replace view public.video_comments with (security_invoker = true) as
select c.id, c.video_id, c.user_id, c.parent_id, c.body, c.created_at, p.username,
       case when c.parent_id is null then (
         select count(*) from public.comments reply where reply.video_id = c.video_id and reply.parent_id = c.id and not reply.hidden
       ) else 0 end as reply_count,
       c.like_count,
       comment_internal.liked_comment(c.id) as liked_by_me
  from public.comments c join public.profiles p on p.id = c.user_id
 where not c.hidden;
