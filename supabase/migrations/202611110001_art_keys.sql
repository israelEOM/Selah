-- A study and each of its days can name an illustration from the app's art manifest (app/assets/art/manifest.json).
-- Null, or a key the app does not know, falls back to a deterministic pick. Existing RLS already covers the columns.
alter table public.studies add column art_key text;
alter table public.devotional_days add column art_key text;
