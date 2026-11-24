-- Push notifications: device tokens, per-type preferences, and a queue that the
-- send-push Edge Function drains through APNs. Triggers enqueue; the function sends.
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;

create schema if not exists push_internal;
revoke all on schema push_internal from public, anon, authenticated;

-- ------------------------------------------------------------ device tokens
-- One row per APNs token. A token belongs to the account last signed in on that device.
create table public.device_tokens (
  token text primary key check (token ~ '^[0-9a-f]{64,200}$'),
  user_id uuid not null references public.profiles(id) on delete cascade,
  environment text not null check (environment in ('sandbox', 'production')),
  updated_at timestamptz not null default now()
);
create index device_tokens_user on public.device_tokens (user_id, environment);
alter table public.device_tokens enable row level security;
revoke all on public.device_tokens from public, anon, authenticated;
grant select, delete on public.device_tokens to authenticated;
grant all on public.device_tokens to service_role;
create policy "read own device tokens" on public.device_tokens for select to authenticated
using (user_id = (select auth.uid()));
create policy "remove own device tokens" on public.device_tokens for delete to authenticated
using (user_id = (select auth.uid()));

-- Registration goes through this function so a token moves to the account now
-- signed in on the device instead of failing on the other account's row.
create function public.register_device_token(p_token text, p_environment text) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'SIGN_IN_REQUIRED' using errcode = '42501'; end if;
  insert into public.device_tokens (token, user_id, environment)
  values (lower(p_token), me, p_environment)
  on conflict (token) do update
    set user_id = excluded.user_id, environment = excluded.environment, updated_at = now();
  -- Keep the 10 most recent devices per account.
  delete from public.device_tokens
  where user_id = me and token not in (
    select d.token from public.device_tokens d where d.user_id = me order by d.updated_at desc limit 10);
end
$$;
revoke all on function public.register_device_token(text, text) from public, anon;
grant execute on function public.register_device_token(text, text) to authenticated;

-- ------------------------------------------------------------- preferences
-- No row means every type is on.
create table public.notification_preferences (
  user_id uuid primary key default auth.uid() references public.profiles(id) on delete cascade,
  remixes boolean not null default true,
  take_replies boolean not null default true,
  likes boolean not null default true,
  comments boolean not null default true,
  following_posts boolean not null default true,
  challenges boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.notification_preferences enable row level security;
revoke all on public.notification_preferences from public, anon, authenticated;
grant select on public.notification_preferences to authenticated;
grant insert (remixes, take_replies, likes, comments, following_posts, challenges),
      update (remixes, take_replies, likes, comments, following_posts, challenges)
  on public.notification_preferences to authenticated;
grant all on public.notification_preferences to service_role;
create policy "read own notification preferences" on public.notification_preferences for select to authenticated
using (user_id = (select auth.uid()));
create policy "create own notification preferences" on public.notification_preferences for insert to authenticated
with check (user_id = (select auth.uid()));
create policy "change own notification preferences" on public.notification_preferences for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create function push_internal.touch_preferences() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end
$$;
create trigger touch_notification_preferences before update on public.notification_preferences
for each row execute function push_internal.touch_preferences();

create function push_internal.wants(recipient uuid, kind text) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select case kind
      when 'remix' then p.remixes
      when 'take_reply' then p.take_replies
      when 'like' then p.likes
      when 'comment' then p.comments
      when 'following_post' then p.following_posts
      when 'challenge' then p.challenges
    end
    from public.notification_preferences p where p.user_id = recipient), true)
$$;

