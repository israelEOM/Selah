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
