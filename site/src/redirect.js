// Runs first on the landing page, before it paints. Returning members go straight to Today, links back from
// sign-in emails reach the app intact, and the Spanish root page follows the language picked on the
// switcher, or the browser's on a first visit.
function landingDecision({ search, hash, pathname, language, storage }) {
  var query = new URLSearchParams(search);
  if (/(?:^|[#&])(?:access_token|error|type)=/.test(hash) || query.has('code') || query.has('error')) {
    return '/today' + search + hash;
  }
  if (query.has('home')) return null;
  var member, chosen;
  try {
    member = storage.getItem('flutter.church') !== null ||
      storage.keys().some(function (k) { return /^sb-.*-auth-token$/.test(k); });
    chosen = storage.getItem('site.lang');
  } catch (e) {
    return null;
  }
  if (member) return '/today';
  if (pathname !== '/') return null;
  // A language picked on the switcher wins; otherwise a first visit follows the browser.
  var lang = (chosen || language || '').toLowerCase();
  if (lang.indexOf('pt') === 0) return '/pt/';
  if (lang.indexOf('en') === 0) return '/en/';
  return null;
}

if (typeof module !== 'undefined') {
  module.exports = { landingDecision: landingDecision };
} else {
  (function () {
    try {
      // localStorage is read inside landingDecision, so a browser that blocks it still forwards sign-in links.
      var target = landingDecision({
        search: location.search,
        hash: location.hash,
        pathname: location.pathname,
        language: navigator.language,
        storage: {
          getItem: function (k) { return window.localStorage.getItem(k); },
          keys: function () { return Object.keys(window.localStorage); },
        },
      });
      if (target) location.replace(target);
    } catch (e) {}
  })();
}
