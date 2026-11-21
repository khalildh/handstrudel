-- The daily sound and posting streaks.
--
-- Days roll over at 00:00 UTC for everyone. Every time used here is a server time:
-- the upload reservation made by `sign-upload` and the publication by `publish-upload`.
-- Nothing the device sends (or its clock) decides which day a take counts for.
--
-- * `daily_sounds`: one featured sound per UTC day. The owner can schedule a post for a
--   date with `schedule_daily_sound`; otherwise the first read of the day picks a popular,
--   recent, free (non-Pro) sound, avoiding any sound featured in the previous 30 days.
-- * A take counts when a screened post is reserved during that day's window and either uses
--   the same sound (instrument, key, scale, progression) or plays along with the featured clip.
-- * One credited day per player and day (`daily_streak_days`). Credit is kept if the post is
--   later deleted or hidden; the post itself disappears from the day's takes.
-- * One freeze per ISO week (Monday to Sunday, UTC) covers a missed day.
-- * Badges at 3, 7 and 30 days; reaching 7 also lends one HandStrudel+ hand theme for 7 days.

create schema daily_internal;
revoke all on schema daily_internal from public;
grant usage on schema daily_internal to service_role;

-- ------------------------------------------------------------ free sounds
-- What a player without Pro can open. An allowlist, so a new catalog item is treated as
-- locked until it is added here. DailySoundTests checks this block against the iOS catalog.
create table daily_internal.free_sound_values (
  kind text not null check (kind in ('soundfont', 'waveform', 'scale', 'progression')),
  value text not null,
  primary key (kind, value)
);
-- BEGIN FREE SOUND VALUES
insert into daily_internal.free_sound_values (kind, value) values
  ('soundfont', 'grand_piano'), ('soundfont', 'electric_piano_1'), ('soundfont', 'nylon_guitar'),
  ('soundfont', 'clean_guitar'), ('soundfont', 'acoustic_bass'), ('soundfont', 'violin'),
  ('soundfont', 'strings'), ('soundfont', 'choir'),
  ('waveform', 'sawtooth'), ('waveform', 'square'), ('waveform', 'triangle'), ('waveform', 'sine'),
  ('waveform', 'pluck'), ('waveform', 'supersaw'), ('waveform', 'pulse'), ('waveform', 'fm'),
  ('waveform', 'piano'), ('waveform', 'epiano'), ('waveform', 'organ'), ('waveform', 'pipeorgan'),
  ('waveform', 'strings'), ('waveform', 'sax'), ('waveform', 'marimba'), ('waveform', 'kalimba'),
  ('waveform', 'flute'), ('waveform', 'bells'), ('waveform', 'steinway'), ('waveform', 'folkharp'),
  ('waveform', 'clavisynth'), ('waveform', 'organ8'), ('waveform', 'pipeorgan_loud'), ('waveform', 'harmonica'),
  ('waveform', 'vibraphone'), ('waveform', 'tubularbells'), ('waveform', 'xylophone'), ('waveform', 'balafon'),
  ('waveform', 'handchimes'), ('waveform', 'dantranh'), ('waveform', 'ocarina'), ('waveform', 'recorder_soprano'),
  ('waveform', 'recorder_tenor'), ('waveform', 'recorder_bass'), ('waveform', 'saxello'), ('waveform', 'sax_vib'),
  ('waveform', 'psaltery'), ('waveform', 'kalimba2'),
  ('scale', 'Major'), ('scale', 'Minor'), ('scale', 'Dorian'), ('scale', 'Pentatonic'), ('scale', 'Blues'),
  ('progression', 'free'), ('progression', 'pop'), ('progression', 'sad_pop'), ('progression', 'fifties'),
  ('progression', 'doo_wop'), ('progression', 'andalusian'), ('progression', 'jazz'), ('progression', 'blues'),
  ('progression', 'minor_vamp'), ('progression', 'custom');
-- END FREE SOUND VALUES
alter table daily_internal.free_sound_values enable row level security;

-- --------------------------------------------------------------- helpers
create function daily_internal.day_of(at_time timestamptz) returns date
language sql immutable set search_path = '' as $$ select (at_time at time zone 'UTC')::date $$;

