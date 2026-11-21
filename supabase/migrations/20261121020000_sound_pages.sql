-- Sound pages: every post belongs to one "sound", and a sound page lists its takes.
--
-- Identity, assigned once when a post is published:
--   1. A play-along (or remix) inherits the sound of the clip it was recorded over.
--   2. Otherwise a post with a sound setup joins the sound that first used the same
--      canonical setup (instrument, key, scale, progression, mode, voicing). This is how
--      "Play this sound" takes join the original: they post the setup they were handed.
--   3. Otherwise the post starts its own sound.
-- A sound's id is the id of the post that started it, so the original post is simply
-- `videos.id = sound_id`. Ids never change after publication, so a takedown or a
-- deleted original never splits or merges a sound; pages and counts just skip the rows
-- the viewer can't see.

-- The canonical "same sound" hash. Performance settings that a player tweaks while
-- playing (tempo, pad level, grid octave and range, auto-strum) are left out.
create function public.sound_identity_hash(setup jsonb) returns text
language sql immutable parallel safe set search_path = '' as $$
  select case when jsonb_typeof(setup) = 'object' then md5(jsonb_build_object(
    'mode', setup->'mode',
    'voice', case when setup->>'useSoundFont' = 'true'
                  then jsonb_build_object('soundfont', setup->'instrument')
                  else jsonb_build_object('synth', setup->'waveform') end,
    'key', setup->'key',
    'scale', setup->'scale',
    'progression', setup->'progression',
    'degrees', case when setup->>'progression' = 'custom' then setup->'customDegrees' end,
    'voicing', setup->'chordVoicing'
  )::text) end
$$;

-- First post to use each canonical setup. Kept even when that post is later removed, so
-- identical setups keep landing on the same sound.
create table public.sound_identities (
  setup_hash text primary key,
  sound_id   uuid not null
);
alter table public.sound_identities enable row level security;
revoke all on public.sound_identities from public, anon, authenticated;
grant all on public.sound_identities to service_role;

alter table public.videos add column sound_id uuid;

create function public.resolve_sound_id(post_id uuid, setup jsonb, source uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  found_sound uuid;
  canonical text := public.sound_identity_hash(setup);
begin
  if source is not null then
    select coalesce(v.sound_id, v.id) into found_sound from public.videos v where v.id = source;
    if found_sound is not null then return found_sound; end if;
  end if;
  if canonical is not null then
    insert into public.sound_identities as known (setup_hash, sound_id) values (canonical, post_id)
      on conflict (setup_hash) do update set sound_id = known.sound_id
      returning known.sound_id into found_sound;
    return found_sound;
  end if;
  return post_id;
end
$$;
revoke all on function public.resolve_sound_id(uuid, jsonb, uuid) from public, anon, authenticated;

-- Backfill in publication order so sources and first uses are resolved before later posts.
do $$
declare post record;
begin
  for post in select id, sound_setup, source_video_id from public.videos order by created_at, id loop
    update public.videos set sound_id = public.resolve_sound_id(post.id, post.sound_setup, post.source_video_id)
      where id = post.id;
  end loop;
end
$$;
alter table public.videos alter column sound_id set not null;

create function public.assign_sound_id() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.sound_id := public.resolve_sound_id(new.id, new.sound_setup, new.source_video_id);
  return new;
end
$$;
revoke all on function public.assign_sound_id() from public, anon, authenticated;
create trigger videos_assign_sound_id before insert on public.videos
  for each row execute function public.assign_sound_id();
-- Clients only update an allow-list of columns (sound_id isn't on it), but keep the id
-- fixed against the service role and the dashboard too.
create function public.keep_sound_id() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.sound_id := old.sound_id;
  return new;
end
$$;
create trigger videos_keep_sound_id before update of sound_id on public.videos
  for each row execute function public.keep_sound_id();

create index videos_sound_recent_idx on public.videos (sound_id, created_at desc, id desc) where not hidden;
create index videos_sound_top_idx on public.videos (sound_id, like_count desc, id desc) where not hidden;

-- Every take the viewer may see, built on feed_videos so hidden posts, blocked creators
-- (either direction), posts the viewer reported and handle-less accounts stay out.
-- Page with keyset cursors on (created_at, id) for Recent and (like_count, id) for Top.
create view public.sound_takes with (security_invoker = true) as
select f.id, f.user_id, f.video_key, f.thumb_key, f.caption, f.instrument, f.mode, f.duration_s, f.width, f.height,
       f.like_count, f.hidden, f.created_at, f.username, f.display_name, f.avatar_key, f.liked_by_me,
       f.sound_setup, f.comments_enabled, f.comment_count, f.backing_enabled, f.source_video_id, f.source_username,
       f.view_count, f.has_note_track, v.sound_id, (v.id = v.sound_id) as is_original
  from public.feed_videos f
  join public.videos v on v.id = f.id;
revoke all on public.sound_takes from public, anon, authenticated;
grant select on public.sound_takes to anon, authenticated;

-- Header for a sound page opened from one of its posts. No row when that post isn't
-- visible to the caller. original_video_id is null when the original isn't visible.
create function public.sound_summary(target_video uuid)
returns table (sound_id uuid, take_count bigint, original_video_id uuid)
language sql stable security invoker set search_path = '' as $$
  select t.sound_id,
         (select count(*) from public.sound_takes s where s.sound_id = t.sound_id),
         (select s.id from public.sound_takes s where s.id = t.sound_id)
    from public.sound_takes t
   where t.id = target_video
$$;

-- Take counts for a page of feed posts (at most 50 ids per call).
create function public.sound_take_counts(target_videos uuid[])
returns table (video_id uuid, sound_id uuid, take_count bigint)
language sql stable security invoker set search_path = '' as $$
  select t.id, t.sound_id, (select count(*) from public.sound_takes s where s.sound_id = t.sound_id)
    from public.sound_takes t
   where t.id = any (target_videos[1:50])
$$;

revoke all on function public.sound_summary(uuid), public.sound_take_counts(uuid[]) from public;
grant execute on function public.sound_summary(uuid), public.sound_take_counts(uuid[]) to anon, authenticated;
grant execute on function public.sound_identity_hash(jsonb) to anon, authenticated;
