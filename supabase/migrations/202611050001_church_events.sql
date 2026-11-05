-- Church calendars: an owner's link to the church's iCal feed, and the upcoming events the
-- sync-church-events function reads from it. Members only read; the function writes as the service role.

create function public.is_timezone(p text) returns boolean
language sql stable set search_path = '' as $$
  select exists (select 1 from pg_catalog.pg_timezone_names where name = p)
$$;

alter table public.churches
  add column events_calendar_url text check (events_calendar_url ~ '^https://'),
  add column timezone text not null default 'Europe/Madrid' check (public.is_timezone(timezone)),
  add column events_synced_at timestamptz,
  add column events_sync_error text;

-- Owners edit the link and the timezone too; the sync columns stay ours.
grant update (events_calendar_url, timezone) on public.churches to authenticated;

create table public.church_events (
  church_id uuid not null references public.churches (id) on delete cascade,
  -- The feed's UID, plus the start for each occurrence of a repeating event.
  uid text not null,
  title text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  all_day boolean not null default false,
  -- The church's wall-clock times, so the app needs no timezone database.
  local_starts_at timestamp not null,
  local_ends_at timestamp not null,
  location text,
  url text,
  timezone text not null,
  primary key (church_id, uid)
);
create index church_events_church_start on public.church_events (church_id, starts_at);

alter table public.church_events enable row level security;
revoke all on public.church_events from anon, authenticated;
grant select on public.church_events to anon, authenticated;
create policy church_events_read on public.church_events for select
  to anon, authenticated using (true);

-- Replaces a church's events in one go and records the sync.
create function public.replace_church_events(p_church uuid, p_events jsonb) returns int
language plpgsql security definer set search_path = '' as $$
declare
  n int;
begin
  delete from public.church_events where church_id = p_church;
  insert into public.church_events (church_id, uid, title, starts_at, ends_at, all_day,
                                    local_starts_at, local_ends_at, location, url, timezone)
  select p_church, e.uid, e.title, e.starts_at, e.ends_at, coalesce(e.all_day, false),
         e.local_starts_at, e.local_ends_at, e.location, e.url, e.timezone
  from jsonb_to_recordset(p_events) as e(uid text, title text, starts_at timestamptz, ends_at timestamptz,
       all_day boolean, local_starts_at timestamp, local_ends_at timestamp, location text, url text,
       timezone text);
  get diagnostics n = row_count;
  update public.churches set events_synced_at = now(), events_sync_error = null where id = p_church;
  return n;
end $$;

-- A failed sync keeps the stored events and notes why.
create function public.record_church_events_error(p_church uuid, p_error text) returns void
language sql security definer set search_path = '' as $$
  update public.churches set events_sync_error = p_error where id = p_church;
$$;

revoke execute on function public.replace_church_events(uuid, jsonb),
  public.record_church_events_error(uuid, text) from public, anon, authenticated;
grant execute on function public.replace_church_events(uuid, jsonb),
  public.record_church_events_error(uuid, text) to service_role;

-- Clearing the link turns the calendar off: its events and sync notes go.
create function public.clear_church_events() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.events_calendar_url is null and old.events_calendar_url is not null then
    delete from public.church_events where church_id = new.id;
    new.events_synced_at := null;
    new.events_sync_error := null;
  end if;
  return new;
end $$;
create trigger churches_clear_events before update of events_calendar_url on public.churches
  for each row execute function public.clear_church_events();
