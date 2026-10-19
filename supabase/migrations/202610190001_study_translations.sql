-- English and Brazilian Portuguese translations of published studies.

create table public.study_translations (
  id uuid primary key default gen_random_uuid(),
  study_id uuid not null references public.studies(id) on delete cascade,
  language text not null check (language in ('en', 'pt')),
  title text not null,
  central_message text,
  summary jsonb not null,
  days jsonb not null,
  bible_version_code text not null references public.bible_versions(code),
  hidden boolean not null default true,
  source_updated_at timestamptz not null,
  model text not null,
  prompt_version text not null,
  input_tokens int,
  output_tokens int,
  created_at timestamptz not null default now(),
  unique (study_id, language)
);

alter table public.study_translations enable row level security;

grant select on public.study_translations to anon;
grant select, insert, update, delete on public.study_translations to authenticated;

create policy study_translations_read_published on public.study_translations
  for select to anon, authenticated
  using (
    not hidden
    and exists (
      select 1 from public.studies s
      where s.id = study_translations.study_id and s.status = 'published'
    )
  );
create policy study_translations_admin on public.study_translations
  for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

-- Allow the 'translate' job step.
alter table public.jobs drop constraint jobs_step_check;
alter table public.jobs add constraint jobs_step_check
  check (step in ('probe', 'transcript', 'analysis', 'summary', 'devotional', 'translate'));