create function daily_internal.day_start(day date) returns timestamptz
language sql immutable set search_path = '' as $$ select day::timestamp at time zone 'UTC' $$;

create function daily_internal.week_start(day date) returns date
language sql immutable set search_path = '' as $$ select day - (extract(isodow from day)::int - 1) $$;

-- The part of a sound setup that makes it "the same sound": instrument, key, scale and
-- progression. Tempo, mode and mix can differ between takes.
create function daily_internal.sound_signature(setup jsonb) returns text
language sql immutable set search_path = '' as $$
  select case when setup is null or jsonb_typeof(setup) <> 'object' then null else concat_ws('|',
    case when setup->'useSoundFont' = 'true'::jsonb then 'sf:' || coalesce(setup->>'instrument', '')
         else 'wave:' || coalesce(setup->>'waveform', '') end,
    coalesce(setup->>'key', ''), coalesce((setup->'scale')::text, ''), coalesce(setup->>'progression', ''),
    case when setup->>'progression' = 'custom' then coalesce((setup->'customDegrees')::text, '') else '' end
  ) end
$$;

-- Mirrors SoundSetup.isValid on iOS for the fields the server can check.
create function daily_internal.is_playable_sound(setup jsonb) returns boolean
language sql immutable set search_path = '' as $$
  select coalesce(
    jsonb_typeof(setup) = 'object'
    and setup->'version' = '1'::jsonb
    and setup->>'key' in ('C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B')
    and jsonb_typeof(setup->'bpm') = 'number' and (setup->>'bpm')::numeric between 20 and 400
    and jsonb_typeof(setup->'padVolume') = 'number' and (setup->>'padVolume')::numeric between 0 and 0.6
    and jsonb_typeof(setup->'gridOctave') = 'number' and (setup->>'gridOctave')::numeric between 1 and 6
    and jsonb_typeof(setup->'gridRange') = 'number' and (setup->>'gridRange')::numeric between 1 and 3
    and jsonb_typeof(setup->'useSoundFont') = 'boolean' and jsonb_typeof(setup->'autoStrum') = 'boolean'
    and jsonb_typeof(setup->'instrument') = 'string' and jsonb_typeof(setup->'waveform') = 'string'
    and jsonb_typeof(setup->'progression') = 'string'
    and (setup->>'progression' <> 'custom' or (
      jsonb_typeof(setup->'customDegrees') = 'array'
      and jsonb_array_length(setup->'customDegrees') between 1 and 64
      and not jsonb_path_exists(setup->'customDegrees', '$[*] ? (@.type() != "number" || @ < 0 || @ > 6)')))
    and setup->>'mode' in ('melodic', 'flow', 'hybrid', 'lead', 'grid', 'drum', 'chordmelody',
      'radialchordmelody', 'splitchordmelody', 'scalechordmelody', 'soundfont')
    and case when setup->>'mode' = 'soundfont' then setup->'useSoundFont' = 'true'::jsonb
             else setup->'useSoundFont' = 'false'::jsonb
               or setup->>'mode' in ('radialchordmelody', 'splitchordmelody', 'scalechordmelody') end,
    false)
$$;

-- True when a player without Pro can open this sound (SoundSetup.requiredPacks on iOS).
create function daily_internal.is_free_sound(setup jsonb) returns boolean
language sql stable set search_path = '' as $$
  select daily_internal.is_playable_sound(setup)
    and exists (select 1 from daily_internal.free_sound_values f
      where (setup->'useSoundFont' = 'true'::jsonb and f.kind = 'soundfont' and f.value = setup->>'instrument')
         or (setup->'useSoundFont' = 'false'::jsonb and f.kind = 'waveform' and f.value = setup->>'waveform'))
    and jsonb_typeof(setup->'scale') = 'string'
    and exists (select 1 from daily_internal.free_sound_values f where f.kind = 'scale' and f.value = setup->>'scale')
    and exists (select 1 from daily_internal.free_sound_values f
      where f.kind = 'progression' and f.value = setup->>'progression')
$$;

