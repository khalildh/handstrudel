-- Admin moderation: review reported posts and comments, hide/restore them,
-- dismiss reports, and ban/unban accounts. Every action is audited.
--
-- Admins live in a private schema that the API never exposes and no client role
-- can write. The owner makes an account an admin once, from the SQL editor:
--
--   insert into moderation_internal.admins (user_id, note)
--   select id, 'owner' from auth.users where email = '<your sign-in email>';
--
-- Visibility stays on the existing `hidden` flags, which every feed view, RLS
-- policy, count and the clip-media worker already check. Two new columns record
-- *why* something is hidden so restores and unbans put back exactly what they took:
--   admin_hidden_at  set when an admin hid the item (cleared on restore)
--   ban_hidden       set when a ban hid an item that was visible (cleared on unban)
-- An item that is hidden with neither marker was hidden automatically by reports.

create schema moderation_internal;
revoke all on schema moderation_internal from public;
-- Only definer functions in this schema are callable by clients; its tables have no client grants.
grant usage on schema moderation_internal to anon, authenticated, service_role;

create table moderation_internal.admins (
  user_id  uuid primary key references auth.users (id) on delete cascade,
  added_at timestamptz not null default now(),
  note     text
);

create table moderation_internal.bans (
  user_id   uuid primary key references public.profiles (id) on delete cascade,
  banned_at timestamptz not null default now(),
  banned_by uuid,
  note      text
);

-- Audit log. No foreign keys: entries outlive deleted posts, comments and accounts.
create table moderation_internal.actions (
  id             bigint generated always as identity primary key,
  admin_id       uuid not null,
  action         text not null check (action in ('hide', 'restore', 'dismiss', 'ban', 'unban')),
  target_kind    text not null check (target_kind in ('post', 'comment', 'user')),
  target_id      uuid not null,
  target_user_id uuid,
  note           text check (char_length(note) <= 500),
  created_at     timestamptz not null default now()
);
create index moderation_actions_recent on moderation_internal.actions (created_at desc, id desc);
create index moderation_actions_target on moderation_internal.actions (target_id, created_at desc);

revoke all on all tables in schema moderation_internal from public, anon, authenticated;
grant all on all tables in schema moderation_internal to service_role;
alter table moderation_internal.admins  enable row level security;
alter table moderation_internal.bans    enable row level security;
alter table moderation_internal.actions enable row level security;

-- ------------------------------------------------------------ moderation state
alter table public.videos   add column admin_hidden_at timestamptz,
                            add column ban_hidden boolean not null default false;
alter table public.comments add column admin_hidden_at timestamptz,
                            add column ban_hidden boolean not null default false;

-- A report is open until an admin acts on its item.
alter table public.reports         add column reviewed_at timestamptz;
alter table public.comment_reports add column reviewed_at timestamptz;
create index reports_open_idx on public.reports (video_id) where reviewed_at is null;
create index comment_reports_open_idx on public.comment_reports (comment_id) where reviewed_at is null;

-- Clients could insert any column of `reports`; narrow that to what the app sends
-- so a report can't arrive already reviewed. (comment_reports was already column-scoped.)
revoke insert on public.reports from authenticated;
grant insert (reporter_id, video_id, reason) on public.reports to authenticated;

-- Videos are only written by the service (publish_screened_video) and by owners
-- through column grants that don't include the new columns, but keep the
-- update trigger authoritative as well.
create or replace function public.protect_video_columns() returns trigger
language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon') then
    new.like_count      := old.like_count;
    new.report_count    := old.report_count;
    new.hidden          := old.hidden;
    new.user_id         := old.user_id;
    new.video_key       := old.video_key;
    new.thumb_key       := old.thumb_key;
    new.admin_hidden_at := old.admin_hidden_at;
    new.ban_hidden      := old.ban_hidden;
  end if;
  return new;
end $$;

-- Auto-hide counts only reports an admin hasn't reviewed, so an item an admin
-- restored needs three fresh reports to be hidden again.
create or replace function public.bump_report_count() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.videos v
     set report_count = v.report_count + 1,
         hidden = v.hidden or (select count(*) from public.reports r
                                where r.video_id = v.id and r.reviewed_at is null) >= 3
   where v.id = new.video_id;
  return null;
