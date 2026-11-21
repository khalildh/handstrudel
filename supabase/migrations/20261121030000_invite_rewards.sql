-- Invite rewards: each account gets a personal invite code. When someone who entered that
-- code publishes their first screened take, both people are queued for 7 days of
-- HandStrudel+, which the `grant-invite-rewards` Edge Function grants through RevenueCat.
--
-- The intro tracker counts everyone who joined with your code (no cap) and awards milestone
-- badges at 1, 5, 10 and 25 intros. Only the count and badge are public; who joined through
-- whom is visible to the two people involved.
--
-- Anti-abuse is intentionally light, at the owner's request: one introducer per account,
-- no self-invites, one reward per redemption, granted only after the invited person's first
-- screened post, and a per-inviter reward cap (`invite_reward_limit`, one place to change).
--
-- Clients never write these tables directly; every change goes through the functions below.

create schema if not exists invite_internal;
revoke all on schema invite_internal from public, anon, authenticated;
grant usage on schema invite_internal to service_role;

-- ------------------------------------------------------------------ codes
create table public.invite_codes (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  code       text not null unique check (code ~ '^[A-Z2-9]{8}$'),
  created_at timestamptz not null default now()
);
alter table public.invite_codes enable row level security;
revoke all on public.invite_codes from public, anon, authenticated;
grant select on public.invite_codes to authenticated;
grant select, insert, update, delete on public.invite_codes to service_role;
create policy "read own invite code" on public.invite_codes
  for select to authenticated using (user_id = (select auth.uid()));

-- ------------------------------------------------------------------ redemptions
-- One accepted invite per invited account. The inviter link survives the inviter
-- deleting their account (set null), so the invited friend still gets their week.
create table public.invite_redemptions (
  invitee_id  uuid primary key references auth.users (id) on delete cascade,
  inviter_id  uuid references auth.users (id) on delete set null,
  -- How the new person named their introducer: an invite code (link or typed), or by
  -- picking their @username at sign-up (for in-person intros). Same rules either way.
  via         text not null default 'code' check (via in ('code', 'username')),
  code        text,
  redeemed_at timestamptz not null default clock_timestamp(),
  first_post_at timestamptz,
  check (inviter_id is distinct from invitee_id)
);
create index invite_redemptions_inviter_idx on public.invite_redemptions (inviter_id);
alter table public.invite_redemptions enable row level security;
revoke all on public.invite_redemptions from public, anon, authenticated;
grant select on public.invite_redemptions to authenticated;
grant select, insert, update, delete on public.invite_redemptions to service_role;
-- The invited person can see their own row. Inviters see only counts, via my_invite().
create policy "read own redemption" on public.invite_redemptions
  for select to authenticated using (invitee_id = (select auth.uid()));

-- ------------------------------------------------------------------ grants
-- The RevenueCat work queue. `status`: pending → granting → granted | failed.
-- A row stuck in `granting` (crash after claiming) is reclaimed after 5 minutes, and the
-- function checks RevenueCat before granting again so a retry cannot double-grant.
create table public.invite_reward_grants (
  id              uuid primary key default gen_random_uuid(),
  invitee_id      uuid not null references auth.users (id) on delete cascade,
  recipient_id    uuid not null references auth.users (id) on delete cascade,
  role            text not null check (role in ('inviter', 'invitee')),
  status          text not null default 'pending' check (status in ('pending', 'granting', 'granted', 'failed')),
  attempts        integer not null default 0,
  -- RevenueCat entitlements already granted for this row, so a partial failure resumes.
  granted_entitlements text[] not null default '{}',
  next_attempt_at timestamptz not null default now(),
  claimed_at      timestamptz,
  granted_at      timestamptz,
  expires_at      timestamptz,
  last_error      text check (char_length(last_error) <= 300),
  seen_at         timestamptz,
  created_at      timestamptz not null default now(),
  unique (invitee_id, role)
);
create index invite_reward_grants_due_idx on public.invite_reward_grants (next_attempt_at)
  where status in ('pending', 'granting');
create index invite_reward_grants_recipient_idx on public.invite_reward_grants (recipient_id, role);
alter table public.invite_reward_grants enable row level security;
revoke all on public.invite_reward_grants from public, anon, authenticated;
grant select, insert, update, delete on public.invite_reward_grants to service_role;

-- Small enough to stay readable on a phone; no 0/O/1/I/L confusion.
create function invite_internal.new_code() returns text
language plpgsql volatile set search_path = '' as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  bytes bytea := extensions.gen_random_bytes(8);
  result text := '';
