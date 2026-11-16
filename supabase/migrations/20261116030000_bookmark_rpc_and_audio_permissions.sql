create function public.set_video_bookmark(target_video uuid, save boolean)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  if save then
    insert into public.video_bookmarks(video_id) values (target_video)
    on conflict (user_id, video_id) do nothing;
  else
    delete from public.video_bookmarks where video_id = target_video and user_id = (select auth.uid());
  end if;
end;
$$;
revoke execute on function public.set_video_bookmark(uuid, boolean) from public, anon;
grant execute on function public.set_video_bookmark(uuid, boolean) to authenticated;

create table public.video_audio_downloads (
  video_id uuid primary key references public.videos(id) on delete cascade
);
alter table public.video_audio_downloads enable row level security;
revoke all on public.video_audio_downloads from public, anon, authenticated;
grant select on public.video_audio_downloads to anon, authenticated;
grant insert, delete on public.video_audio_downloads to authenticated;

create policy "read download permission for visible posts" on public.video_audio_downloads
for select to anon, authenticated using (exists (
  select 1 from public.feed_videos v where v.id = video_id
));
create policy "owner opts in original audio" on public.video_audio_downloads
for insert to authenticated with check (exists (
  select 1 from public.videos v where v.id = video_id and v.user_id = (select auth.uid())
    and not v.hidden and not v.is_play_along
));
create policy "owner can revoke audio downloads" on public.video_audio_downloads
for delete to authenticated using (exists (
  select 1 from public.videos v where v.id = video_id and v.user_id = (select auth.uid())
));