end $$;

create or replace function comment_internal.count_comment_report() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.comments c
     set report_count = c.report_count + 1,
         hidden = c.hidden or (select count(*) from public.comment_reports r
                                where r.comment_id = c.id and r.reviewed_at is null) >= 3
   where c.id = new.comment_id;
  return null;
end $$;

-- ------------------------------------------------------------------ helpers
create function moderation_internal.is_admin(uid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select uid is not null and exists (select 1 from moderation_internal.admins a where a.user_id = uid)
$$;

create function moderation_internal.is_banned(uid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select uid is not null and exists (select 1 from moderation_internal.bans b where b.user_id = uid)
$$;

create function moderation_internal.require_admin() returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if not moderation_internal.is_admin(uid) then
    raise exception 'NOT_ADMIN' using errcode = '42501';
  end if;
  return uid;
end $$;

create function moderation_internal.log(
  admin uuid, act text, kind text, target uuid, target_user uuid, note text
) returns void language sql security definer set search_path = '' as $$
  insert into moderation_internal.actions (admin_id, action, target_kind, target_id, target_user_id, note)
  values (admin, act, kind, target, target_user, nullif(btrim(note), ''))
$$;

-- The author of a post or comment, or an error when it doesn't exist.
create function moderation_internal.author_of(kind text, target uuid) returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare author uuid;
begin
  if kind = 'post' then
    select v.user_id into author from public.videos v where v.id = target;
  elsif kind = 'comment' then
    select c.user_id into author from public.comments c where c.id = target;
  else
    raise exception 'MODERATION_BAD_KIND' using errcode = '22023';
  end if;
  if author is null then
    raise exception 'MODERATION_TARGET_NOT_FOUND' using errcode = 'P0002';
  end if;
  return author;
end $$;

create function moderation_internal.review_reports(kind text, target uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if kind = 'post' then
    update public.reports set reviewed_at = now() where video_id = target and reviewed_at is null;
  else
    update public.comment_reports set reviewed_at = now() where comment_id = target and reviewed_at is null;
  end if;
end $$;

-- ------------------------------------------------------- banned accounts can't post
create function moderation_internal.refuse_banned_author() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if moderation_internal.is_banned(new.user_id) then
    raise exception 'ACCOUNT_BANNED' using errcode = 'P0001',
      hint = 'This account can no longer post or comment because it broke the community guidelines.';
  end if;
  return new;
end $$;

-- Covers every way a post or comment is created (publish_screened_video, replies,
-- play-alongs, direct inserts) without redefining those functions.
create trigger moderation_refuse_banned_post before insert on public.videos
  for each row execute function moderation_internal.refuse_banned_author();
create trigger moderation_refuse_banned_comment before insert on public.comments
  for each row execute function moderation_internal.refuse_banned_author();
-- Stop a banned account at reservation, before it uploads anything (sign-upload).
create trigger moderation_refuse_banned_upload before insert on public.pending_video_uploads
  for each row execute function moderation_internal.refuse_banned_author();

-- Banned accounts disappear from creator lookups and search, as well as having
-- every post and comment hidden.
create or replace view public.public_creators with (security_invoker = true) as
select p.id, p.username, p.display_name, p.avatar_key, totals.likes_received, totals.views_received
from public.profiles p
cross join lateral (
  select coalesce(sum(v.like_count), 0) as likes_received,
         coalesce(sum(v.view_count), 0)::bigint as views_received
  from public.videos v
  where v.user_id = p.id and not v.hidden
) totals
where p.username is not null and not public.is_blocked_between(auth.uid(), p.id)
  and not moderation_internal.is_banned(p.id);

-- ------------------------------------------------------------------- client RPCs
-- Whether the signed-in account may open the Moderation screen.
create function public.is_moderator() returns boolean
language sql stable security definer set search_path = '' as $$
  select moderation_internal.is_admin(auth.uid())
$$;

-- Whether the signed-in account is banned (the app shows why posting fails).
create function public.my_account_banned() returns boolean
language sql stable security definer set search_path = '' as $$
  select moderation_internal.is_banned(auth.uid())
$$;

-- Reported or moderated posts and comments.
--   queue_filter: 'open' (unreviewed reports), 'hidden' (anything hidden by reports, an admin or a ban), 'all'
--   sort_by:      'newest' (latest report first) or 'most' (most open reports first)
create function public.moderation_queue(
  queue_filter text default 'open', sort_by text default 'newest',
  page_size integer default 50, page_offset integer default 0
) returns table (
  target_kind text, target_id uuid, video_id uuid,
  author_id uuid, author_username text, author_banned boolean,
  body text, thumb_key text, video_key text, created_at timestamptz,
  open_reports bigint, total_reports bigint, reasons text[], last_reported_at timestamptz,
  state text
) language plpgsql stable security definer set search_path = '' as $$
begin
  perform moderation_internal.require_admin();
  if queue_filter not in ('open', 'hidden', 'all') or sort_by not in ('newest', 'most') then
    raise exception 'MODERATION_BAD_FILTER' using errcode = '22023';
  end if;
  return query
  with items as (
    select 'post'::text as kind, v.id, v.id as clip, v.user_id, v.caption as text_body,
           v.thumb_key as thumb, v.video_key as clip_key, v.created_at as made_at,
           v.hidden, v.admin_hidden_at, v.ban_hidden,
           r.open_count, r.total_count, r.open_reasons, r.all_reasons, r.last_at
      from public.videos v
      left join lateral (
        select count(*) filter (where x.reviewed_at is null) as open_count, count(*) as total_count,
               array_agg(distinct x.reason) filter (where x.reviewed_at is null) as open_reasons,
               array_agg(distinct x.reason) as all_reasons, max(x.created_at) as last_at
          from public.reports x where x.video_id = v.id
      ) r on true
     where r.total_count > 0 or v.admin_hidden_at is not null or v.ban_hidden
    union all
    select 'comment', c.id, c.video_id, c.user_id, c.body, v.thumb_key, v.video_key, c.created_at,
           c.hidden, c.admin_hidden_at, c.ban_hidden,
           r.open_count, r.total_count, r.open_reasons, r.all_reasons, r.last_at
      from public.comments c
      join public.videos v on v.id = c.video_id
      left join lateral (
        select count(*) filter (where x.reviewed_at is null) as open_count, count(*) as total_count,
               array_agg(distinct x.reason) filter (where x.reviewed_at is null) as open_reasons,
               array_agg(distinct x.reason) as all_reasons, max(x.created_at) as last_at
          from public.comment_reports x where x.comment_id = c.id
      ) r on true
     where r.total_count > 0 or c.admin_hidden_at is not null or c.ban_hidden
  )
  select i.kind, i.id, i.clip, i.user_id, p.username::text, moderation_internal.is_banned(i.user_id),
         i.text_body, i.thumb, i.clip_key, i.made_at,
         i.open_count, i.total_count, coalesce(i.open_reasons, i.all_reasons, '{}'::text[]), i.last_at,
         case when i.ban_hidden then 'banned'
              when i.admin_hidden_at is not null then 'admin_hidden'
              when i.hidden then 'auto_hidden'
              else 'visible' end
    from items i
    left join public.profiles p on p.id = i.user_id
   where case queue_filter
           when 'open' then i.open_count > 0
           when 'hidden' then i.hidden
           else true end
   order by case when sort_by = 'most' then i.open_count end desc nulls last,
            i.last_at desc nulls last, i.made_at desc, i.id
   limit least(greatest(page_size, 1), 200) offset greatest(page_offset, 0);
end $$;

-- Every report on one post or comment, open ones first.
create function public.moderation_item_reports(target_kind text, target_id uuid)
returns table (reporter_username text, reason text, created_at timestamptz, reviewed_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform moderation_internal.require_admin();
  perform moderation_internal.author_of(target_kind, target_id);
  if target_kind = 'post' then
    return query select p.username::text, r.reason, r.created_at, r.reviewed_at
      from public.reports r left join public.profiles p on p.id = r.reporter_id
     where r.video_id = target_id
     order by r.reviewed_at is null desc, r.created_at desc;
  else
    return query select p.username::text, r.reason, r.created_at, r.reviewed_at
      from public.comment_reports r left join public.profiles p on p.id = r.reporter_id
     where r.comment_id = target_id
     order by r.reviewed_at is null desc, r.created_at desc;
  end if;
end $$;

-- Media keys of any post, including hidden ones, for the moderation-media function.
create function public.moderation_video_media(target_video uuid)
returns table (video_key text, thumb_key text)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform moderation_internal.require_admin();
  return query select v.video_key, v.thumb_key from public.videos v where v.id = target_video;
end $$;

-- Hide a post or comment until an admin restores it. Its open reports are resolved.
create function public.moderation_hide(target_kind text, target_id uuid, note text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare admin uuid := moderation_internal.require_admin();
        author uuid := moderation_internal.author_of(target_kind, target_id);
begin
  if target_kind = 'post' then
    update public.videos set hidden = true, admin_hidden_at = now(), ban_hidden = false where id = target_id;
  else
    update public.comments set hidden = true, admin_hidden_at = now(), ban_hidden = false where id = target_id;
  end if;
  perform moderation_internal.review_reports(target_kind, target_id);
  perform moderation_internal.log(admin, 'hide', target_kind, target_id, author, note);
end $$;

-- Make a hidden post or comment public again and resolve its reports.
-- A banned author's content comes back only by unbanning them.
create function public.moderation_restore(target_kind text, target_id uuid, note text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare admin uuid := moderation_internal.require_admin();
        author uuid := moderation_internal.author_of(target_kind, target_id);
begin
  if moderation_internal.is_banned(author) then
    raise exception 'AUTHOR_BANNED' using errcode = 'P0001';
  end if;
  if target_kind = 'post' then
    update public.videos set hidden = false, admin_hidden_at = null, ban_hidden = false where id = target_id;
  else
    update public.comments set hidden = false, admin_hidden_at = null, ban_hidden = false where id = target_id;
  end if;
  perform moderation_internal.review_reports(target_kind, target_id);
  perform moderation_internal.log(admin, 'restore', target_kind, target_id, author, note);
end $$;

-- Resolve open reports without changing whether the item is visible.
create function public.moderation_dismiss_reports(target_kind text, target_id uuid, note text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare admin uuid := moderation_internal.require_admin();
        author uuid := moderation_internal.author_of(target_kind, target_id);
begin
  perform moderation_internal.review_reports(target_kind, target_id);
  perform moderation_internal.log(admin, 'dismiss', target_kind, target_id, author, note);
end $$;

-- Hide everything the account has posted and stop it posting or commenting.
create function public.moderation_ban_user(target_user uuid, note text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare admin uuid := moderation_internal.require_admin();
begin
  if not exists (select 1 from public.profiles where id = target_user) then
    raise exception 'MODERATION_TARGET_NOT_FOUND' using errcode = 'P0002';
  end if;
  if moderation_internal.is_admin(target_user) then
    raise exception 'CANNOT_BAN_ADMIN' using errcode = 'P0001';
  end if;
  insert into moderation_internal.bans (user_id, banned_by, note)
  values (target_user, admin, nullif(btrim(note), ''))
  on conflict (user_id) do update set banned_at = now(), banned_by = excluded.banned_by, note = excluded.note;
  update public.videos set hidden = true, ban_hidden = true where user_id = target_user and not hidden;
  update public.comments set hidden = true, ban_hidden = true where user_id = target_user and not hidden;
  update public.reports r set reviewed_at = now() from public.videos v
   where v.id = r.video_id and v.user_id = target_user and r.reviewed_at is null;
  update public.comment_reports r set reviewed_at = now() from public.comments c
   where c.id = r.comment_id and c.user_id = target_user and r.reviewed_at is null;
  perform moderation_internal.log(admin, 'ban', 'user', target_user, target_user, note);
end $$;

-- Lift a ban: the account can post again and what the ban hid comes back.
-- Items hidden by reports or by an admin stay hidden.
create function public.moderation_unban_user(target_user uuid, note text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare admin uuid := moderation_internal.require_admin();
begin
  delete from moderation_internal.bans where user_id = target_user;
  if not found then
    raise exception 'NOT_BANNED' using errcode = 'P0001';
  end if;
  update public.videos set hidden = false, ban_hidden = false where user_id = target_user and ban_hidden;
  update public.comments set hidden = false, ban_hidden = false where user_id = target_user and ban_hidden;
  perform moderation_internal.log(admin, 'unban', 'user', target_user, target_user, note);
end $$;

-- Newest moderation actions first.
create function public.moderation_log(page_size integer default 50, page_offset integer default 0)
returns table (
  id bigint, admin_username text, action text, target_kind text, target_id uuid,
  target_username text, note text, created_at timestamptz
) language plpgsql stable security definer set search_path = '' as $$
begin
  perform moderation_internal.require_admin();
  return query
  select a.id, admin.username::text, a.action, a.target_kind, a.target_id, target.username::text, a.note, a.created_at
    from moderation_internal.actions a
    left join public.profiles admin on admin.id = a.admin_id
    left join public.profiles target on target.id = a.target_user_id
   order by a.created_at desc, a.id desc
   limit least(greatest(page_size, 1), 200) offset greatest(page_offset, 0);
end $$;

-- Daily-digest hook (service role only; nothing schedules or sends it yet).
-- A scheduled job or the push-notifications sender can call
--   select * from public.moderation_report_digest(now() - interval '1 day');
-- and notify every row of moderation_internal.admins when new_reports > 0.
create function public.moderation_report_digest(since timestamptz)
returns table (new_post_reports bigint, new_comment_reports bigint, new_reports bigint,
               open_items bigint, auto_hidden_items bigint)
language sql stable security definer set search_path = '' as $$
  with posts as (select count(*) as n from public.reports where created_at >= since),
       comments as (select count(*) as n from public.comment_reports where created_at >= since)
  select posts.n, comments.n, posts.n + comments.n,
         (select count(distinct video_id) from public.reports where reviewed_at is null)
           + (select count(distinct comment_id) from public.comment_reports where reviewed_at is null),
         (select count(*) from public.videos where hidden and admin_hidden_at is null and not ban_hidden and report_count > 0)
           + (select count(*) from public.comments where hidden and admin_hidden_at is null and not ban_hidden and report_count > 0)
  from posts, comments
$$;

-- Service-side ban check for the upload functions' error messages.
create function public.account_is_banned(uid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select moderation_internal.is_banned(uid)
$$;

-- ---------------------------------------------------------------- privileges
revoke all on all functions in schema moderation_internal from public, anon, authenticated;
grant execute on function moderation_internal.is_banned(uuid) to anon, authenticated;

revoke all on function public.is_moderator(), public.my_account_banned(),
  public.moderation_queue(text, text, integer, integer), public.moderation_item_reports(text, uuid),
  public.moderation_video_media(uuid), public.moderation_hide(text, uuid, text),
  public.moderation_restore(text, uuid, text), public.moderation_dismiss_reports(text, uuid, text),
  public.moderation_ban_user(uuid, text), public.moderation_unban_user(uuid, text),
  public.moderation_log(integer, integer), public.moderation_report_digest(timestamptz),
  public.account_is_banned(uuid)
from public, anon, authenticated;

grant execute on function public.is_moderator(), public.my_account_banned(),
  public.moderation_queue(text, text, integer, integer), public.moderation_item_reports(text, uuid),
  public.moderation_video_media(uuid), public.moderation_hide(text, uuid, text),
  public.moderation_restore(text, uuid, text), public.moderation_dismiss_reports(text, uuid, text),
  public.moderation_ban_user(uuid, text), public.moderation_unban_user(uuid, text),
  public.moderation_log(integer, integer)
to authenticated;
grant execute on function public.moderation_report_digest(timestamptz), public.account_is_banned(uuid) to service_role;
