// Run: /usr/local/n/versions/node/22.21.0/bin/node --test site/redirect.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const { landingDecision } = createRequire(import.meta.url)('./src/redirect.js');

/** A storage facade over a plain object, shaped like the one the page builds from localStorage. */
function storage(items = {}) {
  return { getItem: (k) => (k in items ? items[k] : null), keys: () => Object.keys(items) };
}

const visit = (over = {}) => ({ search: '', hash: '', pathname: '/', language: 'es-ES', storage: storage(), ...over });

test('auth returns go to the app with hash and query', () => {
  assert.equal(landingDecision(visit({ hash: '#access_token=x&type=signup' })), '/hoje#access_token=x&type=signup');
  assert.equal(landingDecision(visit({ search: '?code=abc' })), '/hoje?code=abc');
  assert.equal(landingDecision(visit({ hash: '#error=access_denied' })), '/hoje#error=access_denied');
});

test('?home shows the landing page even for members', () => {
  assert.equal(landingDecision(visit({ search: '?home', storage: storage({ 'flutter.church': '"selah"' }) })), null);
});

test('a stored church goes to Today', () => {
  assert.equal(landingDecision(visit({ storage: storage({ 'flutter.church': '"selah"' }) })), '/hoje');
});

test('a Supabase session goes to Today', () => {
  assert.equal(landingDecision(visit({ storage: storage({ 'sb-abc-auth-token': '{}' }) })), '/hoje');
});

test('a newcomer on the Spanish page stays', () => {
  assert.equal(landingDecision(visit()), null);
});

test('first visit follows the browser language', () => {
  assert.equal(landingDecision(visit({ language: 'pt-BR' })), '/pt/');
  assert.equal(landingDecision(visit({ language: 'en-US' })), '/en/');
});

test('the language pages never redirect by language', () => {
  assert.equal(landingDecision(visit({ pathname: '/pt/', language: 'en-US' })), null);
});

test('a chosen language wins', () => {
  assert.equal(landingDecision(visit({ language: 'en-US', storage: storage({ 'site.lang': 'es' }) })), null);
});

test('storage that throws shows the landing page', () => {
  const broken = { getItem: () => { throw new Error('blocked'); }, keys: () => { throw new Error('blocked'); } };
  assert.equal(landingDecision(visit({ storage: broken })), null);
});

test('a member on a Portuguese browser goes to the app, not /pt/', () => {
  assert.equal(landingDecision(visit({ language: 'pt-BR', storage: storage({ 'flutter.church': '"selah"' }) })), '/hoje');
});

test('a chosen language sticks at the root', () => {
  assert.equal(landingDecision(visit({ language: 'es-ES', storage: storage({ 'site.lang': 'en' }) })), '/en/');
  assert.equal(landingDecision(visit({ language: 'en-US', storage: storage({ 'site.lang': 'pt' }) })), '/pt/');
});

test('a chosen language never moves you off a language page', () => {
  assert.equal(landingDecision(visit({ pathname: '/en/', storage: storage({ 'site.lang': 'pt' }) })), null);
});
