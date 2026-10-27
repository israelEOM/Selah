begin;
select plan(12);

select has_table('public', 'churches', 'churches table exists');
select has_table('public', 'church_members', 'church_members table exists');

-- Slug rules.
select throws_ok(
  $$insert into public.churches (slug, name) values ('Vida Nueva', 'Vida Nueva')$$,
  '23514', null, 'an uppercase slug with a space is rejected');
select lives_ok(
  $$insert into public.churches (slug, name) values ('vida-nueva', 'Vida Nueva')$$,
  'a lowercase slug is accepted');

-- Two churches, three users.
insert into public.churches (id, slug, name) values
  ('00000000-0000-0000-0000-00000000000a', 'church-a', 'Church A'),
  ('00000000-0000-0000-0000-00000000000b', 'church-b', 'Church B');

create temp table u as
select tests.create_user('editor@example.com') as editor,
       tests.create_user('admin@example.com') as padmin,
       tests.create_user('nobody@example.com') as nobody;
grant select on u to public;

insert into public.church_members (church_id, user_id, role)
select '00000000-0000-0000-0000-00000000000a', editor, 'editor' from u;
update public.profiles set is_platform_admin = true
where id = (select padmin from u);

-- Sermons are unique per church, not globally.
insert into public.sermons (church_id, youtube_video_id, youtube_url)
values ('00000000-0000-0000-0000-00000000000a', 'vid1', 'https://youtu.be/vid1');
select lives_ok(
  $$insert into public.sermons (church_id, youtube_video_id, youtube_url)
    values ('00000000-0000-0000-0000-00000000000b', 'vid1', 'https://youtu.be/vid1')$$,
  'the same video can be imported by another church');
select throws_ok(
  $$insert into public.sermons (church_id, youtube_video_id, youtube_url)
    values ('00000000-0000-0000-0000-00000000000a', 'vid1', 'https://youtu.be/vid1')$$,
  '23505', null, 'the same video twice in one church is rejected');

-- Roles for an editor.
select tests.act_as((select editor from u));
select is(public.church_role_of('00000000-0000-0000-0000-00000000000a'),
  'editor'::public.church_role, 'editor has the editor role in A');
select is(public.church_role_of('00000000-0000-0000-0000-00000000000b'),
  null, 'editor has no role in B');
select ok(public.can_edit_church('00000000-0000-0000-0000-00000000000a'),
  'editor can edit A');
select ok(not public.is_church_owner('00000000-0000-0000-0000-00000000000a'),
  'editor is not an owner of A');

-- A platform admin is an owner everywhere.
select tests.act_as((select padmin from u));
select is(public.church_role_of('00000000-0000-0000-0000-00000000000b'),
  'owner'::public.church_role, 'platform admin owns B');

-- Monthly count ignores last month's sermons.
select tests.reset();
insert into public.sermons (church_id, youtube_video_id, youtube_url, created_at)
values ('00000000-0000-0000-0000-00000000000a', 'old1', 'https://youtu.be/old1',
        date_trunc('month', now() at time zone 'utc') - interval '1 day');
select is(public.sermons_this_month('00000000-0000-0000-0000-00000000000a'), 1,
  'only this month''s sermon is counted');

select * from finish();
rollback;
