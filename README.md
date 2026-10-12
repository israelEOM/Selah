# Selah — La Palabra que permanece

Selah turns a church's YouTube sermons into devotional studies that an admin reviews and publishes, and that members read on the web, iOS and Android.

The plan and current status are in [docs/MVP_PLAN.md](docs/MVP_PLAN.md).

| Piece | Where |
|---|---|
| Flutter app (Riverpod + go_router), all data access through `lib/src/data/repository.dart` | `app/` |
| Schema, row-level security, seed data | `supabase/migrations/` |
| Python worker: YouTube captions, AI pipeline, job polling | `worker/` |

Members read published studies without an account. Admins sign in. The worker runs on the admin's Mac, polls the `jobs` table and writes results back with the service role; it has no public address.

## Run the app

```sh
cd app
flutter run -d chrome --dart-define-from-file=config/beta.json
```

`config/beta.json` holds the Supabase URL and the publishable key, which are safe to ship in the client.

## Run the worker

Requires Python 3.12+. Copy `.env.example` to `.env` and fill in the Supabase secret key and the Gemini key. `.env` is git-ignored; never commit it.

```sh
cd worker
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python -m selah_worker check    # verifies the Supabase connection
.venv/bin/python -m selah_worker run      # polls for jobs
```

## First admin

Create an account in the app (Iniciar sesión → No tengo cuenta), confirm the email, then:

```sh
cd worker && .venv/bin/python -m selah_worker make-admin you@example.com
```

## Database changes

Add a new file under `supabase/migrations/` and apply it with `npx supabase db push`. The Supabase CLI needs Node 20+.

## Tests

```sh
cd worker && .venv/bin/python -m pytest
cd app && flutter test
```
