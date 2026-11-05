import { assertEquals, assertThrows } from '@std/assert';
import { feedUrl, NotCalendarError, parseFeed } from './feed.ts';

const now = new Date('2026-11-05T10:00:00Z');
const madrid = { now, churchTimezone: 'Europe/Madrid' };
const fixture = (name: string) => Deno.readTextFileSync(new URL(`./fixtures/${name}`, import.meta.url));

/** A one-event calendar around [body]'s VEVENT lines. */
const calendar = (...events: string[]) =>
  ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Test//EN', ...events, 'END:VCALENDAR'].join('\r\n');
const event = (uid: string, start: string, end: string) =>
  ['BEGIN:VEVENT', `UID:${uid}`, `DTSTART:${start}`, `DTEND:${end}`, `SUMMARY:${uid}`, 'END:VEVENT'].join('\r\n');

Deno.test('feedUrl turns webcal into https', () => {
  assertEquals(feedUrl('webcal://a.org/x.ics'), 'https://a.org/x.ics');
});

Deno.test('feedUrl turns an Events Calendar page into its iCal feed', () => {
  const feed = 'https://icpresbiteriana.com/?post_type=tribe_events&ical=1&eventDisplay=list';
  assertEquals(feedUrl('https://icpresbiteriana.com/events/'), feed);
  assertEquals(feedUrl('https://icpresbiteriana.com/events'), feed);
});

Deno.test('feedUrl leaves other links alone', () => {
  const google = 'https://calendar.google.com/calendar/ical/abc%40group.calendar.google.com/public/basic.ics';
  assertEquals(feedUrl(google), google);
});

Deno.test('tribe feed reads times in Madrid and decodes the title', () => {
  const events = parseFeed(fixture('tribe.ics'), madrid);
  assertEquals(events.length, 4);
  const first = events[0];
  assertEquals(first.title, 'Reunión de Mujeres – Mi hermana y amiga en la Fe');
  assertEquals(first.local_starts_at, '2026-11-14T17:30:00');
  assertEquals(first.local_ends_at, '2026-11-14T19:30:00');
  assertEquals(first.starts_at, '2026-11-14T16:30:00.000Z');
  assertEquals(first.timezone, 'Europe/Madrid');
  assertEquals(first.all_day, false);
  assertEquals(first.url, 'https://icpresbiteriana.com/event/reunion-de-mujeres-mi-hermana-y-amiga-en-la-fe/');
  assertEquals(first.location, 'Iglesia Cristiana Presbiteriana Alcorcón, Calle Mayor 1, Alcorcón');
  assertEquals(events[1].title, 'Reunión de Hombres – ¿Qué, para qué, cómo y a quién alabamos?');
  assertEquals(events[3].location, null);
});

Deno.test('google feed in UTC uses its X-WR-TIMEZONE', () => {
  const [e] = parseFeed(fixture('google_utc.ics'), madrid);
  assertEquals(e.timezone, 'America/Bogota');
  assertEquals(e.local_starts_at, '2026-11-20T18:00:00');
  assertEquals(e.local_ends_at, '2026-11-20T20:00:00');
  assertEquals(e.starts_at, '2026-11-20T23:00:00.000Z');
  assertEquals(e.url, null);
});

Deno.test('floating times use the church timezone', () => {
  const [e] = parseFeed(fixture('floating.ics'), { now, churchTimezone: 'Europe/Lisbon' });
  assertEquals(e.timezone, 'Europe/Lisbon');
  assertEquals(e.local_starts_at, '2026-11-10T19:00:00');
  assertEquals(e.starts_at, '2026-11-10T19:00:00.000Z');
});

Deno.test('outlook Windows zone maps to an IANA zone', () => {
  const [e] = parseFeed(fixture('outlook_windows_tz.ics'), { now, churchTimezone: 'America/Bogota' });
  assertEquals(e.timezone, 'Europe/Paris');
  assertEquals(e.local_starts_at, '2026-11-18T20:00:00');
  assertEquals(e.starts_at, '2026-11-18T19:00:00.000Z');
});

