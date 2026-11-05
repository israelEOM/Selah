import { assertEquals } from '@std/assert';
import type { ParsedEvent } from './feed.ts';
import { type EventsStore, syncAll, syncChurch, USER_AGENT } from './sync.ts';

const now = new Date('2026-11-05T10:00:00Z');
const tribe = Deno.readTextFileSync(new URL('./fixtures/tribe.ics', import.meta.url));
const church = { id: 'A', link: 'https://icpresbiteriana.com/events/', timezone: 'Europe/Madrid' };

class MemoryStore implements EventsStore {
  events = new Map<string, ParsedEvent[]>();
  errors = new Map<string, string>();
  constructor(public churches: { id: string; link: string; timezone: string }[] = []) {}
  churchesWithLinks() {
    return Promise.resolve(this.churches);
  }
  church(id: string) {
    return Promise.resolve(this.churches.find((c) => c.id === id) ?? null);
  }
  replace(id: string, events: ParsedEvent[]) {
    this.events.set(id, events);
    this.errors.delete(id);
    return Promise.resolve(events.length);
  }
  recordError(id: string, error: string) {
    this.errors.set(id, error);
    return Promise.resolve();
  }
}

/** A fetch that answers each call with the next response, and remembers the requests. */
function fakeFetch(...responses: (() => Response)[]) {
  const requests: Request[] = [];
  const fetch = (input: RequestInfo | URL, init?: RequestInit) => {
    requests.push(new Request(input, init));
    const next = responses.shift();
    return next ? Promise.resolve(next()) : Promise.reject(new TypeError('network down'));
  };
  return { fetch: fetch as typeof globalThis.fetch, requests };
}

const ics = (body: string) => () => new Response(body, { headers: { 'content-type': 'text/calendar' } });

Deno.test('a calendar is fetched honestly and stored', async () => {
  const store = new MemoryStore();
  const { fetch, requests } = fakeFetch(ics(tribe));
  assertEquals(await syncChurch(church, { fetch, store, now }), { ok: true, count: 4 });
  assertEquals(store.events.get('A')?.length, 4);
  assertEquals(requests.length, 1);
  assertEquals(requests[0].url, 'https://icpresbiteriana.com/?post_type=tribe_events&ical=1&eventDisplay=list');
  assertEquals(requests[0].headers.get('user-agent'), USER_AGENT);
  assertEquals(USER_AGENT, 'Selah-Calendar/1.0 (+https://selah-226.pages.dev)');
});

Deno.test('challenge page reports blocked and keeps events', async () => {
  const store = new MemoryStore();
  const kept = [{ uid: '1' }, { uid: '2' }] as ParsedEvent[];
  store.events.set('A', kept);
  const { fetch, requests } = fakeFetch(() =>
    new Response('<!DOCTYPE html><title>Just a moment...</title>', {
      status: 403,
      headers: { 'content-type': 'text/html', 'cf-mitigated': 'challenge' },
    })
  );
  assertEquals(await syncChurch(church, { fetch, store, now }), { ok: false, error: 'blocked' });
  assertEquals(store.events.get('A'), kept);
  assertEquals(store.errors.get('A'), 'blocked');
  assertEquals(requests.length, 1);
});

Deno.test('a challenge page without the header is still blocked', async () => {
  const { fetch } = fakeFetch(() =>
    new Response('<html><script src="/cdn-cgi/challenge-platform/h/b/orchestrate"></script></html>', {
      status: 503,
      headers: { 'content-type': 'text/html' },
    })
  );
  assertEquals(await syncChurch(church, { fetch, store: new MemoryStore(), now }), { ok: false, error: 'blocked' });
});

Deno.test('a web page that is not a calendar', async () => {
  const store = new MemoryStore();
  const { fetch } = fakeFetch(() => new Response('<!DOCTYPE html><p>Eventos</p>', { status: 200 }));
  assertEquals(await syncChurch(church, { fetch, store, now }), { ok: false, error: 'not_calendar' });
  assertEquals(store.errors.get('A'), 'not_calendar');
});

Deno.test('a network failure is retried once, then unreachable', async () => {
  const { fetch, requests } = fakeFetch();
  assertEquals(await syncChurch(church, { fetch, store: new MemoryStore(), now }), {
    ok: false,
    error: 'unreachable',
  });
  assertEquals(requests.length, 2);
});

Deno.test('a server error is retried once and can recover', async () => {
  const { fetch, requests } = fakeFetch(() => new Response('oops', { status: 502 }), ics(tribe));
  assertEquals(await syncChurch(church, { fetch, store: new MemoryStore(), now }), { ok: true, count: 4 });
  assertEquals(requests.length, 2);
});

Deno.test('one church failing does not stop the others', async () => {
  const store = new MemoryStore([
    { id: 'A', link: 'https://a.org/a.ics', timezone: 'Europe/Madrid' },
    { id: 'B', link: 'https://b.org/b.ics', timezone: 'Europe/Madrid' },
    { id: 'C', link: 'https://c.org/c.ics', timezone: 'Europe/Madrid' },
  ]);
  const { fetch } = fakeFetch(ics(tribe), () => new Response('nope', { status: 404 }), ics(tribe));
  assertEquals(await syncAll({ fetch, store, now }), { synced: 2, failed: 1 });
  assertEquals(store.errors.get('B'), 'unreachable');
});
