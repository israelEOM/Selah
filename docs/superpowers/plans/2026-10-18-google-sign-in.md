# Google Sign-In (Web) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On the Selah web app (https://selah-226.pages.dev), people can sign in with their Google account in addition to email and password.

**Architecture:** Supabase Auth handles Google through its OAuth redirect flow (PKCE). The Flutter app calls `signInWithOAuth`; the browser goes to Google, then to Supabase's callback, then back to `/login` on the Selah site, where `supabase_flutter` picks up the session from the URL. The login page sends the person on (admin → `/admin`, everyone else → `/`) or shows the provider's error. No database changes: `handle_new_user` already creates a `member` profile for every new auth user, and admins are still promoted with `make-admin`.

**Tech Stack:** Flutter web (`supabase_flutter` 2.18, Riverpod 3, go_router 18, `flutter_svg` for the Google mark), Supabase Auth (hosted project `oyulenlgixlhhqttitpm`), Cloudflare Pages for deploy.

**Spec:** the request of 2026-10-18 ("make it possible in the Selah web page to log in using Google and Apple accounts"; Apple removed on 2026-10-18, "for now"), within [docs/MVP_PLAN.md](../../MVP_PLAN.md) §3.3 (members read without an account; only admins must sign in).

## Global Constraints

- Web only. Apple sign-in and native iOS/Android sign-in are out of scope for now.
- Supabase project ref: `oyulenlgixlhhqttitpm`. OAuth callback URL: `https://oyulenlgixlhhqttitpm.supabase.co/auth/v1/callback`.
- App return URL: `<origin>/login`, i.e. `https://selah-226.pages.dev/login` live and `http://localhost:3100/login` locally. Both already match the Supabase redirect allow-list (`https://selah-226.pages.dev/**`, `http://localhost:3100/**`, `http://localhost:*/**`); do not change it.
- The Google client secret never goes into git. They are entered in the Supabase dashboard; `supabase/config.toml` keeps `secret = "env(...)"` references only.
- All UI copy is Spanish and goes in `app/lib/l10n/app_es.arb`.
- Email and password sign-in keeps working unchanged.
- The button follows Google's branding rules: "Continuar con Google" on a white button with the four-colour G.
- Supabase CLI and Wrangler need Node 20+: prefix commands with `PATH=/usr/local/n/versions/node/22.21.0/bin:$PATH`.

## Review Focus

1. **The person cancels at Google.** Supabase returns to `/login?error=access_denied…`. Expected: the login page says "No se completó el inicio de sesión. Inténtalo de nuevo." and the buttons work again. Pinned in Task 2 (`oauthErrorFrom`) and Task 3 (widget test).
2. **The existing admin (email + password) signs in with Google using the same address.** Expected: the same account and admin role, not a new member account. Supabase links verified identities with the same email automatically; checked by hand in Task 4.
3. **A Google account with no existing Selah account.** Expected: a new member account that can read and lands on `/`, not on the admin-only message. Checked by hand in Task 4.
4. **Two quick taps on the button.** Expected: one redirect; the button disables after the first tap. Pinned in Task 3 (widget test).
5. **Link opened inside Instagram or Facebook's in-app browser.** Google refuses OAuth in embedded webviews (`disallowed_useragent`). Expected: the login page tells the person to open the page in Safari or Chrome. Pinned in Task 2 (`isEmbeddedBrowser`) and Task 3.

---

### Task 1: Enable Google in Supabase

Setup only; the deliverable is Supabase reporting Google as enabled.

**Files:**
- Modify: `supabase/config.toml` (`[auth.external.google]` block)

**Interfaces:**
- Produces: Google provider enabled on project `oyulenlgixlhhqttitpm`; used by Task 3.

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

### Task 2: Redirect helpers and repository method

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

### Task 3: Google button on the login page

**Files:**
- Modify: `app/lib/src/features/auth/login_page.dart`
- Create: `app/lib/src/features/auth/google_button.dart`
- Create: `app/lib/src/core/user_agent.dart`, `user_agent_web.dart`, `user_agent_stub.dart`
- Modify: `app/lib/src/app/app.dart` (the `/login` route stays `const LoginPage()`)
- Modify: `app/lib/l10n/app_es.arb`
- Modify: `app/pubspec.yaml` (add `flutter_svg`)
- Test: `app/test/login_page_test.dart`

**Interfaces:**
- Consumes: `oauthReturnUrl`, `oauthErrorFrom`, `isEmbeddedBrowser` (Task 2); `SelahRepository.signInWithProvider` (Task 2); `userIdProvider`, `isAdminProvider` (existing, `app/lib/src/data/providers.dart`).
- Produces:
  - `LoginPage({super.key, Uri? landing, String? userAgent})`. Tests pass `landing` and `userAgent`; the app passes neither, and the page then uses `Uri.base` and `currentUserAgent()`.
  - `String currentUserAgent()` from `core/user_agent.dart`, a conditional export: `user_agent_web.dart` (`if (dart.library.js_interop)`) returns `web.window.navigator.userAgent`; `user_agent_stub.dart` returns `''`. `package:web` must not be imported anywhere else, or the iOS and Android builds stop compiling.
  - `GoogleButton({required VoidCallback? onPressed})`, a full-width button; a null callback disables it.