-- ---------------------------------------------------------------- tables
create table public.daily_sounds (
  day date primary key,
  -- The featured post. The sound is copied, so the day keeps working if the post goes away.
  video_id uuid references public.videos(id) on delete set null,
  creator_id uuid references public.profiles(id) on delete set null,
  sound_setup jsonb not null check (jsonb_typeof(sound_setup) = 'object' and octet_length(sound_setup::text) <= 4096),
  signature text not null,
  source text not null check (source in ('scheduled', 'auto')),
  title text check (title is null or char_length(btrim(title)) between 1 and 60),
  note text check (note is null or char_length(btrim(note)) between 1 and 240),
  created_at timestamptz not null default now()
);
create index daily_sounds_signature on public.daily_sounds (signature, day desc);
create index daily_sounds_creator on public.daily_sounds (creator_id, day desc);

create table public.daily_sound_takes (
  video_id uuid primary key references public.videos(id) on delete cascade,
  day date not null references public.daily_sounds(day) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  taken_at timestamptz not null
);
create index daily_sound_takes_day on public.daily_sound_takes (day);

-- Credited days. Deliberately no cascade from the post: deleting it later keeps the day.
create table public.daily_streak_days (
  user_id uuid not null references public.profiles(id) on delete cascade,
  day date not null,
  video_id uuid references public.videos(id) on delete set null,
  credited_at timestamptz not null default now(),
  primary key (user_id, day)
);

-- Rebuilt from `daily_streak_days` whenever a day is credited.
create table public.daily_streaks (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  current_streak int not null default 0 check (current_streak >= 0),
  best_streak int not null default 0 check (best_streak >= 0),
  last_day date,
  updated_at timestamptz not null default now()
);
create index daily_streaks_last_day on public.daily_streaks (last_day);

-- One freeze per ISO week, and the missed day it covered.
create table public.daily_streak_freezes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  week_start date not null,
  covered_day date not null,
  primary key (user_id, week_start)
);

-- Profile badges, earned once.
create table public.daily_streak_badges (
  user_id uuid not null references public.profiles(id) on delete cascade,
  milestone int not null check (milestone in (3, 7, 30)),
  earned_on date not null,
  primary key (user_id, milestone)
);

-- A HandStrudel+ hand theme lent for a week each time a streak reaches 7 days.
create table public.daily_theme_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  theme_id text not null check (theme_id in ('fire_ice', 'purple_gold', 'matrix', 'sunset', 'ocean')),
  streak_day date not null,
  starts_at timestamptz not null,
  expires_at timestamptz not null check (expires_at > starts_at),
  unique (user_id, streak_day)
);
create index daily_theme_grants_active on public.daily_theme_grants (user_id, expires_at desc);

