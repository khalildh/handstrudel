create or replace view public.public_creators with (security_invoker = true) as
select p.id, p.username, p.display_name, p.avatar_key,
       coalesce((
         select sum(v.like_count)
         from public.videos v
         where v.user_id = p.id and not v.hidden
       ), 0) as likes_received
from public.profiles p
where p.username is not null and not public.is_blocked_between(auth.uid(), p.id);
