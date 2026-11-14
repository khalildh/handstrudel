begin;
select plan(6);

insert into auth.users (id, email) values
  ('60000000-0000-4000-8000-000000000001', 'profile-avatar@test.dev');
update public.profiles set username = 'avatar_test',
  avatar_key = 'avatars/60000000-0000-4000-8000-000000000001/60000000-0000-4000-8000-000000000002.jpg'
where id = '60000000-0000-4000-8000-000000000001';

set local role anon;
select is((select avatar_key from public.public_creators where username = 'avatar_test'),
  'avatars/60000000-0000-4000-8000-000000000001/60000000-0000-4000-8000-000000000002.jpg',
  'photos are visible on profiles without posts');
reset role;

set local role authenticated;
select ok(not has_column_privilege('public.profiles', 'avatar_key', 'UPDATE'), 'clients cannot set arbitrary keys');
select ok(has_column_privilege('public.profiles', 'display_name', 'UPDATE'), 'clients can still change display names');
select ok(not has_function_privilege('public.claim_avatar_upload(uuid)', 'EXECUTE'), 'clients cannot claim upload slots');
reset role;

set local role service_role;
select ok(public.claim_avatar_upload('60000000-0000-4000-8000-000000000001'), 'first upload is allowed');
select ok(not public.claim_avatar_upload('60000000-0000-4000-8000-000000000001'), 'immediate retry is limited');
reset role;

select * from finish();
rollback;
