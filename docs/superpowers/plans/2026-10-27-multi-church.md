# Many Churches, Roles and Open Sign-in Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Selah hosts many churches. Anyone can sign in with Google (or email) and create a church. Each church has its own address, its own studies and its own people with the roles Owner, Editor and Member.

**Architecture:** A `churches` table replaces the single `church_settings` row, and a `church_members` table holds each person's role per church. Every church-owned row (`sermons`, `studies`, `jobs`, `youtube_channels`) carries `church_id`, and row-level security checks the caller's role in that church through helper functions. Actions that cross the RLS boundary (create a church, accept an invite, list a church's people with emails, change roles) are `security definer` RPCs with their own checks. The app moves every page under `/c/<church-slug>/…`. The worker still serves every church from the admin's Mac with the service role, and a per-church monthly limit protects its keys.

**Tech Stack:** Supabase Postgres (migrations, RLS, pgTAP tests through the local Supabase stack), Python worker (pytest), Flutter (go_router, Riverpod 3, gen-l10n).

**Spec:** the request of 2026-10-27, "the space for several churches… any user able to login with Google… different roles for users", and the answers given that day, recorded under Decisions. Product context is in [docs/MVP_PLAN.md](../../MVP_PLAN.md).

## Decisions

**Confirmed 2026-10-27:**
- **New churches are self-serve.** Any signed-in user can create a church and becomes its Owner.
- **Roles per church: Owner, Editor, Member.** Owner: settings, people and invites, everything an Editor does. Editor: imports, edits, regenerates, publishes and approves translations. Member: follows the church; reading needs no role. Above every church is the **platform admin** (you), who can do everything in every church.
- **Reading stays public.** Published studies need no sign-in. Signing in is for creating or joining churches and working in them.
- **One person can belong to several churches,** with a different role in each and a church switcher in the app.
- **Joining is by invite link per role.** An Owner creates a link, "join as Editor" or "join as Member". Whoever opens it and signs in gets that role. Anyone can also follow a church as Member from its page.
- **The worker is shared, with a monthly limit per church.** Your worker and your Gemini and YouTube keys serve every church.
- **Addresses look like `/c/<slug>`** on the current site, for example `selah-226.pages.dev/c/vida-nueva`.
- **Sign-in is Google plus email and password.** Both already work on the web. Neither changes beyond routing people to the right place afterwards.

**Calls this plan makes (check them while reviewing):**
- **The monthly limit counts new sermons imported per calendar month (UTC),** with a default of **4** per church. Re-generating or re-importing an existing sermon doesn't count. Only the platform admin changes the limit, with the worker command `set-limit <slug> <n>`.
- **A church's slug is chosen at creation and never changes,** so shared links keep working. Rules: 3–40 characters, lowercase `a–z`, `0–9` and `-`, globally unique.
- **Invite links are multi-use, never expire, and can be revoked by an Owner.** Links exist for `editor` and `member` only. To make someone an Owner, an Owner promotes an existing member.
- **Accepting an invite never lowers a role.** An Owner who opens a Member link stays Owner.
- **A church always keeps at least one Owner.** The last Owner can't leave, be removed or be demoted.
- **Existing data becomes the first church.** Its name comes from `church_settings.church_name`, and its slug from that name in slug form, falling back to `selah`. Every current `admin` becomes its Owner **and** a platform admin.
- **Old links keep working.** `/studies/<slug>` and `/studies/<slug>/day/<n>` redirect to the same study under its church, and `/admin` goes to the first church where you are an Editor or Owner.
- **The home page `/` lists churches.** Signed in, it shows "Your churches" first. The public list only shows churches with at least one published study.
- **Reading progress stays on the device,** as today. Members get no synced progress in this plan.
- **Admin screens stay Spanish-only,** as today. Member-facing new pages are in `es`, `en` and `pt`: home, church page, create church, join.

**Out of scope:** native Google sign-in in the iOS and Android apps (Phase 5 in MVP_PLAN). When the iOS app ships with Google sign-in, App Store rules also require Sign in with Apple. Also out: billing, custom domains per church, and moving the worker off the Mac.

## Global Constraints

- Roles are the Postgres enum `public.church_role` with values exactly `'owner'`, `'editor'`, `'member'`. Ordering for comparisons is owner > editor > member.
- Slug regex: `^[a-z0-9](?:[a-z0-9-]{1,38})[a-z0-9]$`. It is unique across all churches and immutable.
- Default `monthly_sermon_limit` is `4`.
- Error messages raised by SQL use stable codes in the message so the app can translate them. They are `church_slug_taken`, `church_slug_invalid`, `invite_invalid`, `last_owner`, `monthly_limit_reached` and `not_allowed`, and the app matches on these strings.
- Every church-owned table filters by `church_id`. No policy may grant access by role alone without a church.
- The worker uses the service role. Every row it inserts carries the `church_id` of the sermon it works on.
- Routes: `/`, `/login?next=<path>`, `/churches/new`, `/join/<token>`, `/c/:church`, `/c/:church/studies/:slug`, `/c/:church/studies/:slug/day/:number`, `/c/:church/admin`, `/c/:church/admin/sermons/new`, `/c/:church/admin/sermons/:id`, `/c/:church/admin/people`, `/c/:church/admin/settings`. Legacy redirects are `/studies/…` and `/admin`.
- ARB files `app_es.arb`, `app_en.arb`, `app_pt.arb`: every key exists in all three. Admin keys hold the same Spanish text in all three.
- Supabase CLI and Wrangler need Node 20+: `PATH=/usr/local/n/versions/node/22.21.0/bin:$PATH`.
- Phase A (Tasks 1–7) changes the schema and the app together. Push the migrations only in Task 12, right before deploying the matching app and restarting the worker, because the old app can't read the new schema.

## Review Focus

1. **An Editor of church A goes after church B's data,** by reading B's draft studies, queuing a job on B's sermon, or importing into B by passing B's `church_id`. Expected: every attempt returns nothing or is refused. Pinned in Task 2 (`cross_church_isolation` tests).
2. **The last Owner tries to leave, demote themself or be removed.** Expected: refused with `last_owner`, and the church keeps its Owner. Pinned in Task 3.
3. **Two churches import the same YouTube video.** Expected: both work independently, each with its own sermon, study and slug. Pinned in Task 1 (unique per church) and Task 4 (slug per church).
4. **An invite link is opened while signed out.** Expected: after Google sign-in, the person lands back on the join page and gets the role. A revoked or unknown token shows a clear message. Pinned in Task 7 (login `next`) and Task 9 (join page).
5. **Old shared links `/studies/<slug>`.** Expected: they open the same study under `/c/<church>/…`. Pinned in Task 6.

---

## Phase A: churches in the data and the app

### Task 1: Churches, memberships and church-owned rows

**Files:**
- Create: `supabase/migrations/202610280001_churches.sql`
- Create: `supabase/tests/database/00_helpers.sql`, `supabase/tests/database/churches_test.sql`

**Interfaces:**
- Produces enum `public.church_role ('owner','editor','member')`.
- Produces table `public.churches`: `id uuid pk default gen_random_uuid()`, `slug text not null unique check (slug ~ '<slug regex>')`, `name text not null check (length(trim(name)) between 2 and 80)`, `default_sermon_language`, `default_output_language`, `default_bible_version_code`, `default_devotional_days`, `require_review` (same types, defaults and checks as `church_settings`), `monthly_sermon_limit int not null default 4 check (monthly_sermon_limit >= 0)`, `created_by uuid references auth.users on delete set null`, `created_at`, `updated_at` (with the `touch_updated_at` trigger).
- Produces table `public.church_members`: `church_id uuid references churches on delete cascade`, `user_id uuid references auth.users on delete cascade`, `role church_role not null`, `created_at timestamptz default now()`, `primary key (church_id, user_id)`, index on `user_id`.
- Produces `profiles.is_platform_admin boolean not null default false`.
- Adds `church_id uuid not null references churches on delete cascade` to `sermons`, `studies`, `jobs`, `youtube_channels`.
- Replaces `sermons.youtube_video_id` unique with `unique (church_id, youtube_video_id)`, and `studies.slug` unique with `unique (church_id, slug)`. `youtube_channels` primary key becomes `(church_id, channel_id)`.
- Produces `security definer stable` SQL functions, each with `set search_path = ''`:
  - `public.is_platform_admin() returns boolean`
  - `public.church_role_of(p_church uuid) returns public.church_role`: the caller's role, `'owner'` for a platform admin, `null` for none.
  - `public.can_edit_church(p_church uuid) returns boolean`: role is owner or editor.
  - `public.is_church_owner(p_church uuid) returns boolean`
  - `public.sermons_this_month(p_church uuid) returns int`: sermons with `created_at >= date_trunc('month', now() at time zone 'utc')`.
- Backfill, in order, inside the migration:
  1. Insert one church from `church_settings`. The slug is `church_name` lowercased, accents removed with `extensions.unaccent` (or `translate` for the Spanish and Portuguese accented letters if the extension is missing), non-alphanumerics replaced by `-` and trimmed. Use `selah` if the result fails the regex.
  2. Set `church_id` on every existing `sermons`, `studies`, `jobs` and `youtube_channels` row.
  3. Every profile with `role = 'admin'` gets `is_platform_admin = true` and an `owner` row in `church_members`.
- Then drop `church_settings`. Leave `profiles.role`, `user_role` and `is_admin()` for Task 2 to drop after the policies that use them are replaced.

- [ ] **Step 1: Write the test helpers.** `00_helpers.sql` defines `tests.create_user(email text) returns uuid` (inserts into `auth.users`) and `tests.act_as(uid uuid)` (`set local role authenticated` plus `set local request.jwt.claims` to `{"sub": uid}`), plus `tests.act_as_anon()`. Wrap it in `begin; … rollback;`-friendly SQL with no `plan()`, so other test files can use it.

- [ ] **Step 2: Write the failing tests** in `churches_test.sql`:
  - `has_table('public','churches')` and `has_table('public','church_members')`.
  - Inserting a church with slug `'Vida Nueva'` throws `23514` (check violation). `'vida-nueva'` succeeds.
  - Two sermons with the same `youtube_video_id` in two different churches both insert, and a second one in the same church throws `23505`.
  - With a user who is `editor` of church A: `church_role_of(A) = 'editor'`, `church_role_of(B) is null`, `can_edit_church(A)`, `not is_church_owner(A)`.
  - A platform admin gets `church_role_of(B) = 'owner'`.
  - `sermons_this_month(A)` counts a sermon created now and ignores one with `created_at` set to the previous month.

- [ ] **Step 3: Start the local stack and confirm the tests fail**

  Run: `PATH=/usr/local/n/versions/node/22.21.0/bin:$PATH npx supabase start && npx supabase test db`
  Expected: FAIL. `churches` does not exist.

- [ ] **Step 4: Write the migration** with the definitions above.

- [ ] **Step 5: Reset the local database and run the tests**

  Run: `PATH=/usr/local/n/versions/node/22.21.0/bin:$PATH npx supabase db reset && npx supabase test db`
  Expected: PASS. The reset applies every migration, including the backfill on the empty seed with one church named `Selah` and slug `selah`.

- [ ] **Step 6: Commit**
  ```bash
  git add supabase/migrations/202610280001_churches.sql supabase/tests
  git commit -m "Add churches, memberships and church_id on church-owned rows"
  ```

### Task 2: Row-level security per church

**Files:**
- Create: `supabase/migrations/202610280002_church_policies.sql`
- Create: `supabase/tests/database/policies_test.sql`

**Interfaces:**
- Consumes the Task 1 helpers.
- Drops every policy that calls `is_admin()`, then `is_admin()`, `profiles.role` and the `user_role` type. Also drops `profiles_read_own`'s admin branch.
- Policies to create, all `to authenticated` unless noted:
  - `churches`: select for `anon, authenticated` (true). Update when `is_church_owner(id)`, with columns limited by grant to `name`, the `default_*` columns and `require_review` (`revoke update` plus a column `grant update (...)`, as `202610120002` does for profiles). No direct insert or delete; `create_church` (Task 3) inserts.
  - `church_members`: select when `user_id = auth.uid()` or `church_role_of(church_id) is not null`. No direct writes; Task 3's RPCs write.
  - `sermons`, `studies`: keep today's published-read policies for `anon, authenticated`. All rights when `can_edit_church(church_id)`.
  - Monthly limit: a `before insert` trigger on `sermons` raises `monthly_limit_reached` when `sermons_this_month(new.church_id) >= monthly_sermon_limit`. It must first return `new` untouched when a sermon with the same `(church_id, youtube_video_id)` already exists, because the trigger fires before `on conflict` resolves an upsert. Use a trigger rather than a policy, so the app gets a readable code instead of an RLS failure.
  - `transcripts`, `sermon_analyses`, `bible_references`, `devotional_days`, `study_translations`: the published-read policies stay. The admin policy becomes `can_edit_church((select church_id from public.sermons/studies where id = <parent>))`.
  - `jobs`: select when `can_edit_church(church_id)`. Insert when `can_edit_church(church_id) and status = 'queued' and created_by = auth.uid()`, and when `sermon_id` is set, the sermon's `church_id = church_id`.
  - `youtube_channels`: all rights when `can_edit_church(church_id)`.
  - `bible_versions`: write when `is_platform_admin()`.

- [ ] **Step 1: Write the failing tests** in `policies_test.sql`, grouped under the comment `-- cross_church_isolation`. Set up churches A and B, an editor of A, a member of A, a stranger, a draft study and a published study in each church:
  - Anon sees B's published study and not B's draft.
  - The editor of A sees A's draft and not B's draft (`results_eq` on count = 0).
  - The editor of A inserting a job with `church_id = B` throws `42501`. Inserting a job with `church_id = A` and `sermon_id` = B's sermon throws `42501`.
  - The editor of A inserting a sermon with `church_id = B` throws `42501`.
  - The member of A cannot update A's study (0 rows affected) or insert a job (`42501`).
  - The member of A cannot update `churches.name` for A. The owner of A can. The owner of A updating `monthly_sermon_limit` throws `42501`.
  - With `monthly_sermon_limit = 1` and one sermon this month, a second sermon insert throws with message `monthly_limit_reached`. `insert … on conflict (church_id, youtube_video_id) do update` of the existing sermon still succeeds.
  - `select is_admin()` throws `42883`, because the function is gone.

- [ ] **Step 2: Run them and confirm they fail.** Run `npx supabase test db`. Expected: FAIL, because the old policies still let any `admin` through and no church checks exist.

- [ ] **Step 3: Write the migration** with the policies above.

- [ ] **Step 4: Reset and run the tests.** Run `npx supabase db reset && npx supabase test db`. Expected: PASS.

- [ ] **Step 5: Commit** (`Scope every policy to the caller's role in the church`).

### Task 3: Church RPCs: create, invite, join, people, roles

**Files:**
- Create: `supabase/migrations/202610280003_church_functions.sql`
- Create: `supabase/tests/database/functions_test.sql`

**Interfaces:**
- Produces table `public.church_invites`: `token uuid pk default gen_random_uuid()`, `church_id uuid references churches on delete cascade`, `role church_role not null check (role in ('editor','member'))`, `created_by uuid references auth.users on delete set null`, `created_at timestamptz default now()`, `revoked_at timestamptz`. RLS: select when `is_church_owner(church_id)`. No direct writes.
- Produces `security definer` functions with `set search_path = ''`, granted to `authenticated` only:
  - `create_church(p_name text, p_slug text) returns public.churches`: inserts the church with `created_by = auth.uid()` and an `owner` membership. Raises `church_slug_invalid` when the regex fails and `church_slug_taken` on conflict.
  - `create_invite(p_church uuid, p_role public.church_role) returns uuid`: owner only, otherwise `not_allowed`.
  - `revoke_invite(p_token uuid) returns void`: owner of that church only.
  - `invite_info(p_token uuid) returns table(church_name text, church_slug text, role public.church_role)`: granted to `anon` too, so the join page can say what you're joining before sign-in. Returns no row for unknown or revoked tokens.
  - `accept_invite(p_token uuid) returns text`: returns the church slug. Inserts the membership, or raises the role when the invite's role is higher than the current one, and never lowers it. Raises `invite_invalid` for unknown or revoked tokens.
  - `join_church(p_church uuid) returns void`: adds a `member` row, and does nothing if the caller already has any role.
  - `church_people(p_church uuid) returns table(user_id uuid, name text, email text, role public.church_role, joined_at timestamptz)`: owner only. The email comes from `auth.users`. Ordered owners, then editors, then members, each by name.
  - `set_member_role(p_church uuid, p_user uuid, p_role public.church_role) returns void`: owner only. Raises `last_owner` when it would leave no owner.
  - `remove_member(p_church uuid, p_user uuid) returns void`: owner, or the user themself (leaving). Same `last_owner` guard.

- [ ] **Step 1: Write the failing tests** in `functions_test.sql`:
  - `create_church('Vida Nueva', 'vida-nueva')` returns a church, and the caller's `church_role_of` is `'owner'`. Calling it again with the same slug throws `church_slug_taken`. A slug of `'VN'` throws `church_slug_invalid`.
  - Anon calling `create_church` throws `42501`.
  - An owner gets a token from `create_invite(A,'editor')`. Another user's `accept_invite(token)` returns `'vida-nueva'` and gives them `editor`. The owner's own `accept_invite` of a `member` token leaves them `owner`.
  - After `revoke_invite`, `accept_invite` throws `invite_invalid` and `invite_info` returns 0 rows.
  - `create_invite(A,'owner')` throws (check violation). A non-owner calling `create_invite` throws `not_allowed`.
  - The only owner calling `set_member_role(A, self, 'editor')` throws `last_owner`, and so does `remove_member(A, self)`. After promoting a second owner, both succeed.
  - `church_people(A)` called by an editor throws `not_allowed`. Called by the owner, it lists emails.
  - `join_church(A)` by a stranger gives `member`. By an editor it leaves `editor`.

- [ ] **Step 2: Run and confirm failure,** then **Step 3: write the migration,** then **Step 4: reset and run until PASS.**

- [ ] **Step 5: Commit** (`Add church creation, invites, people and role changes`).

### Task 4: Worker works per church

**Files:**
- Modify: `worker/selah_worker/pipeline.py` (`_unique_slug`, `summary` study insert)
- Modify: `worker/selah_worker/__main__.py` (`next_job`, `check`, `make_admin` → `make_platform_admin`, new `set_limit`)
- Test: `worker/tests/test_chain.py`, `worker/tests/test_church_scope.py`

**Interfaces:**
- `_unique_slug(church_id: str, title: str) -> str`: uniqueness is checked with `.eq("church_id", church_id)`.
- The study insert in `summary` adds `"church_id": sermon["church_id"]`.
- `next_job(job)` copies `church_id` from the finished job onto the follow-up.
- CLI: `make-admin <email>` sets `profiles.is_platform_admin = true`. The command keeps its name, and the README is updated. New command `set-limit <church-slug> <n>` updates `churches.monthly_sermon_limit` and prints `"<name>: <n> sermons a month"`. `check` prints `"Connected to Supabase. Churches: <count>"`.

- [ ] **Step 1: Write the failing tests:**
  - In `test_chain.py`, extend the existing chain test to give the job `"church_id": "c1"` and assert `follow_up["church_id"] == "c1"`.
  - In `test_church_scope.py`, `test_slug_is_unique_per_church`: monkeypatch `pipeline.client` with a fake whose `studies` table holds `{"church_id": "c2", "slug": "fe-que-obra"}`, and assert `_unique_slug("c1", "Fe que obra") == "fe-que-obra"`. With the row in `c1`, assert the result is `"fe-que-obra-2"`. The fake records the `.eq` calls, and the test asserts that `("church_id", "c1")` was among them.

- [ ] **Step 2: Run** `cd worker && .venv/bin/python -m pytest -q`. Expected: the new assertions FAIL.

- [ ] **Step 3: Implement** the interfaces above.

- [ ] **Step 4: Run the tests again.** Expected: PASS.

- [ ] **Step 5: Commit** (`Keep slugs and follow-up jobs inside their church`).

### Task 5: App data layer for churches and roles

This task only **adds**: new models, new repository methods and new providers. The existing methods whose signatures change, and the removals, happen in Task 6 together with the pages that call them, so every commit builds.

**Files:**
- Modify: `app/lib/src/core/models.dart` (add `Church`, `ChurchRole`, `Membership`, `Person`)
- Modify: `app/lib/src/data/repository.dart`, `app/lib/src/data/providers.dart`
- Test: `app/test/church_models_test.dart`

**Interfaces:**
- `enum ChurchRole { owner, editor, member }` with `bool get canEdit` (owner or editor) and `static ChurchRole? parse(String?)`.
- `class Church { id, slug, name, defaultSermonLanguage, defaultOutputLanguage, defaultBibleVersionCode, defaultDevotionalDays, monthlySermonLimit; factory Church.fromJson }`
- `class Membership { Church church; ChurchRole role; }` and `class Person { userId, name, email, role, joinedAt }`.
- Repository. Methods marked *(Task 6)* change or replace an existing one, and Task 6 makes that change:
  - `Future<Church?> churchBySlug(String slug)`
  - `Future<List<Membership>> myChurches()`: from `church_members` joined with `churches`, for the current user.
  - `Future<List<Church>> publicChurches()`: churches that have a published study, by name.
  - `Future<ChurchRole?> roleIn(String churchId)`: `rpc('church_role_of')`.
  - `Future<int> sermonsThisMonth(String churchId)`
  - *(Task 6)* `publishedStudies(String churchId)`, `sermons(String churchId)` and `recentChannels(String churchId)` gain the filter.
  - *(Task 6)* `studyBySlug(String churchId, String slug)`
  - *(Task 6)* `createJob(String step, Map<String, dynamic> payload, {required String churchId, String? sermonId})`
  - *(Task 6)* `saveSermon(String churchId, Map<String, dynamic> fields)` upserts with `onConflict: 'church_id,youtube_video_id'`.
  - *(Task 6)* `rememberChannel(String churchId, Map<String, dynamic> channel)`
  - `Future<Church> createChurch(String name, String slug)`, `Future<String> createInvite(String churchId, ChurchRole role)`, `Future<void> revokeInvite(String token)`, `Future<List<Map<String, dynamic>>> invites(String churchId)`, `Future<({String churchName, String churchSlug, ChurchRole role})?> inviteInfo(String token)`, `Future<String> acceptInvite(String token)`, `Future<void> joinChurch(String churchId)`, `Future<List<Person>> people(String churchId)`, `Future<void> setMemberRole(String churchId, String userId, ChurchRole role)`, `Future<void> removeMember(String churchId, String userId)`, `Future<void> updateChurch(String churchId, Map<String, dynamic> fields)`.
  - *(Task 6)* `Future<bool> isPlatformAdmin(String userId)` replaces `isAdmin`, and `churchSettings()` is removed.
- Providers. Task 6 removes `churchSettingsProvider` and `isAdminProvider`:
  - `churchProvider = FutureProvider.family<Church?, String>` (by slug)
  - `myChurchesProvider = FutureProvider<List<Membership>>` (watches `userIdProvider`)
  - `churchRoleProvider = FutureProvider.family<ChurchRole?, String>` (by church id, watches `userIdProvider`)
  - `publicChurchesProvider`
  - *(Task 6)* `publishedStudiesProvider`, `sermonsProvider` and `recentChannelsProvider` become families by church id.
- `SelahError.fromException(Object e) -> String?` in `models.dart`: returns one of the Global Constraints codes found in a `PostgrestException.message`, or null.

- [ ] **Step 1: Write the failing tests** in `church_models_test.dart`:
  - `Church.fromJson` reads the columns above.
  - `ChurchRole.parse('editor')!.canEdit` is true. `ChurchRole.parse('member')!.canEdit` is false. `ChurchRole.parse('x')` is null.
  - `SelahError.fromException(PostgrestException(message: 'monthly_limit_reached'))` is `'monthly_limit_reached'`. An unrelated message gives null.

- [ ] **Step 2: Run** `cd app && flutter test test/church_models_test.dart`. Expected: FAIL, because `Church` isn't defined.

- [ ] **Step 3: Implement** the models, the new repository methods and the new providers (everything not marked *(Task 6)*).

- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: no issues, all pass. Pages are unchanged until Task 6.

- [ ] **Step 5: Commit** (`Model churches and roles in the app data layer`).

### Task 6: Church-scoped routes, admin gate by role, legacy redirects

**Files:**
- Modify: `app/lib/src/app/app.dart` (router)
- Create: `app/lib/src/features/church/church_scope.dart`
- Modify: `app/lib/src/features/admin/admin_gate.dart`, `admin_home_page.dart`, `sermon_page.dart`, `import_page.dart`, `app/lib/src/features/study/study_page.dart`, `reader_page.dart`
- Modify: `app/lib/src/data/repository.dart`, `app/lib/src/data/providers.dart` (the *(Task 6)* items from Task 5)
- Test: `app/test/church_routes_test.dart`, `app/test/admin_gate_test.dart`, `app/test/import_picker_test.dart`, and the other fakes in `app/test/*`

**Interfaces:**
- `ChurchScope({required String slug, required Widget Function(Church church) builder})`: loads `churchProvider(slug)`, shows the loading state, and shows `l.churchNotFound` for null.
- `AdminPage` gains `required Church church` and `ChurchRole minRole = ChurchRole.editor`. It shows the content when `churchRoleProvider(church.id)` meets `minRole` (owner > editor > member). Otherwise it shows today's "admin only" message with the text `l.churchAdminOnly`. Back links and paths use `/c/${church.slug}/…`.
- `StudyPage({required Church church, required String slug})` and `ReaderPage({required Church church, required String slug, required int dayNumber})` build their paths from `church.slug`.
- Router: the routes in Global Constraints. The `/c/:church/...` builders wrap the page in `ChurchScope`, and the admin ones in `inSpanish`. Legacy redirects:
  - `/studies/:slug` and `/studies/:slug/day/:n` render `LegacyStudyRedirect`, which calls `repo.legacyStudyChurch(slug) -> Future<String?>` (the church slug of the oldest study with that slug) and then `context.go('/c/<church>/studies/<slug>[/day/<n>]')`. If it finds nothing, it goes to `/`.
  - `/admin` goes to the first church in `myChurchesProvider` whose role `canEdit`, or to `/` when there is none.
- Add `Future<String?> legacyStudyChurch(String slug)` to the repository, and make every change marked *(Task 6)* in Task 5. Update every test fake that implements `SelahRepository` to the new signatures.
- `ImportPage({required Church church})` uses the church for its defaults (in place of `churchSettingsProvider`) and passes `church.id` to `createJob`, `saveSermon`, `recentChannels` and `rememberChannel`. After saving, it goes to `/c/${church.slug}/admin/sermons/$sermonId`. When saving fails with `monthly_limit_reached`, it shows `l.monthlyLimitReached(church.monthlySermonLimit)`. That key (admin, Spanish, with an int placeholder `limit`) is added here.

- [ ] **Step 1: Write the failing tests:**
  - `church_routes_test.dart`: with a fake repo where `legacyStudyChurch('fe')` returns `'vida-nueva'`, pumping the router at `/studies/fe/day/2` ends on `/c/vida-nueva/studies/fe/day/2`. Unknown slug `/c/nope` shows `churchNotFound`.
  - `admin_gate_test.dart`: an `AdminPage` for church A shows its child for role `editor`, and shows `churchAdminOnly` for `member` and for `null`. With `minRole: owner`, it shows the message to an editor.
  - `import_picker_test.dart` (update): the fake records `createJob` with `churchId: 'A'`. A `saveSermon` that throws `PostgrestException(message: 'monthly_limit_reached')` shows the `monthlyLimitReached` text.

- [ ] **Step 2: Run** `flutter test test/church_routes_test.dart test/admin_gate_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement.** Add the keys `churchNotFound` and `churchAdminOnly` to all three ARB files, and run `flutter gen-l10n`.

- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: PASS.

- [ ] **Step 5: Commit** (`Move every page under its church and gate admin screens by role`).

### Task 7: Home lists churches, church page lists studies, login returns to `next`

**Files:**
- Modify: `app/lib/src/features/home/home_page.dart` (becomes the church list)
- Create: `app/lib/src/features/church/church_page.dart` (today's studies list, for one church)
- Modify: `app/lib/src/features/auth/login_page.dart`, `app/lib/src/core/auth_redirect.dart`
- Test: `app/test/home_page_test.dart` (rewrite), `app/test/church_page_test.dart`, `app/test/auth_redirect_test.dart`, `app/test/login_page_test.dart`

**Interfaces:**
- `oauthReturnUrl(Uri base, {String? next}) -> String`: returns `'${base.origin}/login'`, plus `?next=<encoded>` when `next` is a safe path. `safeNext(String? next) -> String?` keeps only values that start with `/` and not `//`.
- `LoginPage({Uri? landing, String? userAgent})` reads `next` from `landing.queryParameters`. After sign-in it goes to `safeNext(next)`, or else to `/c/<slug>/admin` if the person can edit exactly one church, or else to `/`.
- `HomePage`: when signed in and `myChurchesProvider` is not empty, a "Your churches" section (`l.yourChurches`) with each church's name and role label. Then "Churches on Selah" (`l.allChurches`) from `publicChurchesProvider`, a "Create a church" button (`l.createChurch`) going to `/churches/new` (or to `/login?next=/churches/new` when signed out), and the sign-in/out actions as today.
- `ChurchPage({required Church church})`: the hero and study list that `HomePage` shows today, using `publishedStudiesProvider(church.id)` and the church's name as the title. App-bar action: `l.manage` going to `/c/<slug>/admin` when `churchRoleProvider` can edit. When the person is signed in without a role, the action is `l.followChurch`, which calls `joinChurch` and refreshes `myChurchesProvider`.

- [ ] **Step 1: Write the failing tests:**
  - `auth_redirect_test.dart`: `oauthReturnUrl(Uri.parse('https://x.dev/join/t'), next: '/join/t') == 'https://x.dev/login?next=%2Fjoin%2Ft'`. `safeNext('//evil.com')` is null, and `safeNext('https://evil.com')` is null.
  - `login_page_test.dart`: signed in with `landing` `/login?next=/join/abc`, it goes to `/join/abc`. Signed in as editor of exactly one church `vida-nueva` with no `next`, it goes to `/c/vida-nueva/admin`.
  - `home_page_test.dart`: signed out, it lists the public churches and tapping one goes to `/c/<slug>`. Signed in with one membership, "Your churches" shows it.
  - `church_page_test.dart`: lists that church's studies, and tapping one goes to `/c/vida-nueva/studies/<slug>`. A signed-in person with no role in the church sees "Follow" (`l.followChurch`), and tapping it calls `joinChurch('A')`.

- [ ] **Step 2: Run** the four test files. Expected: FAIL.

- [ ] **Step 3: Implement.** New keys go in all three ARB files, translated into `es`, `en` and `pt`: `yourChurches`, `allChurches`, `createChurch`, `manage`, `followChurch`, `roleOwner`, `roleEditor`, `roleMember`.

- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: PASS.

- [ ] **Step 5: Commit** (`List churches on home and send people back where they came from after sign-in`).

## Phase B: creating churches and managing people

### Task 8: Create a church

**Files:**
- Create: `app/lib/src/features/church/create_church_page.dart`
- Modify: `app/lib/src/app/app.dart` (route `/churches/new`)
- Test: `app/test/create_church_page_test.dart`

**Interfaces:**
- `slugFromName(String name) -> String` in `create_church_page.dart`: lowercases, removes accents (á→a, ñ→n, ç→c, ã→a, õ→o and so on), turns runs of non-alphanumerics into `-`, trims `-`, and caps the length at 40.
- `CreateChurchPage`: signed out, it redirects to `/login?next=/churches/new`. It has a name field and a slug field that is pre-filled from the name until the person edits it. The address preview reads `selah-226.pages.dev/c/<slug>`, built from `Uri.base.host`. Submitting calls `createChurch`, invalidates `myChurchesProvider` and goes to `/c/<slug>/admin/settings`. The error codes `church_slug_taken` and `church_slug_invalid` show `l.slugTaken` and `l.slugInvalid`.

- [ ] **Step 1: Write the failing tests:** `slugFromName('Iglesia Vida Nueva — São Paulo') == 'iglesia-vida-nueva-sao-paulo'`. Typing a name fills the slug. Submitting calls `createChurch('Iglesia X', 'iglesia-x')` and navigates to `/c/iglesia-x/admin/settings`. A fake that throws `PostgrestException(message: 'church_slug_taken')` shows `slugTaken`.
- [ ] **Step 2: Run them and confirm FAIL.** **Step 3: Implement** (keys `createChurchTitle`, `churchName`, `churchAddress`, `slugTaken`, `slugInvalid` in `es`, `en`, `pt`). **Step 4: Run** `flutter analyze && flutter test` until PASS.
- [ ] **Step 5: Commit** (`Let anyone signed in create a church`).

### Task 9: People, invite links and the join page

**Files:**
- Create: `app/lib/src/features/admin/people_page.dart`, `app/lib/src/features/church/join_page.dart`
- Modify: `app/lib/src/app/app.dart` (routes `/c/:church/admin/people`, `/join/:token`), `admin_home_page.dart` (links to People and Settings when owner)
- Test: `app/test/people_page_test.dart`, `app/test/join_page_test.dart`

**Interfaces:**
- `PeoplePage({required Church church})` inside `AdminPage(minRole: ChurchRole.owner)`:
  - **Invite links section:** one row per role (`editor`, `member`). It shows the active link `'${Uri.base.origin}/join/<token>'` with a copy button (`Clipboard.setData`) and "Revoke". Without an active link, the row shows "Create link". It uses `invites`, `createInvite` and `revokeInvite`.
  - **People section:** `people(church.id)`, one row each with name (or email), email and a role dropdown that calls `setMemberRole`, plus "Remove" (`removeMember`). `last_owner` shows `l.lastOwner`.
- `JoinPage({required String token})`: shows `inviteInfo` ("Join *Vida Nueva* as Editor"). With no info it shows `l.inviteInvalid`. Signed out, the button reads "Sign in to join" and goes to `/login?next=/join/<token>`. Signed in, it calls `acceptInvite`, invalidates `myChurchesProvider`, and goes to `/c/<slug>/admin` for editor or `/c/<slug>` for member.

- [ ] **Step 1: Write the failing tests:**
  - `people_page_test.dart`: with one editor link active, it shows the URL ending in `/join/t1`, and "Revoke" calls `revokeInvite('t1')`. Changing a person's dropdown to `owner` calls `setMemberRole('A','u2',ChurchRole.owner)`. A fake throwing `last_owner` shows `lastOwner`. An editor (not owner) sees `churchAdminOnly`.
  - `join_page_test.dart`: signed out with valid info, it shows the church name and role, and the button goes to `/login?next=%2Fjoin%2Ft1`. Signed in, it calls `acceptInvite('t1')` and lands on `/c/vida-nueva/admin` for an editor invite. With unknown info it shows `inviteInvalid`.
- [ ] **Step 2: Run them and confirm FAIL.** **Step 3: Implement.** Admin keys are Spanish: `people`, `inviteLinks`, `createLink`, `revokeLink`, `copyLink`, `linkCopied`, `removePerson`, `lastOwner`. Member keys go in `es`, `en` and `pt`: `joinChurchAs` (placeholders `church`, `role`), `signInToJoin`, `inviteInvalid`. **Step 4: Run** `flutter analyze && flutter test` until PASS.
- [ ] **Step 5: Commit** (`Invite people by link and manage their roles`).

### Task 10: Church settings and the monthly limit

**Files:**
- Create: `app/lib/src/features/admin/church_settings_page.dart`
- Modify: `app/lib/src/app/app.dart` (route `/c/:church/admin/settings`), `admin_home_page.dart` (usage line)
- Test: `app/test/church_settings_page_test.dart`, `app/test/admin_home_test.dart`

**Interfaces:**
- `ChurchSettingsPage({required Church church})` inside `AdminPage(minRole: ChurchRole.owner)` has these fields: name, default sermon language, default output language, Bible version (filtered by language, as on the import page), and default days (1/3/5/7). The slug is shown read-only. Save calls `updateChurch(church.id, {...})` and invalidates `churchProvider(church.slug)`.
- `AdminHomePage` shows `l.sermonsThisMonth(used, limit)` under the title, from `sermonsThisMonth`. When `used >= limit`, the Import button is disabled and shows `l.monthlyLimitReached(limit)`.

- [ ] **Step 1: Write the failing tests:** saving after changing the name to "Vida Nueva Centro" calls `updateChurch('A', {'name': 'Vida Nueva Centro', …})` with all five fields. The admin home with `used = 4, limit = 4` has a disabled Import button and the limit text, and with `used = 1` the button is enabled and the text reads "1 de 4 este mes".
- [ ] **Step 2: Run them and confirm FAIL.** **Step 3: Implement** (admin keys `churchSettings`, `save`, `saved`, `sermonsThisMonth` with int placeholders `used` and `limit`). **Step 4: Run** `flutter analyze && flutter test` until PASS.
- [ ] **Step 5: Commit** (`Let owners edit church settings and show the monthly limit`).

### Task 11: Church switcher

**Files:**
- Create: `app/lib/src/features/church/church_switcher.dart`
- Modify: `admin_gate.dart` (app bar), `church_page.dart` (app bar)
- Test: `app/test/church_switcher_test.dart`

**Interfaces:**
- `ChurchSwitcher({required Church current, required bool admin})`: a `PopupMenuButton` whose label is the current church's name. It lists `myChurchesProvider` items, plus "Create a church" (`l.createChurch`). Picking a church goes to `/c/<slug>/admin` when `admin` is true and that role `canEdit`, and to `/c/<slug>` otherwise. It is hidden when the person belongs to one church or none.

- [ ] **Step 1: Write the failing test:** with memberships A (owner) and B (member) and `admin: true`, picking B goes to `/c/b` and picking A goes to `/c/a/admin`. With one membership, no switcher is shown.
- [ ] **Step 2: Run it and confirm FAIL.** **Step 3: Implement.** **Step 4: Run** `flutter analyze && flutter test` until PASS.
- [ ] **Step 5: Commit** (`Switch between churches`).

### Task 12: Release

**Files:**
- Modify: `README.md` (churches, roles, `set-limit`, `make-admin` meaning platform admin, running `supabase test db`), `docs/MVP_PLAN.md` (status line)

- [ ] **Step 1: Run every suite.** Run `cd worker && .venv/bin/python -m pytest -q`, then `cd app && flutter analyze && flutter test`, then `npx supabase db reset && npx supabase test db`. Expected: all pass.
- [ ] **Step 2: Allow `next` on the OAuth return.** In the Supabase dashboard, under Authentication → URL Configuration → Redirect URLs, make sure `https://selah-226.pages.dev/login**` and `http://localhost:*/login**` are listed, so `/login?next=…` is accepted. The user does this; confirm with them before going on.
- [ ] **Step 3: Stop the worker** (Ctrl+C in its tab), so no job runs against a half-migrated schema.
- [ ] **Step 4: Push the migrations.** Run `PATH=/usr/local/n/versions/node/22.21.0/bin:$PATH npx supabase db push --linked`. Expected: it applies `202610280001`, `…0002` and `…0003`, then prints `Finished supabase db push.`
- [ ] **Step 5: Check the backfill.** Run `cd worker && .venv/bin/python -m selah_worker check`. Expected: `Churches: 1`. Then open `https://selah-226.pages.dev/studies/<an existing slug>` after Step 6 and confirm it lands on `/c/<church>/studies/<slug>`.
- [ ] **Step 6: Build and deploy the web app** with the README's `flutter build web` and `wrangler pages deploy` commands. Expected: `Deployment complete!`.
- [ ] **Step 7: Restart the worker** with `.venv/bin/python -m selah_worker run`.
- [ ] **Step 8: Smoke test on the live site.** Sign in with a second Google account, create a church, open an Editor invite link from the first account's church, and confirm that account sees only its churches' drafts.
- [ ] **Step 9: Commit and push** the README and MVP_PLAN updates (`Document churches, roles and the release steps`).
