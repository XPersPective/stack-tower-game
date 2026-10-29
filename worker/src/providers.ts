/**
 * PB-012 — sağlayıcı kimlik belirteci doğrulama (Google/Apple).
 * RS256 + JWKS; kid seçimi, bilinmeyen kid'de BİR kez yenileme,
 * aud/iss/exp kontrolü. E-posta okunmaz/saklanmaz (SPEC §7.5).
 */

export interface Jwk {
  kid: string;
  kty: string;
  n: string;
  e: string;
  alg?: string;
}

export interface VerifyOptions {
  jwksUrl: string;
  audience: string;
  issuers: string[];
  fetchImpl?: typeof fetch;
  nowSec?: number;
}

const b64urlToBytes = (s: string): Uint8Array => {
  const pad = s.length % 4 === 0 ? '' : '='.repeat(4 - (s.length % 4));
  const raw = atob(s.replace(/-/g, '+').replace(/_/g, '/') + pad);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
};

const decodeJson = (s: string): any => JSON.parse(new TextDecoder().decode(b64urlToBytes(s)));

async function importKey(jwk: Jwk): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    'jwk',
    { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: 'RS256', ext: true },
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
}

const cache = new Map<string, { keys: Jwk[]; at: number }>();
const CACHE_MS = 60 * 60 * 1000;

async function loadJwks(url: string, fetchImpl: typeof fetch, force: boolean): Promise<Jwk[]> {
  const hit = cache.get(url);
  const now = Date.now();
  if (!force && hit && now - hit.at < CACHE_MS) return hit.keys;
  const res = await fetchImpl(url);
  if (!res.ok) return hit?.keys ?? [];
  const body: any = await res.json();
  const keys: Jwk[] = Array.isArray(body.keys) ? body.keys : [];
  cache.set(url, { keys, at: now });
  return keys;
}

/** Belirteci doğrular; başarılıysa `sub` döner, aksi halde null. */
export async function verifyIdToken(
  token: string,
  opts: VerifyOptions,
): Promise<string | null> {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [h, p, s] = parts;

  let header: any, payload: any;
  try {
    header = decodeJson(h);
    payload = decodeJson(p);
  } catch {
    return null;
  }
  if (header.alg !== 'RS256' || typeof header.kid !== 'string') return null;
  if (!opts.issuers.includes(payload.iss)) return null;
  if (payload.aud !== opts.audience) return null;

  const now = opts.nowSec ?? Math.floor(Date.now() / 1000);
  if (typeof payload.exp !== 'number' || payload.exp < now) return null;
  if (typeof payload.sub !== 'string' || payload.sub.length === 0) return null;

  const fetchImpl = opts.fetchImpl ?? fetch;
  let keys = await loadJwks(opts.jwksUrl, fetchImpl, false);
  let jwk = keys.find((k) => k.kid === header.kid);
  if (!jwk) {
    // bilinmeyen kid → BİR kez yenile (anahtar rotasyonu)
    keys = await loadJwks(opts.jwksUrl, fetchImpl, true);
    jwk = keys.find((k) => k.kid === header.kid);
  }
  if (!jwk) return null;

  const key = await importKey(jwk);
  const ok = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    b64urlToBytes(s),
    new TextEncoder().encode(`${h}.${p}`),
  );
  return ok ? (payload.sub as string) : null;
}

/** Test/üretim için JWKS önbelleğini temizler. */
export function clearJwksCache(): void {
  cache.clear();
}