begin
  for i in 0..7 loop
    result := result || substr(alphabet, 1 + (get_byte(bytes, i) % length(alphabet)), 1);
  end loop;
  return result;
end
$$;

-- ------------------------------------------------------------------ client API
-- The most free weeks one inviter can earn. Intros keep counting past it. Raise or remove
-- (e.g. return a very large number) here; nothing else hard-codes it.
create function public.invite_reward_limit() returns integer language sql immutable as $$ select 10 $$;

-- The caller's code (created on first use) and how many friends joined with it.
create function public.my_invite()
returns table (code text, friends_joined integer, friends_rewarded integer, reward_limit integer)
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'SIGN_IN_REQUIRED' using errcode = '42501'; end if;
  if not exists (select 1 from public.profiles p where p.id = me and p.username is not null) then
    raise exception 'PROFILE_REQUIRED' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.invite_codes c where c.user_id = me) then
    for attempt in 1..5 loop
      begin
        insert into public.invite_codes (user_id, code) values (me, invite_internal.new_code());
        exit;
      exception when unique_violation then
        if exists (select 1 from public.invite_codes c where c.user_id = me) then exit; end if;
        if attempt = 5 then raise; end if;
      end;
    end loop;
  end if;
  return query
    select c.code,
      (select count(*)::int from public.invite_redemptions r where r.inviter_id = me),
      (select count(*)::int from public.invite_reward_grants g where g.recipient_id = me and g.role = 'inviter'),
      public.invite_reward_limit()
    from public.invite_codes c where c.user_id = me;
end
$$;
revoke execute on function public.my_invite() from public, anon;
grant execute on function public.my_invite() to authenticated;

-- Records who introduced the caller's account, by invite code or, when `introducer` is given
-- instead, by the introducer's account (picked by @username). Returns
-- {"ok": true, "inviter": "<username>", "inviter_rewarded": bool} or {"ok": false, "reason": "<code>"}.
create function public.redeem_invite_code(invite_code text, introducer uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  normalized text := upper(regexp_replace(coalesce(invite_code, ''), '[^A-Za-z0-9]', '', 'g'));
  inviter uuid;
  used_code text;
  inviter_name text;
begin
  if me is null then raise exception 'SIGN_IN_REQUIRED' using errcode = '42501'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('invite:' || me::text, 7));

  if exists (select 1 from public.invite_redemptions r where r.invitee_id = me) then
    return jsonb_build_object('ok', false, 'reason', 'already_redeemed');
  end if;
  if introducer = me then return jsonb_build_object('ok', false, 'reason', 'self_invite'); end if;
  if introducer is not null then
    select p.id into inviter from public.profiles p where p.id = introducer and p.username is not null;
  else
    select c.user_id, c.code into inviter, used_code from public.invite_codes c where c.code = normalized;
  end if;
  if inviter is null then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
  if inviter = me then return jsonb_build_object('ok', false, 'reason', 'self_invite'); end if;
  -- The reward is triggered by the first screened post, so it must come before that.
  if exists (select 1 from public.videos v where v.user_id = me) then
    return jsonb_build_object('ok', false, 'reason', 'already_posted');
  end if;

  insert into public.invite_redemptions (invitee_id, inviter_id, via, code)
    values (me, inviter, case when introducer is null then 'code' else 'username' end, used_code);
  select p.username into inviter_name from public.profiles p where p.id = inviter;
  -- Past the inviter's reward cap the intro still counts and the new person still gets their
  -- week; only the inviter's week is skipped. Tell the client so its wording stays true.
  return jsonb_build_object('ok', true, 'inviter', inviter_name,
    'inviter_rewarded', (select count(*) from public.invite_reward_grants g
       where g.recipient_id = inviter and g.role = 'inviter') < public.invite_reward_limit());
end
$$;
revoke execute on function public.redeem_invite_code(text, uuid) from public, anon;
grant execute on function public.redeem_invite_code(text, uuid) to authenticated;

