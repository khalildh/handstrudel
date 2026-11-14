create table public.video_bookmarks (
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  video_id uuid not null references public.videos(id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, video_id)
);
create index video_bookmarks_library on public.video_bookmarks (user_id, saved_at desc, video_id desc);
create index video_bookmarks_video on public.video_bookmarks (video_id);
alter table public.video_bookmarks enable row level security;
revoke all on public.video_bookmarks from public, anon, authenticated;
grant select, delete on public.video_bookmarks to authenticated;
grant insert (video_id) on public.video_bookmarks to authenticated;
grant all on public.video_bookmarks to service_role;

create policy "read own video bookmarks" on public.video_bookmarks for select to authenticated
using (user_id = (select auth.uid()));
create policy "save visible videos as self" on public.video_bookmarks for insert to authenticated
with check (user_id = (select auth.uid()) and exists (
  select 1 from public.feed_videos v where v.id = video_id
));
create policy "remove own video bookmarks" on public.video_bookmarks for delete to authenticated
using (user_id = (select auth.uid()));

create view public.saved_videos with (security_invoker = true) as
select v.*, b.saved_at from public.video_bookmarks b
join public.feed_videos v on v.id = b.video_id
where b.user_id = (select auth.uid());
revoke all on public.saved_videos from public, anon, authenticated;
grant select on public.saved_videos to authenticated;

-- Curators use the dashboard. There are no client write permissions or enrollment records.
create table public.weekly_challenges (
  id uuid primary key default gen_random_uuid(),
  source_video_id uuid not null unique references public.videos(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 60),
  prompt text not null check (char_length(btrim(prompt)) between 1 and 240),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  featured boolean not null default false,
  check (ends_at > starts_at and ends_at <= starts_at + interval '8 days'),
  exclude using gist (tstzrange(starts_at, ends_at, '[)') with &&) where (featured)
);
alter table public.weekly_challenges enable row level security;
revoke all on public.weekly_challenges from public, anon, authenticated;
grant select on public.weekly_challenges to anon, authenticated;
grant all on public.weekly_challenges to service_role;

create policy "read active challenges with a visible opted-in source" on public.weekly_challenges
for select to anon, authenticated
using (featured and starts_at <= now() and ends_at > now() and exists (
  select 1 from public.feed_videos v where v.id = source_video_id and v.backing_enabled
));

create view public.weekly_challenge_entries with (security_invoker = true) as
select v.*, w.id as challenge_id from public.weekly_challenges w
join public.feed_videos v on v.source_video_id = w.source_video_id
where v.created_at >= w.starts_at and v.created_at < w.ends_at;
grant select on public.weekly_challenge_entries to anon, authenticated;