-- Clients never touch these tables; they read through the functions below.
do $$
declare t text;
begin
  foreach t in array array['daily_sounds', 'daily_sound_takes', 'daily_streak_days', 'daily_streaks',
                           'daily_streak_freezes', 'daily_streak_badges', 'daily_theme_grants'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('grant all on public.%I to service_role', t);
  end loop;
end
$$;
revoke all on daily_internal.free_sound_values from public, anon, authenticated;
grant select on daily_internal.free_sound_values to service_role;

-- --------------------------------------------------------- picking a sound
-- Ranked candidates for a day: free, playable, visible, unreported posts by named creators,
-- published before the day began. Recent (30 days) first, then creators not featured in the
-- last week, then sounds never or least recently featured, then popularity.
create function daily_internal.daily_candidates(p_day date, p_allow_repeats boolean default false)
returns table (video_id uuid, user_id uuid, sound_setup jsonb, signature text)
language sql stable set search_path = '' as $$
  with pool as (
    select v.id, v.user_id, v.sound_setup, v.created_at, daily_internal.sound_signature(v.sound_setup) as sig,
           v.like_count * 3 + v.view_count / 10.0
             + 5 * (select count(*) from public.videos remix where remix.source_video_id = v.id and not remix.hidden)
             as score
    from public.videos v
    join public.profiles p on p.id = v.user_id
    where not v.hidden and v.report_count = 0 and p.username is not null
      and v.created_at < daily_internal.day_start(p_day)
      and daily_internal.is_free_sound(v.sound_setup)
  )
  select pool.id, pool.user_id, pool.sound_setup, pool.sig from pool
  where p_allow_repeats or not exists (
    select 1 from public.daily_sounds d
    where d.day >= p_day - 30 and d.day < p_day and (d.signature = pool.sig or d.video_id = pool.id))
  order by
    pool.created_at >= daily_internal.day_start(p_day) - interval '30 days' desc,
    exists (select 1 from public.daily_sounds d
            where d.creator_id = pool.user_id and d.day >= p_day - 7 and d.day < p_day),
    (select max(d.day) from public.daily_sounds d where d.signature = pool.sig and d.day < p_day) asc nulls first,
    pool.score desc, pool.created_at desc, pool.id
$$;

-- The day's sound, picking one the first time anyone asks. Concurrent first reads agree
-- because the day is the primary key. Returns an all-null row when nothing is playable.
create function daily_internal.ensure_daily_sound(p_day date) returns public.daily_sounds
language plpgsql set search_path = '' as $$
declare picked public.daily_sounds;
begin
  select * into picked from public.daily_sounds where day = p_day;
  if found then return picked; end if;
  insert into public.daily_sounds (day, video_id, creator_id, sound_setup, signature, source)
    select p_day, c.video_id, c.user_id, c.sound_setup, c.signature, 'auto'
    from daily_internal.daily_candidates(p_day) c limit 1
    on conflict (day) do nothing;
  if not found then
    insert into public.daily_sounds (day, video_id, creator_id, sound_setup, signature, source)
      select p_day, c.video_id, c.user_id, c.sound_setup, c.signature, 'auto'
      from daily_internal.daily_candidates(p_day, true) c limit 1
      on conflict (day) do nothing;
  end if;
  select * into picked from public.daily_sounds where day = p_day;
  return picked;
end
$$;

-- ---------------------------------------------------------------- streaks
-- Replays a player's credited days in order. Consecutive days extend the run; missed days
-- are forgiven only when each falls in a different ISO week whose freeze is still unused.
-- `p_new_day` is the day just credited at `p_at`, which may reach a reward.
create function daily_internal.rebuild_streak(p_user uuid, p_new_day date, p_at timestamptz)
returns void language plpgsql set search_path = '' as $$
declare
  d date;
  prev date;
  gap date;
  run int := 0;
  best int := 0;
  used date[] := '{}';
  pending date[];
  covered date[] := '{}';
  ok boolean;
  themes constant text[] := array['fire_ice', 'purple_gold', 'matrix', 'sunset', 'ocean'];
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('daily_streak:' || p_user::text, 0));
  for d in select s.day from public.daily_streak_days s where s.user_id = p_user order by s.day loop
    if prev is null or d = prev + 1 then
      run := run + 1;
    else
      ok := d - prev <= 3;  -- at most two missed days, and they must be in different weeks
      pending := '{}';
      if ok then
        for gap in select prev + i from generate_series(1, d - prev - 1) i loop
          if daily_internal.week_start(gap) = any(used)
             or daily_internal.week_start(gap) = any(array(select daily_internal.week_start(x) from unnest(pending) x)) then
            ok := false;
          end if;
          pending := pending || gap;
        end loop;
      end if;
      if ok then
        used := used || array(select daily_internal.week_start(x) from unnest(pending) x);
        covered := covered || pending;
        run := run + 1;
      else
        run := 1;
      end if;
    end if;
    best := greatest(best, run);
    prev := d;

    if run in (3, 7, 30) then
      insert into public.daily_streak_badges (user_id, milestone, earned_on) values (p_user, run, d)
        on conflict do nothing;
    end if;
    if run = 7 and d = p_new_day then
      insert into public.daily_theme_grants (user_id, theme_id, streak_day, starts_at, expires_at)
        values (p_user, themes[1 + ((select count(*) from public.daily_theme_grants g where g.user_id = p_user) % 5)::int],
                d, p_at, p_at + interval '7 days')
        on conflict (user_id, streak_day) do nothing;
    end if;
  end loop;

  insert into public.daily_streaks (user_id, current_streak, best_streak, last_day, updated_at)
    values (p_user, run, best, prev, p_at)
    on conflict (user_id) do update set current_streak = excluded.current_streak,
      best_streak = excluded.best_streak, last_day = excluded.last_day, updated_at = excluded.updated_at;
  delete from public.daily_streak_freezes where user_id = p_user;
  insert into public.daily_streak_freezes (user_id, week_start, covered_day)
    select p_user, daily_internal.week_start(c), c from unnest(covered) c;