-- ------------------------------------------------------------------- queue
-- Clients have no access. Rows are kept as a send log; `status` tracks delivery.
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('remix', 'take_reply', 'like', 'comment', 'following_post', 'challenge')),
  -- Latest actor; likes also keep every actor in the current batch.
  actor_id uuid references public.profiles(id) on delete cascade,
  actor_ids uuid[] not null default '{}',
  video_id uuid references public.videos(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  challenge_id uuid references public.weekly_challenges(id) on delete cascade,
  -- One push per recipient per key, e.g. 'video:<id>' for a new post or 'comment:<id>'.
  -- Likes have no key; they batch through the pending-like index below.
  dedupe_key text,
  send_after timestamptz not null default now(),
  created_at timestamptz not null default now(),
  status text not null default 'pending' check (status in ('pending', 'sending', 'sent', 'skipped', 'failed')),
  claimed_at timestamptz,
  sent_at timestamptz,
  attempts int not null default 0,
  last_error text,
  unique (recipient_id, dedupe_key)
);
create index notifications_due on public.notifications (send_after) where status = 'pending';
create unique index notifications_pending_like on public.notifications (recipient_id, video_id)
  where kind = 'like' and status = 'pending';
create index notifications_like_history on public.notifications (recipient_id, video_id, claimed_at desc)
  where kind = 'like';
create index notifications_video on public.notifications (video_id);
create index notifications_actor on public.notifications (actor_id);
create index notifications_comment on public.notifications (comment_id);
create index notifications_challenge on public.notifications (challenge_id);
alter table public.notifications enable row level security;
revoke all on public.notifications from public, anon, authenticated;
grant all on public.notifications to service_role;

-- When several triggers queue a push for the same new post, the most specific wins.
create function push_internal.kind_rank(kind text) returns int
language sql immutable set search_path = '' as $$
  select case kind when 'take_reply' then 3 when 'remix' then 2 when 'following_post' then 1 else 0 end
$$;

create function push_internal.enqueue(p_recipient uuid, p_actor uuid, p_kind text, p_video uuid,
                                      p_comment uuid, p_challenge uuid, p_dedupe_key text,
                                      p_send_after timestamptz default now()) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if p_recipient is null or p_recipient = p_actor
     or (p_actor is not null and public.is_blocked_between(p_recipient, p_actor))
     or not push_internal.wants(p_recipient, p_kind)
     or not exists (select 1 from public.device_tokens d where d.user_id = p_recipient) then
    return;
  end if;
  insert into public.notifications as n
    (recipient_id, actor_id, actor_ids, kind, video_id, comment_id, challenge_id, dedupe_key, send_after)
  values (p_recipient, p_actor, case when p_actor is null then '{}' else array[p_actor] end,
          p_kind, p_video, p_comment, p_challenge, p_dedupe_key, p_send_after)
  on conflict (recipient_id, dedupe_key) do update set kind = excluded.kind
    where n.status = 'pending' and push_internal.kind_rank(excluded.kind) > push_internal.kind_rank(n.kind);
end
$$;

-- -------------------------------------------------------------- new posts
-- Remixes / play-alongs notify the source's creator; every public post notifies followers.
create function push_internal.notify_new_video() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  key text := 'video:' || new.id;
  source_owner uuid;
begin
  if new.hidden or not exists (select 1 from public.profiles p where p.id = new.user_id and p.username is not null) then
    return null;
  end if;
  if new.source_video_id is not null then
    select v.user_id into source_owner from public.videos v where v.id = new.source_video_id and not v.hidden;
    perform push_internal.enqueue(source_owner, new.user_id, 'remix', new.id, null, null, key);
  end if;
  perform push_internal.enqueue(f.follower_id, new.user_id, 'following_post', new.id, null, null, key)
  from public.follows f where f.followee_id = new.user_id;
  return null;
end
$$;
create trigger push_new_video after insert on public.videos
for each row execute function push_internal.notify_new_video();

