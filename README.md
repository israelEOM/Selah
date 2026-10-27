# Selah — La Palabra que permanece

Selah turns a church's YouTube sermons into devotional studies that an admin reviews and publishes, and that members read on the web, iOS and Android.

The plan and current status are in [docs/MVP_PLAN.md](docs/MVP_PLAN.md).

| Piece | Where |
|---|---|
| Flutter app (Riverpod + go_router), all data access through `lib/src/data/repository.dart` | `app/` |
| Schema, row-level security, seed data | `supabase/migrations/` |
| Python worker: YouTube captions, AI pipeline, job polling | `worker/` |

Members read published studies without an account. Admins sign in. Each church has its own address, `/c/<slug>` (for example `/c/my-church/studies/<study>`); old `/studies/…` links redirect to the right church. The worker runs on the admin's Mac, polls the `jobs` table and writes results back with the service role; it has no public address.

## Run the app

```sh
cd app
flutter run -d chrome --dart-define-from-file=config/beta.json
```

Or build once and serve the result (deep links work, nothing is cached):

```sh
cd app
flutter build web --release --dart-define-from-file=config/beta.json
python3 tool/serve.py 3100
```

Importing a sermon needs the worker running (see below); reading published studies does not.

`config/beta.json` holds the Supabase URL and the publishable key, which are safe to ship in the client.

## Live app

https://selah-226.pages.dev (Cloudflare Pages project `selah`). To publish a new version:

```sh
cd app
flutter build web --release --dart-define-from-file=config/beta.json
npx --yes wrangler pages deploy build/web --project-name selah --branch main
```

Wrangler needs Node 20+ (`PATH=/usr/local/n/versions/node/22.21.0/bin:$PATH`). The Supabase auth site address points to this URL, so confirmation emails open the live app.

## Run the worker

Requires Python 3.12+. Copy `.env.example` to `.env` and fill in the Supabase secret key and the Gemini key. `.env` is git-ignored; never commit it.

```sh
cd worker
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python -m selah_worker check    # verifies the Supabase connection, prints the church count
.venv/bin/python -m selah_worker run      # polls for jobs
.venv/bin/python -m selah_worker pipeline <church-slug> <url> [days]   # run one sermon by hand
```

## Churches and roles

Only platform admins create churches (see below); everyone else joins one through an invite link, or a pastor asks for one to be created. Each church has members with one of three roles:

| Role | Can |
|---|---|
| Owner | Everything an Editor can, plus edit church settings, invite people and change or remove roles |
| Editor | Import sermons, review, edit, publish and unpublish studies |
| Member | Follow the church and read its published studies, like anyone else (no access to drafts) |

New accounts choose what they are: a member joins a church (Unirme a una iglesia), or a pastor requests one (Traer mi iglesia a Selah) with the church's name and an optional note. A request only creates a church once a platform admin approves it. Nobody becomes Owner or Editor without a person approving it.

People join by invite link. A link can be used many times and can be revoked by an Owner from the church's people page. Owners can also promote an Editor from the same People page. The Hoy tab shows today's reading across the churches a member follows, and the app has a light and a dark theme (Perfil → Tema, which follows the device by default). Each church can add a limited number of new sermons per month (default 4).

## Platform admin

A platform admin is above all churches (not tied to one) and is the only kind of user who can create one, directly or by approving a request. Create an account in the app (Iniciar sesión → No tengo cuenta), confirm the email, then:

```sh
cd worker && .venv/bin/python -m selah_worker make-admin you@example.com
```

This sets `profiles.is_platform_admin`. Platform admins see church requests in the app, under Perfil → Solicitudes de iglesias: each request shows the church, the requester and a suggested address, and the admin approves it (which creates the church and makes the requester its Owner) or rejects it.

To change a church's monthly sermon limit:

```sh
cd worker && .venv/bin/python -m selah_worker set-limit <church-slug> <n>
```

## Database changes

Add a new file under `supabase/migrations/` and apply it with `npx supabase db push`. The Supabase CLI needs Node 20+.

## Tests

```sh
cd worker && .venv/bin/python -m pytest -q
cd app && flutter analyze && flutter test
```

Database tests run against a local Supabase stack (needs Docker and Node 20+):

```sh
export PATH=/usr/local/n/versions/node/22.21.0/bin:$PATH
npx supabase start
npx supabase db reset    # applies every migration to the local database only
npx supabase test db
```

If `db reset` complains about the Google secret, set `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=dummy`.

## Releasing the churches change

The migrations and the new app must go out together: the old app does not understand the new schema and the new app needs it. In order:

1. In the Supabase dashboard, Authentication → URL Configuration → Redirect URLs, make sure `https://selah-226.pages.dev/login**` and `http://localhost:*/login**` are listed, so `/login?next=…` is accepted.
2. Stop the worker (Ctrl+C), so no job runs against a half-migrated schema.
3. `npx supabase db push --linked` (Node 20+). It applies `202610280001`, `…0002` and `…0003`.
4. `cd worker && .venv/bin/python -m selah_worker check` should print `Churches: 1` (the existing studies move into one church).
   Optional: adjust that church's limit, which starts at 30: `.venv/bin/python -m selah_worker set-limit <slug> <n>`.
5. Build and deploy the web app with the commands under "Live app". Then open `https://selah-226.pages.dev/studies/<an existing slug>` and confirm it lands on `/c/<church>/studies/<slug>`.
6. Restart the worker: `.venv/bin/python -m selah_worker run`.
7. Smoke test on the live site: sign in with a second Google account, check it is not offered to create a church, open an Editor invite link from the first account's church, and confirm that account only sees its own churches' drafts.

## Releasing church requests and the Today page

Migration `202610300001_church_requests.sql` (a table and functions only) must be pushed (`npx supabase db push --linked`) before deploying this app version, because the new app calls the request functions at sign-up and from Perfil → Solicitudes de iglesias. The old app keeps working against the new schema.
