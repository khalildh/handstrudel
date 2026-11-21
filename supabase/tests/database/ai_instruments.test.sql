-- "Make your own instrument": daily quotas from remote config, the private
-- generation log, and players' saved instruments.
begin;
select plan(30);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'maker@test.dev'),
  ('00000000-0000-0000-0000-0000000000b2', 'other@test.dev');
truncate public.app_config restart identity;

-- Defaults when no config row exists.
set local role service_role;
select is(public.instrument_generation_limit('free'), 5, 'free players get 5 a day by default');
select is(public.instrument_generation_limit('pro'), 25, 'Pro players get 25 by default');
select is(public.instrument_generation_limit('plus'), 50, 'Plus players get 50 by default');

-- Remote config tunes the limits live.
insert into public.app_config (key, value, platform, priority, enabled) values
  ('ai_instruments.daily_limit_free', '2', 'all', 0, true),
  ('ai_instruments.daily_limit_free', '9', 'android', 5, true),
  ('ai_instruments.daily_limit_free', '7', 'all', 9, false),
  ('ai_instruments.daily_limit_pro', '"lots"', 'all', 0, true);
select is(public.instrument_generation_limit('free'), 2, 'the enabled all/iOS row sets the free limit');
select is(public.instrument_generation_limit('pro'), 25, 'a wrongly typed value keeps the default');

-- Claims count per user per UTC day.
select is((select row(allowed, used, daily_limit)::text from public.claim_instrument_generation(
  '00000000-0000-0000-0000-0000000000a1', 'free', 'create', 'a big glowing wheel', 'builtin.wide-wheel')),
  '(t,1,2)', 'the first claim is allowed');
select is((select row(allowed, used, daily_limit)::text from public.claim_instrument_generation(
  '00000000-0000-0000-0000-0000000000a1', 'free', 'refine', 'more glow', null)),
  '(t,2,2)', 'the second claim is allowed');
select is((select row(allowed, used, daily_limit, generation_id)::text from public.claim_instrument_generation(
  '00000000-0000-0000-0000-0000000000a1', 'free', 'create', 'one more', null)),
  '(f,2,2,)', 'the third claim is refused and records nothing');
select is((select count(*)::int from public.instrument_generations where user_id = '00000000-0000-0000-0000-0000000000a1'),
  2, 'only allowed claims are logged');
select is((select allowed from public.claim_instrument_generation(
  '00000000-0000-0000-0000-0000000000a1', 'pro', 'create', 'pro gets more', null)),
  true, 'a higher tier has room left');
select is((select allowed from public.claim_instrument_generation(
  '00000000-0000-0000-0000-0000000000b2', 'free', 'create', 'someone else', null)),
  true, 'quotas are per player');
select is((select allowed from public.claim_instrument_generation(
  '00000000-0000-0000-0000-0000000000b2', 'gold', 'create', 'unknown tier', null)),
  true, 'an unknown tier is treated as free');
select is((select tier from public.instrument_generations where prompt = 'unknown tier'), 'free',
  'and logged as free');

-- Yesterday's generations and blocked prompts don't count.
update public.instrument_generations set created_at = now() - interval '1 day'
 where user_id = '00000000-0000-0000-0000-0000000000a1';
select public.log_blocked_instrument_prompt('00000000-0000-0000-0000-0000000000a1', 'create', 'blocked words', 'slur:x');
select is((select used from public.claim_instrument_generation(
  '00000000-0000-0000-0000-0000000000a1', 'free', 'create', 'a new day', null)),
  1, 'yesterday and blocked prompts are not counted');

-- Finishing records the result once.
select public.finish_instrument_generation(
  (select id from public.instrument_generations where prompt = 'a new day'), 'repaired', 2, 1840, 'claude-haiku-5-5',
  '{"format":"handstrudel.instrument","id":"ai.abc"}', '{"key":"D","scale":"Minor","bpm":null}',
  array['attempt 1 schema: $.surface.radius: must be <= 1'], 3100, 220, 0.00042, null);
select is((select row(status, attempts, latency_ms, result->>'id', suggestion->>'scale')::text
             from public.instrument_generations where prompt = 'a new day'),
  '(repaired,2,1840,ai.abc,Minor)', 'the result, suggestion and latency are stored');
select public.finish_instrument_generation(
  (select id from public.instrument_generations where prompt = 'a new day'), 'ok', 1, 1, 'x', null, null, null, 0, 0, 0, null);
select is((select status from public.instrument_generations where prompt = 'a new day'), 'repaired',
  'a finished generation cannot be rewritten');
reset role;

-- The log is private to its player, and only the server writes it.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select is((select count(*)::int from public.instrument_generations), 2, 'players see only their own generations');
select throws_ok($$insert into public.instrument_generations (user_id, kind, prompt)
  values ('00000000-0000-0000-0000-0000000000b2', 'create', 'free generation')$$, '42501', null,
  'players cannot log generations themselves');
select throws_ok($$update public.instrument_generations set created_at = now() - interval '2 days'$$, '42501', null,
  'players cannot age out their quota');
select throws_ok($$select public.claim_instrument_generation('00000000-0000-0000-0000-0000000000b2', 'plus', 'create', 'x', null)$$,
  '42501', null, 'players cannot claim quota directly');
select throws_ok($$select public.instrument_generation_limit('free')$$, '42501', null, 'the limit lookup is server-only');

-- My instruments: private, owner-only, validated shape.
select lives_ok($$insert into public.my_instruments (id, body, prompt) values ('ai.b2b2',
  '{"format":"handstrudel.instrument","format_version":1,"id":"ai.b2b2","name":"Mine","ai_generated":true}', 'mine')$$,
  'a player saves an instrument');
select is((select ai_generated from public.my_instruments where id = 'ai.b2b2'), true, 'the AI marker is readable');
select throws_ok($$insert into public.my_instruments (id, body) values ('builtin.scale-wheel',
  '{"format":"handstrudel.instrument","format_version":1,"id":"builtin.scale-wheel","name":"Fake"}')$$, '23514', null,
  'built-in ids are reserved');
select throws_ok($$insert into public.my_instruments (id, body) values ('ai.mismatch',
  '{"format":"handstrudel.instrument","format_version":1,"id":"ai.other","name":"X"}')$$, '23514', null,
  'the body id must match');
select throws_ok($$insert into public.my_instruments (user_id, id, body) values ('00000000-0000-0000-0000-0000000000a1', 'ai.planted',
  '{"format":"handstrudel.instrument","format_version":1,"id":"ai.planted","name":"X"}')$$, '42501', null,
  'players cannot save into another account');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select is((select count(*)::int from public.my_instruments), 0, 'other players cannot see saved instruments');
select is((select count(*)::int from public.instrument_generations), 5, 'the first player sees their own log');
update public.my_instruments set body = body || '{"name":"Stolen"}' where id = 'ai.b2b2';
delete from public.my_instruments where id = 'ai.b2b2';
reset role;
select is((select body->>'name' from public.my_instruments where id = 'ai.b2b2'), 'Mine',
  'other players cannot change or delete them');

set local role anon;
select throws_ok($$select * from public.my_instruments$$, '42501', null, 'signed-out clients read nothing');
reset role;

select * from finish();
rollback;
