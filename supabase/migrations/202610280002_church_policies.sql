-- Row-level security per church. Access depends on the caller's role in the
-- row's church, never on a global role. profiles.role, user_role and
-- is_admin() are replaced by church_members and profiles.is_platform_admin.

-- Drop every policy that depended on is_admin() ---------------------------------

drop policy profiles_read_own on public.profiles;
drop policy bible_versions_admin on public.bible_versions;
drop policy studies_admin on public.studies;
drop policy sermons_admin on public.sermons;
drop policy devotional_days_admin on public.devotional_days;
drop policy bible_references_admin on public.bible_references;
drop policy transcripts_admin on public.transcripts;
drop policy sermon_analyses_admin on public.sermon_analyses;
drop policy jobs_admin_read on public.jobs;
drop policy jobs_admin_insert on public.jobs;
drop policy study_translations_admin on public.study_translations;
drop policy youtube_channels_admin on public.youtube_channels;

drop function public.is_admin();
alter table public.profiles drop column role;
drop type public.user_role;

-- Helper functions: signed-in callers and the service role only ----------------
-- No policy that applies to anon calls them.

-- The month boundary must not depend on the session time zone.
create or replace function public.sermons_this_month(p_church uuid) returns int
language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.sermons s
  where s.church_id = p_church
    and s.created_at >= date_trunc('month', now(), 'UTC');
$$;

revoke execute on function
  public.is_platform_admin(), public.church_role_of(uuid),
  public.can_edit_church(uuid), public.is_church_owner(uuid),
  public.sermons_this_month(uuid)
  from public, anon;
grant execute on function
  public.is_platform_admin(), public.church_role_of(uuid),
  public.can_edit_church(uuid), public.is_church_owner(uuid),
  public.sermons_this_month(uuid)
  to authenticated, service_role;

drop index public.youtube_channels_recent_idx;
create index youtube_channels_recent_idx
  on public.youtube_channels (church_id, last_used_at desc);

-- Profiles ----------------------------------------------------------------------

create policy profiles_read_own on public.profiles for select to authenticated
  using (id = (select auth.uid()));

-- Bible versions: anyone reads, platform admins write ---------------------------

create policy bible_versions_admin on public.bible_versions for all to authenticated
  using ((select public.is_platform_admin()))
  with check ((select public.is_platform_admin()));

-- Churches and memberships --------------------------------------------------------

revoke all on public.churches, public.church_members from anon, authenticated;
grant select on public.churches to anon, authenticated;
grant select on public.church_members to authenticated;
-- Owners edit only these columns. create_church inserts; the limit is ours.
grant update (name, default_sermon_language, default_output_language,
  default_bible_version_code, default_devotional_days, require_review)
  on public.churches to authenticated;

create policy churches_read on public.churches for select
  to anon, authenticated using (true);
create policy churches_owner_update on public.churches for update to authenticated
  using ((select public.is_church_owner(id)))
  with check ((select public.is_church_owner(id)));

create policy church_members_read on public.church_members for select to authenticated
  using (user_id = (select auth.uid())
         or (select public.church_role_of(church_id)) is not null);

-- Studies and sermons (the published-read policies stay) -----------------------------

create policy studies_edit on public.studies for all to authenticated
  using ((select public.can_edit_church(church_id)))
  with check ((select public.can_edit_church(church_id)));

create policy sermons_edit on public.sermons for all to authenticated
  using ((select public.can_edit_church(church_id)))
  with check ((select public.can_edit_church(church_id)));

-- Monthly limit. A trigger gives the app a readable code instead of an RLS
-- failure. It runs before `on conflict` resolves, so a sermon that already
-- exists in the church passes untouched. Security definer so the existence
-- check and the count see every row of the church.
create function public.enforce_monthly_sermon_limit() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if exists (
    select 1 from public.sermons s
    where s.church_id = new.church_id
      and s.youtube_video_id = new.youtube_video_id
  ) then
    return new;
  end if;
  if public.sermons_this_month(new.church_id) >= (
    select c.monthly_sermon_limit from public.churches c where c.id = new.church_id
  ) then
    raise exception 'monthly_limit_reached';
  end if;
  return new;
end $$;
create trigger sermons_monthly_limit before insert on public.sermons
  for each row execute function public.enforce_monthly_sermon_limit();

-- Children of a sermon or study (the published-read policies stay) -------------------

create policy transcripts_edit on public.transcripts for all to authenticated
  using ((select public.can_edit_church(
    (select s.church_id from public.sermons s where s.id = transcripts.sermon_id))))
  with check ((select public.can_edit_church(
    (select s.church_id from public.sermons s where s.id = transcripts.sermon_id))));

create policy sermon_analyses_edit on public.sermon_analyses for all to authenticated
  using ((select public.can_edit_church(
    (select s.church_id from public.sermons s where s.id = sermon_analyses.sermon_id))))
  with check ((select public.can_edit_church(
    (select s.church_id from public.sermons s where s.id = sermon_analyses.sermon_id))));

create policy bible_references_edit on public.bible_references for all to authenticated
  using ((select public.can_edit_church(
    (select s.church_id from public.sermons s where s.id = bible_references.sermon_id))))
  with check ((select public.can_edit_church(
    (select s.church_id from public.sermons s where s.id = bible_references.sermon_id))));

create policy devotional_days_edit on public.devotional_days for all to authenticated
  using ((select public.can_edit_church(
    (select s.church_id from public.studies s where s.id = devotional_days.study_id))))
  with check ((select public.can_edit_church(
    (select s.church_id from public.studies s where s.id = devotional_days.study_id))));

create policy study_translations_edit on public.study_translations for all to authenticated
  using ((select public.can_edit_church(
    (select s.church_id from public.studies s where s.id = study_translations.study_id))))
  with check ((select public.can_edit_church(
    (select s.church_id from public.studies s where s.id = study_translations.study_id))));

-- Jobs and channels -----------------------------------------------------------------

create policy jobs_read on public.jobs for select to authenticated
  using ((select public.can_edit_church(church_id)));
create policy jobs_insert on public.jobs for insert to authenticated
  with check (
    (select public.can_edit_church(church_id))
    and status = 'queued'
    and created_by = (select auth.uid())
    and (sermon_id is null or exists (
      select 1 from public.sermons s
      where s.id = jobs.sermon_id and s.church_id = jobs.church_id))
  );

create policy youtube_channels_edit on public.youtube_channels for all to authenticated
  using ((select public.can_edit_church(church_id)))
  with check ((select public.can_edit_church(church_id)));
