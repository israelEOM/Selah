-- Selah MVP schema.
-- Members read published studies anonymously. Admins manage everything.
-- The worker uses the service role, which bypasses RLS.

create type public.user_role as enum ('admin', 'member');
create type public.study_status as enum ('draft', 'generating', 'review', 'published');
create type public.job_status as enum ('queued', 'running', 'succeeded', 'failed');
create type public.reference_classification as enum ('explicit', 'quoted', 'possible');

create function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- Profiles and roles ---------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text,
  role public.user_role not null default 'member',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, name)
  values (new.id, new.raw_user_meta_data ->> 'name');
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;

-- Settings and Bible versions -------------------------------------------------

create table public.bible_versions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  language text not null,
  provider text not null default 'external_link',
  provider_identifier text,
  copyright_information text,
  active boolean not null default true
);

create table public.church_settings (
  id boolean primary key default true check (id),
  church_name text not null default 'Selah',
  default_sermon_language text not null default 'es',
  default_output_language text not null default 'es',
  default_bible_version_code text not null default 'RVR1960'
    references public.bible_versions (code) on update cascade,
  default_devotional_days int not null default 5
    check (default_devotional_days in (1, 3, 5, 7)),
  require_review boolean not null default true,
  updated_at timestamptz not null default now()
);
create trigger church_settings_touch before update on public.church_settings
  for each row execute function public.touch_updated_at();

-- Sermons and source material -------------------------------------------------

create table public.sermons (
  id uuid primary key default gen_random_uuid(),
  youtube_video_id text not null unique,
  youtube_url text not null,
  title text,
  channel text,
  preacher text,
  thumbnail_url text,
  sermon_date date,
  duration_seconds int,
  original_language text not null default 'es',
  start_seconds int not null default 0 check (start_seconds >= 0),
  end_seconds int check (end_seconds is null or end_seconds > start_seconds),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger sermons_touch before update on public.sermons
  for each row execute function public.touch_updated_at();

create table public.transcripts (
  id uuid primary key default gen_random_uuid(),
  sermon_id uuid not null unique references public.sermons (id) on delete cascade,
  language text not null,
  source text not null check (source in ('youtube', 'manual')),
  is_auto_generated boolean,
  -- Array of {text, start, duration}; start and duration are seconds.
  segments jsonb not null default '[]',
  raw_text text not null default '',
  created_at timestamptz not null default now()
);

create table public.sermon_analyses (
  id uuid primary key default gen_random_uuid(),
  sermon_id uuid not null unique references public.sermons (id) on delete cascade,
  content jsonb not null,
  model text not null,
  prompt_version text not null,
  input_tokens int,
  output_tokens int,
  created_at timestamptz not null default now()
);

create table public.bible_references (
  id uuid primary key default gen_random_uuid(),
  sermon_id uuid not null references public.sermons (id) on delete cascade,
  reference text not null,
  book text,
  chapter int,
  verse_start int,
  verse_end int,
  classification public.reference_classification not null,
  confidence real not null check (confidence between 0 and 1),
  start_seconds real,
  transcript_excerpt text,
  -- Only approved references are visible to members.
  approved boolean not null default false,
  position int not null default 0
);
create index bible_references_sermon_idx on public.bible_references (sermon_id);

-- Studies ---------------------------------------------------------------------

create table public.studies (
  id uuid primary key default gen_random_uuid(),
  sermon_id uuid not null unique references public.sermons (id) on delete cascade,
  title text not null,
  slug text not null unique,
  output_language text not null default 'es',
  bible_version_code text not null default 'RVR1960'
    references public.bible_versions (code) on update cascade,
  number_of_days int not null default 5 check (number_of_days in (1, 3, 5, 7)),
  central_message text,
  summary jsonb,
  status public.study_status not null default 'draft',
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger studies_touch before update on public.studies
  for each row execute function public.touch_updated_at();
create index studies_published_idx on public.studies (published_at desc)
  where status = 'published';

create table public.devotional_days (
  id uuid primary key default gen_random_uuid(),
  study_id uuid not null references public.studies (id) on delete cascade,
  day_number int not null check (day_number between 1 and 7),
  title text not null,
  bible_reading text,
  main_idea text,
  reflection text,
  application text,
  questions jsonb not null default '[]',
  prayer text,
  start_seconds real,
  end_seconds real,
  unique (study_id, day_number)
);

-- Jobs ------------------------------------------------------------------------

create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  sermon_id uuid references public.sermons (id) on delete cascade,
  -- probe | transcript | analysis | summary | devotional
  step text not null check (step in ('probe', 'transcript', 'analysis', 'summary', 'devotional')),
  status public.job_status not null default 'queued',
  payload jsonb not null default '{}',
  result jsonb,
  error text,
  attempts int not null default 0,
  model text,
  prompt_version text,
  input_tokens int,
  output_tokens int,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz
);
create index jobs_queue_idx on public.jobs (created_at) where status = 'queued';
create index jobs_sermon_idx on public.jobs (sermon_id, created_at desc);
-- One active job per sermon and step.
create unique index jobs_one_active_idx on public.jobs (sermon_id, step)
  where status in ('queued', 'running') and sermon_id is not null;

-- The worker claims the oldest queued job. Skip-locked keeps two workers apart.
create function public.claim_job() returns setof public.jobs
language plpgsql security definer set search_path = '' as $$
begin
  return query
  update public.jobs j
  set status = 'running', started_at = now(), attempts = j.attempts + 1
  where j.id = (
    select q.id from public.jobs q
    where q.status = 'queued'
    order by q.created_at
    limit 1
    for update skip locked
  )
  returning j.*;
end $$;
revoke all on function public.claim_job() from public, anon, authenticated;
grant execute on function public.claim_job() to service_role;

-- Row-level security ----------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.bible_versions enable row level security;
alter table public.church_settings enable row level security;
alter table public.sermons enable row level security;
alter table public.transcripts enable row level security;
alter table public.sermon_analyses enable row level security;
alter table public.bible_references enable row level security;
alter table public.studies enable row level security;
alter table public.devotional_days enable row level security;
alter table public.jobs enable row level security;

grant usage on schema public to anon, authenticated;
grant select on public.bible_versions, public.church_settings, public.sermons,
  public.bible_references, public.studies, public.devotional_days to anon;
grant select, insert, update, delete on all tables in schema public to authenticated;

create policy profiles_read_own on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));
create policy profiles_update_own_name on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy bible_versions_read on public.bible_versions for select
  to anon, authenticated using (true);
