-- HandStrudel accounts + public video feed.
-- Video/thumbnail files live in Cloudflare R2; these tables store their object keys.

create extension if not exists citext;

-- ---------------------------------------------------------------- profiles
create table public.profiles (
  id                uuid primary key references auth.users (id) on delete cascade,
  username          citext unique check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name      text check (char_length(display_name) <= 40),
  avatar_key        text,
  accepted_terms_at timestamptz,
  created_at        timestamptz not null default now()
);

-- One profile row per auth user, created at sign-up (username is chosen later).
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ------------------------------------------------------------------ videos
create table public.videos (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles (id) on delete cascade,
  video_key    text not null,
  thumb_key    text not null,
  caption      text not null default '' check (char_length(caption) <= 150),
  instrument   text,
  mode         text,
  duration_s   real check (duration_s > 0 and duration_s <= 60),
  width        int,
  height       int,
  like_count   int not null default 0,
  report_count int not null default 0,
  hidden       boolean not null default false,
  created_at   timestamptz not null default now(),
  -- object keys must sit under the uploader's own folder
  check (video_key like 'videos/' || user_id::text || '/%'),
  check (thumb_key like 'thumbs/' || user_id::text || '/%')
);

create index videos_feed_idx on public.videos (created_at desc, id desc) where not hidden;
create index videos_user_idx on public.videos (user_id, created_at desc);

-- ---------------------------------------------------- likes / follows / ...
create table public.likes (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  video_id   uuid not null references public.videos (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, video_id)
);

create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  followee_id uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

create table public.reports (
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  video_id    uuid not null references public.videos (id) on delete cascade,
  reason      text not null check (char_length(reason) between 1 and 200),
  created_at  timestamptz not null default now(),
  primary key (reporter_id, video_id)
);

create table public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- --------------------------------------------------------------- counters
create function public.bump_like_count() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    update public.videos set like_count = like_count + 1 where id = new.video_id;
  else
    update public.videos set like_count = greatest(like_count - 1, 0) where id = old.video_id;
  end if;
  return null;
end $$;

create trigger likes_count after insert or delete on public.likes
  for each row execute function public.bump_like_count();

-- First-line moderation: 3 distinct reports hide a video until reviewed.
create function public.bump_report_count() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.videos
     set report_count = report_count + 1,
         hidden = hidden or report_count + 1 >= 3
   where id = new.video_id;
  return null;
end $$;

create trigger reports_count after insert on public.reports
  for each row execute function public.bump_report_count();

-- Clients may only write the descriptive columns of their own videos;
-- counters and moderation state are owned by the triggers above.
create function public.protect_video_columns() returns trigger
language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon') then
    new.like_count   := old.like_count;
    new.report_count := old.report_count;
    new.hidden       := old.hidden;
    new.user_id      := old.user_id;
    new.video_key    := old.video_key;
    new.thumb_key    := old.thumb_key;
  end if;
  return new;
end $$;

create trigger videos_protect before update on public.videos
  for each row execute function public.protect_video_columns();

create function public.reset_video_counters() returns trigger
language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon') then
    new.like_count := 0; new.report_count := 0; new.hidden := false;
  end if;
  return new;
end $$;

create trigger videos_insert_defaults before insert on public.videos
  for each row execute function public.reset_video_counters();

-- ----------------------------------------------------------- privileges
-- Explicit privileges, independent of the project's "auto-expose new tables"
-- setting: start from nothing, then grant exactly what the app needs.
-- RLS below then narrows each grant to the caller's own rows.
revoke all on public.profiles, public.videos, public.likes, public.follows,
              public.reports, public.blocks from anon, authenticated;
grant select on public.profiles, public.videos, public.likes, public.follows to anon, authenticated;
grant update (username, display_name, avatar_key, accepted_terms_at) on public.profiles to authenticated;
grant insert, update, delete on public.videos to authenticated;
grant insert, delete on public.likes, public.follows to authenticated;
grant select, insert, delete on public.blocks to authenticated;
grant insert on public.reports to authenticated;
-- Edge Functions (service role) manage everything; RLS doesn't apply to them.
grant all on public.profiles, public.videos, public.likes, public.follows,
             public.reports, public.blocks to service_role;

-- -------------------------------------------------------------------- RLS
alter table public.profiles enable row level security;
alter table public.videos   enable row level security;
alter table public.likes    enable row level security;
alter table public.follows  enable row level security;
alter table public.reports  enable row level security;
alter table public.blocks   enable row level security;

create policy "profiles are public" on public.profiles for select using (true);
create policy "edit own profile"    on public.profiles for update
  using (auth.uid() = id) with check (auth.uid() = id);

create policy "visible videos are public" on public.videos for select
  using (not hidden or auth.uid() = user_id);
create policy "post own videos"   on public.videos for insert with check (auth.uid() = user_id);
create policy "edit own videos"   on public.videos for update using (auth.uid() = user_id);
create policy "delete own videos" on public.videos for delete using (auth.uid() = user_id);

create policy "likes are public" on public.likes for select using (true);
create policy "like as self"     on public.likes for insert with check (auth.uid() = user_id);
create policy "unlike as self"   on public.likes for delete using (auth.uid() = user_id);

create policy "follows are public" on public.follows for select using (true);
create policy "follow as self"     on public.follows for insert with check (auth.uid() = follower_id);
create policy "unfollow as self"   on public.follows for delete using (auth.uid() = follower_id);

-- Reports are write-only for clients (readable by the dashboard/service role).
create policy "report as self" on public.reports for insert with check (auth.uid() = reporter_id);

create policy "see own blocks" on public.blocks for select using (auth.uid() = blocker_id);
create policy "block as self"  on public.blocks for insert with check (auth.uid() = blocker_id);
create policy "unblock"        on public.blocks for delete using (auth.uid() = blocker_id);

-- Blocks are private (RLS shows only your own), so the "they blocked me"
-- direction is checked through this definer function.
create function public.is_blocked_between(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select a is not null and exists (
    select 1 from public.blocks
     where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a))
$$;

-- Posts you reported never come back to your own feed (reports are write-only,
-- so this reads them through a definer function).
create function public.reported_by_me(video uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.reports where video_id = video and reporter_id = auth.uid())
$$;

-- ------------------------------------------------------------- feed view
-- Newest-first public feed without hidden videos or anyone the caller blocked
-- (in either direction). Page with: created_at < cursor (keyset, no OFFSET).
create view public.feed_videos with (security_invoker = true) as
select v.*, p.username, p.display_name, p.avatar_key,
       exists (select 1 from public.likes l where l.video_id = v.id and l.user_id = auth.uid()) as liked_by_me
  from public.videos v
  join public.profiles p on p.id = v.user_id
 where not v.hidden
   and p.username is not null
   and not public.is_blocked_between(auth.uid(), v.user_id)
   and not public.reported_by_me(v.id);

grant select on public.feed_videos to anon, authenticated;

grant execute on function public.is_blocked_between(uuid, uuid) to anon, authenticated;
grant execute on function public.reported_by_me(uuid) to anon, authenticated;

-- Upload rate limit helper used by the sign-upload Edge Function (service role only).
create function public.uploads_today(uid uuid) returns int
language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.videos
   where user_id = uid and created_at > now() - interval '24 hours'
$$;
revoke execute on function public.uploads_today(uuid) from public, anon, authenticated;
grant execute on function public.uploads_today(uuid) to service_role;
