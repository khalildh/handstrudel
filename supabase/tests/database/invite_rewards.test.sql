-- Invite codes, redemption rules, reward queueing on the first screened post, and the grant queue.
begin;
select plan(54);

-- Inviter (a) exists before the invite; friends (b, c, d) sign up after it.
insert into auth.users (id, email, created_at) values
  ('00000000-0000-0000-0000-0000000000a1', 'inviter@test.dev', now() - interval '30 days');
update auth.users set created_at = now() where created_at is null;
update public.profiles set username = 'inviter' where id = '00000000-0000-0000-0000-0000000000a1';

-- ---------------------------------------------------------------- codes
set local role anon;
select throws_ok($$ select * from public.my_invite() $$, '42501', null, 'signed-out visitors have no invite');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select matches((select code from public.my_invite()), '^[A-Z2-9]{8}$', 'creates a readable 8-character code');
select is((select code from public.my_invite()), (select code from public.invite_codes), 'returns the same code every time');
select is((select friends_joined from public.my_invite()), 0, 'no friends yet');
select is((select reward_limit from public.my_invite()), 10, 'reports the 10-reward limit');
select throws_ok($$ insert into public.invite_codes (user_id, code) values (auth.uid(), 'AAAAAAAA') $$,
  '42501', null, 'clients cannot write codes');
select throws_ok($$ insert into public.invite_reward_grants (invitee_id, recipient_id, role) values (auth.uid(), auth.uid(), 'invitee') $$,
  '42501', null, 'clients cannot queue rewards');
select throws_ok($$ select * from public.claim_invite_grants() $$, '42501', null, 'clients cannot claim the grant queue');
reset role;

-- Postdate the code so the new accounts below are "after the invite".
update public.invite_codes set created_at = now() - interval '1 day';
select set_config('test.code', (select code from public.invite_codes), true);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000b1', 'friend@test.dev'),
  ('00000000-0000-0000-0000-0000000000c1', 'second@test.dev'),
  ('00000000-0000-0000-0000-0000000000d1', 'third@test.dev'),
  ('00000000-0000-0000-0000-0000000000e1', 'spammer@test.dev');
update auth.users set created_at = now() where created_at is null;
insert into auth.users (id, email, created_at) values
  ('00000000-0000-0000-0000-0000000000f1', 'old@test.dev', now() - interval '20 days');
update auth.users set created_at = now() where created_at is null;
update public.profiles set username = 'friend' where id = '00000000-0000-0000-0000-0000000000b1';
update public.profiles set username = 'second' where id = '00000000-0000-0000-0000-0000000000c1';

-- ---------------------------------------------------------------- redemption rules
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select is(public.redeem_invite_code(current_setting('test.code'))->>'reason', 'self_invite', 'no self-invites');


select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}', true);
select is(public.redeem_invite_code('NOPE2345')->>'reason', 'not_found', 'unknown codes are rejected');
select is(public.redeem_invite_code(lower(current_setting('test.code')) || ' '),
  '{"ok": true, "inviter": "inviter", "inviter_rewarded": true}'::jsonb, 'a new friend redeems the code, case and spacing ignored');
select is((select count(*)::int from public.invite_redemptions), 1, 'the friend sees their own redemption');
select is(public.redeem_invite_code(current_setting('test.code'))->>'reason', 'already_redeemed',
  'one invite per account');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);
select is(public.redeem_invite_code(current_setting('test.code'))->>'ok', 'true', 'a second friend can join too');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select is((select friends_joined from public.my_invite()), 2, 'the inviter sees two friends joined');
select is((select count(*)::int from public.invite_redemptions), 0, 'the inviter cannot read redemption rows directly');
select results_eq($$ select username, posted_first_take from public.my_intros() $$,
  $$ values ('second'::text, false), ('friend'::text, false) $$, 'the inviter lists who joined, newest first');
select results_eq($$ select milestone from public.invite_milestones where user_id = auth.uid() $$,
  $$ values (1) $$, 'the first intro earns the 1-intro badge');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}', true);
select is((select count(*)::int from public.my_intros()), 0, 'other people cannot list someone''s intros');
select is((select username from public.my_introducer()), 'inviter', 'the invited friend sees who introduced them');
reset role;

set local role anon;
select results_eq($$ select intros, milestone, badge from public.intro_stats('00000000-0000-0000-0000-0000000000a1') $$,
  $$ values (2, 1, 'Spark') $$, 'anyone can see the public count and badge');
