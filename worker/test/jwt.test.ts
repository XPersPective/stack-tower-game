import { test } from 'node:test';
import assert from 'node:assert/strict';
import { signSession, verifySession } from '../src/jwt.ts';

const SECRET = 'test-secret';
const NOW = 1_800_000_000;

test('imzalanan oturum doğrulanır', async () => {
  const t = await signSession(SECRET, 'sub-1', 'Oyuncu', NOW);
  const p = await verifySession(SECRET, t, NOW + 10);
  assert.equal(p?.sub, 'sub-1');
  assert.equal(p?.name, 'Oyuncu');
  assert.equal(p?.exp, NOW + 30 * 24 * 3600);
});

test('yanlış sır / bozuk imza reddedilir', async () => {
  const t = await signSession(SECRET, 'sub-1', 'Oyuncu', NOW);
  assert.equal(await verifySession('baska-sir', t, NOW), null);
  assert.equal(await verifySession(SECRET, t.slice(0, -2) + 'xx', NOW), null);
  assert.equal(await verifySession(SECRET, 'a.b', NOW), null);
});

test('süresi geçmiş belirteç reddedilir', async () => {
  const t = await signSession(SECRET, 'sub-1', 'Oyuncu', NOW, 60);
  assert.equal(await verifySession(SECRET, t, NOW + 61), null);
  assert.notEqual(await verifySession(SECRET, t, NOW + 59), null);
});

test('alg=none saldırısı reddedilir', async () => {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' }))
    .toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({ sub: 'saldirgan', name: 'x', iat: NOW, exp: NOW + 999 }),
  ).toString('base64url');
  assert.equal(await verifySession(SECRET, `${header}.${payload}.`, NOW), null);
});
