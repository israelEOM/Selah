-- Only platform admins create churches; everyone else joins one by invite.
create or replace function public.create_church(p_name text, p_slug text)
returns public.churches
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  c public.churches;
begin
  if uid is null then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if not (select public.is_platform_admin()) then
    raise exception 'not_allowed';
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
