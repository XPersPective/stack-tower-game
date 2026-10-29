import { test } from 'node:test';
import assert from 'node:assert/strict';
import { verifyIdToken, clearJwksCache } from '../src/providers.ts';

const enc = new TextEncoder();
const b64url = (b: Uint8Array) =>
  Buffer.from(b).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

async function makeKey(kid: string) {
  const pair = await crypto.subtle.generateKey(
    {
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256',
    },
    true,
    ['sign', 'verify'],
  );
  const jwk: any = await crypto.subtle.exportKey('jwk', pair.publicKey);
  return { kid, privateKey: pair.privateKey, jwk: { ...jwk, kid } };
}

async function sign(kid: string, privateKey: CryptoKey, payload: any) {
  const h = b64url(enc.encode(JSON.stringify({ alg: 'RS256', kid, typ: 'JWT' })));
  const p = b64url(enc.encode(JSON.stringify(payload)));
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', privateKey, enc.encode(`${h}.${p}`));
  return `${h}.${p}.${b64url(new Uint8Array(sig))}`;
}

const now = 1_800_000_000;

test('geçerli Google belirteci → sub döner', async () => {
  clearJwksCache();
  const k = await makeKey('kid-1');
  let calls = 0;
  const fetchImpl = (async () => {
    calls++;
    return new Response(JSON.stringify({ keys: [k.jwk] }), { status: 200 });
  }) as unknown as typeof fetch;
  const token = await sign('kid-1', k.privateKey, {
    iss: 'https://accounts.google.com',
    aud: 'client-1',
    sub: 'user-42',
    exp: now + 3600,
  });
  const sub = await verifyIdToken(token, {
    jwksUrl: 'https://example/jwks',
    audience: 'client-1',
    issuers: ['https://accounts.google.com', 'accounts.google.com'],
    fetchImpl,
    nowSec: now,
  });
  assert.equal(sub, 'user-42');
  assert.equal(calls, 1);
});

test('yanlış audience / süresi geçmiş / yanlış imza reddedilir', async () => {
  clearJwksCache();
  const k = await makeKey('kid-2');
  const other = await makeKey('kid-2');
  const fetchImpl = (async () =>
    new Response(JSON.stringify({ keys: [k.jwk] }), { status: 200 })) as unknown as typeof fetch;
  const opts = {
    jwksUrl: 'https://example/jwks2',
    audience: 'client-1',
    issuers: ['https://accounts.google.com'],
    fetchImpl,
    nowSec: now,
  };

  const wrongAud = await sign('kid-2', k.privateKey, {
    iss: 'https://accounts.google.com', aud: 'baska', sub: 'u', exp: now + 10,
  });
  assert.equal(await verifyIdToken(wrongAud, opts), null);

  const expired = await sign('kid-2', k.privateKey, {
    iss: 'https://accounts.google.com', aud: 'client-1', sub: 'u', exp: now - 1,
  });
  assert.equal(await verifyIdToken(expired, opts), null);

  const forged = await sign('kid-2', other.privateKey, {
    iss: 'https://accounts.google.com', aud: 'client-1', sub: 'u', exp: now + 10,
  });
  assert.equal(await verifyIdToken(forged, opts), null);
});

test('bilinmeyen kid → JWKS bir kez yenilenir', async () => {
  clearJwksCache();
  const oldKey = await makeKey('old');
  const newKey = await makeKey('new');
  let calls = 0;
  const fetchImpl = (async () => {
    calls++;
    const keys = calls === 1 ? [oldKey.jwk] : [oldKey.jwk, newKey.jwk];
    return new Response(JSON.stringify({ keys }), { status: 200 });
  }) as unknown as typeof fetch;
  const token = await sign('new', newKey.privateKey, {
    iss: 'https://accounts.google.com', aud: 'c', sub: 'u2', exp: now + 60,
  });
  const sub = await verifyIdToken(token, {
    jwksUrl: 'https://example/jwks3',
    audience: 'c',
    issuers: ['https://accounts.google.com'],
    fetchImpl,
    nowSec: now,
  });
  assert.equal(sub, 'u2');
  assert.equal(calls, 2, 'önce önbellek, sonra tek yenileme');
});
