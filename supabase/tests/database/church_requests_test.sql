begin;
select plan(29);

create temp table u as
select tests.create_user('pastor@example.com') as pastor,
       tests.create_user('admin@example.com') as admin,
       tests.create_user('stranger@example.com') as stranger;
grant select on u to public;
update public.profiles set is_platform_admin = true where id = (select admin from u);
create temp table t (k text primary key, v uuid);
grant all on t to public;

-- request_church
select tests.act_as_anon();
select throws_ok($$select public.request_church('Anon Church', null)$$,
  '42501', null, 'anon cannot request a church');

select tests.act_as((select pastor from u));
insert into t select 'first', (public.request_church('  Vida Nueva  ', '   ')).id;
select results_eq($$select church_name, note, status::text, requested_by from public.church_requests$$,
  $$values ('Vida Nueva', null::text, 'pending', (select pastor from u))$$,
  'the request is stored trimmed, pending, with a blank note as null');
select throws_ok($$select public.request_church('Otra', 'again')$$,
  'P0001', 'request_pending_exists', 'a second pending request is refused');
select throws_ok($$select public.request_church('X', null)$$,
  '23514', null, 'a too-short name is refused');
select throws_ok($$insert into public.church_requests (requested_by, church_name) values ((select pastor from u), 'Direct')$$,
  '42501', null, 'requests cannot be inserted directly');
select throws_ok($$update public.church_requests set status = 'approved'$$,
  '42501', null, 'requests cannot be updated directly');
select throws_ok($$select public.pending_church_requests()$$,
  'P0001', 'not_allowed', 'a non-admin cannot list pending requests');

select tests.act_as((select stranger from u));
select is_empty($$select id from public.church_requests$$,
  'a stranger sees no requests');

select tests.act_as((select admin from u));
select results_eq($$select id, church_name, note, status::text, requester_email from public.pending_church_requests()$$,
  $$values ((select v from t where k = 'first'), 'Vida Nueva', null::text, 'pending', 'pastor@example.com')$$,
  'a platform admin lists pending requests with the requester email');
select results_eq($$select count(*)::int from public.church_requests$$,
  $$values (1)$$, 'a platform admin reads every request');

-- decide_church_request
select tests.act_as((select pastor from u));
select throws_ok($$select public.decide_church_request((select v from t where k = 'first'), true, 'vida-nueva')$$,
  'P0001', 'not_allowed', 'the requester cannot approve their own request');
select tests.act_as((select stranger from u));
select throws_ok($$select public.decide_church_request((select v from t where k = 'first'), true, 'vida-nueva')$$,
  'P0001', 'not_allowed', 'a non-admin cannot decide');
select tests.act_as_anon();
select throws_ok($$select public.decide_church_request((select v from t where k = 'first'), true, 'vida-nueva')$$,
  '42501', null, 'anon cannot decide');

select tests.act_as((select admin from u));
select lives_ok($$select public.create_church('Taken', 'taken-slug')$$, 'a church takes a slug');
select throws_ok($$select public.decide_church_request((select v from t where k = 'first'), true, 'taken-slug')$$,
  'P0001', 'church_slug_taken', 'approving with a taken slug is refused');
select throws_ok($$select public.decide_church_request((select v from t where k = 'first'), true, 'VN')$$,
  'P0001', 'church_slug_invalid', 'approving with an invalid slug is refused');
select results_eq($$select status::text, church_id from public.church_requests where id = (select v from t where k = 'first')$$,
  $$values ('pending', null::uuid)$$, 'a failed approval leaves the request pending');
select results_eq($$select count(*)::int from public.churches where name = 'Vida Nueva'$$,
  $$values (0)$$, 'a failed approval adds no church');

select results_eq($$select status::text, decided_by from public.decide_church_request((select v from t where k = 'first'), true, 'vida-nueva')$$,
  $$values ('approved', (select admin from u))$$, 'approving returns the approved request');
insert into t select 'church', id from public.churches where slug = 'vida-nueva';
select results_eq($$select name, created_by from public.churches where slug = 'vida-nueva'$$,
  $$values ('Vida Nueva', (select pastor from u))$$, 'the church is created by the requester');
select results_eq($$select church_id, decided_at is not null from public.church_requests where id = (select v from t where k = 'first')$$,
  $$values ((select v from t where k = 'church'), true)$$, 'the request links the church and the decision time');
select throws_ok($$select public.decide_church_request((select v from t where k = 'first'), true, 'vida-nueva-2')$$,
  'P0001', 'request_not_pending', 'approving again is refused');
select is_empty($$select id from public.pending_church_requests()$$,
  'a decided request is no longer pending');

select tests.act_as((select pastor from u));
select results_eq($$select public.church_role_of((select v from t where k = 'church'))::text$$,
  $$values ('owner')$$, 'the requester is the owner of the new church');

-- reject, then request again
insert into t select 'second', (public.request_church('Iglesia Dos', 'Somos pocos')).id;
select tests.act_as((select admin from u));
select results_eq($$select status::text, church_id from public.decide_church_request((select v from t where k = 'second'), false, null)$$,
  $$values ('rejected', null::uuid)$$, 'rejecting needs no slug and adds no church');
select throws_ok($$select public.decide_church_request((select v from t where k = 'second'), true, 'iglesia-dos')$$,
  'P0001', 'request_not_pending', 'a rejected request cannot be approved');
select tests.act_as((select pastor from u));
select lives_ok($$select public.request_church('Iglesia Dos', null)$$,
  'a rejected requester can request again');
select results_eq($$select count(*)::int from public.church_requests$$,
  $$values (3)$$, 'the requester reads all of their own requests');

-- deleting the admin who decided keeps the requests
select tests.reset();
delete from auth.users where id = (select admin from u);
select results_eq($$select count(*)::int from public.church_requests where status <> 'pending' and decided_by is null$$,
  $$values (2)$$, 'deleting the deciding admin keeps their decisions with no decider');

select * from finish();
rollback;
