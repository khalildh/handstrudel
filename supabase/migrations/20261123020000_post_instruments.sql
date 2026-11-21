-- Instruments travel with posts. A take played on an instrument file (shared/instruments/) carries
-- that file, so viewers can play it, keep it and remix it, with credit back to whoever made it.
--
-- An instrument is structure only. The post's music (key, scale, voicing, sound) stays in
-- sound_setup; a post pairs one instrument with one sound and neither contains the other.
-- The file is data the apps draw with their own code. Every client validates it again with its
-- loader before use; the checks here only keep junk out of the table.

-- ------------------------------------------------------------------ validation mirror
-- Mirrors what InstrumentSpec.load rejects (iOS, shared/instruments/fixtures/). Values the loader
-- only repairs (long names, out-of-range radii) are accepted, because every loader repairs them.
-- Newer format versions are accepted with the version-independent checks only, so a newer app can
-- post an instrument an older app will decline to open ("update to play this instrument").
create function public.instrument_spec_issue(spec jsonb) returns text
language plpgsql immutable set search_path = '' as $$
declare
  version numeric;
  surface jsonb;
  notes jsonb;
begin
  if spec is null or jsonb_typeof(spec) is distinct from 'object' then return 'malformed'; end if;
  -- jsonb's text form adds a space after every ':' and ','; the 16 KB file limit is enforced on
  -- compact JSON by publish-upload and the apps. This is the hard backstop.
  if octet_length(spec::text) > 20480 then return 'too_large'; end if;
  if spec->>'format' is distinct from 'handstrudel.instrument' or jsonb_typeof(spec->'format') <> 'string' then
    return 'unsupported_format';
  end if;
  if jsonb_typeof(spec->'format_version') is distinct from 'number' then return 'malformed'; end if;
  version := (spec->>'format_version')::numeric;
  if version <> trunc(version) or version < 1 or version > 99 then return 'unsupported_version'; end if;
  if jsonb_typeof(spec->'id') is distinct from 'string' or jsonb_typeof(spec->'name') is distinct from 'string'
     or coalesce(jsonb_typeof(spec->'description'), 'null') not in ('string', 'null') then
    return 'malformed';
  end if;
  if spec->>'id' !~ '^[a-z0-9][a-z0-9._-]{0,79}$' then return 'id_invalid'; end if;
  if regexp_replace(spec->>'name', '^\s+|\s+$', '', 'g') = '' then return 'name_missing'; end if;
  if version > 1 then return null; end if;

  -- Format version 1: one split_wheel surface, a chord side and a note source.
  surface := spec->'surface';
  notes := spec->'notes';
  if jsonb_typeof(surface) is distinct from 'object' or surface->>'type' is distinct from 'split_wheel'
     or jsonb_typeof(surface->'radius') is distinct from 'number'
     or jsonb_typeof(surface->'rest_radius') is distinct from 'number'
     or jsonb_typeof(surface->'octave_band_radius') is distinct from 'number'
     or jsonb_typeof(spec->'chords') is distinct from 'object'
     or spec#>>'{chords,side}' is null or spec#>>'{chords,side}' not in ('left', 'right')
     or jsonb_typeof(notes) is distinct from 'object'
     or notes->>'source' is null or notes->>'source' not in ('scale_one_octave', 'chord_tones_three_octaves')
     or jsonb_typeof(notes->'octave_band') is distinct from 'boolean'
     or coalesce(jsonb_typeof(notes->'highlight_chord_tones'), 'null') not in ('boolean', 'null') then
    return 'malformed';
  end if;
  return null;
end;
$$;
grant execute on function public.instrument_spec_issue(jsonb) to anon, authenticated, service_role;

