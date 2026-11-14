-- Only the authenticated avatar Edge Function should write managed media keys.
revoke update (avatar_key) on public.profiles from authenticated;

-- Keep upload timing private; profiles deliberately expose public fields.
create table public.profile_avatar_uploads (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  attempted_at timestamptz not null
);
alter table public.profile_avatar_uploads enable row level security;
revoke all on public.profile_avatar_uploads from public, anon, authenticated;

create function public.claim_avatar_upload(uid uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profile_avatar_uploads as uploads (user_id, attempted_at)
  values (uid, clock_timestamp())
  on conflict (user_id) do update set attempted_at = excluded.attempted_at
    where uploads.attempted_at < excluded.attempted_at - interval '10 seconds';
  return found;
end;
$$;
revoke all on function public.claim_avatar_upload(uuid) from public, anon, authenticated;
grant execute on function public.claim_avatar_upload(uuid) to service_role;

create or replace view public.public_creators with (security_invoker = true) as
select p.id, p.username, p.display_name, p.avatar_key from public.profiles p
where p.username is not null and not public.is_blocked_between(auth.uid(), p.id);
