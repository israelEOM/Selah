begin;
select plan(20);

-- cross_church_isolation
-- Churches A and B, plus C with a monthly limit of one.
insert into public.churches (id, slug, name, monthly_sermon_limit) values
  ('00000000-0000-0000-0000-00000000000a', 'church-a', 'Church A', 4),
  ('00000000-0000-0000-0000-00000000000b', 'church-b', 'Church B', 4),
  ('00000000-0000-0000-0000-00000000000c', 'church-c', 'Church C', 1);

create temp table u as
select tests.create_user('owner@example.com') as owner,
       tests.create_user('editor@example.com') as editor,
       tests.create_user('member@example.com') as member,
       tests.create_user('stranger@example.com') as stranger;
grant select on u to public;

insert into public.church_members (church_id, user_id, role)
select '00000000-0000-0000-0000-00000000000a'::uuid, owner, 'owner'::public.church_role from u
union all select '00000000-0000-0000-0000-00000000000a', editor, 'editor' from u
union all select '00000000-0000-0000-0000-00000000000a', member, 'member' from u
union all select '00000000-0000-0000-0000-00000000000c', editor, 'editor' from u;

-- A draft and a published study in each of A and B.
insert into public.sermons (id, church_id, youtube_video_id, youtube_url) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000a', 'a-draft', 'https://youtu.be/a-draft'),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-00000000000a', 'a-pub', 'https://youtu.be/a-pub'),
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-00000000000b', 'b-draft', 'https://youtu.be/b-draft'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-00000000000b', 'b-pub', 'https://youtu.be/b-pub'),
  ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-00000000000b', 'b-free', 'https://youtu.be/b-free'),
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000c', 'c-one', 'https://youtu.be/c-one');
insert into public.studies (id, church_id, sermon_id, title, slug, status) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a1', 'A draft', 'a-draft', 'draft'),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a2', 'A pub', 'a-pub', 'published'),
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000b1', 'B draft', 'b-draft', 'draft'),
  ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000b2', 'B pub', 'b-pub', 'published');

-- Anonymous visitors.
select tests.act_as_anon();
select results_eq($$select count(*)::int from public.studies where slug = 'b-pub'$$,
  $$values (1)$$, 'anon sees the published study of B');
select results_eq($$select count(*)::int from public.studies where slug = 'b-draft'$$,
  $$values (0)$$, 'anon does not see the draft of B');
select throws_ok($$select public.sermons_this_month('00000000-0000-0000-0000-00000000000a')$$,
  '42501', null, 'anon cannot call the role helpers');

-- Editor of A (and of C).
select tests.act_as((select editor from u));
select results_eq($$select count(*)::int from public.studies where slug = 'a-draft'$$,
  $$values (1)$$, 'the editor of A sees the draft of A');
select results_eq($$select count(*)::int from public.studies where slug = 'b-draft'$$,
  $$values (0)$$, 'the editor of A does not see the draft of B');
select throws_ok(
  $$insert into public.jobs (church_id, step, status, created_by)
    values ('00000000-0000-0000-0000-00000000000b', 'probe', 'queued', (select editor from u))$$,
  '42501', null, 'the editor of A cannot queue a job in B');
select throws_ok(
  $$insert into public.jobs (church_id, sermon_id, step, status, created_by)
    values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b2',
            'probe', 'queued', (select editor from u))$$,
  '42501', null, 'a job in A cannot point at a sermon of B');
select lives_ok(
  $$insert into public.jobs (church_id, sermon_id, step, status, created_by)
    values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a1',
            'probe', 'queued', (select editor from u))$$,
  'the editor of A can queue a job for a sermon of A');
select throws_ok(
  $$insert into public.studies (church_id, sermon_id, title, slug, status)
    values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b3',
            'stolen', 'stolen', 'published')$$,
  '23503', null, 'a study of A cannot point at a sermon of B');
select throws_ok(
  $$insert into public.sermons (church_id, youtube_video_id, youtube_url)
    values ('00000000-0000-0000-0000-00000000000b', 'x1', 'https://youtu.be/x1')$$,
  '42501', null, 'the editor of A cannot add a sermon to B');
select throws_ok(
  $$insert into public.church_members (church_id, user_id, role)
    values ('00000000-0000-0000-0000-00000000000a', (select stranger from u), 'owner')$$,
  '42501', null, 'memberships cannot be written directly');

-- Monthly limit (church C allows one sermon and already has one).
select throws_ok(
  $$insert into public.sermons (church_id, youtube_video_id, youtube_url)
    values ('00000000-0000-0000-0000-00000000000c', 'c-two', 'https://youtu.be/c-two')$$,
  'P0001', 'monthly_limit_reached', 'a second sermon over the monthly limit is refused');
select lives_ok(
  $$insert into public.sermons (church_id, youtube_video_id, youtube_url)
    values ('00000000-0000-0000-0000-00000000000c', 'c-one', 'https://youtu.be/c-one')
    on conflict (church_id, youtube_video_id) do update set youtube_url = excluded.youtube_url$$,
  're-importing an existing sermon is not blocked by the limit');

-- Member of A: reads only what is published, changes nothing.
select tests.act_as((select member from u));
select results_eq($$select count(*)::int from public.studies where slug = 'a-draft'$$,
  $$values (0)$$, 'a member does not see drafts');
select results_eq(
  $$with x as (update public.studies set title = 'hacked' where slug = 'a-pub' returning 1)
    select count(*)::int from x$$,
  $$values (0)$$, 'a member cannot update a study');
select throws_ok(
  $$insert into public.jobs (church_id, step, status, created_by)
    values ('00000000-0000-0000-0000-00000000000a', 'probe', 'queued', (select member from u))$$,
  '42501', null, 'a member cannot queue a job');
select results_eq(
  $$with x as (update public.churches set name = 'Hijacked'
               where id = '00000000-0000-0000-0000-00000000000a' returning 1)
    select count(*)::int from x$$,
  $$values (0)$$, 'a member cannot rename the church');

-- Owner of A.
select tests.act_as((select owner from u));
select results_eq(
  $$with x as (update public.churches set name = 'Church Alpha'
               where id = '00000000-0000-0000-0000-00000000000a' returning 1)
    select count(*)::int from x$$,
  $$values (1)$$, 'the owner can rename the church');
select throws_ok(
  $$update public.churches set monthly_sermon_limit = 99
    where id = '00000000-0000-0000-0000-00000000000a'$$,
  '42501', null, 'the owner cannot raise the monthly limit');

-- The old admin check is gone.
select tests.reset();
select throws_ok($$select public.is_admin()$$, '42883', null, 'is_admin() no longer exists');

select * from finish();
rollback;