Deno.test('weekly rule expands inside the window', () => {
  const events = parseFeed(fixture('weekly.ics'), madrid);
  assertEquals(events.length, 9);
  assertEquals(events[0].local_starts_at, '2026-11-08T11:00:00');
  assertEquals(events[8].local_starts_at, '2027-01-03T11:00:00');
  assertEquals(new Set(events.map((e) => e.uid)).size, 9);
  assertEquals(events[0].uid, 'weekly-1@example.org@2026-11-08T10:00:00.000Z');
});

Deno.test('past and far-off events are dropped', () => {
  const ics = calendar(
    event('past', '20261104T100000Z', '20261104T110000Z'),
    event('ongoing', '20261105T090000Z', '20261105T120000Z'),
    event('far', '20270105T100000Z', '20270105T110000Z'),
  );
  assertEquals(parseFeed(ics, madrid).map((e) => e.uid), ['ongoing']);
});

Deno.test('at most 20 events, earliest first', () => {
  const days = Array.from({ length: 25 }, (_, i) => 25 - i);
  const ics = calendar(...days.map((d) => event(`d${d}`, `202611${String(d + 5).padStart(2, '0')}T100000Z`,
    `202611${String(d + 5).padStart(2, '0')}T110000Z`)));
  const events = parseFeed(ics, madrid);
  assertEquals(events.length, 20);
  assertEquals(events[0].uid, 'd1');
  assertEquals(events[19].uid, 'd20');
});

Deno.test('an all-day event keeps its date', () => {
  const ics = calendar(['BEGIN:VEVENT', 'UID:retreat', 'DTSTART;VALUE=DATE:20261120',
    'DTEND;VALUE=DATE:20261121', 'SUMMARY:Retiro', 'END:VEVENT'].join('\r\n'));
  const [e] = parseFeed(ics, madrid);
  assertEquals(e.all_day, true);
  assertEquals(e.local_starts_at, '2026-11-20T00:00:00');
  assertEquals(e.local_ends_at, '2026-11-21T00:00:00');
  assertEquals(e.starts_at, '2026-11-19T23:00:00.000Z');
});

Deno.test('a web page is not a calendar', () => {
  assertThrows(() => parseFeed('<!DOCTYPE html><html><body>Hola</body></html>', madrid), NotCalendarError);
});

const editedFeed = () => parseFeed(fixture('weekly_edited.ics'), madrid);
const sundays = () => editedFeed().filter((e) => e.uid.startsWith('weekly-edited@'));

Deno.test('an edited occurrence replaces its slot instead of adding one', () => {
  const events = sundays();
  assertEquals(new Set(events.map((e) => e.uid)).size, events.length);
  const moved = events.filter((e) => e.local_starts_at.startsWith('2026-11-15'));
  assertEquals(moved.length, 1);
  assertEquals(moved[0].local_starts_at, '2026-11-15T12:00:00');
  assertEquals(moved[0].title, 'Culto dominical (con Santa Cena)');
  assertEquals(events.filter((e) => e.local_starts_at.startsWith('2026-11-22')).map((e) => e.title), [
    'Culto dominical – invitado especial',
  ]);
});

Deno.test('cancelled events and cancelled occurrences are dropped', () => {
  const events = editedFeed();
  assertEquals(events.some((e) => e.title === 'Ensayo del coro'), false);
  assertEquals(sundays().some((e) => e.local_starts_at.startsWith('2026-11-29')), false);
});

Deno.test('a daily series that began years ago still shows its next days', () => {
  const ics = Deno.readTextFileSync(new URL('./fixtures/weekly_edited.ics', import.meta.url));
  const daily = parseFeed(ics, { now, churchTimezone: 'Europe/Madrid' }).filter((e) =>
    e.uid.startsWith('daily-prayer@')
  );
  assertEquals(daily.length > 0, true);
  assertEquals(daily[0].local_starts_at, '2026-11-06T07:00:00');
});
