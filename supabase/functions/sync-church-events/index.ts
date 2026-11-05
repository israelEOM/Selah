// POST { church_id } as a church owner: sync that church now (Church settings, after the link changes).
// POST { all: true } with x-selah-cron: sync every church with a link (pg_cron, every 3 hours).
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type { ParsedEvent } from './feed.ts';
import { type EventsStore, syncAll, syncChurch } from './sync.ts';

const cors = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'content-type': 'application/json' } });

function databaseStore(db: SupabaseClient): EventsStore {
  return {
    async churchesWithLinks() {
      const { data, error } = await db.from('churches').select('id, events_calendar_url, timezone')
        .not('events_calendar_url', 'is', null);
      if (error) throw error;
      return data.map((c) => ({ id: c.id, link: c.events_calendar_url, timezone: c.timezone }));
    },
    async church(id: string) {
      const { data, error } = await db.from('churches').select('id, events_calendar_url, timezone').eq('id', id)
        .maybeSingle();
      if (error) throw error;
      return data && { id: data.id, link: data.events_calendar_url, timezone: data.timezone };
    },
    async replace(id: string, events: ParsedEvent[]) {
      const { data, error } = await db.rpc('replace_church_events', { p_church: id, p_events: events });
      if (error) throw error;
      return data as number;
    },
    async recordError(id: string, message: string) {
      const { error } = await db.rpc('record_church_events_error', { p_church: id, p_error: message });
      if (error) throw error;
    },
  };
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (request.method !== 'POST') return json({ error: 'method' }, 405);
  const body = await request.json().catch(() => null);
  const url = Deno.env.get('SUPABASE_URL')!;
  const service = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false },
  });
  const deps = { fetch, store: databaseStore(service), now: new Date() };

  if (body?.all === true) {
    const secret = Deno.env.get('SYNC_SECRET');
    if (!secret || request.headers.get('x-selah-cron') !== secret) return json({ error: 'forbidden' }, 403);
    return json(await syncAll(deps));
  }

  if (typeof body?.church_id === 'string') {
    const authorization = request.headers.get('authorization');
    if (!authorization) return json({ error: 'forbidden' }, 403);
    const asCaller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { authorization } },
      auth: { persistSession: false },
    });
    const { data: isOwner } = await asCaller.rpc('is_church_owner', { p_church: body.church_id });
    if (isOwner !== true) return json({ error: 'forbidden' }, 403);
    const church = await deps.store.church(body.church_id);
    if (!church?.link) return json({ error: 'no_link' }, 400);
    return json(await syncChurch({ ...church, link: church.link }, deps));
  }

  return json({ error: 'bad_request' }, 400);
});