end
$$;

-- A player's streak as seen at `p_now`, including a freeze that would cover yesterday.
create function daily_internal.streak_state(p_user uuid, p_now timestamptz) returns jsonb
language plpgsql stable set search_path = '' as $$
declare
  today date := daily_internal.day_of(p_now);
  s public.daily_streaks;
  gap date[] := '{}';
  alive boolean := false;
  week_used boolean;
  next_day date;
  grant_row public.daily_theme_grants;
begin
  select * into s from public.daily_streaks where user_id = p_user;
  if found and s.last_day is not null and s.last_day <= today then
    if s.last_day >= today - 1 then
      alive := true;
    elsif today - s.last_day <= 3 then
      gap := array(select s.last_day + i from generate_series(1, today - s.last_day - 1) i);
      alive := (select count(distinct daily_internal.week_start(x)) = count(*) from unnest(gap) x)
        and not exists (select 1 from public.daily_streak_freezes f, unnest(gap) x
                        where f.user_id = p_user and f.week_start = daily_internal.week_start(x));
    end if;
  end if;
  if not alive then gap := '{}'; end if;

  week_used := exists (select 1 from public.daily_streak_freezes f
                       where f.user_id = p_user and f.week_start = daily_internal.week_start(today))
    or exists (select 1 from unnest(gap) x where daily_internal.week_start(x) = daily_internal.week_start(today));
  -- The next day that needs a take, and whether missing it alone would be forgiven.
  next_day := case when s.last_day = today then today + 1 else today end;
  select * into grant_row from public.daily_theme_grants g
    where g.user_id = p_user and g.starts_at <= p_now and g.expires_at > p_now order by g.expires_at desc limit 1;

  return jsonb_build_object(
    'current', case when alive then s.current_streak else 0 end,
    'best', coalesce(s.best_streak, 0),
    'last_day', s.last_day,
    'posted_today', coalesce(s.last_day = today, false),
    'alive', alive,
    'freeze_covering', to_jsonb(gap),
    'freeze_available', not week_used,
    'freeze_used_on', (select f.covered_day from public.daily_streak_freezes f
                       where f.user_id = p_user and f.week_start = daily_internal.week_start(today)),
    'ends_at', case when alive then daily_internal.day_start(next_day + 1) end,
    'freeze_would_cover', alive and not exists (
      select 1 from public.daily_streak_freezes f
      where f.user_id = p_user and f.week_start = daily_internal.week_start(next_day))
      and not exists (select 1 from unnest(gap) x where daily_internal.week_start(x) = daily_internal.week_start(next_day))
      and cardinality(gap) = 0,
    'badges', coalesce((select jsonb_agg(b.milestone order by b.milestone) from public.daily_streak_badges b
                        where b.user_id = p_user), '[]'::jsonb),
    'next_milestone', (select m from unnest(array[3, 7, 30]) m
                       where m > case when alive then s.current_streak else 0 end order by m limit 1),
    'theme_grant', case when grant_row.id is null then null
                        else jsonb_build_object('theme_id', grant_row.theme_id, 'expires_at', grant_row.expires_at) end
  );
end
$$;

-- --------------------------------------------------------- counting takes
-- After a post is published: if it was reserved during a day's window with that day's sound,
-- record the take and credit the day. The publication may finish shortly after midnight; it
-- still counts for the day it was submitted, up to six hours late. Never blocks publishing.
create function daily_internal.record_daily_take() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  taken_at timestamptz;
  take_day date;
  featured public.daily_sounds;
