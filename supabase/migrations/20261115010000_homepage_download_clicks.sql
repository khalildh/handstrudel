create table public.homepage_download_clicks (
  day date not null,
  placement text not null check (placement in ('header', 'hero', 'footer')),
  clicks bigint not null check (clicks > 0),
  primary key (day, placement)
);

alter table public.homepage_download_clicks enable row level security;
revoke all on public.homepage_download_clicks from public, anon, authenticated, service_role;
grant select on public.homepage_download_clicks to service_role;

create function public.record_homepage_download_click(p_placement text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_placement is null or p_placement not in ('header', 'hero', 'footer') then
    raise exception 'Invalid homepage download placement' using errcode = '22023';
  end if;

  insert into public.homepage_download_clicks as counter (day, placement, clicks)
  values ((current_timestamp at time zone 'UTC')::date, p_placement, 1)
  on conflict (day, placement) do update set clicks = counter.clicks + 1;
end;
$$;

revoke all on function public.record_homepage_download_click(text) from public;
grant execute on function public.record_homepage_download_click(text) to anon, authenticated;
