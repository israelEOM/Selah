-- Many churches. Every church-owned row now carries a church_id, and people
-- belong to churches through church_members. RLS policies and RPCs follow in
-- later migrations; profiles.role, user_role and is_admin() stay until the
-- policies that use them are replaced.

create extension if not exists unaccent with schema extensions;

create type public.church_role as enum ('owner', 'editor', 'member');

-- Churches and memberships ----------------------------------------------------

create table public.churches (
  id uuid primary key default gen_random_uuid(),
  -- Lowercase letters, digits and hyphens, 3 to 40 characters. Never changes.
  slug text not null unique check (slug ~ '^[a-z0-9](?:[a-z0-9-]{1,38})[a-z0-9]$'),
  name text not null check (length(trim(name)) between 2 and 80),
  default_sermon_language text not null default 'es',
  default_output_language text not null default 'es',
  default_bible_version_code text not null default 'RVR1960'
    references public.bible_versions (code) on update cascade,
  default_devotional_days int not null default 5
    check (default_devotional_days in (1, 3, 5, 7)),
  require_review boolean not null default true,
  monthly_sermon_limit int not null default 4 check (monthly_sermon_limit >= 0),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger churches_touch before update on public.churches
  for each row execute function public.touch_updated_at();

create function public.keep_church_slug() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.slug is distinct from old.slug then
    raise exception 'A church slug cannot change' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger churches_keep_slug before update on public.churches
  for each row execute function public.keep_church_slug();

create table public.church_members (
  church_id uuid not null references public.churches (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.church_role not null,
  created_at timestamptz not null default now(),
  primary key (church_id, user_id)
);
create index church_members_user_idx on public.church_members (user_id);

-- No policies yet: the tables are closed to the API until the RLS migration.
alter table public.churches enable row level security;
alter table public.church_members enable row level security;

alter table public.profiles
  add column is_platform_admin boolean not null default false;

-- Role helpers ------------------------------------------------------------------

create function public.is_platform_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select p.is_platform_admin from public.profiles p
    where p.id = (select auth.uid())
  ), false);
$$;

-- The caller's role in a church. A platform admin is an owner everywhere.
create function public.church_role_of(p_church uuid) returns public.church_role
language sql stable security definer set search_path = '' as $$
  select case
    when (select public.is_platform_admin()) then 'owner'::public.church_role
    else (
      select m.role from public.church_members m
      where m.church_id = p_church and m.user_id = (select auth.uid())
    )
  end;
$$;

create function public.can_edit_church(p_church uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select public.church_role_of(p_church)) in ('owner', 'editor'), false);
$$;

create function public.is_church_owner(p_church uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select public.church_role_of(p_church)) = 'owner', false);
$$;

-- church_id on church-owned rows ------------------------------------------------

alter table public.sermons add column church_id uuid references public.churches (id) on delete cascade;
alter table public.studies add column church_id uuid references public.churches (id) on delete cascade;
alter table public.jobs add column church_id uuid references public.churches (id) on delete cascade;
alter table public.youtube_channels add column church_id uuid references public.churches (id) on delete cascade;

create function public.sermons_this_month(p_church uuid) returns int
language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.sermons s
  where s.church_id = p_church
    and s.created_at >= date_trunc('month', now() at time zone 'utc');
$$;

-- Backfill: today's single church comes from church_settings.
insert into public.churches (
  slug, name, default_sermon_language, default_output_language,
  default_bible_version_code, default_devotional_days, require_review)
select
  case
    when s.slug ~ '^[a-z0-9](?:[a-z0-9-]{1,38})[a-z0-9]$' then s.slug
    else 'selah'
  end,
  case when length(trim(cs.church_name)) between 2 and 80
       then trim(cs.church_name) else 'Selah' end,
  cs.default_sermon_language, cs.default_output_language,
  cs.default_bible_version_code, cs.default_devotional_days, cs.require_review
from public.church_settings cs
cross join lateral (
  select trim(both '-' from left(trim(both '-' from regexp_replace(
    lower(extensions.unaccent(cs.church_name)), '[^a-z0-9]+', '-', 'g')), 40)) as slug
) s;

update public.sermons set church_id = (select id from public.churches limit 1);
update public.studies set church_id = (select id from public.churches limit 1);
update public.jobs set church_id = (select id from public.churches limit 1);
update public.youtube_channels set church_id = (select id from public.churches limit 1);

update public.profiles set is_platform_admin = true where role = 'admin';
insert into public.church_members (church_id, user_id, role)
select (select id from public.churches limit 1), p.id, 'owner'
from public.profiles p where p.role = 'admin';

alter table public.sermons alter column church_id set not null;
alter table public.studies alter column church_id set not null;
alter table public.jobs alter column church_id set not null;
alter table public.youtube_channels alter column church_id set not null;

create index sermons_church_idx on public.sermons (church_id);
create index studies_church_idx on public.studies (church_id);
create index jobs_church_idx on public.jobs (church_id);

-- Uniqueness is per church.
alter table public.sermons drop constraint sermons_youtube_video_id_key;
alter table public.sermons add constraint sermons_church_video_key
  unique (church_id, youtube_video_id);

alter table public.studies drop constraint studies_slug_key;
alter table public.studies add constraint studies_church_slug_key
  unique (church_id, slug);

alter table public.youtube_channels drop constraint youtube_channels_pkey;
alter table public.youtube_channels add primary key (church_id, channel_id);

-- Settings now live on the church.
drop table public.church_settings;