begin
  if new.hidden or new.video_key not like 'videos/' || new.user_id::text || '/screened/%' then return null; end if;
  taken_at := coalesce((select u.created_at from public.pending_video_uploads u where u.id = new.id), new.created_at);
  take_day := daily_internal.day_of(taken_at);
  if new.created_at >= daily_internal.day_start(take_day + 1) + interval '6 hours' then return null; end if;

  select * into featured from public.daily_sounds where day = take_day;
  if not found or new.id is not distinct from featured.video_id then return null; end if;
  if not (new.source_video_id is not null and new.source_video_id = featured.video_id)
     and daily_internal.sound_signature(new.sound_setup) is distinct from featured.signature then
    return null;
  end if;

  insert into public.daily_sound_takes (video_id, day, user_id, taken_at)
    values (new.id, take_day, new.user_id, taken_at) on conflict do nothing;
  insert into public.daily_streak_days (user_id, day, video_id, credited_at)
    values (new.user_id, take_day, new.id, new.created_at) on conflict do nothing;
  if found then
    perform daily_internal.rebuild_streak(new.user_id, take_day, new.created_at);
  end if;
  return null;
exception when others then
  raise warning 'daily sound take not recorded for %: %', new.id, sqlerrm;
  return null;
end
$$;
revoke all on function daily_internal.record_daily_take() from public, anon, authenticated;
create trigger record_daily_take after insert on public.videos
  for each row execute function daily_internal.record_daily_take();

-- ------------------------------------------------------------- client RPC
-- Today's sound, its visible takes, and the caller's streak (null when signed out).
-- Hidden posts, posts the caller reported, and creators blocked in either direction are
-- left out, because everything shown comes through `feed_videos` as the caller.
create function daily_internal.daily_payload(p_now timestamptz) returns jsonb
language plpgsql set search_path = '' as $$
declare
  today date := daily_internal.day_of(p_now);
  featured public.daily_sounds;
  viewer uuid := auth.uid();
begin
  featured := daily_internal.ensure_daily_sound(today);
  return jsonb_build_object(
    'day', today,
    'starts_at', daily_internal.day_start(today),
    'ends_at', daily_internal.day_start(today + 1),
    'server_now', p_now,
    'sound', case when featured.day is null then null else jsonb_build_object(
      'setup', featured.sound_setup,
      'title', featured.title,
      'note', featured.note,
      'source', featured.source,
      'video', (select to_jsonb(v) from public.feed_videos v where v.id = featured.video_id)) end,
    'take_count', (select count(*) from public.daily_sound_takes t join public.feed_videos v on v.id = t.video_id
                   where t.day = today),
    'takes', coalesce((select jsonb_agg(to_jsonb(top) order by top.like_count desc, top.created_at desc) from (
        select v.* from public.daily_sound_takes t join public.feed_videos v on v.id = t.video_id
        where t.day = today order by v.like_count desc, v.created_at desc limit 12) top), '[]'::jsonb),
    'streak', case when viewer is null then null else daily_internal.streak_state(viewer, p_now) end
  );
end
$$;

create function public.daily_sound_today() returns jsonb
language sql volatile security definer set search_path = '' as $$ select daily_internal.daily_payload(now()) $$;
revoke all on function public.daily_sound_today() from public;
grant execute on function public.daily_sound_today() to anon, authenticated;

-- A creator's public streak and badges for their profile (null if hidden from the caller).
create function public.daily_streak_profile(target_username text) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('current', state->'current', 'best', state->'best', 'badges', state->'badges')
  from public.profiles p, lateral daily_internal.streak_state(p.id, now()) state
  where p.username is not null and p.username::text = lower(target_username)
    and not public.is_blocked_between(auth.uid(), p.id)
$$;
revoke all on function public.daily_streak_profile(text) from public;
grant execute on function public.daily_streak_profile(text) to anon, authenticated;

-- ------------------------------------------------------------------ admin
-- Owner only (SQL editor or service role). See supabase/README.md "Daily sound".
create function public.schedule_daily_sound(p_day date, p_video_id uuid, p_title text default null,
                                            p_note text default null, p_allow_pro boolean default false)
returns public.daily_sounds language plpgsql security definer set search_path = '' as $$
declare
  post public.videos;
  result public.daily_sounds;
