# Google and Apple Sign-In (Web) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On the Selah web app (https://selah-226.pages.dev), people can sign in with their Google or Apple account in addition to email and password.

**Architecture:** Supabase Auth handles both providers through its OAuth redirect flow (PKCE). The Flutter app calls `signInWithOAuth`; the browser goes to Google or Apple, then to Supabase's callback, then back to `/login` on the Selah site, where `supabase_flutter` picks up the session from the URL. The login page sends the person on (admin → `/admin`, everyone else → `/`) or shows the provider's error. No database changes: `handle_new_user` already creates a `member` profile for every new auth user, and admins are still promoted with `make-admin`.

**Tech Stack:** Flutter web (`supabase_flutter` 2.18, Riverpod 3, go_router 18, `flutter_svg` for the Google mark), Supabase Auth (hosted project `oyulenlgixlhhqttitpm`), Python worker (PyJWT with `cryptography`) for the Apple client secret, Cloudflare Pages for deploy.

**Spec:** the request of 2026-10-18 ("make it possible in the Selah web page to log in using Google and Apple accounts"), within [docs/MVP_PLAN.md](../../MVP_PLAN.md) §3.3 (members read without an account; only admins must sign in).

## Global Constraints

- Web only. Native iOS/Android sign-in (required for App Store "Sign in with Apple") is a separate plan.
- Supabase project ref: `oyulenlgixlhhqttitpm`. OAuth callback URL for both providers: `https://oyulenlgixlhhqttitpm.supabase.co/auth/v1/callback`.
- App return URL: `<origin>/login`, i.e. `https://selah-226.pages.dev/login` live and `http://localhost:3100/login` locally. Both already match the Supabase redirect allow-list (`https://selah-226.pages.dev/**`, `http://localhost:3100/**`, `http://localhost:*/**`); do not change it.
- Provider client secrets never go into git. They are entered in the Supabase dashboard; `supabase/config.toml` keeps `secret = "env(...)"` references only.
- All UI copy is Spanish and goes in `app/lib/l10n/app_es.arb`.
- Email and password sign-in keeps working unchanged.
- Button labels and look follow the providers' branding rules: "Continuar con Google" on a white button with the four-colour G; "Continuar con Apple" on a black button with the Apple logo.
- Supabase CLI and Wrangler need Node 20+: prefix commands with `PATH=/usr/local/n/versions/node/22.21.0/bin:$PATH`.

## Review Focus

1. **The person cancels at Google or Apple.** Supabase returns to `/login?error=access_denied…`. Expected: the login page says "No se completó el inicio de sesión. Inténtalo de nuevo." and the buttons work again. Pinned in Task 3 (`oauthErrorFrom`) and Task 4 (widget test).
2. **The existing admin (email + password) signs in with Google using the same address.** Expected: the same account and admin role, not a new member account. Supabase links verified identities with the same email automatically; checked by hand in Task 5.
3. **Apple "Ocultar mi correo".** Apple gives a `@privaterelay.appleid.com` address, so that person becomes a new member account. Expected: they can read; to make them admin, run `make-admin` with the relay address shown in Supabase → Authentication → Users. Documented in Task 5.
4. **The Apple client secret expires** (Apple allows at most 6 months). Expected: it is generated with an explicit expiry, the date is written in the README, and a request for more than 180 days is refused. Pinned in Task 2.
5. **Link opened inside Instagram or Facebook's in-app browser.** Google refuses OAuth in embedded webviews (`disallowed_useragent`). Expected: the login page tells the person to open the page in Safari or Chrome. Pinned in Task 3 (`isEmbeddedBrowser`) and Task 4.

---

### Task 1: Enable Google in Supabase

Setup only; the deliverable is Supabase reporting Google as enabled.

**Files:**
- Modify: `supabase/config.toml` (`[auth.external.google]` block)

**Interfaces:**
- Produces: Google provider enabled on project `oyulenlgixlhhqttitpm`; used by Task 4.

- [ ] **Step 1: Create the Google OAuth client** (by the project owner, in Google Cloud Console)

  - New project "Selah". Do not reuse NeoSkin's client: its consent screen says NeoSkin.
  - OAuth consent screen: External; app name "Selah"; support email the owner's; scopes `openid`, `email`, `profile` only (no verification needed for these); publishing status **In production**, otherwise only listed test users can sign in.
  - Credentials → Create OAuth client ID → Web application. Authorised JavaScript origins: `https://selah-226.pages.dev`, `http://localhost:3100`. Authorised redirect URI: `https://oyulenlgixlhhqttitpm.supabase.co/auth/v1/callback`.
  - Copy the client ID and client secret.

