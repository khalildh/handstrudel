-- "Make your own instrument" (1.0.3): generation log + daily quotas for the
-- generate-instrument Edge Function, and each player's saved instruments.
-- See docs/ai-instruments.md. Instrument bodies are data the app's own loader
-- checks and its own code draws; nothing stored here is executed.

-- Every generation request, for quotas, abuse review and evals. Players can
-- read their own rows; only the service role (the Edge Function) writes.
create table public.instrument_generations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('create', 'refine')),
  status text not null default 'pending' check (status in ('pending', 'ok', 'repaired', 'fallback', 'blocked')),
  tier text check (tier in ('free', 'pro', 'plus')),
  prompt text not null check (length(prompt) between 1 and 600),
  seed_id text,
  model text,
  attempts smallint check (attempts between 0 and 5),
  latency_ms int check (latency_ms >= 0),
  input_tokens int check (input_tokens >= 0),
  output_tokens int check (output_tokens >= 0),
  cost_usd numeric(12, 8) check (cost_usd >= 0),
  result jsonb check (result is null or (jsonb_typeof(result) = 'object' and octet_length(result::text) <= 16384)),
  suggestion jsonb check (suggestion is null or jsonb_typeof(suggestion) = 'object'),
  issues text[] not null default '{}',
  error text,
  block_reason text,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);

create index instrument_generations_user_day_idx on public.instrument_generations (user_id, created_at desc);

alter table public.instrument_generations enable row level security;
revoke all on public.instrument_generations from public, anon, authenticated;
grant select on public.instrument_generations to authenticated;
grant select, insert, update, delete on public.instrument_generations to service_role;

create policy "players read their own generations" on public.instrument_generations
  for select to authenticated using (user_id = (select auth.uid()));

-- Daily limit for a tier, tunable live with remote config rows
-- (ai_instruments.daily_limit_free / _pro / _plus, shared/remote-config/keys.json).
-- The highest-priority enabled row for all platforms or iOS wins; rollout
-- percentages and app versions don't apply server-side. 0 turns generation off.
create function public.instrument_generation_limit(p_tier text)
returns int
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select least(greatest(floor((c.value #>> '{}')::numeric)::int, 0), 1000)
       from public.app_config c
      where c.key = 'ai_instruments.daily_limit_' || p_tier
        and c.enabled
        and c.platform in ('all', 'ios')
        and jsonb_typeof(c.value) = 'number'
      order by c.priority desc, c.id desc
      limit 1),
    case p_tier when 'plus' then 50 when 'pro' then 25 else 5 end);
$$;

-- Atomically checks today's (UTC) count and, when under the limit, records a
-- pending generation. Blocked prompts don't count; pending ones do.
create function public.claim_instrument_generation(p_user_id uuid, p_tier text, p_kind text, p_prompt text, p_seed_id text)
returns table (allowed boolean, used int, daily_limit int, generation_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  tier text := case when p_tier in ('free', 'pro', 'plus') then p_tier else 'free' end;
  lim int := public.instrument_generation_limit(tier);
  today timestamptz := date_trunc('day', now() at time zone 'utc') at time zone 'utc';
  n int;
  new_id uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended('instrument_generation:' || p_user_id::text, 0));
  select count(*) into n
    from public.instrument_generations g
   where g.user_id = p_user_id and g.created_at >= today and g.status <> 'blocked';
  if n >= lim then
    return query select false, n, lim, null::uuid;
    return;
  end if;
  insert into public.instrument_generations (user_id, kind, tier, prompt, seed_id)
  values (p_user_id, p_kind, tier, left(p_prompt, 600), p_seed_id)
  returning id into new_id;
  return query select true, n + 1, lim, new_id;
end;
$$;

create function public.finish_instrument_generation(
  p_generation_id uuid, p_status text, p_attempts int, p_latency_ms int, p_model text, p_result jsonb,
  p_suggestion jsonb, p_issues text[], p_input_tokens int, p_output_tokens int, p_cost_usd numeric, p_error text)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  update public.instrument_generations
     set status = p_status, attempts = p_attempts, latency_ms = p_latency_ms, model = p_model,
         result = case when jsonb_typeof(p_result) = 'object' then p_result end,
         suggestion = case when jsonb_typeof(p_suggestion) = 'object' then p_suggestion end,
         issues = coalesce(p_issues, '{}'), input_tokens = p_input_tokens, output_tokens = p_output_tokens,
         cost_usd = p_cost_usd, error = left(p_error, 500), finished_at = now()
   where id = p_generation_id and status = 'pending';
$$;

create function public.log_blocked_instrument_prompt(p_user_id uuid, p_kind text, p_prompt text, p_reason text)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  insert into public.instrument_generations (user_id, kind, status, prompt, block_reason, attempts, finished_at)
  values (p_user_id, p_kind, 'blocked', left(p_prompt, 600), left(p_reason, 100), 0, now());
$$;

revoke all on function public.instrument_generation_limit(text) from public, anon, authenticated;
revoke all on function public.claim_instrument_generation(uuid, text, text, text, text) from public, anon, authenticated;
revoke all on function public.finish_instrument_generation(uuid, text, int, int, text, jsonb, jsonb, text[], int, int, numeric, text) from public, anon, authenticated;
revoke all on function public.log_blocked_instrument_prompt(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.instrument_generation_limit(text) to service_role;
grant execute on function public.claim_instrument_generation(uuid, text, text, text, text) to service_role;
grant execute on function public.finish_instrument_generation(uuid, text, int, int, text, jsonb, jsonb, text[], int, int, numeric, text) to service_role;
grant execute on function public.log_blocked_instrument_prompt(uuid, text, text, text) to service_role;

-- "My instruments": instruments a player saved, synced to their account so
-- they survive a reinstall. Private to the owner. The app validates every
-- body with InstrumentSpec.load when it reads them back.
create table public.my_instruments (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null check (id ~ '^[a-z0-9][a-z0-9._-]{0,79}$' and id !~ '^builtin\.'),
  body jsonb not null check (
    jsonb_typeof(body) = 'object'
    and octet_length(body::text) <= 16384
    and body->>'format' = 'handstrudel.instrument'
    and jsonb_typeof(body->'format_version') = 'number'),
  ai_generated boolean generated always as (case when jsonb_typeof(body->'ai_generated') = 'boolean' then (body->'ai_generated')::boolean else false end) stored,
  prompt text check (prompt is null or length(prompt) <= 600),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id),
  check (body->>'id' = id)
);

alter table public.my_instruments enable row level security;
revoke all on public.my_instruments from public, anon, authenticated;
grant select, insert, update, delete on public.my_instruments to authenticated;
grant select, insert, update, delete on public.my_instruments to service_role;

create policy "players read their own instruments" on public.my_instruments
  for select to authenticated using (user_id = (select auth.uid()));
create policy "players add their own instruments" on public.my_instruments
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "players change their own instruments" on public.my_instruments
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "players delete their own instruments" on public.my_instruments
  for delete to authenticated using (user_id = (select auth.uid()));

-- At most 200 saved instruments per player; edits bump updated_at.
create function public.my_instruments_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' and (select count(*) from public.my_instruments m where m.user_id = new.user_id) >= 200 then
    raise exception 'You can keep up to 200 instruments' using errcode = '54000';
  end if;
  new.updated_at := now();
  if tg_op = 'UPDATE' then new.created_at := old.created_at; end if;
  return new;
end;
$$;

revoke all on function public.my_instruments_guard() from public, anon, authenticated;

create trigger my_instruments_guard before insert or update on public.my_instruments
  for each row execute function public.my_instruments_guard();