-- Rewards that have landed but haven't been celebrated in the app yet.
create function public.unseen_invite_rewards()
returns table (id uuid, role text, friend_username text, expires_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select g.id, g.role,
    case when g.role = 'inviter' then invitee.username else inviter.username end,
    g.expires_at
  from public.invite_reward_grants g
  join public.invite_redemptions r on r.invitee_id = g.invitee_id
  left join public.profiles invitee on invitee.id = r.invitee_id
  left join public.profiles inviter on inviter.id = r.inviter_id
  where g.recipient_id = auth.uid() and g.status = 'granted' and g.seen_at is null
  order by g.granted_at;
$$;
revoke execute on function public.unseen_invite_rewards() from public, anon;
grant execute on function public.unseen_invite_rewards() to authenticated;

create function public.mark_invite_rewards_seen(grant_ids uuid[])
returns void language sql security definer set search_path = '' as $$
  update public.invite_reward_grants set seen_at = now()
    where recipient_id = auth.uid() and id = any (grant_ids) and status = 'granted' and seen_at is null;
$$;
revoke execute on function public.mark_invite_rewards_seen(uuid[]) from public, anon;
grant execute on function public.mark_invite_rewards_seen(uuid[]) to authenticated;

-- ------------------------------------------------------------------ queueing
-- Videos are only inserted by publish_screened_video, after Sightengine clears the clip,
-- so an inserted, visible video is a screened take. The first one queues both rewards.
create function invite_internal.queue_rewards_for_first_post() returns trigger
language plpgsql security definer set search_path = '' as $$
declare redemption public.invite_redemptions%rowtype;
begin
  if new.hidden then return new; end if;
  update public.invite_redemptions set first_post_at = now()
    where invitee_id = new.user_id and first_post_at is null
    returning * into redemption;
  if not found then return new; end if;

  insert into public.invite_reward_grants (invitee_id, recipient_id, role)
    values (redemption.invitee_id, redemption.invitee_id, 'invitee')
    on conflict do nothing;
  if redemption.inviter_id is not null then
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('invite-cap:' || redemption.inviter_id::text, 7));
    if (select count(*) from public.invite_reward_grants g
          where g.recipient_id = redemption.inviter_id and g.role = 'inviter') < public.invite_reward_limit() then
      insert into public.invite_reward_grants (invitee_id, recipient_id, role)
        values (redemption.invitee_id, redemption.inviter_id, 'inviter')
        on conflict do nothing;
    end if;
  end if;
  return new;
end
$$;
create trigger queue_invite_rewards after insert on public.videos
  for each row execute function invite_internal.queue_rewards_for_first_post();

-- ------------------------------------------------------------------ worker API (service role)
-- Claims up to `max_rows` due grants. With `for_user`, only grants that involve that
-- account (as recipient or as the invited friend). `verify_first` is true when an earlier
-- attempt may have reached RevenueCat (a retry, or a reclaimed `granting` row), so the
-- worker checks for a promotional grant made since `previous_claim` before granting again.
create function public.claim_invite_grants(for_user uuid default null, max_rows integer default 20)
returns table (id uuid, recipient_id uuid, role text, attempts integer, claimed_at timestamptz,
               previous_claim timestamptz, verify_first boolean, granted_entitlements text[])
language plpgsql set search_path = '' as $$
begin
  return query
  with due as (
    select g.id, g.claimed_at as old_claim
    from public.invite_reward_grants g
    where ((g.status = 'pending' and g.next_attempt_at <= now())
        or (g.status = 'granting' and g.claimed_at < now() - interval '5 minutes'))
      and (for_user is null or g.recipient_id = for_user or g.invitee_id = for_user)
    order by g.next_attempt_at
    limit greatest(1, least(max_rows, 100))
    for update skip locked
  )
  update public.invite_reward_grants g
    set status = 'granting', attempts = g.attempts + 1, claimed_at = clock_timestamp()
    from due where g.id = due.id
    returning g.id, g.recipient_id, g.role, g.attempts, g.claimed_at, due.old_claim, due.old_claim is not null,
      g.granted_entitlements;
end
$$;
revoke execute on function public.claim_invite_grants(uuid, integer) from public, anon, authenticated;
grant execute on function public.claim_invite_grants(uuid, integer) to service_role;

-- Records the outcome of one claimed attempt. Ignored if the claim was superseded.
create function public.finish_invite_grant(grant_id uuid, claim timestamptz, succeeded boolean,
                                           reward_expires_at timestamptz default null, error text default null)
returns boolean language plpgsql set search_path = '' as $$
begin
  if succeeded then
    update public.invite_reward_grants set status = 'granted', granted_at = now(),
        expires_at = reward_expires_at, last_error = null
      where id = grant_id and status = 'granting' and claimed_at = claim;
  else
    update public.invite_reward_grants g set
        status = case when g.attempts >= 8 then 'failed' else 'pending' end,
        next_attempt_at = now() + least(interval '6 hours', interval '1 minute' * power(4, g.attempts - 1)),
        last_error = left(error, 300)
      where g.id = grant_id and g.status = 'granting' and g.claimed_at = claim;
  end if;
  return found;
