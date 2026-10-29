/**
 * PB-012 — oturum JWT'si (HMAC-SHA256). Cloudflare Workers Web Crypto kullanır.
 * Belirteç yükü: sub (sağlayıcı kimliği), name (takma ad), iat, exp.
 * E-posta ASLA yüke konmaz (SPEC §7.5).
 */

export interface SessionPayload {
  sub: string;
  name: string;
  iat: number;
  exp: number;
}

const enc = new TextEncoder();

function b64url(bytes: Uint8Array): string {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function b64urlDecode(s: string): Uint8Array {
  const pad = s.length % 4 === 0 ? '' : '='.repeat(4 - (s.length % 4));
  const raw = atob(s.replace(/-/g, '+').replace(/_/g, '/') + pad);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

async function hmacKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    'raw',
    enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign', 'verify'],
  );
}

/** 30 gün geçerli oturum belirteci üretir. */
export async function signSession(
  secret: string,
  sub: string,
  name: string,
  nowSec: number,
  ttlSec = 30 * 24 * 3600,
): Promise<string> {
  const header = b64url(enc.encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' })));
  const payload = b64url(
    enc.encode(JSON.stringify({ sub, name, iat: nowSec, exp: nowSec + ttlSec })),
  );
  const data = `${header}.${payload}`;
  const key = await hmacKey(secret);
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', key, enc.encode(data)));
  return `${data}.${b64url(sig)}`;
}

/** Belirteci doğrular: imza + alg + exp. Hatalıysa null. */
export async function verifySession(
  secret: string,
  token: string,
  nowSec: number,
): Promise<SessionPayload | null> {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [header, payload, sig] = parts;
  let head: { alg?: string };
  try {
    head = JSON.parse(new TextDecoder().decode(b64urlDecode(header)));
  } catch {
    return null;
  }
  if (head.alg !== 'HS256') return null;
  const key = await hmacKey(secret);
  const ok = await crypto.subtle.verify(
    'HMAC',
    key,
    b64urlDecode(sig),
    enc.encode(`${header}.${payload}`),
  );
  if (!ok) return null;
  let body: SessionPayload;
  try {
    body = JSON.parse(new TextDecoder().decode(b64urlDecode(payload)));
  } catch {
    return null;
  }
  if (typeof body.sub !== 'string' || body.sub.length === 0) return null;
  if (typeof body.exp !== 'number' || body.exp < nowSec) return null;
  return body;
}
