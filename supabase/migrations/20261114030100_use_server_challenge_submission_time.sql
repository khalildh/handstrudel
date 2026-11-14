-- Challenges use publication time, not a date supplied by the posting client.
create or replace function public.reset_video_counters() returns trigger
language plpgsql set search_path = '' as $$
begin
  if current_user in ('authenticated', 'anon') then
    new.like_count := 0;
    new.report_count := 0;
    new.hidden := false;
    new.created_at := now();
  end if;
  return new;
end
$$;