begin
  if p_day is null or p_day < daily_internal.day_of(now()) then
    raise exception 'DAILY_SOUND_IN_PAST' using errcode = 'P0001', hint = 'Days are UTC dates; schedule today or later.';
  end if;
  select * into post from public.videos where id = p_video_id;
  if not found or post.hidden or not exists (select 1 from public.profiles p where p.id = post.user_id and p.username is not null) then
    raise exception 'DAILY_SOUND_VIDEO_UNAVAILABLE' using errcode = 'P0001';
  end if;
  if not daily_internal.is_playable_sound(post.sound_setup) then
    raise exception 'DAILY_SOUND_NOT_PLAYABLE' using errcode = 'P0001', hint = 'The post has no shared playable preset.';
  end if;
  if not p_allow_pro and not daily_internal.is_free_sound(post.sound_setup) then
    raise exception 'DAILY_SOUND_NEEDS_PRO' using errcode = 'P0001',
      hint = 'Free players could not open it. Pass p_allow_pro => true to feature it anyway.';
  end if;
  if exists (select 1 from public.daily_sound_takes t where t.day = p_day) then
    raise exception 'DAILY_SOUND_HAS_TAKES' using errcode = 'P0001', hint = 'Takes were already counted for this day.';
  end if;
  insert into public.daily_sounds (day, video_id, creator_id, sound_setup, signature, source, title, note)
    values (p_day, post.id, post.user_id, post.sound_setup, daily_internal.sound_signature(post.sound_setup),
            'scheduled', nullif(btrim(p_title), ''), nullif(btrim(p_note), ''))
    on conflict (day) do update set video_id = excluded.video_id, creator_id = excluded.creator_id,
      sound_setup = excluded.sound_setup, signature = excluded.signature, source = 'scheduled',
      title = excluded.title, note = excluded.note, created_at = now()
    returning * into result;
  return result;
end
$$;

create function public.unschedule_daily_sound(p_day date) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if p_day < daily_internal.day_of(now()) or exists (select 1 from public.daily_sound_takes t where t.day = p_day) then
    raise exception 'DAILY_SOUND_LOCKED' using errcode = 'P0001', hint = 'Past days and days with takes stay as they are.';
  end if;
  delete from public.daily_sounds where day = p_day;
  return found;
end
$$;

-- ---------------------------------------------------- notification hooks
-- For the push notification service (service role). Nothing here sends anything.
-- "Today's sound is live": call at 00:00 UTC; picks the day's sound if nobody has yet.
create function public.daily_sound_live(p_now timestamptz default now())
returns table (day date, video_id uuid, creator_id uuid, title text, starts_at timestamptz, ends_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare featured public.daily_sounds;
begin
  featured := daily_internal.ensure_daily_sound(daily_internal.day_of(p_now));
  if featured.day is null then return; end if;
  return query select featured.day, featured.video_id, featured.creator_id, featured.title,
    daily_internal.day_start(featured.day), daily_internal.day_start(featured.day + 1);
end
$$;

-- "Your streak ends in 3 hours": live streaks without a take today whose deadline is within
-- `p_within`. `freeze_would_cover` is true when missing today would use this week's freeze
-- instead of ending the streak, so the caller can soften or skip the message.
create function public.daily_streaks_at_risk(p_within interval default interval '3 hours', p_now timestamptz default now())
returns table (user_id uuid, current_streak int, ends_at timestamptz, freeze_would_cover boolean)
language sql stable security definer set search_path = '' as $$
  select s.user_id, (state->>'current')::int, (state->>'ends_at')::timestamptz, (state->>'freeze_would_cover')::boolean
  from public.daily_streaks s, lateral daily_internal.streak_state(s.user_id, p_now) state
  where s.last_day >= daily_internal.day_of(p_now) - 3 and s.last_day < daily_internal.day_of(p_now)
    and (state->>'alive')::boolean
    and (state->>'ends_at')::timestamptz - p_now <= p_within
$$;

revoke all on function public.schedule_daily_sound(date, uuid, text, text, boolean),
  public.unschedule_daily_sound(date), public.daily_sound_live(timestamptz),
  public.daily_streaks_at_risk(interval, timestamptz) from public, anon, authenticated;
grant execute on function public.schedule_daily_sound(date, uuid, text, text, boolean),
  public.unschedule_daily_sound(date), public.daily_sound_live(timestamptz),
  public.daily_streaks_at_risk(interval, timestamptz) to service_role;
revoke all on all functions in schema daily_internal from public, anon, authenticated;
grant execute on all functions in schema daily_internal to service_role;
