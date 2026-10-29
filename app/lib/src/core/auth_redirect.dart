/// [next] only when it is a path on this site: it starts with `/` but not `//`
/// (and not `/\`, which browsers also read as another host).
String? safeNext(String? next) {
  if (next == null || !next.startsWith('/') || next.startsWith('//') || next.startsWith('/\\')) {
    return null;
  }
  return next;
}

/// Where the iOS app asks Google to send the person back to; Info.plist registers the scheme.
const nativeOAuthReturnUrl = 'com.israel.selah.app://login-callback';

/// Where Google sends the person back to, and how the app reads the result.
/// A safe [next] rides along so the login page can send them on afterwards.
/// Outside a browser there is no site to return to, so the app's own link is used;
/// the login page is still open there and moves on once the session arrives.
String oauthReturnUrl(Uri base, {String? next}) {
  if (!base.isScheme('http') && !base.isScheme('https')) return nativeOAuthReturnUrl;
  final safe = safeNext(next);
  return '${base.origin}/login${safe == null ? '' : '?next=${Uri.encodeQueryComponent(safe)}'}';
}

class OAuthReturn {
  const OAuthReturn({required this.cancelled, this.description});

  final bool cancelled;
  final String? description;
}

/// The provider's error on the page Supabase returned to, or null when there is none.
/// Supabase puts it in the query string or the `#` fragment.
OAuthReturn? oauthErrorFrom(Uri landing) {
  final params = {
    ...Uri.splitQueryString(landing.fragment),
    ...landing.queryParameters,
  };
  final error = params['error'];
  if (error == null) return null;
  return OAuthReturn(cancelled: error == 'access_denied', description: params['error_description']);
}

/// In-app browsers where Google refuses to sign people in.
bool isEmbeddedBrowser(String userAgent) =>
    const ['FBAN', 'FBAV', 'Instagram', 'Line/'].any(userAgent.contains);
