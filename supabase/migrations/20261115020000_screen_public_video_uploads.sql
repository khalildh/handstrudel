-- Reserve and screen uploads server-side. Existing public media is unchanged.
create table public.pending_video_uploads (
  id uuid primary key default gen_random_uuid(),
  -- Keep reservations long enough to clean up even if the account closes with a valid PUT URL.
  user_id uuid not null,
  video_bytes integer not null check (video_bytes between 1 and 15728640),
  thumb_bytes integer not null check (thumb_bytes between 1 and 1048576),
  status text not null default 'reserved' check (status in ('reserved', 'checking', 'published', 'held', 'failed')),
  created_at timestamptz not null default now(),
  check_started_at timestamptz,
  attempt integer not null default 0,
  retry_at timestamptz,
  post_fields jsonb
);

create index pending_video_uploads_user_idx on public.pending_video_uploads (user_id, created_at desc);
create index pending_video_uploads_created_idx on public.pending_video_uploads (created_at);
create index pending_video_uploads_checking_idx on public.pending_video_uploads (created_at) where status = 'checking';
alter table public.pending_video_uploads enable row level security;
revoke all on public.pending_video_uploads from public, anon, authenticated;
grant select, update, insert, delete on public.pending_video_uploads to service_role;

revoke insert on public.videos from public, anon, authenticated;
drop policy "post own videos" on public.videos;
revoke delete on public.videos from public, anon, authenticated;
drop policy "delete own videos" on public.videos;

create function public.reserve_video_upload(uploader uuid, video_size integer, thumb_size integer)
returns uuid language plpgsql set search_path = '' as $$
declare upload_id uuid;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(uploader::text, 1));
  if (select count(*) from public.pending_video_uploads
        where user_id = uploader and created_at > now() - interval '24 hours') >= 20 then
    raise exception 'UPLOAD_LIMIT';
  end if;
  insert into public.pending_video_uploads (user_id, video_bytes, thumb_bytes)
    values (uploader, video_size, thumb_size) returning id into upload_id;
  return upload_id;
end;
$$;
revoke execute on function public.reserve_video_upload(uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.reserve_video_upload(uuid, integer, integer) to service_role;

-- A server-published video has no end-user JWT. Its owner, not the current
-- database session's identity, determines whether a play-along source is available.
create or replace function public.validate_backing_permission() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.is_play_along := new.source_video_id is not null;
    if new.is_play_along and not exists (
      select 1 from public.videos v join public.profiles p on p.id = v.user_id
      where v.id = new.source_video_id and not v.hidden and v.backing_enabled and p.username is not null
        and not public.is_blocked_between(new.user_id, v.user_id)
        and not exists (
          select 1 from public.reports r where r.video_id = v.id and r.reporter_id = new.user_id
        )
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

-- The service calls this after screening the write-once objects in private storage.
create function public.publish_screened_video(upload_id uuid, fields jsonb, checked_attempt integer default 0)
returns void language plpgsql set search_path = '' as $$
declare owner_id uuid;
begin
  update public.pending_video_uploads set status = 'published', post_fields = null, retry_at = null
    where id = upload_id and status = 'checking' and attempt = checked_attempt returning user_id into owner_id;
  if not found then raise exception 'UPLOAD_NOT_CHECKING'; end if;

  insert into public.videos (id, user_id, video_key, thumb_key, caption, instrument, mode,
      duration_s, width, height, sound_setup, comments_enabled, backing_enabled, source_video_id)
    values (upload_id, owner_id, 'videos/' || owner_id || '/screened/' || upload_id || '.mp4',
      'thumbs/' || owner_id || '/screened/' || upload_id || '.jpg', coalesce(fields->>'caption', ''),
      fields->>'instrument', fields->>'mode', (fields->>'duration_s')::real,
      (fields->>'width')::int, (fields->>'height')::int, nullif(fields->'sound_setup', 'null'::jsonb),
      coalesce((fields->>'comments_enabled')::boolean, true),
      coalesce((fields->>'backing_enabled')::boolean, false), (fields->>'source_video_id')::uuid);
end;
$$;
revoke execute on function public.publish_screened_video(uuid, jsonb, integer) from public, anon, authenticated;
grant execute on function public.publish_screened_video(uuid, jsonb, integer) to service_role;

-- Playback needs only public visibility, never a service-role credential or a signed download URL.
create function public.can_play_screened_media(post_id uuid, media_key text)
returns boolean language sql stable set search_path = '' as $$
  select exists (
    select 1 from public.videos v
    where v.id = post_id and not v.hidden and (
      (media_key = v.video_key and media_key = 'videos/' || v.user_id || '/screened/' || v.id || '.mp4') or
      (media_key = v.thumb_key and media_key = 'thumbs/' || v.user_id || '/screened/' || v.id || '.jpg')
    )
  );
$$;
revoke execute on function public.can_play_screened_media(uuid, text) from public;
grant execute on function public.can_play_screened_media(uuid, text) to anon, authenticated;

-- Keep the lightweight reservation for live clips so account deletion can be retried
-- even after the auth user and video rows are gone.
create function public.expired_video_uploads()
returns table (id uuid, user_id uuid, status text) language sql stable set search_path = '' as $$
  select p.id, p.user_id, p.status
  from public.pending_video_uploads p
  where p.created_at < now() - interval '24 hours'
    and (p.status <> 'checking' or p.check_started_at < now() - interval '10 minutes')
    and not exists (select 1 from public.videos v where v.id = p.id)
  order by p.created_at
  limit 50;
$$;
revoke execute on function public.expired_video_uploads() from public, anon, authenticated;
grant execute on function public.expired_video_uploads() to service_role;