end
$$;
revoke execute on function public.finish_invite_grant(uuid, timestamptz, boolean, timestamptz, text) from public, anon, authenticated;
grant execute on function public.finish_invite_grant(uuid, timestamptz, boolean, timestamptz, text) to service_role;

-- Notes that one entitlement of a claimed grant reached RevenueCat.
create function public.record_invite_entitlement(grant_id uuid, claim timestamptz, entitlement text)
returns boolean language plpgsql set search_path = '' as $$
begin
  update public.invite_reward_grants
    set granted_entitlements = array_append(granted_entitlements, entitlement)
    where id = grant_id and status = 'granting' and claimed_at = claim
      and not (entitlement = any (granted_entitlements));
  return found;
end
$$;
revoke execute on function public.record_invite_entitlement(uuid, timestamptz, text) from public, anon, authenticated;
grant execute on function public.record_invite_entitlement(uuid, timestamptz, text) to service_role;

-- ------------------------------------------------------------------ intro tracker
-- Milestone badges, awarded once and kept (a badge isn't taken back if an invited account
-- is later deleted). Public, like the count.
create table public.invite_milestones (
  user_id    uuid not null references auth.users (id) on delete cascade,
  milestone  integer not null check (milestone in (1, 5, 10, 25)),
  reached_at timestamptz not null default now(),
  primary key (user_id, milestone)
);
alter table public.invite_milestones enable row level security;
revoke all on public.invite_milestones from public, anon, authenticated;
grant select on public.invite_milestones to anon, authenticated;
grant select, insert, update, delete on public.invite_milestones to service_role;
create policy "milestones are public" on public.invite_milestones for select to anon, authenticated using (true);

create function public.intro_badge_name(milestone integer) returns text
language sql immutable set search_path = '' as $$
  select case milestone when 1 then 'Spark' when 5 then 'Bandleader' when 10 then 'Connector'
                        when 25 then 'Headliner' end;
$$;
grant execute on function public.intro_badge_name(integer) to anon, authenticated;

create function invite_internal.award_intro_milestones() returns trigger
language plpgsql security definer set search_path = '' as $$
declare intros integer;
begin
  if new.inviter_id is null then return new; end if;
  select count(*) into intros from public.invite_redemptions r where r.inviter_id = new.inviter_id;
  insert into public.invite_milestones (user_id, milestone)
    select new.inviter_id, m from unnest(array[1, 5, 10, 25]) m where m <= intros
    on conflict do nothing;
  return new;
end
$$;
create trigger award_intro_milestones after insert on public.invite_redemptions
  for each row execute function invite_internal.award_intro_milestones();

-- Anyone's public intro count and highest badge (no names).
create function public.intro_stats(profile_id uuid)
returns table (intros integer, milestone integer, badge text)
language sql stable security definer set search_path = '' as $$
  select (select count(*)::int from public.invite_redemptions r where r.inviter_id = profile_id),
         top.milestone, public.intro_badge_name(top.milestone)
  from (select max(m.milestone) as milestone from public.invite_milestones m where m.user_id = profile_id) top;
$$;
revoke execute on function public.intro_stats(uuid) from public;
grant execute on function public.intro_stats(uuid) to anon, authenticated;

-- The caller's own intros, newest first. Only the inviter can list them.
create function public.my_intros()
returns table (user_id uuid, username text, display_name text, avatar_key text,
               joined_at timestamptz, posted_first_take boolean)
language sql stable security definer set search_path = '' as $$
  select r.invitee_id, p.username::text, p.display_name, p.avatar_key, r.redeemed_at, r.first_post_at is not null
  from public.invite_redemptions r
  left join public.profiles p on p.id = r.invitee_id
  where r.inviter_id = auth.uid()
  order by r.redeemed_at desc, r.invitee_id
  limit 200;
$$;
revoke execute on function public.my_intros() from public, anon;
grant execute on function public.my_intros() to authenticated;

-- "Introduced by @handle", for the invited person only. Private by default: the link
-- between two accounts is known to those two and nobody else.
create function public.my_introducer()
returns table (user_id uuid, username text, display_name text, avatar_key text)
language sql stable security definer set search_path = '' as $$
  select p.id, p.username::text, p.display_name, p.avatar_key
  from public.invite_redemptions r join public.profiles p on p.id = r.inviter_id
  where r.invitee_id = auth.uid();
$$;
revoke execute on function public.my_introducer() from public, anon;
grant execute on function public.my_introducer() to authenticated;