-- Take replies: call this from the reply feature's trigger once a reply post exists.
-- It takes over any remix or follower push already queued for the same reply post.
create function push_internal.notify_take_reply(reply_video uuid, replied_to_video uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  author uuid;
  recipient uuid;
begin
  select v.user_id into author from public.videos v where v.id = reply_video and not v.hidden;
  select v.user_id into recipient from public.videos v where v.id = replied_to_video and not v.hidden;
  if author is null then return; end if;
  perform push_internal.enqueue(recipient, author, 'take_reply', reply_video, null, null, 'video:' || reply_video);
end
$$;

-- ---------------------------------------------------------------- comments
create function push_internal.notify_comment() returns trigger
language plpgsql security definer set search_path = '' as $$
declare recipient uuid;
begin
  select v.user_id into recipient from public.videos v
  where v.id = new.video_id and not v.hidden and v.comments_enabled;
  if not new.hidden then
    perform push_internal.enqueue(recipient, new.user_id, 'comment', new.video_id, new.id, null, 'comment:' || new.id);
  end if;
  return null;
end
$$;
create trigger push_new_comment after insert on public.comments
for each row execute function push_internal.notify_comment();

-- ------------------------------------------------------------------- likes
-- At most one push per post per hour: new likes join the pending batch, and a new
-- batch waits until an hour after the previous one for the same post went out.
create function push_internal.notify_like() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  recipient uuid;
  last_batch timestamptz;
begin
  select v.user_id into recipient from public.videos v where v.id = new.video_id and not v.hidden;
  if recipient is null or recipient = new.user_id or public.is_blocked_between(recipient, new.user_id)
     or not push_internal.wants(recipient, 'like')
     or not exists (select 1 from public.device_tokens d where d.user_id = recipient) then
    return null;
  end if;

  update public.notifications
  set actor_id = case when new.user_id = any(actor_ids) then actor_id else new.user_id end,
      actor_ids = case when new.user_id = any(actor_ids) then actor_ids else actor_ids || new.user_id end
  where recipient_id = recipient and video_id = new.video_id and kind = 'like' and status = 'pending';
  if found then return null; end if;

  select max(n.claimed_at) into last_batch from public.notifications n
  where n.recipient_id = recipient and n.video_id = new.video_id and n.kind = 'like' and n.status <> 'pending';

  insert into public.notifications (recipient_id, actor_id, actor_ids, kind, video_id, send_after)
  values (recipient, new.user_id, array[new.user_id], 'like', new.video_id,
          greatest(now(), coalesce(last_batch + interval '1 hour', now())))
  on conflict (recipient_id, video_id) where kind = 'like' and status = 'pending' do nothing;
  return null;
end
$$;
create trigger push_new_like after insert on public.likes
for each row execute function push_internal.notify_like();

-- ------------------------------------------------------- weekly challenges
-- Announced when the window opens (curators may add rows ahead of time), once each,
-- and only within a day of the start so a late deploy doesn't announce old challenges.
create table push_internal.announced_challenges (
  challenge_id uuid primary key references public.weekly_challenges(id) on delete cascade,
  announced_at timestamptz not null default now()
);

create function push_internal.announce_started_challenges() returns void
language plpgsql security definer set search_path = '' as $$
declare challenge record;
begin
  for challenge in
    select w.id, w.source_video_id, v.user_id as source_owner from public.weekly_challenges w
    join public.videos v on v.id = w.source_video_id and not v.hidden and v.backing_enabled
    where w.featured and w.starts_at <= now() and w.ends_at > now() and w.starts_at > now() - interval '1 day'
      and not exists (select 1 from push_internal.announced_challenges a where a.challenge_id = w.id)
    for update of w skip locked
  loop
    insert into push_internal.announced_challenges (challenge_id) values (challenge.id);
    perform push_internal.enqueue(r.user_id, challenge.source_owner, 'challenge', challenge.source_video_id,
                                  null, challenge.id, 'challenge:' || challenge.id)
    from (select distinct d.user_id from public.device_tokens d) r;
  end loop;
end
$$;

-- ---------------------------------------------------------------- dispatch
-- Called only by the send-push function (service role). Marks due rows as sending,
-- drops ones that no longer apply, and returns what to send with the recipients' tokens.
create function public.claim_push_notifications(batch_size int default 100, apns_environment text default 'production')
returns table (id uuid, kind text, actor_username text, actor_count int, video_id uuid,
               comment_body text, video_caption text, challenge_title text, tokens text[])
language plpgsql security definer set search_path = '' as $$
declare claimed uuid[];
begin
  perform push_internal.announce_started_challenges();

  -- A run that died mid-send: give up rather than risk a duplicate push.
  update public.notifications n set status = 'failed', last_error = 'claim expired'
  where n.status = 'sending' and n.claimed_at < now() - interval '15 minutes';

  with due as (
    select n.id from public.notifications n
    where n.status = 'pending' and n.send_after <= now()
    order by n.send_after
    limit greatest(1, least(batch_size, 500))
    for update skip locked
  ), marked as (
    update public.notifications n set status = 'sending', claimed_at = now(), attempts = n.attempts + 1
    from due where n.id = due.id
    returning n.id
  )
  select coalesce(array_agg(marked.id), '{}') into claimed from marked;

  -- Recheck everything that can change after enqueueing.
  update public.notifications n set status = 'skipped', last_error = 'no longer applies'
  where n.id = any(claimed) and (
    not push_internal.wants(n.recipient_id, n.kind)
    or (n.actor_id is not null and public.is_blocked_between(n.recipient_id, n.actor_id))
    or (n.actor_id is not null and n.kind <> 'challenge' and not exists (
      select 1 from public.profiles p where p.id = n.actor_id and p.username is not null))
    or (n.kind = 'following_post' and not exists (
      select 1 from public.follows f where f.follower_id = n.recipient_id and f.followee_id = n.actor_id))
    or (n.video_id is not null and not exists (
      select 1 from public.videos v where v.id = n.video_id and not v.hidden))
    or (n.comment_id is not null and not exists (
      select 1 from public.comments cm join public.videos v on v.id = cm.video_id
      where cm.id = n.comment_id and not cm.hidden and v.comments_enabled))
    or (n.challenge_id is not null and not exists (
      select 1 from public.weekly_challenges w where w.id = n.challenge_id
        and w.featured and w.starts_at <= now() and w.ends_at > now()))
    or not exists (select 1 from public.device_tokens d
                   where d.user_id = n.recipient_id and d.environment = apns_environment));

  return query
  select n.id, n.kind, p.username::text,
         greatest(1, cardinality(array(
           select a from unnest(n.actor_ids) a
           where not public.is_blocked_between(n.recipient_id, a)
             and exists (select 1 from public.profiles ap where ap.id = a and ap.username is not null))))::int,
         n.video_id, cm.body, v.caption, w.title,
         array(select d.token from public.device_tokens d
               where d.user_id = n.recipient_id and d.environment = apns_environment
               order by d.updated_at desc)
  from public.notifications n
  left join public.profiles p on p.id = n.actor_id
  left join public.videos v on v.id = n.video_id
  left join public.comments cm on cm.id = n.comment_id
  left join public.weekly_challenges w on w.id = n.challenge_id
  where n.id = any(claimed) and n.status = 'sending';
end
$$;
revoke all on function public.claim_push_notifications(int, text) from public, anon, authenticated;
grant execute on function public.claim_push_notifications(int, text) to service_role;

-- Every minute, wake the send-push function when something is due. The function URL
-- and shared secret come from Vault (see supabase/README.md); without them this is a no-op.
create function push_internal.kick_dispatcher() returns void
language plpgsql security definer set search_path = '' as $$
declare
  url text;
  secret text;
begin
  select decrypted_secret into url from vault.decrypted_secrets where name = 'push_dispatch_url';
  select decrypted_secret into secret from vault.decrypted_secrets where name = 'push_dispatch_secret';
  if url is null or secret is null then return; end if;
  if not exists (select 1 from public.notifications where status = 'pending' and send_after <= now())
     and not exists (select 1 from public.weekly_challenges w
                     where w.featured and w.starts_at <= now() and w.ends_at > now()
                       and w.starts_at > now() - interval '1 day'
                       and not exists (select 1 from push_internal.announced_challenges a where a.challenge_id = w.id)) then
    return;
  end if;
  perform net.http_post(url := url, body := '{}'::jsonb,
                        headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', secret),
                        timeout_milliseconds := 55000);
end
$$;
revoke all on function push_internal.kick_dispatcher() from public, anon, authenticated;

select cron.schedule('send-push-notifications', '* * * * *', 'select push_internal.kick_dispatcher()');
