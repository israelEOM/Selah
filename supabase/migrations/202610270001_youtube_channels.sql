-- Channels the admin has imported from, so the import page can offer them
-- again without a YouTube search. Shared by every admin until churches get
-- their own data.

create table public.youtube_channels (
  channel_id text primary key,
  title text not null,
  handle text,
  thumbnail_url text,
  last_used_at timestamptz not null default now()
);
create index youtube_channels_recent_idx on public.youtube_channels (last_used_at desc);

alter table public.youtube_channels enable row level security;

grant select, insert, update, delete on public.youtube_channels to authenticated;

create policy youtube_channels_admin on public.youtube_channels
  for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

-- Allow the import picker's job steps.
alter table public.jobs drop constraint jobs_step_check;
alter table public.jobs add constraint jobs_step_check
  check (step in ('probe', 'channel_search', 'channel_lives', 'transcript', 'analysis', 'summary', 'devotional',
                  'translate'));