- [ ] **Step 2: Enter them in Supabase**

  Dashboard → Authentication → Sign In / Providers → Google: enable, paste client ID and secret, save.

- [ ] **Step 3: Mirror the non-secret values in `supabase/config.toml`**

  In `[auth.external.google]`: `enabled = true`, `client_id = "<client id>"`, `secret = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET)"`. Leave the rest as is.

- [ ] **Step 4: Verify**

  Run:
  ```bash
  ANON=$(python3 -c "import json;print(json.load(open('app/config/beta.json'))['SUPABASE_ANON_KEY'])")
  curl -s https://oyulenlgixlhhqttitpm.supabase.co/auth/v1/settings -H "apikey: $ANON" | python3 -c "import json,sys;print(json.load(sys.stdin)['external']['google'])"
  ```
  Expected: `True`

  Then `printf 'n\nn\n' | npx --yes supabase config push` must list no auth change other than secret lines. Answer `n` to every prompt; nothing is pushed.

- [ ] **Step 5: Commit**

  ```bash
  git add supabase/config.toml
  git commit -m "Enable Google sign-in in Supabase config"
  ```

### Task 2: Apple client secret generator, then enable Apple in Supabase

**Files:**
- Create: `worker/selah_worker/apple_secret.py`
- Modify: `worker/selah_worker/__main__.py` (new `apple-secret` command in `main()` and the module docstring)
- Modify: `worker/requirements.txt` (add `PyJWT[crypto]>=2.9`)
- Modify: `supabase/config.toml` (`[auth.external.apple]` block)
- Test: `worker/tests/test_apple_secret.py`

**Interfaces:**
- Produces: `make_client_secret(team_id: str, key_id: str, services_id: str, private_key_pem: str, now: int, days: int = 180) -> str` and the command `python -m selah_worker apple-secret <team_id> <key_id> <services_id> <path/to/AuthKey.p8>`, which prints the secret and its expiry date (YYYY-MM-DD).

- [ ] **Step 1: Write the failing tests**

```python
import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec

from selah_worker.apple_secret import make_client_secret

NOW = 1_800_000_000


def _key():
    key = ec.generate_private_key(ec.SECP256R1())
    pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                            serialization.NoEncryption()).decode()
    return key, pem


def test_secret_has_the_claims_apple_expects():
    key, pem = _key()
    token = make_client_secret("TEAM123456", "KEY1234567", "app.selah.web", pem, now=NOW)
    header = jwt.get_unverified_header(token)
    claims = jwt.decode(token, key.public_key(), algorithms=["ES256"],
                        audience="https://appleid.apple.com", options={"verify_exp": False})
    assert header["alg"] == "ES256" and header["kid"] == "KEY1234567"
    assert claims["iss"] == "TEAM123456"
    assert claims["sub"] == "app.selah.web"
    assert claims["iat"] == NOW
    assert claims["exp"] == NOW + 180 * 86400


def test_refuses_more_than_180_days():
    _, pem = _key()
    with pytest.raises(ValueError):
        make_client_secret("TEAM123456", "KEY1234567", "app.selah.web", pem, now=NOW, days=181)
```

- [ ] **Step 2: Run them to see them fail**

  Run: `cd worker && .venv/bin/pip install -r requirements.txt && .venv/bin/python -m pytest tests/test_apple_secret.py -v`
  Expected: FAIL with `ModuleNotFoundError: No module named 'selah_worker.apple_secret'`

