-- A regenerated study no longer matches its approved translations. When a study
-- leaves 'published', hide them all so the admin must approve the new ones.

create function public.hide_translations_on_unpublish() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.study_translations set hidden = true where study_id = new.id;
  return new;
end $$;

create trigger studies_hide_translations_on_unpublish
  after update of status on public.studies
  for each row
  when (old.status = 'published' and new.status is distinct from 'published')
  execute function public.hide_translations_on_unpublish();
