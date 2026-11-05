-- Every three hours, ask sync-church-events to refresh every church's calendar. The project URL and the shared
-- secret live in Vault (see README → Church calendars), so nothing secret is in this file.

create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'sync-church-events',
  '0 */3 * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/sync-church-events',
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-selah-cron', (select decrypted_secret from vault.decrypted_secrets where name = 'sync_church_events_secret')
    ),
    body := '{"all": true}'::jsonb,
    timeout_milliseconds := 300000
  );
  $$
);
