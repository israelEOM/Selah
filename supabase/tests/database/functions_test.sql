begin;
select plan(32);

create temp table u as
select tests.create_user('pastor@example.com') as owner,
       tests.create_user('second@example.com') as second,
       tests.create_user('stranger@example.com') as stranger;
grant select on u to public;
create temp table t (k text primary key, v uuid);
grant all on t to public;

-- create_church
select tests.act_as((select owner from u));
select lives_ok($$select public.create_church('Vida Nueva', 'vida-nueva')$$,
  'create_church returns a church');
create temp table c as select id from public.churches where slug = 'vida-nueva';
grant select on c to public;
select results_eq($$select public.church_role_of((select id from c))::text$$,
  $$values ('owner')$$, 'the creator is an owner');
select throws_ok($$select public.create_church('Other', 'vida-nueva')$$,
  'P0001', 'church_slug_taken', 'a taken slug is refused');
select throws_ok($$select public.create_church('Tiny', 'VN')$$,
  'P0001', 'church_slug_invalid', 'an invalid slug is refused');
select tests.act_as_anon();
select throws_ok($$select public.create_church('Anon', 'anon-church')$$,
  '42501', null, 'anon cannot create a church');

-- invites
select tests.act_as((select owner from u));
insert into t select 'editor', public.create_invite((select id from c), 'editor');
insert into t select 'member', public.create_invite((select id from c), 'member');
select results_eq($$select count(*)::int from public.church_invites$$,
  $$values (2)$$, 'the owner sees the invites');
select throws_ok($$select public.create_invite((select id from c), 'owner')$$,
  '23514', null, 'an owner invite is refused');

select tests.act_as_anon();
select results_eq($$select church_slug, role::text from public.invite_info((select v from t where k = 'editor'))$$,
  $$values ('vida-nueva', 'editor')$$, 'anon can read invite info');

select tests.act_as((select stranger from u));
select throws_ok($$select public.create_invite((select id from c), 'member')$$,
  'P0001', 'not_allowed', 'a non-owner cannot create an invite');
select results_eq($$select count(*)::int from public.church_invites$$,
  $$values (0)$$, 'a non-owner does not see invites');
select results_eq($$select public.accept_invite((select v from t where k = 'editor'))$$,
  $$values ('vida-nueva')$$, 'accepting returns the slug');
select results_eq($$select public.church_role_of((select id from c))::text$$,
  $$values ('editor')$$, 'the invitee becomes an editor');
select lives_ok($$select public.accept_invite((select v from t where k = 'member'))$$,
  'accepting a lower invite works');
select results_eq($$select public.church_role_of((select id from c))::text$$,
  $$values ('editor')$$, 'a lower invite never lowers the role');
select throws_ok($$select public.accept_invite(gen_random_uuid())$$,
  'P0001', 'invite_invalid', 'an unknown token is refused');
select throws_ok($$select public.revoke_invite((select v from t where k = 'member'))$$,
  'P0001', 'not_allowed', 'a non-owner cannot revoke');

select tests.act_as((select owner from u));
select lives_ok($$select public.accept_invite((select v from t where k = 'member'))$$,
  'the owner accepts a member invite');
select results_eq($$select public.church_role_of((select id from c))::text$$,
  $$values ('owner')$$, 'the owner stays an owner');
select lives_ok($$select public.revoke_invite((select v from t where k = 'editor'))$$,
  'the owner revokes an invite');
select tests.act_as((select second from u));
select throws_ok($$select public.accept_invite((select v from t where k = 'editor'))$$,
  'P0001', 'invite_invalid', 'a revoked invite is refused');
select tests.act_as_anon();
select results_eq($$select count(*)::int from public.invite_info((select v from t where k = 'editor'))$$,
  $$values (0)$$, 'a revoked invite has no info');

-- join_church
select tests.act_as((select second from u));
select lives_ok($$select public.join_church((select id from c))$$, 'a stranger joins');
select results_eq($$select public.church_role_of((select id from c))::text$$,
  $$values ('member')$$, 'the joiner is a member');
select tests.act_as((select stranger from u));
select lives_ok($$select public.join_church((select id from c))$$, 'an editor joins again');

-- people, roles (stranger is the editor here)
select throws_ok($$select * from public.church_people((select id from c))$$,
  'P0001', 'not_allowed', 'an editor cannot list people');
select tests.act_as((select owner from u));
select results_eq($$select email from public.church_people((select id from c))$$,
  $$values ('pastor@example.com'), ('stranger@example.com'), ('second@example.com')$$,
  'the owner lists people with emails, owners first');

-- last owner
select throws_ok($$select public.set_member_role((select id from c), (select owner from u), 'editor')$$,
  'P0001', 'last_owner', 'the last owner cannot step down');
select throws_ok($$select public.remove_member((select id from c), (select owner from u))$$,
  'P0001', 'last_owner', 'the last owner cannot leave');
select lives_ok($$select public.set_member_role((select id from c), (select second from u), 'owner')$$,
  'a second owner is promoted');
select lives_ok($$select public.set_member_role((select id from c), (select owner from u), 'editor')$$,
  'stepping down works with another owner');
select tests.act_as((select stranger from u));
select lives_ok($$select public.remove_member((select id from c), (select stranger from u))$$,
  'a member can leave');
select tests.act_as((select second from u));
select lives_ok($$select public.remove_member((select id from c), (select owner from u))$$,
  'an owner removes someone');

select * from finish();
rollback;
