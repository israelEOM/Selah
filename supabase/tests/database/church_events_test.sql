begin;
select plan(13);

select has_table('public', 'church_events', 'church_events table exists');

insert into public.churches (id, slug, name) values
  ('00000000-0000-0000-0000-00000000000a', 'church-a', 'Church A');

create temp table u as select tests.create_user('owner@example.com') as owner;
grant select on u to public;
insert into public.church_members (church_id, user_id, role)
select '00000000-0000-0000-0000-00000000000a', owner, 'owner' from u;

-- Anyone reads events.
select tests.act_as_anon();
select lives_ok($$select * from public.church_events$$, 'anon can read church_events');

-- The owner sets the link and the timezone, nothing the sync writes.
select tests.act_as((select owner from u));
select lives_ok(
  $$update public.churches set events_calendar_url = 'https://example.org/cal.ics', timezone = 'Europe/Lisbon'
    where id = '00000000-0000-0000-0000-00000000000a'$$,
  'owner can set the calendar link and timezone');
select throws_ok(
  $$update public.churches set events_synced_at = now() where id = '00000000-0000-0000-0000-00000000000a'$$,
  '42501', null, 'owner cannot set events_synced_at');
select throws_ok(
  $$update public.churches set events_calendar_url = 'http://example.org/cal.ics'
    where id = '00000000-0000-0000-0000-00000000000a'$$,
  '23514', null, 'a link that is not https is rejected');
select throws_ok(
  $$update public.churches set timezone = 'Mars/Base' where id = '00000000-0000-0000-0000-00000000000a'$$,
  '23514', null, 'an unknown timezone is rejected');
select throws_ok(
  $$select public.replace_church_events('00000000-0000-0000-0000-00000000000a', '[]'::jsonb)$$,
  '42501', null, 'members cannot replace events');

-- The sync (service role) replaces the church's events.
select tests.reset();
set local role service_role;
select is(public.replace_church_events('00000000-0000-0000-0000-00000000000a', '[
  {"uid": "1", "title": "Reunión", "starts_at": "2026-11-14T16:30:00Z", "ends_at": "2026-11-14T18:30:00Z",
   "all_day": false, "local_starts_at": "2026-11-14T17:30:00", "local_ends_at": "2026-11-14T19:30:00",
   "location": "ICP Alcorcón", "url": "https://example.org/e/1", "timezone": "Europe/Madrid"}
]'::jsonb), 1, 'replace returns the number of events');
select isnt((select events_synced_at from public.churches where id = '00000000-0000-0000-0000-00000000000a'),
  null, 'replace records when it synced');
select is(public.replace_church_events('00000000-0000-0000-0000-00000000000a', '[]'::jsonb), 0,
  'replace with nothing leaves nothing');
select public.replace_church_events('00000000-0000-0000-0000-00000000000a', '[
  {"uid": "1", "title": "Reunión", "starts_at": "2026-11-14T16:30:00Z", "ends_at": "2026-11-14T18:30:00Z",
   "all_day": false, "local_starts_at": "2026-11-14T17:30:00", "local_ends_at": "2026-11-14T19:30:00",
   "location": null, "url": null, "timezone": "Europe/Madrid"}
]'::jsonb);
select public.record_church_events_error('00000000-0000-0000-0000-00000000000a', 'blocked');
select is((select events_sync_error from public.churches where id = '00000000-0000-0000-0000-00000000000a'),
  'blocked', 'an error is recorded');
select is((select count(*)::int from public.church_events), 1, 'an error keeps the stored events');

-- Clearing the link deletes the events.
select tests.act_as((select owner from u));
update public.churches set events_calendar_url = null where id = '00000000-0000-0000-0000-00000000000a';
select tests.reset();
select is((select count(*)::int from public.church_events
           where church_id = '00000000-0000-0000-0000-00000000000a'), 0, 'clearing the link deletes events');

select * from finish();
rollback;
