begin;
select plan(6);

insert into auth.users (id, email) values
  ('71000000-0000-4000-8000-000000000001', 'likes-creator@test.dev'),
  ('71000000-0000-4000-8000-000000000002', 'likes-viewer@test.dev');
update public.profiles set username = 'likes_creator'
where id = '71000000-0000-4000-8000-000000000001';
update public.profiles set username = 'likes_viewer'
where id = '71000000-0000-4000-8000-000000000002';

insert into public.videos (id, user_id, video_key, thumb_key)
select ('72000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  '71000000-0000-4000-8000-000000000001'::uuid,
  'videos/71000000-0000-4000-8000-000000000001/' || n || '.mp4',
  'thumbs/71000000-0000-4000-8000-000000000001/' || n || '.jpg'
from generate_series(1, 14) n;
insert into public.likes (user_id, video_id)
select '71000000-0000-4000-8000-000000000002'::uuid, id from public.videos
where user_id = '71000000-0000-4000-8000-000000000001';
update public.videos set hidden = true where id = '72000000-0000-4000-8000-000000000014';

set local role anon;
select is((select likes_received from public.public_creators where username = 'likes_creator'),
  13::bigint, 'sums likes across every public clip, including beyond one feed page');
select is((select likes_received from public.public_creators where username = 'likes_viewer'),
  0::bigint, 'likes given do not count toward likes received');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '71000000-0000-4000-8000-000000000001', true);
select is((select likes_received from public.public_creators where username = 'likes_creator'),
  13::bigint, 'the creator sees the same total, excluding their hidden clip');
reset role;

delete from public.likes where video_id = '72000000-0000-4000-8000-000000000001';
select is((select likes_received from public.public_creators where username = 'likes_creator'),
  12::bigint, 'unlikes lower the profile total');
delete from public.videos where id = '72000000-0000-4000-8000-000000000002';
select is((select likes_received from public.public_creators where username = 'likes_creator'),
  11::bigint, 'a deleted post no longer contributes');

insert into public.blocks (blocker_id, blocked_id)
values ('71000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub', '71000000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.public_creators where username = 'likes_creator'),
  0::bigint, 'a blocked viewer cannot look up the profile or its total');
reset role;

select * from finish();
rollback;
