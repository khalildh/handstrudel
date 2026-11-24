-- Opt-in usage counters for Pro sounds opened from the feed: how often a viewer without Pro
-- taps one, and how often that leads to unlocking Pro. Daily totals only, no identifiers.
alter table public.app_usage_daily drop constraint app_usage_daily_event_check;
alter table public.app_usage_daily add constraint app_usage_daily_event_check check (event in (
  'active_day', 'return_day', 'first_note', 'recording_started', 'recording_saved', 'recording_posted',
  'locked_sound_tapped', 'locked_sound_unlocked'
));

create or replace function public.record_app_usage_event(p_event text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_event is null or p_event not in (
    'active_day', 'return_day', 'first_note', 'recording_started', 'recording_saved', 'recording_posted',
    'locked_sound_tapped', 'locked_sound_unlocked'
  ) then
    raise exception 'Invalid app usage event' using errcode = '22023';
  end if;

  insert into public.app_usage_daily as counter (day, event, events)
  values ((current_timestamp at time zone 'UTC')::date, p_event, 1)
  on conflict (day, event) do update set events = counter.events + 1;
end;
$$;