select results_eq($$ select intros, milestone, badge from public.intro_stats('00000000-0000-0000-0000-0000000000e1') $$,
  $$ values (0, null::int, null::text) $$, 'no intros, no badge');
select throws_ok($$ select * from public.my_intros() $$, '42501', null, 'signed-out visitors cannot list intros');
reset role;

select is((select count(*)::int from public.invite_reward_grants), 0, 'nothing is queued before a post');

-- ---------------------------------------------------------------- first screened post queues both rewards
insert into public.pending_video_uploads (id, user_id, video_bytes, thumb_bytes, status) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b1', 100, 20, 'checking'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000b1', 100, 20, 'checking'),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000d1', 100, 20, 'checking');
set local role service_role;
select public.publish_screened_video('10000000-0000-0000-0000-000000000001', '{"duration_s":7,"width":720,"height":1560}');
reset role;

select results_eq($$ select recipient_id::text, role, status from public.invite_reward_grants order by role $$,
  $$ values ('00000000-0000-0000-0000-0000000000b1', 'invitee', 'pending'),
            ('00000000-0000-0000-0000-0000000000a1', 'inviter', 'pending') $$,
  'the friend''s first post queues a week for both people');
select isnt((select first_post_at from public.invite_redemptions where invitee_id = '00000000-0000-0000-0000-0000000000b1'),
  null, 'the redemption is marked rewarded');

set local role service_role;
select public.publish_screened_video('10000000-0000-0000-0000-000000000002', '{"duration_s":7,"width":720,"height":1560}');
reset role;
select is((select count(*)::int from public.invite_reward_grants), 2, 'a second post does not reward again');

set local role service_role;
select public.publish_screened_video('10000000-0000-0000-0000-000000000003', '{"duration_s":7,"width":720,"height":1560}');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);
select is(public.redeem_invite_code(current_setting('test.code'))->>'reason', 'already_posted',
  'an account that has already posted cannot redeem');
reset role;

-- ---------------------------------------------------------------- the grant queue
create temp table claimed as select * from public.claim_invite_grants('00000000-0000-0000-0000-0000000000b1', 20);
select is((select count(*)::int from claimed), 2, 'claiming for the friend takes both grants of that invite');
select is((select bool_or(verify_first) from claimed), false, 'a first attempt needs no RevenueCat check');
select is((select count(*)::int from public.claim_invite_grants(null, 20)), 0, 'claimed rows cannot be claimed twice');

select ok(public.record_invite_entitlement(c.id, c.claimed_at, 'plus_features'), 'records a granted entitlement')
  from claimed c where c.role = 'invitee';
select ok(public.finish_invite_grant(c.id, c.claimed_at, false, null, 'HTTP 503'), 'records a failed attempt')
  from claimed c where c.role = 'invitee';
select ok(not public.finish_invite_grant(c.id, c.claimed_at, true, now()), 'a finished claim cannot be finished again')
  from claimed c where c.role = 'invitee';
select is((select status from public.invite_reward_grants where role = 'invitee'), 'pending', 'a failure goes back to the queue');
update public.invite_reward_grants set next_attempt_at = now() where role = 'invitee';
select results_eq($$ select verify_first, granted_entitlements from public.claim_invite_grants(null, 20) $$,
  $$ values (true, array['plus_features']) $$, 'a retry resumes and checks RevenueCat first');

select ok(public.finish_invite_grant(c.id, c.claimed_at, true, now() + interval '7 days'), 'records the inviter''s grant')
  from claimed c where c.role = 'inviter';
-- A crashed attempt is reclaimable after five minutes, by the service role the function uses.
update public.invite_reward_grants set claimed_at = now() - interval '6 minutes' where role = 'invitee';
set local role service_role;
select is((select count(*)::int from public.claim_invite_grants(null, 20)), 1, 'a stale claim is reclaimed');
reset role;

-- ---------------------------------------------------------------- celebration
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select results_eq($$ select role, friend_username from public.unseen_invite_rewards() $$,
  $$ values ('inviter', 'friend') $$, 'the inviter sees the landed reward with the friend''s name');
select public.mark_invite_rewards_seen(array(select id from public.unseen_invite_rewards()));
select is((select count(*)::int from public.unseen_invite_rewards()), 0, 'a reward is celebrated once');
select is((select friends_rewarded from public.my_invite()), 1, 'counts rewarded friends');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}', true);
select is((select count(*)::int from public.unseen_invite_rewards()), 0, 'the friend''s reward isn''t shown before it lands');
reset role;

