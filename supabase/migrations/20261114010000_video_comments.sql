alter table public.videos add column comments_enabled boolean not null default true;

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos (id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  parent_id uuid,
  body text not null check (char_length(body) between 1 and 300 and body ~ '[^[:space:]]'),
  created_at timestamptz not null default now(),
  hidden boolean not null default false,
  report_count integer not null default 0,
  unique (id, video_id),
  foreign key (parent_id, video_id) references public.comments (id, video_id) on delete cascade
);

create index comments_thread_idx on public.comments (video_id, parent_id, created_at, id) where not hidden;
create index comments_author_idx on public.comments (user_id);

create table public.comment_reports (
  comment_id uuid not null references public.comments (id) on delete cascade,
  reporter_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  reason text not null check (reason in ('harassment', 'sexual', 'violence', 'spam', 'other')),
  created_at timestamptz not null default now(),
  primary key (comment_id, reporter_id)
);

create schema comment_internal;
revoke all on schema comment_internal from public;
grant usage on schema comment_internal to anon, authenticated, service_role;

create table comment_internal.post_limits (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  window_start timestamptz not null,
  post_count integer not null
);

create table comment_internal.blocked_patterns (pattern text primary key);
insert into comment_internal.blocked_patterns values
  ('https?://|www[.]|t[.]me/|discord[.]gg/|bit[.]ly/'),
  ('\m(kill yourself|go die|kys)\M');
grant all on comment_internal.blocked_patterns to service_role;

-- Internal check for replies. Do not expose a reply if its parent was hidden,
-- reported by this viewer, or written by someone blocked in either direction.
create function comment_internal.parent_is_visible(parent uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.comments c
      where c.id = parent and c.parent_id is null and not c.hidden
        and not public.is_blocked_between(auth.uid(), c.user_id)
        and not exists (
          select 1 from public.comment_reports r where r.comment_id = c.id and r.reporter_id = auth.uid()
        )
  )
$$;

create function comment_internal.reported_by_viewer(comment uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.comment_reports where comment_id = comment and reporter_id = auth.uid())
$$;

create function comment_internal.can_read_thread(video uuid) returns boolean
language sql stable set search_path = '' as $$
  select exists (
    select 1 from public.videos v join public.profiles p on p.id = v.user_id
    where v.id = video and not v.hidden and v.comments_enabled and p.username is not null
      and not public.is_blocked_between(auth.uid(), v.user_id) and not public.reported_by_me(v.id)
  )
$$;

create function comment_internal.validate_comment() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  size integer;
begin
  new.body := regexp_replace(new.body, '^[[:space:]]+|[[:space:]]+$', '', 'g');
  if exists (select 1 from comment_internal.blocked_patterns p
              where regexp_replace(new.body, '[[:space:]]+', ' ', 'g') ~* p.pattern) then
    raise exception 'COMMENT_FILTERED' using errcode = 'P0001';
  end if;
  if new.parent_id is not null and not comment_internal.parent_is_visible(new.parent_id) then
    raise exception 'COMMENT_THREAD_UNAVAILABLE' using errcode = 'P0001';
  end if;
  insert into comment_internal.post_limits as limits values (new.user_id, now(), 1)
    on conflict (user_id) do update
    set post_count = case when limits.window_start <= now() - interval '1 minute' then 1 else limits.post_count + 1 end,
        window_start = case when limits.window_start <= now() - interval '1 minute' then now() else limits.window_start end
    returning post_count into size;
  if size > 5 then
    raise exception 'COMMENT_RATE_LIMITED' using errcode = 'P0001';
  end if;
  return new;
end
$$;

create trigger validate_new_comment before insert on public.comments
for each row execute function comment_internal.validate_comment();

create function comment_internal.count_comment_report() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.comments set report_count = report_count + 1,
    hidden = hidden or report_count + 1 >= 3 where id = new.comment_id;
  return null;
end
$$;

create trigger count_new_comment_report after insert on public.comment_reports
for each row execute function comment_internal.count_comment_report();

revoke execute on all functions in schema comment_internal from public, anon, authenticated;
grant execute on function comment_internal.parent_is_visible(uuid),
  comment_internal.reported_by_viewer(uuid), comment_internal.can_read_thread(uuid) to anon, authenticated;

alter table public.comments enable row level security;
alter table public.comment_reports enable row level security;
revoke all on public.comments, public.comment_reports from public, anon, authenticated;
grant select (id, video_id, user_id, parent_id, body, created_at, hidden) on public.comments to anon, authenticated;
grant insert (video_id, parent_id, body) on public.comments to authenticated;
grant insert (comment_id, reason) on public.comment_reports to authenticated;
grant all on public.comments, public.comment_reports to service_role;

create policy "read visible comments" on public.comments for select
using (
  not hidden and not public.is_blocked_between(auth.uid(), user_id)
  and not comment_internal.reported_by_viewer(id)
  and comment_internal.can_read_thread(video_id)
  and (parent_id is null or comment_internal.parent_is_visible(parent_id))
);

create policy "comment as self with a complete profile" on public.comments for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (select 1 from public.profiles p where p.id = auth.uid()
              and p.username is not null and p.accepted_terms_at is not null)
  and comment_internal.can_read_thread(video_id)
);

create policy "report a visible comment by someone else" on public.comment_reports for insert to authenticated
with check (
  reporter_id = auth.uid()
  and exists (select 1 from public.comments c where c.id = comment_id and c.user_id <> auth.uid())
);

create function public.delete_video_comment(target_comment uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.comments c using public.videos v
  where c.id = target_comment and v.id = c.video_id and auth.uid() in (c.user_id, v.user_id);
  if not found then raise exception 'COMMENT_NOT_FOUND' using errcode = 'P0001'; end if;
end
$$;
revoke all on function public.delete_video_comment(uuid) from public, anon;
grant execute on function public.delete_video_comment(uuid) to authenticated;

create view public.video_comments with (security_invoker = true) as
select c.id, c.video_id, c.user_id, c.parent_id, c.body, c.created_at, p.username,
       case when c.parent_id is null then (
         select count(*) from public.comments reply where reply.video_id = c.video_id and reply.parent_id = c.id and not reply.hidden
       ) else 0 end as reply_count
  from public.comments c join public.profiles p on p.id = c.user_id
 where not c.hidden;
grant select on public.video_comments to anon, authenticated;

create or replace view public.feed_videos with (security_invoker = true) as
select v.id, v.user_id, v.video_key, v.thumb_key, v.caption, v.instrument, v.mode,
       v.duration_s, v.width, v.height, v.like_count, v.report_count, v.hidden, v.created_at,
       p.username, p.display_name, p.avatar_key,
       exists (select 1 from public.likes l where l.video_id = v.id and l.user_id = auth.uid()) as liked_by_me,
       v.sound_setup, v.comments_enabled,
       (select count(*) from public.comments c where c.video_id = v.id and not c.hidden) as comment_count
  from public.videos v
  join public.profiles p on p.id = v.user_id
 where not v.hidden
   and p.username is not null
   and not public.is_blocked_between(auth.uid(), v.user_id)
   and not public.reported_by_me(v.id);