-- Generated instruments carry an AI marker in the file: "ai_generated": true, or a
-- "generator" object whose "kind" is "ai". Loaders ignore both, so the flag survives every copy.
create function public.instrument_spec_ai_generated(spec jsonb) returns boolean
language sql immutable set search_path = '' as $$
  select coalesce(spec->'ai_generated' = 'true'::jsonb, false) or coalesce(spec#>>'{generator,kind}' = 'ai', false)
$$;
grant execute on function public.instrument_spec_ai_generated(jsonb) to anon, authenticated, service_role;

-- ------------------------------------------------------------------ posts
-- instrument_kind says whose instrument it is:
--   own   the poster made it (or it came from no post);
--   copy  played unchanged from another post: instrument_source_id is the post that made it;
--   remix an edited copy: instrument_source_id is the post whose instrument was remixed.
-- A source that is later deleted leaves the kind in place, so credit is never moved to the poster.
alter table public.videos
  add column instrument_spec jsonb check (instrument_spec is null or public.instrument_spec_issue(instrument_spec) is null),
  add column instrument_kind text check (instrument_kind in ('own', 'copy', 'remix')),
  add column instrument_source_id uuid references public.videos(id) on delete set null,
  add column instrument_remixes_allowed boolean not null default true,
  add column instrument_ai_generated boolean not null default false,
  add constraint videos_instrument_kind_matches_spec check ((instrument_spec is null) = (instrument_kind is null)),
  add constraint videos_instrument_source_needs_kind check (instrument_source_id is null or instrument_kind in ('copy', 'remix'));
create index videos_instrument_remixes_idx on public.videos (instrument_source_id) where instrument_kind = 'remix';

-- Resolve credit once, at publication. Runs for every insert path, so the client's word is never
-- trusted: copy or remix is decided by comparing the files, and a remix of an instrument whose
-- creator turned remixes off doesn't keep the instrument at all.
create function public.resolve_video_instrument() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  source public.videos;
  maker uuid;
begin
  if new.instrument_spec is null then
    new.instrument_kind := null;
    new.instrument_source_id := null;
    new.instrument_remixes_allowed := true;
    new.instrument_ai_generated := false;
    return new;
  end if;
  new.instrument_ai_generated := coalesce(new.instrument_ai_generated, false)
    or public.instrument_spec_ai_generated(new.instrument_spec);
  new.instrument_remixes_allowed := coalesce(new.instrument_remixes_allowed, true);
  if new.instrument_source_id is null then
    new.instrument_kind := 'own';
    return new;
  end if;

  select * into source from public.videos where id = new.instrument_source_id;
  if not found or source.instrument_spec is null or source.hidden
     or public.is_blocked_between(new.user_id, source.user_id) then
    -- It came from somewhere the poster can't credit. Never present it as the poster's own.
    new.instrument_kind := 'copy';
    new.instrument_source_id := null;
    return new;
  end if;

  -- The post that made the instrument: a copy credits its own source.
  maker := case when source.instrument_kind = 'copy' then source.instrument_source_id else source.id end;
  if new.instrument_spec = source.instrument_spec then
    new.instrument_kind := 'copy';
    new.instrument_source_id := maker;
    -- Playing a no-remix instrument in your own take doesn't open it up for remixing.
    new.instrument_remixes_allowed := new.instrument_remixes_allowed and source.instrument_remixes_allowed;
  elsif not source.instrument_remixes_allowed then
    new.instrument_spec := null;
    new.instrument_kind := null;
    new.instrument_source_id := null;
    new.instrument_remixes_allowed := true;
    new.instrument_ai_generated := false;
  else
    new.instrument_kind := 'remix';
    new.instrument_source_id := coalesce(maker, source.id);
  end if;
  return new;
end;
$$;
revoke execute on function public.resolve_video_instrument() from public, anon, authenticated;

create trigger videos_resolve_instrument before insert on public.videos
  for each row execute function public.resolve_video_instrument();

-- Only the screened publish path writes it; clients still have no insert or update on videos.
create or replace function public.publish_screened_video(upload_id uuid, fields jsonb, checked_attempt integer default 0)
returns void language plpgsql set search_path = '' as $$
declare owner_id uuid;
begin
  update public.pending_video_uploads set status = 'published', post_fields = null, retry_at = null
    where id = upload_id and status = 'checking' and attempt = checked_attempt returning user_id into owner_id;
  if not found then raise exception 'UPLOAD_NOT_CHECKING'; end if;

  insert into public.videos (id, user_id, video_key, thumb_key, caption, instrument, mode,
      duration_s, width, height, sound_setup, note_track, comments_enabled, backing_enabled, source_video_id,
      instrument_spec, instrument_source_id, instrument_remixes_allowed, instrument_ai_generated)
    values (upload_id, owner_id, 'videos/' || owner_id || '/screened/' || upload_id || '.mp4',
      'thumbs/' || owner_id || '/screened/' || upload_id || '.jpg', coalesce(fields->>'caption', ''),
      fields->>'instrument', fields->>'mode', (fields->>'duration_s')::real,
      (fields->>'width')::int, (fields->>'height')::int, nullif(fields->'sound_setup', 'null'::jsonb),
      -- Notes only make sense with the preset that tells Learn mode which key and scale to use.
      case when nullif(fields->'sound_setup', 'null'::jsonb) is null then null
           else nullif(fields->'note_track', 'null'::jsonb) end,
      coalesce((fields->>'comments_enabled')::boolean, true),
      coalesce((fields->>'backing_enabled')::boolean, false), (fields->>'source_video_id')::uuid,
      -- The instrument stands alone: it is shared with or without the playable preset.
      nullif(fields->'instrument_spec', 'null'::jsonb), (fields->>'instrument_source_id')::uuid,
      coalesce((fields->>'instrument_remixes_allowed')::boolean, true),
      coalesce((fields->>'instrument_ai_generated')::boolean, false));
end;
$$;
revoke execute on function public.publish_screened_video(uuid, jsonb, integer) from public, anon, authenticated;
grant execute on function public.publish_screened_video(uuid, jsonb, integer) to service_role;

-- Whether the caller may keep or remix a post's instrument: the post is visible to them and its
-- creator allows remixes. Playing it only needs the post to be visible.
create function public.instrument_reuse_allowed(video uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.videos v join public.profiles p on p.id = v.user_id
     where v.id = video and v.instrument_spec is not null and v.instrument_remixes_allowed
       and not v.hidden and p.username is not null
       and not public.is_blocked_between(auth.uid(), v.user_id) and not public.reported_by_me(v.id))
$$;
grant execute on function public.instrument_reuse_allowed(uuid) to anon, authenticated;

-- How many visible posts remix this instrument (counted on the post that made it).
create function public.instrument_remix_count(maker uuid) returns integer
language sql stable security invoker set search_path = '' as $$
  select count(*)::int from public.videos r join public.profiles p on p.id = r.user_id
   where maker is not null and r.instrument_source_id = maker and r.instrument_kind = 'remix'
     and not r.hidden and p.username is not null
     and not public.is_blocked_between(auth.uid(), r.user_id) and not public.reported_by_me(r.id)
$$;
grant execute on function public.instrument_remix_count(uuid) to anon, authenticated;

-- ------------------------------------------------------------------ feeds
-- Feeds carry the chip (name, AI flag, credit, remix count); the file itself is read from
-- videos.instrument_spec only when a viewer plays, saves or remixes it. Credit to a hidden,
-- blocked or reported post is left out (instrument_source_id null), never moved to the poster.
create or replace view public.feed_videos with (security_invoker = true) as
select v.id, v.user_id, v.video_key, v.thumb_key, v.caption, v.instrument, v.mode,
       v.duration_s, v.width, v.height, v.like_count, v.report_count, v.hidden, v.created_at,
       p.username, p.display_name, p.avatar_key,
       exists (select 1 from public.likes l where l.video_id = v.id and l.user_id = auth.uid()) as liked_by_me,
       v.sound_setup, v.comments_enabled,
       (select count(*) from public.comments c where c.video_id = v.id and not c.hidden) as comment_count,
       v.backing_enabled, source.id as source_video_id, author.username as source_username, v.view_count,
       (v.note_track is not null and v.sound_setup is not null) as has_note_track,
       (v.instrument_spec is not null) as has_instrument,
       left(btrim(v.instrument_spec->>'name'), 40) as instrument_spec_name,
       v.instrument_kind, v.instrument_remixes_allowed, v.instrument_ai_generated,
       maker.id as instrument_source_id, maker_profile.username as instrument_source_username,
       -- A copy shows the count of the post that made it; own instruments and remixes their own.
       case when v.instrument_kind = 'copy' then public.instrument_remix_count(maker.id)
            when v.instrument_kind is not null then public.instrument_remix_count(v.id) end as instrument_remix_count
  from public.videos v
  join public.profiles p on p.id = v.user_id
  left join public.videos source on source.id = v.source_video_id and not source.hidden
    and not public.is_blocked_between(auth.uid(), source.user_id) and not public.reported_by_me(source.id)
  left join public.profiles author on author.id = source.user_id
  left join public.videos maker on maker.id = v.instrument_source_id and not maker.hidden
    and not public.is_blocked_between(auth.uid(), maker.user_id) and not public.reported_by_me(maker.id)
  left join public.profiles maker_profile on maker_profile.id = maker.user_id
 where not v.hidden and p.username is not null
   and not public.is_blocked_between(auth.uid(), v.user_id) and not public.reported_by_me(v.id);

create or replace view public.following_videos with (security_invoker = true) as
select v.* from public.feed_videos v
where exists (select 1 from public.follows f where f.follower_id = (select auth.uid()) and f.followee_id = v.user_id);

create or replace view public.saved_videos with (security_invoker = true) as
select v.id, v.user_id, v.video_key, v.thumb_key, v.caption, v.instrument, v.mode, v.duration_s, v.width, v.height,
       v.like_count, v.report_count, v.hidden, v.created_at, v.username, v.display_name, v.avatar_key, v.liked_by_me,
       v.sound_setup, v.comments_enabled, v.comment_count, v.backing_enabled, v.source_video_id, v.source_username,
       b.saved_at, v.view_count, v.has_note_track,
       v.has_instrument, v.instrument_spec_name, v.instrument_kind, v.instrument_remixes_allowed,
       v.instrument_ai_generated, v.instrument_source_id, v.instrument_source_username, v.instrument_remix_count
from public.video_bookmarks b
join public.feed_videos v on v.id = b.video_id
where b.user_id = (select auth.uid());

create or replace view public.weekly_challenge_entries with (security_invoker = true) as
select v.id, v.user_id, v.video_key, v.thumb_key, v.caption, v.instrument, v.mode, v.duration_s, v.width, v.height,
       v.like_count, v.report_count, v.hidden, v.created_at, v.username, v.display_name, v.avatar_key, v.liked_by_me,
       v.sound_setup, v.comments_enabled, v.comment_count, v.backing_enabled, v.source_video_id, v.source_username,
       w.id as challenge_id, v.view_count, v.has_note_track,
       v.has_instrument, v.instrument_spec_name, v.instrument_kind, v.instrument_remixes_allowed,
       v.instrument_ai_generated, v.instrument_source_id, v.instrument_source_username, v.instrument_remix_count
from public.weekly_challenges w
join public.feed_videos v on v.source_video_id = w.source_video_id
where v.created_at >= w.starts_at and v.created_at < w.ends_at;

-- The remix chain from a post back to the original, newest first: depth 0 is the post itself.
-- Walks videos with the caller's rights, so the chain ends at a hidden post, and returns only links
-- visible in their feed, so blocked and reported posts never appear.
create function public.instrument_remix_chain(target_video uuid)
returns table (depth integer, video_id uuid, username text, instrument_name text, instrument_kind text)
language sql stable security invoker set search_path = '' as $$
  with recursive chain as (
    select v.id, v.instrument_kind, v.instrument_source_id, 0 as depth
      from public.videos v where v.id = target_video and v.instrument_spec is not null
    union all
    select parent.id, parent.instrument_kind, parent.instrument_source_id, chain.depth + 1
      from chain join public.videos parent on parent.id = chain.instrument_source_id
     where chain.depth < 50 and parent.instrument_spec is not null
  )
  select chain.depth, f.id, f.username, f.instrument_spec_name, f.instrument_kind
    from chain join public.feed_videos f on f.id = chain.id
   order by chain.depth
$$;
grant execute on function public.instrument_remix_chain(uuid) to anon, authenticated;

-- ------------------------------------------------------------------ My instruments
-- A player's saved, created, remixed and imported instruments, synced across their devices.
-- The id is chosen by the app so a cached entry keeps its identity when it syncs.
create table public.my_instruments (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  spec jsonb not null check (public.instrument_spec_issue(spec) is null),
  kind text not null check (kind in ('saved', 'created', 'remixed', 'imported')),
  source_video_id uuid references public.videos(id) on delete set null,
  ai_generated boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index my_instruments_user_idx on public.my_instruments (user_id, created_at desc);
alter table public.my_instruments enable row level security;

create policy "read own instruments" on public.my_instruments for select to authenticated
  using (user_id = (select auth.uid()));
-- Keeping or remixing a post's instrument needs its creator's permission (Allow remixes).
create policy "keep instruments as self" on public.my_instruments for insert to authenticated
  with check (user_id = (select auth.uid())
    and (kind not in ('saved', 'remixed') or source_video_id is null or public.instrument_reuse_allowed(source_video_id))
    and (kind in ('saved', 'remixed') or source_video_id is null));
create policy "edit own instruments" on public.my_instruments for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "delete own instruments" on public.my_instruments for delete to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.my_instruments from public, anon, authenticated;
grant select, insert, delete on public.my_instruments to authenticated;
grant update (spec) on public.my_instruments to authenticated;
grant all on public.my_instruments to service_role;

create function public.prepare_my_instrument() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.user_id::text, 2));
    if (select count(*) from public.my_instruments where user_id = new.user_id) >= 500 then
      raise exception 'INSTRUMENT_LIMIT' using errcode = '54000';
    end if;
    new.created_at := now();
  end if;
  new.ai_generated := new.ai_generated or public.instrument_spec_ai_generated(new.spec);
  new.updated_at := now();
  return new;
end;
$$;
revoke execute on function public.prepare_my_instrument() from public, anon, authenticated;
create trigger my_instruments_prepare before insert or update on public.my_instruments
  for each row execute function public.prepare_my_instrument();