-- ---------------------------------------------------------------- caps and recreated accounts
-- At ten rewarded friends the code stops accepting new friends.
insert into auth.users (id, email) select ('00000000-0000-0000-0000-0000000001' || lpad(n::text, 2, '0'))::uuid,
  'cap' || n || '@test.dev' from generate_series(1, 9) n;
update auth.users set created_at = now() where created_at is null;
insert into public.invite_reward_grants (invitee_id, recipient_id, role)
  select ('00000000-0000-0000-0000-0000000001' || lpad(n::text, 2, '0'))::uuid, '00000000-0000-0000-0000-0000000000a1', 'inviter'
  from generate_series(1, 9) n;
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000a9', 'late@test.dev');
update auth.users set created_at = now() where created_at is null;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a9","role":"authenticated"}', true);
select is(public.redeem_invite_code(current_setting('test.code')),
  '{"ok": true, "inviter": "inviter", "inviter_rewarded": false}'::jsonb,
  'past the 10-reward cap a friend can still join, and is told the inviter isn''t rewarded');
reset role;


-- The second friend posts after the cap: they still get their week, the inviter does not.
insert into public.pending_video_uploads (id, user_id, video_bytes, thumb_bytes, status) values
  ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000c1', 100, 20, 'checking');
set local role service_role;
select public.publish_screened_video('10000000-0000-0000-0000-000000000004', '{"duration_s":7,"width":720,"height":1560}');
reset role;
select results_eq($$ select role from public.invite_reward_grants where invitee_id = '00000000-0000-0000-0000-0000000000c1' $$,
  $$ values ('invitee') $$, 'past the cap only the friend is rewarded');

-- The tally keeps going past the cap: 12 more friends join (3 + 12 = 15 intros).
insert into auth.users (id, email) select ('00000000-0000-0000-0000-0000000002' || lpad(n::text, 2, '0'))::uuid,
  'tally' || n || '@test.dev' from generate_series(1, 12) n;
update auth.users set created_at = now() where created_at is null;
do $$
begin
  for n in 1..12 loop
    perform set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000002' || lpad(n::text, 2, '0'),
      'role', 'authenticated')::text, true);
    perform public.redeem_invite_code(current_setting('test.code'));
  end loop;
end $$;
set local role anon;
select results_eq($$ select intros, milestone, badge from public.intro_stats('00000000-0000-0000-0000-0000000000a1') $$,
  $$ values (15, 10, 'Connector') $$, 'the count passes the reward cap and earns the 10-intro badge');
reset role;
select results_eq($$ select milestone from public.invite_milestones where user_id = '00000000-0000-0000-0000-0000000000a1' order by 1 $$,
  $$ values (1), (5), (10) $$, 'milestones are stored once each');
select is((select count(*)::int from public.invite_reward_grants g
  where g.recipient_id = '00000000-0000-0000-0000-0000000000a1' and g.role = 'inviter'), 10, 'rewards stay capped at 10');

-- In-person intros: pick the introducer by @username instead of a code. Same rules apply.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000003a1', 'met-in-person@test.dev'),
  ('00000000-0000-0000-0000-0000000003a2', 'met-twice@test.dev');
update auth.users set created_at = now() where created_at is null;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000003a1","role":"authenticated"}', true);
select is(public.redeem_invite_code(null, '00000000-0000-0000-0000-0000000003a1')->>'reason',
  'self_invite', 'you cannot pick yourself');
select is(public.redeem_invite_code(null, '00000000-0000-0000-0000-0000000009ff')->>'reason',
  'not_found', 'an unknown introducer is rejected');
select is(public.redeem_invite_code(introducer => '00000000-0000-0000-0000-0000000000a1')->>'ok',
  'true', 'a new account can name its introducer by @username, sending only that argument as the app does');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000003a2","role":"authenticated"}', true);
select is(public.redeem_invite_code(null, '00000000-0000-0000-0000-0000000000a1')->>'ok',
  'true', 'a second person met in person can name the same introducer');
reset role;
select results_eq($$ select via, code from public.invite_redemptions where invitee_id = '00000000-0000-0000-0000-0000000003a1' $$,
  $$ values ('username'::text, null::text) $$, 'the intro is recorded as picked by username');
set local role anon;
select is((select intros from public.intro_stats('00000000-0000-0000-0000-0000000000a1')), 17, 'both count as intros');
reset role;

-- Account deletion cleans up.
delete from auth.users where id = '00000000-0000-0000-0000-0000000000b1';
select is((select count(*)::int from public.invite_reward_grants where invitee_id = '00000000-0000-0000-0000-0000000000b1'), 0,
  'account deletion removes that account''s grants');
select * from finish();
rollback;