- [ ] **Step 3: Implement `make_client_secret` and the `apple-secret` command**

  `jwt.encode` with ES256, headers `{"kid": key_id}`, claims `iss`, `iat=now`, `exp=now + days*86400`, `aud="https://appleid.apple.com"`, `sub=services_id`. Raise `ValueError` when `days > 180` (Apple's limit is 6 months). The command reads the .p8 file, uses `int(time.time())`, and prints the secret, then `Expires: YYYY-MM-DD`.

- [ ] **Step 4: Run the tests**

  Run: `cd worker && .venv/bin/python -m pytest -q`
  Expected: all pass (31 existing + 2 new).

- [ ] **Step 5: Create the Apple identifiers** (by the project owner; needs a paid Apple Developer Program membership)

  In Certificates, Identifiers & Profiles:
  - App ID `app.selah.selah` (the Flutter bundle id) with the "Sign in with Apple" capability.
  - Services ID `app.selah.web`, Sign in with Apple enabled and linked to that App ID. Domains: `oyulenlgixlhhqttitpm.supabase.co`. Return URL: `https://oyulenlgixlhhqttitpm.supabase.co/auth/v1/callback`.
  - Key with "Sign in with Apple" enabled. Download `AuthKey_<KEYID>.p8` once and keep it outside the repo. Note the Key ID and the Team ID.

- [ ] **Step 6: Generate the secret and enter it in Supabase**

  Run: `cd worker && .venv/bin/python -m selah_worker apple-secret <TEAM_ID> <KEY_ID> app.selah.web ~/Keys/AuthKey_<KEY_ID>.p8`
  Dashboard → Authentication → Sign In / Providers → Apple: enable; Client IDs `app.selah.web`; Secret Key = the printed secret; save.

- [ ] **Step 7: Mirror the non-secret values and verify**

  In `[auth.external.apple]`: `enabled = true`, `client_id = "app.selah.web"`, `secret` stays `"env(SUPABASE_AUTH_EXTERNAL_APPLE_SECRET)"`. Run the `curl` from Task 1 Step 4 with `['external']['apple']`. Expected: `True`.

- [ ] **Step 8: Commit**

  ```bash
  git add worker/selah_worker/apple_secret.py worker/selah_worker/__main__.py worker/requirements.txt worker/tests/test_apple_secret.py supabase/config.toml
  git commit -m "Add Apple client secret generator and enable Apple sign-in"
  ```

### Task 3: Redirect helpers and repository method

**Files:**
- Create: `app/lib/src/core/auth_redirect.dart`
- Modify: `app/lib/src/data/repository.dart` (Auth section)
- Test: `app/test/auth_redirect_test.dart`

**Interfaces:**
- Produces, in `auth_redirect.dart`:
  - `String oauthReturnUrl(Uri base)` → `'${base.origin}/login'`
  - `OAuthReturn? oauthErrorFrom(Uri landing)` → null when the URL has no `error`; otherwise `OAuthReturn(cancelled: error == 'access_denied', description: <error_description or null>)`. Reads both the query string and the `#` fragment, because Supabase uses either.
  - `class OAuthReturn { final bool cancelled; final String? description; }`
  - `bool isEmbeddedBrowser(String userAgent)` → true when the user agent contains `FBAN`, `FBAV`, `Instagram` or `Line/`.
- Produces, in `SelahRepository`: `Future<void> signInWithProvider(OAuthProvider provider, {required String redirectTo})`, which calls `_client.auth.signInWithOAuth(provider, redirectTo: redirectTo)`. On web this replaces the current page.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/src/core/auth_redirect.dart';

void main() {
  test('returns to /login on the same origin', () {
    expect(oauthReturnUrl(Uri.parse('https://selah-226.pages.dev/admin?x=1')),
        'https://selah-226.pages.dev/login');
    expect(oauthReturnUrl(Uri.parse('http://localhost:3100/')), 'http://localhost:3100/login');
  });

  test('no error on a normal landing', () {
    expect(oauthErrorFrom(Uri.parse('https://selah-226.pages.dev/login?code=abc')), isNull);
  });

  test('cancel in the query string', () {
    final r = oauthErrorFrom(Uri.parse(
        'https://selah-226.pages.dev/login?error=access_denied&error_description=User+cancelled'))!;
    expect(r.cancelled, isTrue);
    expect(r.description, 'User cancelled');
  });

  test('error in the fragment', () {
    final r = oauthErrorFrom(Uri.parse(
        'https://selah-226.pages.dev/login#error=server_error&error_description=Unable+to+exchange+external+code'))!;
    expect(r.cancelled, isFalse);
    expect(r.description, 'Unable to exchange external code');
  });

  test('detects in-app browsers Google refuses', () {
    expect(isEmbeddedBrowser('Mozilla/5.0 (iPhone) Instagram 300.0'), isTrue);
    expect(isEmbeddedBrowser('Mozilla/5.0 (iPhone) [FBAN/FBIOS;FBAV/400.0]'), isTrue);
    expect(isEmbeddedBrowser('Mozilla/5.0 (iPhone) Version/18.0 Mobile/15E148 Safari/604.1'), isFalse);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

  Run: `cd app && flutter test test/auth_redirect_test.dart`
  Expected: FAIL, `auth_redirect.dart` not found.

- [ ] **Step 3: Implement `auth_redirect.dart` and `signInWithProvider`** with the signatures above.

- [ ] **Step 4: Run all app tests and analyze**

  Run: `cd app && flutter test && flutter analyze`
  Expected: all tests pass; "No issues found!"

- [ ] **Step 5: Commit**

  ```bash
  git add app/lib/src/core/auth_redirect.dart app/lib/src/data/repository.dart app/test/auth_redirect_test.dart
  git commit -m "Add OAuth redirect helpers and provider sign-in to the repository"
  ```

### Task 4: Google and Apple buttons on the login page

**Files:**
- Modify: `app/lib/src/features/auth/login_page.dart`
- Create: `app/lib/src/features/auth/provider_buttons.dart`
- Create: `app/lib/src/core/user_agent.dart`, `user_agent_web.dart`, `user_agent_stub.dart`
- Modify: `app/lib/src/app/app.dart` (the `/login` route stays `const LoginPage()`)
- Modify: `app/lib/l10n/app_es.arb`
- Modify: `app/pubspec.yaml` (add `flutter_svg`)
- Test: `app/test/login_page_test.dart`

**Interfaces:**
- Consumes: `oauthReturnUrl`, `oauthErrorFrom`, `isEmbeddedBrowser` (Task 3); `SelahRepository.signInWithProvider` (Task 3); `userIdProvider`, `isAdminProvider` (existing, `app/lib/src/data/providers.dart`).
- Produces:
  - `LoginPage({super.key, Uri? landing, String? userAgent})`. Tests pass `landing` and `userAgent`; the app passes neither, and the page then uses `Uri.base` and `currentUserAgent()`.
  - `String currentUserAgent()` from `core/user_agent.dart`, a conditional export: `user_agent_web.dart` (`if (dart.library.js_interop)`) returns `web.window.navigator.userAgent`; `user_agent_stub.dart` returns `''`. `package:web` must not be imported anywhere else, or the iOS and Android builds stop compiling.
  - `ProviderButtons({required VoidCallback? onGoogle, required VoidCallback? onApple})`, two full-width buttons; null callbacks disable them.

New strings in `app_es.arb`:

| Key | Text |
|---|---|
| `continueWithGoogle` | Continuar con Google |
| `continueWithApple` | Continuar con Apple |
| `orWithEmail` | o con tu correo |
| `oauthCancelled` | No se completó el inicio de sesión. Inténtalo de nuevo. |
| `oauthFailed` | No fue posible iniciar sesión con esa cuenta. Inténtalo de nuevo o usa tu correo. |
| `embeddedBrowserHint` | Para entrar con Google o Apple, abre esta página en Safari o Chrome. |

Behaviour:
- Buttons sit above the email form, followed by a divider labelled `orWithEmail`. The email form is unchanged.
- Tapping a button sets `_busy` (both buttons and the form submit disable) and calls `signInWithProvider(provider, redirectTo: oauthReturnUrl(Uri.base))`.
- On first build, `oauthErrorFrom(landing)` non-null shows `oauthCancelled` when `cancelled`, otherwise `oauthFailed`. The raw `description` is not shown.
- `isEmbeddedBrowser(userAgent)` shows `embeddedBrowserHint` above the buttons; the buttons stay enabled.
- `ref.listen(userIdProvider)`: when it becomes non-null, read `isAdminProvider.future` and `context.go('/admin')` for admins, `context.go('/')` otherwise. This covers the return from Google or Apple and replaces the current `context.go('/admin')` after email sign-in.
- Google button: white background, 1px border `#747775`, text `#1F1F1F`, the standard four-colour G as an inline SVG string (`SvgPicture.string`) at 18px. Apple button: black background, white text, `Icons.apple`.

- [ ] **Step 1: Write the failing widget tests**

  A fake repository records provider calls: `class _FakeRepository implements SelahRepository` with `final calls = <OAuthProvider>[];`, `signInWithProvider` adding to `calls`, and `noSuchMethod` for the rest. Pump `LoginPage` inside `ProviderScope(overrides: [repositoryProvider.overrideWithValue(fake), userIdProvider.overrideWith((ref) => Stream.value(null)), isAdminProvider.overrideWith((ref) async => false)])` and a `MaterialApp` with `AppLocalizations` delegates and `locale: Locale('es')`.

  - `test: shows both provider buttons` → `find.text('Continuar con Google')` and `find.text('Continuar con Apple')` each `findsOneWidget`.
  - `test: Google button starts Google sign-in` → tap it; `expect(fake.calls, [OAuthProvider.google])`.
  - `test: Apple button starts Apple sign-in` → tap it; `expect(fake.calls, [OAuthProvider.apple])`.
  - `test: cancelled return shows the cancel message` → `landing: Uri.parse('https://selah-226.pages.dev/login?error=access_denied')`; `find.text('No se completó el inicio de sesión. Inténtalo de nuevo.')` `findsOneWidget`.
  - `test: other provider error shows a generic message` → `landing: Uri.parse('https://selah-226.pages.dev/login#error=server_error&error_description=x')`; finds the `oauthFailed` text, and `find.text('x')` `findsNothing`.
  - `test: in-app browser hint` → `userAgent: 'Mozilla/5.0 (iPhone) Instagram 300.0'`; finds the `embeddedBrowserHint` text.

- [ ] **Step 2: Run them to see them fail**

  Run: `cd app && flutter test test/login_page_test.dart`
  Expected: FAIL, the provider button texts are not found.

- [ ] **Step 3: Implement** `ProviderButtons`, the `LoginPage` changes, the strings, `core/user_agent*.dart`, and `flutter pub add flutter_svg web`. Run `flutter gen-l10n`.

- [ ] **Step 4: Run all app tests and analyze**

  Run: `cd app && flutter test && flutter analyze && flutter build ios --simulator --debug --dart-define-from-file=config/beta.json`
  Expected: all pass; "No issues found!"; the iOS build succeeds, which proves the conditional import.

- [ ] **Step 5: Commit**

  ```bash
  git add app/lib app/test/login_page_test.dart app/pubspec.yaml app/pubspec.lock
  git commit -m "Add Google and Apple sign-in buttons to the login page"
  ```

### Task 5: Deploy and verify on a phone

**Files:**
- Modify: `README.md` (new "Sign-in providers" section)

- [ ] **Step 1: Build and deploy**

  ```bash
  cd app
  flutter build web --release --dart-define-from-file=config/beta.json
  PATH=/usr/local/n/versions/node/22.21.0/bin:$PATH npx --yes wrangler pages deploy build/web --project-name selah --branch main
  ```
  Expected: "Deployment complete!". Do not pass `--force`.

- [ ] **Step 2: Check each case on a phone at https://selah-226.pages.dev/login**

  | Case | Expected |
  |---|---|
  | Continuar con Google, with the admin's Gmail (the address of the existing email account) | Lands on `/admin` with the sermon list. Supabase → Authentication → Users shows that user with providers `email, google` and no second user. |
  | Continuar con Google, cancel on Google's screen | Back on `/login` with the cancel message. |
  | Continuar con Apple, sharing the real email | Lands on `/`; a new user with provider `apple` and role `member`. |
  | Continuar con Apple, "Ocultar mi correo" | Lands on `/`; the new user's email ends in `@privaterelay.appleid.com`. |
  | Open the login link from an Instagram message | The in-app browser hint is shown. |
  | Email and password sign-in | Still lands on `/admin`. |

  If the Google case creates a second user instead of linking, stop. Report it before going further, because the admin role would be on the wrong account.

- [ ] **Step 3: Document in `README.md`**

  A "Sign-in providers" section with: where each provider is configured (Google Cloud project "Selah", Apple Services ID `app.selah.web`, Supabase dashboard); the Apple secret expiry date printed in Task 2 Step 6 and the regeneration command; that `make-admin` takes the email shown in Supabase → Authentication → Users, including Apple relay addresses.

- [ ] **Step 4: Commit**

  ```bash
  git add README.md
  git commit -m "Document Google and Apple sign-in setup and the Apple secret expiry"
  ```