New strings in `app_es.arb`:

| Key | Text |
|---|---|
| `continueWithGoogle` | Continuar con Google |
| `orWithEmail` | o con tu correo |
| `oauthCancelled` | No se completó el inicio de sesión. Inténtalo de nuevo. |
| `oauthFailed` | No fue posible iniciar sesión con esa cuenta. Inténtalo de nuevo o usa tu correo. |
| `embeddedBrowserHint` | Para entrar con Google, abre esta página en Safari o Chrome. |

Behaviour:
- The button sits above the email form, followed by a divider labelled `orWithEmail`. The email form is unchanged.
- Tapping it sets `_busy` (the button and the form submit disable) and calls `signInWithProvider(provider, redirectTo: oauthReturnUrl(Uri.base))`.
- On first build, `oauthErrorFrom(landing)` non-null shows `oauthCancelled` when `cancelled`, otherwise `oauthFailed`. The raw `description` is not shown.
- `isEmbeddedBrowser(userAgent)` shows `embeddedBrowserHint` above the button; the button stays enabled.
- `ref.listen(userIdProvider)`: when it becomes non-null, read `isAdminProvider.future` and `context.go('/admin')` for admins, `context.go('/')` otherwise. This covers the return from Google and replaces the current `context.go('/admin')` after email sign-in.
- Google button: white background, 1px border `#747775`, text `#1F1F1F`, the standard four-colour G as an inline SVG string (`SvgPicture.string`) at 18px.

- [ ] **Step 1: Write the failing widget tests**

  A fake repository records provider calls: `class _FakeRepository implements SelahRepository` with `final calls = <OAuthProvider>[];`, `signInWithProvider` adding to `calls`, and `noSuchMethod` for the rest. Pump `LoginPage` inside `ProviderScope(overrides: [repositoryProvider.overrideWithValue(fake), userIdProvider.overrideWith((ref) => Stream.value(null)), isAdminProvider.overrideWith((ref) async => false)])` and a `MaterialApp` with `AppLocalizations` delegates and `locale: Locale('es')`.

  - `test: shows the Google button` → `find.text('Continuar con Google')` `findsOneWidget`.
  - `test: Google button starts Google sign-in` → tap it; `expect(fake.calls, [OAuthProvider.google])`.
  - `test: a second tap does nothing` → tap twice, `pump()` between; `expect(fake.calls, [OAuthProvider.google])`.
  - `test: cancelled return shows the cancel message` → `landing: Uri.parse('https://selah-226.pages.dev/login?error=access_denied')`; `find.text('No se completó el inicio de sesión. Inténtalo de nuevo.')` `findsOneWidget`.
  - `test: other provider error shows a generic message` → `landing: Uri.parse('https://selah-226.pages.dev/login#error=server_error&error_description=x')`; finds the `oauthFailed` text, and `find.text('x')` `findsNothing`.
  - `test: in-app browser hint` → `userAgent: 'Mozilla/5.0 (iPhone) Instagram 300.0'`; finds the `embeddedBrowserHint` text.

- [ ] **Step 2: Run them to see them fail**

  Run: `cd app && flutter test test/login_page_test.dart`
  Expected: FAIL, the button text is not found.

- [ ] **Step 3: Implement** `GoogleButton`, the `LoginPage` changes, the strings, `core/user_agent*.dart`, and `flutter pub add flutter_svg web`. Run `flutter gen-l10n`.

- [ ] **Step 4: Run all app tests and analyze**

  Run: `cd app && flutter test && flutter analyze && flutter build ios --simulator --debug --dart-define-from-file=config/beta.json`
  Expected: all pass; "No issues found!"; the iOS build succeeds, which proves the conditional import.

- [ ] **Step 5: Commit**

  ```bash
  git add app/lib app/test/login_page_test.dart app/pubspec.yaml app/pubspec.lock
  git commit -m "Add a Google sign-in button to the login page"
  ```

### Task 4: Deploy and verify on a phone

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
  | Continuar con Google, with a Google account that has no Selah account | Lands on `/`; a new user with provider `google` and role `member`. |
  | Open the login link from an Instagram message | The in-app browser hint is shown. |
  | Email and password sign-in | Still lands on `/admin`. |

  If the Google case creates a second user instead of linking, stop. Report it before going further, because the admin role would be on the wrong account.

- [ ] **Step 3: Document in `README.md`**

  A "Google sign-in" section: where it is configured (Google Cloud project "Selah", Supabase dashboard → Authentication → Providers), which origins and redirect URI the OAuth client lists, and that a new Google user is a member until `make-admin` is run with their email.

- [ ] **Step 4: Commit**

  ```bash
  git add README.md
  git commit -m "Document Google sign-in setup"
  ```
