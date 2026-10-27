-- Shared helpers for the database tests. This file runs first (alphabetical)
-- and commits, so every later file can call tests.* inside its own
-- begin ... rollback block.
begin;

create extension if not exists pgtap with schema extensions;
create schema if not exists tests;

create or replace function tests.create_user(email text) returns uuid
language plpgsql as $$
declare
  uid uuid := gen_random_uuid();
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data,
                          created_at, updated_at)
  values (uid, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', email, '{}'::jsonb, now(), now());
  return uid;
end $$;

create or replace function tests.act_as(uid uuid) returns void
language plpgsql as $$
begin
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', uid)::text, true);
  set local role authenticated;
end $$;

create or replace function tests.act_as_anon() returns void
language plpgsql as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '{}', true);
  set local role anon;
end $$;

create or replace function tests.reset() returns void
language plpgsql as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '', true);
end $$;

-- Test files switch roles mid-run, so every role must reach the helpers.
grant usage on schema tests to public;
grant execute on all functions in schema tests to public;

select plan(1);
select pass('test helpers installed');
select * from finish();

commit;
