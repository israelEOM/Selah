// Fetches a church's calendar and stores its upcoming events. Requests say plainly who they are and never try to
// get past a site's bot protection: a blocked site is reported so the owner can ask their web admin to allow it.
import { feedUrl, NotCalendarError, type ParsedEvent, parseFeed } from './feed.ts';

/** Fixed: website admins allow Selah by this name, so it must not change. */
export const USER_AGENT = 'Selah-Calendar/1.0 (+https://selah-226.pages.dev)';
const TIMEOUT_MS = 15_000;

export type SyncError = 'blocked' | 'unreachable' | 'not_calendar';
export type SyncResult = { ok: true; count: number } | { ok: false; error: SyncError };
export type ChurchFeed = { id: string; link: string; timezone: string };

export interface EventsStore {
  churchesWithLinks(): Promise<ChurchFeed[]>;
  church(id: string): Promise<{ id: string; link: string | null; timezone: string } | null>;
  replace(id: string, events: ParsedEvent[]): Promise<number>;
  recordError(id: string, error: string): Promise<void>;
}

export type SyncDeps = { fetch: typeof fetch; store: EventsStore; now: Date };

class SyncFailure extends Error {
  constructor(readonly code: SyncError) {
    super(code);
  }
}

/** Fetches [church]'s feed and replaces its events; on failure keeps what was stored and records why. */
export async function syncChurch(church: ChurchFeed, deps: SyncDeps): Promise<SyncResult> {
  try {
    const body = await fetchFeed(feedUrl(church.link), deps.fetch);
    const events = parseFeed(body, { now: deps.now, churchTimezone: church.timezone });
    return { ok: true, count: await deps.store.replace(church.id, events) };
  } catch (e) {
    const error: SyncError = e instanceof SyncFailure
      ? e.code
      : e instanceof NotCalendarError
      ? 'not_calendar'
      : 'unreachable';
    await deps.store.recordError(church.id, error);
    return { ok: false, error };
  }
}

/** Syncs every church with a link, one after another. */
export async function syncAll(deps: SyncDeps): Promise<{ synced: number; failed: number }> {
  let synced = 0, failed = 0;
  for (const church of await deps.store.churchesWithLinks()) {
    const result = await syncChurch(church, deps);
    result.ok ? synced++ : failed++;
  }
  return { synced, failed };
}

/** The feed's text. One retry on a network error or a server error that isn't a bot challenge. */
async function fetchFeed(url: string, fetch: typeof globalThis.fetch): Promise<string> {
  for (let attempt = 1;; attempt++) {
    let response: Response;
    try {
      response = await fetch(url, {
        headers: { 'user-agent': USER_AGENT, accept: 'text/calendar, */*' },
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
    } catch {
      if (attempt < 2) continue;
      throw new SyncFailure('unreachable');
    }
    const body = await response.text();
    if (isChallenge(response, body)) throw new SyncFailure('blocked');
    if (response.ok) return body;
    if (response.status >= 500 && attempt < 2) continue;
    throw new SyncFailure('unreachable');
  }
}

function isChallenge(response: Response, body: string): boolean {
  if (response.headers.get('cf-mitigated') === 'challenge') return true;
  return (response.status === 403 || response.status === 503) && body.includes('challenge-platform');
}
