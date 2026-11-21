-- Remote config, feature flags and the downloadable instrument catalog (1.0.3).
-- See docs/remote-updates.md. Clients read only through the security-definer
-- functions below; only the service role writes. Everything here is data that
-- shipped app code interprets; nothing is executable.

-- App versions: major.minor.patch, up to three numeric parts, missing parts 0
-- (shared/remote-config/fixtures/versions.json). Returns null when invalid.
create function public.app_version_parts(p_version text)
returns int[]
language sql
immutable
set search_path = ''
as $$
  select case
    when p_version ~ '^[0-9]{1,6}(\.[0-9]{1,6}){0,2}$' then
      (select array_agg(coalesce(part::int, 0) order by n)
         from generate_series(1, 3) as n
         left join lateral (select (string_to_array(p_version, '.'))[n] as part) parts on true)
    else null
  end;
$$;

-- Rollout bucket: uint32 of the first 4 bytes of SHA-256("<key>:<install_id>") mod 100
-- (shared/remote-config/fixtures/buckets.json). Apps compute this on the device; this
-- copy is for admin previews and tests.
create function public.app_config_bucket(p_key text, p_install_id text)
returns int
language sql
immutable
set search_path = ''
as $$
  select (('x' || substr(encode(sha256(convert_to(p_key || ':' || p_install_id, 'UTF8')), 'hex'), 1, 8))::bit(32)::bigint % 100)::int;
$$;

create table public.app_config (
  id bigint generated always as identity primary key,
  key text not null check (key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$' and length(key) <= 80),
  value jsonb not null,
  platform text not null default 'all' check (platform in ('all', 'ios', 'android', 'web')),
  min_app_version text check (min_app_version is null or public.app_version_parts(min_app_version) is not null),
  max_app_version text check (max_app_version is null or public.app_version_parts(max_app_version) is not null),
  rollout_percent smallint not null default 100 check (rollout_percent between 0 and 100),
  priority int not null default 0,
  enabled boolean not null default true,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (min_app_version is null or max_app_version is null
         or public.app_version_parts(min_app_version) <= public.app_version_parts(max_app_version))
);

create index app_config_key_idx on public.app_config (key);

alter table public.app_config enable row level security;
revoke all on public.app_config from public, anon, authenticated;
grant select, insert, update, delete on public.app_config to service_role;

create table public.instrument_catalog (
  id text primary key check (id ~ '^[a-z0-9][a-z0-9._-]{0,79}$' and id !~ '^builtin\.'),
  format_version int not null check (format_version >= 1),
  body jsonb not null check (jsonb_typeof(body) = 'object' and octet_length(body::text) <= 16384),
  platform text not null default 'all' check (platform in ('all', 'ios', 'android', 'web')),
  min_app_version text check (min_app_version is null or public.app_version_parts(min_app_version) is not null),
  published boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (body->>'id' = id),
  check (body->'format_version' = to_jsonb(format_version))
);

alter table public.instrument_catalog enable row level security;
revoke all on public.instrument_catalog from public, anon, authenticated;
grant select, insert, update, delete on public.instrument_catalog to service_role;

create function public.remote_content_touch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger app_config_touch before update on public.app_config
  for each row execute function public.remote_content_touch();
create trigger instrument_catalog_touch before update on public.instrument_catalog
  for each row execute function public.remote_content_touch();

-- Rows an app on this platform and version should consider, best first per key.
-- Rollout is applied on the device so the install id never leaves it.
create function public.app_config_for(p_platform text, p_app_version text)
returns table (id bigint, key text, value jsonb, rollout_percent smallint, priority int)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v int[] := public.app_version_parts(p_app_version);
begin
  if p_platform is null or p_platform not in ('ios', 'android', 'web') then
    raise exception 'Invalid platform' using errcode = '22023';
  end if;
  if v is null then
    raise exception 'Invalid app version' using errcode = '22023';
  end if;

  return query
    select c.id, c.key, c.value, c.rollout_percent, c.priority
      from public.app_config c
     where c.enabled
       and c.platform in ('all', p_platform)
       and (c.min_app_version is null or public.app_version_parts(c.min_app_version) <= v)
       and (c.max_app_version is null or public.app_version_parts(c.max_app_version) >= v)
     order by c.key, c.priority desc, c.id desc;
end;
$$;

revoke all on function public.app_config_for(text, text) from public, anon, authenticated;
grant execute on function public.app_config_for(text, text) to anon, authenticated, service_role;

-- Admin preview: what one install resolves to (rollout applied, types not checked).
create function public.app_config_resolve(p_platform text, p_app_version text, p_install_id text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(r.key, r.value), '{}'::jsonb)
    from (
      select distinct on (c.key) c.key, c.value
        from public.app_config_for(p_platform, p_app_version) c
       where public.app_config_bucket(c.key, p_install_id) < c.rollout_percent
       order by c.key, c.priority desc, c.id desc
    ) r;
$$;

revoke all on function public.app_config_resolve(text, text, text) from public, anon, authenticated;
grant execute on function public.app_config_resolve(text, text, text) to service_role;

-- Published instrument files an app can read. The app still runs every body
-- through its own loader and keeps bundled instruments on id collisions.
create function public.instrument_catalog_for(p_platform text, p_app_version text, p_max_format_version int)
returns table (id text, format_version int, body text, sort_order int, updated_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v int[] := public.app_version_parts(p_app_version);
begin
  if p_platform is null or p_platform not in ('ios', 'android', 'web') then
    raise exception 'Invalid platform' using errcode = '22023';
  end if;
  if v is null then
    raise exception 'Invalid app version' using errcode = '22023';
  end if;

  return query
    select i.id, i.format_version, i.body::text, i.sort_order, i.updated_at
      from public.instrument_catalog i
     where i.published
       and i.platform in ('all', p_platform)
       and i.format_version <= coalesce(p_max_format_version, 1)
       and (i.min_app_version is null or public.app_version_parts(i.min_app_version) <= v)
     order by i.sort_order, i.id
     limit 200;
end;
$$;

revoke all on function public.instrument_catalog_for(text, text, int) from public, anon, authenticated;
grant execute on function public.instrument_catalog_for(text, text, int) to anon, authenticated, service_role;

revoke all on function public.app_version_parts(text) from public, anon, authenticated;
revoke all on function public.app_config_bucket(text, text) from public, anon, authenticated;
grant execute on function public.app_version_parts(text) to anon, authenticated, service_role;
grant execute on function public.app_config_bucket(text, text) to anon, authenticated, service_role;
revoke all on function public.remote_content_touch() from public, anon, authenticated;
