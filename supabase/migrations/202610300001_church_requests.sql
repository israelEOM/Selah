-- Church requests. A signed-in pastor asks to bring their church to Selah; only
-- a platform admin approves, which creates the church with the requester as its
-- owner. Nobody becomes an owner without that approval. RLS lets people read
-- their own requests and admins read all; every write goes through the RPCs.
-- New error codes: request_pending_exists, request_not_pending.

create type public.church_request_status as enum ('pending', 'approved', 'rejected');

create table public.church_requests (
  id uuid primary key default gen_random_uuid(),
  requested_by uuid not null references auth.users (id) on delete cascade,
  church_name text not null check (char_length(btrim(church_name)) between 2 and 80),
  note text check (note is null or char_length(note) <= 500),
  status public.church_request_status not null default 'pending',
  church_id uuid references public.churches (id) on delete set null,
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references auth.users (id)
);
-- One pending request per person.
create unique index church_requests_one_pending_idx on public.church_requests (requested_by)
  where status = 'pending';

alter table public.church_requests enable row level security;
revoke all on public.church_requests from anon, authenticated;
grant select on public.church_requests to authenticated;
create policy church_requests_read on public.church_requests for select to authenticated
  using (requested_by = (select auth.uid()) or (select public.is_platform_admin()));

create function public.request_church(p_name text, p_note text)
returns public.church_requests
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  r public.church_requests;
begin
  if uid is null then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  begin
    insert into public.church_requests (requested_by, church_name, note)
    values (uid, btrim(p_name), nullif(btrim(p_note), ''))
    returning * into r;
  exception when unique_violation then
    raise exception 'request_pending_exists';
  end;
  return r;
end $$;

create function public.decide_church_request(p_request uuid, p_approve boolean, p_slug text)
returns public.church_requests
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  r public.church_requests;
  c public.churches;
begin
  if uid is null then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if not (select public.is_platform_admin()) then
    raise exception 'not_allowed';
  end if;
  -- Lock the request so two concurrent decisions cannot both pass the check.
  select * into r from public.church_requests where id = p_request for update;
  if not found or r.status <> 'pending' then
    raise exception 'request_not_pending';
  end if;
  if p_approve then
    if p_slug is null or p_slug !~ '^[a-z0-9](?:[a-z0-9-]{1,38})[a-z0-9]$' then
      raise exception 'church_slug_invalid';
    end if;
    begin
      insert into public.churches (slug, name, created_by)
      values (p_slug, r.church_name, r.requested_by) returning * into c;
    exception when unique_violation then
      raise exception 'church_slug_taken';
    end;
    insert into public.church_members (church_id, user_id, role)
    values (c.id, r.requested_by, 'owner');
  end if;
  update public.church_requests set
    status = case when p_approve then 'approved' else 'rejected' end::public.church_request_status,
    church_id = c.id,
    decided_at = now(),
    decided_by = uid
  where id = p_request
  returning * into r;
  return r;
end $$;

create function public.pending_church_requests()
returns table (id uuid, church_name text, note text,
               status public.church_request_status, created_at timestamptz,
               requester_email text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (select public.is_platform_admin()) then
    raise exception 'not_allowed';
  end if;
  return query
    select q.id, q.church_name, q.note, q.status, q.created_at, u.email::text
    from public.church_requests q
    join auth.users u on u.id = q.requested_by
    where q.status = 'pending'
    order by q.created_at, q.id;
end $$;

revoke execute on function
  public.request_church(text, text), public.decide_church_request(uuid, boolean, text),
  public.pending_church_requests()
  from public, anon;
grant execute on function
  public.request_church(text, text), public.decide_church_request(uuid, boolean, text),
  public.pending_church_requests()
  to authenticated;
