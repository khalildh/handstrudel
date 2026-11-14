-- Preserve the restriction even after the original video's link is removed.
alter table public.videos add column is_play_along boolean not null default false;
update public.videos set is_play_along = true where source_video_id is not null;

create or replace function public.validate_backing_permission() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.is_play_along := new.source_video_id is not null;
    if new.is_play_along and not exists (
      select 1 from public.videos v join public.profiles p on p.id = v.user_id
      where v.id = new.source_video_id and not v.hidden and v.backing_enabled and p.username is not null
        and not public.is_blocked_between(auth.uid(), v.user_id) and not public.reported_by_me(v.id)
    ) then
      raise exception 'BACKING_UNAVAILABLE' using errcode = 'P0001';
    end if;
  end if;
  if new.is_play_along and new.backing_enabled then
    raise exception 'BACKING_REMIX_NOT_REUSABLE' using errcode = 'P0001';
  end if;
  return new;
end
$$;
