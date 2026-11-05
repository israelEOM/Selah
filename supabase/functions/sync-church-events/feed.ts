// Reads a church's iCalendar feed into the upcoming events Selah stores (see church_events).
import ICAL from 'ical.js';
import { TZDate } from '@date-fns/tz';

/** How far ahead, and how many events, a church shows. */
export const WINDOW_DAYS = 60;
export const MAX_EVENTS = 20;

export type ParsedEvent = {
  uid: string;
  title: string;
  /** UTC ISO instants. */
  starts_at: string;
  ends_at: string;
  all_day: boolean;
  /** The church's wall-clock times, `YYYY-MM-DDTHH:mm:ss` with no offset. */
  local_starts_at: string;
  local_ends_at: string;
  location: string | null;
  url: string | null;
  timezone: string;
};

export class NotCalendarError extends Error {
  constructor() {
    super('not a calendar');
  }
}

/** The URL to fetch for what an owner pasted: webcal becomes https, an Events Calendar page becomes its feed. */
export function feedUrl(link: string): string {
  const url = new URL(link.trim().replace(/^webcal:\/\//i, 'https://'));
  if (/^\/events\/?$/.test(url.pathname) && !url.search) {
    return `${url.origin}/?post_type=tribe_events&ical=1&eventDisplay=list`;
  }
  return url.toString();
}

/** The upcoming events in [ics]: from now through WINDOW_DAYS, at most MAX_EVENTS, earliest first. */
export function parseFeed(ics: string, opts: { now: Date; churchTimezone: string }): ParsedEvent[] {
  if (!ics.trimStart().startsWith('BEGIN:VCALENDAR')) throw new NotCalendarError();
  let calendar: ICAL.Component;
  try {
    calendar = new ICAL.Component(ICAL.parse(ics));
  } catch {
    throw new NotCalendarError();
  }
  const feedZone = ianaZone(calendar.getFirstPropertyValue('x-wr-timezone') as string | null);
  const fallbackZone = feedZone ?? opts.churchTimezone;
  const from = opts.now.getTime();
  const until = from + WINDOW_DAYS * 24 * 60 * 60 * 1000;

  const events: ParsedEvent[] = [];
  for (const component of calendar.getAllSubcomponents('vevent')) {
    const event = new ICAL.Event(component);
    const tzid = component.getFirstProperty('dtstart')?.getParameter('tzid') as string | undefined;
    const zone = ianaZone(tzid ?? null) ?? fallbackZone;
    const base = {
      uid: event.uid,
      title: decodeEntities(event.summary ?? '').trim(),
      location: nonEmpty(decodeEntities(event.location ?? '')),
      url: nonEmpty(component.getFirstPropertyValue('url') as string | null),
      timezone: zone,
    };
    const occurrences: { start: ICAL.Time; end: ICAL.Time }[] = [];
    if (event.isRecurring()) {
      const iterator = event.iterator();
      for (let next = iterator.next(), guard = 0; next && guard < 1000; next = iterator.next(), guard++) {
        const details = event.getOccurrenceDetails(next);
        if (toInstant(details.startDate, zone) >= until) break;
        occurrences.push({ start: details.startDate, end: details.endDate });
      }
    } else {
      occurrences.push({ start: event.startDate, end: event.endDate });
    }
    for (const { start, end } of occurrences) {
      const startsAt = toInstant(start, zone);
      const endsAt = toInstant(end, zone);
      if (endsAt <= from || startsAt >= until) continue;
      const startsIso = new Date(startsAt).toISOString();
      events.push({
        ...base,
        uid: event.isRecurring() ? `${base.uid}@${startsIso}` : base.uid,
        starts_at: startsIso,
        ends_at: new Date(endsAt).toISOString(),
        all_day: start.isDate,
        local_starts_at: wallClock(start, startsAt, zone),
        local_ends_at: wallClock(end, endsAt, zone),
      });
    }
  }
  return events.sort((a, b) => a.starts_at.localeCompare(b.starts_at)).slice(0, MAX_EVENTS);
}

/** The UTC instant of [time]: UTC times as they are, everything else read as wall-clock in [zone]. */
function toInstant(time: ICAL.Time, zone: string): number {
  if (isUtc(time)) return Date.UTC(time.year, time.month - 1, time.day, time.hour, time.minute, time.second);
  if (time.isDate) return new TZDate(time.year, time.month - 1, time.day, 0, 0, 0, zone).getTime();
  return new TZDate(time.year, time.month - 1, time.day, time.hour, time.minute, time.second, zone).getTime();
}

/** [time] on the church's wall clock. */
function wallClock(time: ICAL.Time, instant: number, zone: string): string {
  if (!isUtc(time)) return format(time.year, time.month, time.day, time.isDate ? 0 : time.hour,
    time.isDate ? 0 : time.minute, time.isDate ? 0 : time.second);
  const local = new TZDate(instant, zone);
  return format(local.getFullYear(), local.getMonth() + 1, local.getDate(), local.getHours(), local.getMinutes(),
    local.getSeconds());
}

const isUtc = (time: ICAL.Time) => !time.isDate && time.zone?.tzid === 'UTC';

const pad = (n: number) => String(n).padStart(2, '0');
const format = (y: number, mo: number, d: number, h: number, mi: number, s: number) =>
  `${y}-${pad(mo)}-${pad(d)}T${pad(h)}:${pad(mi)}:${pad(s)}`;

const nonEmpty = (value: string | null | undefined) => (value && value.trim() ? value.trim() : null);

/** Windows zone names that Outlook and Exchange put in TZID, to IANA. */
const windowsZones: Record<string, string> = {
  'Romance Standard Time': 'Europe/Paris',
  'W. Europe Standard Time': 'Europe/Berlin',
  'Central Europe Standard Time': 'Europe/Budapest',
  'Central European Standard Time': 'Europe/Warsaw',
  'GMT Standard Time': 'Europe/London',
  'Greenwich Standard Time': 'Atlantic/Reykjavik',
  'E. South America Standard Time': 'America/Sao_Paulo',
  'SA Pacific Standard Time': 'America/Bogota',
  'SA Western Standard Time': 'America/La_Paz',
  'Pacific SA Standard Time': 'America/Santiago',
  'Argentina Standard Time': 'America/Buenos_Aires',
  'Venezuela Standard Time': 'America/Caracas',
  'Central Standard Time (Mexico)': 'America/Mexico_City',
  'Eastern Standard Time': 'America/New_York',
  'Central Standard Time': 'America/Chicago',
  'Mountain Standard Time': 'America/Denver',
  'Pacific Standard Time': 'America/Los_Angeles',
  'UTC': 'UTC',
};

/** [name] as an IANA zone, or null when it isn't one we know. */
function ianaZone(name: string | null): string | null {
  if (!name) return null;
  const candidate = windowsZones[name] ?? name;
  try {
    new Intl.DateTimeFormat('en', { timeZone: candidate });
    return candidate;
  } catch {
    return null;
  }
}

const namedEntities: Record<string, string> = { amp: '&', quot: '"', apos: "'", lt: '<', gt: '>', nbsp: ' ' };

/** WordPress titles arrive with HTML entities such as `&#8211;`. */
function decodeEntities(text: string): string {
  return text.replace(/&(#x[0-9a-f]+|#[0-9]+|[a-z]+);/gi, (match, code: string) => {
    if (code[0] === '#') {
      const n = code[1] === 'x' || code[1] === 'X' ? parseInt(code.slice(2), 16) : parseInt(code.slice(1), 10);
      return Number.isFinite(n) ? String.fromCodePoint(n) : match;
    }
    return namedEntities[code.toLowerCase()] ?? match;
  });
}
