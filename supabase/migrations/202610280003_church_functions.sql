-- Church RPCs: the only writers of churches and church_members. RLS blocks
-- direct writes, so creating a church, inviting, joining and changing roles
-- happen here. Errors use stable message codes the app translates:
-- church_slug_taken, church_slug_invalid, invite_invalid, last_owner,
-- not_allowed. Role order in the enum is owner < editor < member, so a
-- "higher" role is a smaller enum value.

-- Invites -------------------------------------------------------------------------

create table public.church_invites (
  token uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches (id) on delete cascade,
  role public.church_role not null check (role in ('editor', 'member')),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);
create index church_invites_church_idx on public.church_invites (church_id);

alter table public.church_invites enable row level security;
revoke all on public.church_invites from anon, authenticated;
grant select on public.church_invites to authenticated;
create policy church_invites_owner_read on public.church_invites for select
  to authenticated using ((select public.is_church_owner(church_id)));

-- Churches --------------------------------------------------------------------------

create function public.create_church(p_name text, p_slug text)
returns public.churches
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  c public.churches;
begin
  if uid is null then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if p_slug is null or p_slug !~ '^[a-z0-9](?:[a-z0-9-]{1,38})[a-z0-9]$' then
    raise exception 'church_slug_invalid';
  end if;
  begin
    insert into public.churches (slug, name, created_by)
    values (p_slug, p_name, uid) returning * into c;
  exception when unique_violation then
    raise exception 'church_slug_taken';
  end;
  insert into public.church_members (church_id, user_id, role)
  values (c.id, uid, 'owner');
  return c;
end $$;

create function public.create_invite(p_church uuid, p_role public.church_role)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  t uuid;
begin
  if not (select public.is_church_owner(p_church)) then
    raise exception 'not_allowed';
  end if;
  insert into public.church_invites (church_id, role, created_by)
  values (p_church, p_role, (select auth.uid()))
  returning token into t;
  return t;
end $$;

create function public.revoke_invite(p_token uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  ch uuid;
begin
  select i.church_id into ch from public.church_invites i where i.token = p_token;
  if ch is null or not (select public.is_church_owner(ch)) then
    raise exception 'not_allowed';
  end if;
  update public.church_invites set revoked_at = now()
  where token = p_token and revoked_at is null;
end $$;

create function public.invite_info(p_token uuid)
returns table (church_name text, church_slug text, role public.church_role)
language sql stable security definer set search_path = '' as $$
  select c.name, c.slug, i.role
  from public.church_invites i
  join public.churches c on c.id = i.church_id
  where i.token = p_token and i.revoked_at is null;
$$;

create function public.accept_invite(p_token uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  inv public.church_invites;
  slug text;
begin
  if uid is null then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  select * into inv from public.church_invites
  where token = p_token and revoked_at is null;
  if not found then
    raise exception 'invite_invalid';
  end if;
  insert into public.church_members (church_id, user_id, role)
  values (inv.church_id, uid, inv.role)
  on conflict (church_id, user_id) do update set role = excluded.role
    where public.church_members.role > excluded.role;  -- raise, never lower
  select c.slug into slug from public.churches c where c.id = inv.church_id;
  return slug;
end $$;

create function public.join_church(p_church uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if not exists (select 1 from public.churches c where c.id = p_church) then
    raise exception 'not_allowed';
  end if;
  insert into public.church_members (church_id, user_id, role)
  values (p_church, uid, 'member')
  on conflict (church_id, user_id) do nothing;
end $$;

-- People and roles ---------------------------------------------------------------------

create function public.church_people(p_church uuid)
returns table (user_id uuid, name text, email text,
               role public.church_role, joined_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (select public.is_church_owner(p_church)) then
    raise exception 'not_allowed';
  end if;
  return query
    select m.user_id, p.name, u.email::text, m.role, m.created_at
    from public.church_members m
    join auth.users u on u.id = m.user_id
    left join public.profiles p on p.id = m.user_id
    where m.church_id = p_church
    order by m.role, lower(coalesce(p.name, u.email)), u.email;
end $$;

create function public.set_member_role(
  p_church uuid, p_user uuid, p_role public.church_role) returns void
language plpgsql security definer set search_path = '' as $$
declare
  cur public.church_role;
begin
  if not (select public.is_church_owner(p_church)) then
    raise exception 'not_allowed';
  end if;
  -- Lock the owners so two concurrent demotions cannot both pass the guard.
  perform 1 from public.church_members m
  where m.church_id = p_church and m.role = 'owner' for update;
  select m.role into cur from public.church_members m
  where m.church_id = p_church and m.user_id = p_user;
  if cur is null then
    raise exception 'not_allowed';
  end if;
  if cur = 'owner' and p_role <> 'owner' and not exists (
    select 1 from public.church_members m
    where m.church_id = p_church and m.role = 'owner' and m.user_id <> p_user
  ) then
    raise exception 'last_owner';
  end if;
  update public.church_members set role = p_role
  where church_id = p_church and user_id = p_user;
end $$;

create function public.remove_member(p_church uuid, p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  cur public.church_role;
begin
  if p_user is distinct from (select auth.uid())
     and not (select public.is_church_owner(p_church)) then
    raise exception 'not_allowed';
  end if;
  perform 1 from public.church_members m
  where m.church_id = p_church and m.role = 'owner' for update;
  select m.role into cur from public.church_members m
  where m.church_id = p_church and m.user_id = p_user;
  if cur is null then
    return;
  end if;
  if cur = 'owner' and not exists (
    select 1 from public.church_members m
    where m.church_id = p_church and m.role = 'owner' and m.user_id <> p_user
  ) then
    raise exception 'last_owner';
  end if;
  delete from public.church_members
  where church_id = p_church and user_id = p_user;
end $$;

revoke execute on function
  public.create_church(text, text), public.create_invite(uuid, public.church_role),
  public.revoke_invite(uuid), public.invite_info(uuid), public.accept_invite(uuid),
  public.join_church(uuid), public.church_people(uuid),
  public.set_member_role(uuid, uuid, public.church_role),
  public.remove_member(uuid, uuid)
  from public, anon;
grant execute on function
  public.create_church(text, text), public.create_invite(uuid, public.church_role),
  public.revoke_invite(uuid), public.accept_invite(uuid),
  public.join_church(uuid), public.church_people(uuid),
  public.set_member_role(uuid, uuid, public.church_role),
  public.remove_member(uuid, uuid)
  to authenticated;
grant execute on function public.invite_info(uuid) to anon, authenticated;
