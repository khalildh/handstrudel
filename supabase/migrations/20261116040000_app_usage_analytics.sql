create table public.app_usage_daily (
  day date not null,
  event text not null check (event in (
    'active_day', 'return_day', 'first_note', 'recording_started', 'recording_saved', 'recording_posted'
  )),
  events bigint not null check (events > 0),
  primary key (day, event)
);

alter table public.app_usage_daily enable row level security;
revoke all on public.app_usage_daily from public, anon, authenticated, service_role;
grant select on public.app_usage_daily to service_role;

create function public.record_app_usage_event(p_event text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_event is null or p_event not in (
    'active_day', 'return_day', 'first_note', 'recording_started', 'recording_saved', 'recording_posted'
  ) then
    raise exception 'Invalid app usage event' using errcode = '22023';
  end if;

  insert into public.app_usage_daily as counter (day, event, events)
  values ((current_timestamp at time zone 'UTC')::date, p_event, 1)
  on conflict (day, event) do update set events = counter.events + 1;
end;
$$;

revoke all on function public.record_app_usage_event(text) from public;
grant execute on function public.record_app_usage_event(text) to anon;