create policy bible_versions_admin on public.bible_versions for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy church_settings_read on public.church_settings for select
  to anon, authenticated using (true);
create policy church_settings_admin on public.church_settings for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy studies_read_published on public.studies for select
  to anon, authenticated using (status = 'published');
create policy studies_admin on public.studies for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy sermons_read_published on public.sermons for select
  to anon, authenticated using (exists (
    select 1 from public.studies s
    where s.sermon_id = sermons.id and s.status = 'published'));
create policy sermons_admin on public.sermons for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy devotional_days_read_published on public.devotional_days for select
  to anon, authenticated using (exists (
    select 1 from public.studies s
    where s.id = devotional_days.study_id and s.status = 'published'));
create policy devotional_days_admin on public.devotional_days for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy bible_references_read_published on public.bible_references for select
  to anon, authenticated using (approved and exists (
    select 1 from public.studies s
    where s.sermon_id = bible_references.sermon_id and s.status = 'published'));
create policy bible_references_admin on public.bible_references for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy transcripts_admin on public.transcripts for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy sermon_analyses_admin on public.sermon_analyses for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy jobs_admin_read on public.jobs for select to authenticated
  using ((select public.is_admin()));
create policy jobs_admin_insert on public.jobs for insert to authenticated
  with check ((select public.is_admin()) and status = 'queued'
    and created_by = (select auth.uid()));

-- Admins watch job progress live.
alter publication supabase_realtime add table public.jobs;

-- Seed ------------------------------------------------------------------------

insert into public.bible_versions (code, name, language, provider, provider_identifier, copyright_information) values
  ('RVR1960', 'Reina-Valera 1960', 'es', 'external_link', 'RVR1960',
   'Reina-Valera 1960 ® © Sociedades Bíblicas en América Latina, 1960. Renovado © Sociedades Bíblicas Unidas, 1988. Selah no almacena ni reproduce el texto; enlaza a un lector externo.'),
  ('NVI', 'Nueva Versión Internacional', 'es', 'external_link', 'NVI', '© Biblica, Inc.'),
  ('ARA', 'Almeida Revista e Atualizada', 'pt', 'external_link', 'ARA', '© Sociedade Bíblica do Brasil'),
  ('NVI-PT', 'Nova Versão Internacional', 'pt', 'external_link', 'NVI-PT', '© Biblica, Inc.'),
  ('KJV', 'King James Version', 'en', 'external_link', 'KJV', 'Public domain'),
  ('NIV', 'New International Version', 'en', 'external_link', 'NIV', '© Biblica, Inc.'),
  ('ESV', 'English Standard Version', 'en', 'external_link', 'ESV', '© Crossway');

insert into public.church_settings default values;
