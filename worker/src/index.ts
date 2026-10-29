/**
 * PB-012 — Stack Tower Game API (Cloudflare Workers + D1).
 * Uçlar: POST /auth/google, POST /auth/apple, GET /me, GET /leaderboard,
 * POST /score, DELETE /account. SPEC §7.3-7.4.
 * Gizlilik: e-posta saklanmaz; kimlik = sağlayıcı `sub` (C-014).
 */
import { signSession, verifySession } from './jwt.ts';
import { RateLimiter, rankRows, sanitizeScore, shouldReplace, utcDay, type Board } from './logic.ts';
import { verifyIdToken } from './providers.ts';

export interface Env {
  DB: D1Database;
  SESSION_SECRET: string;
  GOOGLE_CLIENT_ID: string;
  APPLE_CLIENT_ID: string;
  ALLOWED_ORIGIN?: string;
  GOOGLE_JWKS?: string;
  APPLE_JWKS?: string;
}

const GOOGLE_JWKS = 'https://www.googleapis.com/oauth2/v3/certs';
const APPLE_JWKS = 'https://appleid.apple.com/auth/keys';
const limiter = new RateLimiter(10);

const json = (body: unknown, status = 200, origin = '*'): Response =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'access-control-allow-origin': origin,
      'access-control-allow-headers': 'authorization,content-type',
      'access-control-allow-methods': 'GET,POST,DELETE,OPTIONS',
      'cache-control': 'no-store',
    },
  });

function bearer(req: Request): string | null {
  const h = req.headers.get('authorization') ?? '';
  return h.startsWith('Bearer ') ? h.slice(7) : null;
}

async function displayNameFor(env: Env, sub: string): Promise<string> {
  const row = await env.DB.prepare('SELECT display_name FROM users WHERE sub = ?1')
    .bind(sub)
    .first<{ display_name: string }>();
  if (row?.display_name) return row.display_name;
  const name = `Oyuncu${Math.abs(hash(sub)) % 9000 + 1000}`;
  await env.DB.prepare(
    'INSERT INTO users (sub, display_name, created_at) VALUES (?1, ?2, ?3) ' +
      'ON CONFLICT(sub) DO NOTHING',
  )
    .bind(sub, name, Date.now())
    .run();
  return name;
}

function hash(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h | 0;
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const origin = env.ALLOWED_ORIGIN ?? '*';
    const url = new URL(req.url);
    const path = url.pathname;
    if (req.method === 'OPTIONS') return json({}, 204, origin);

    try {
      /* ---------------------------- kimlik ---------------------------- */
      if (req.method === 'POST' && (path === '/auth/google' || path === '/auth/apple')) {
        const body = (await req.json().catch(() => null)) as { idToken?: string } | null;
        const idToken = body?.idToken;
        if (!idToken) return json({ error: 'idToken' }, 400, origin);

        const apple = path === '/auth/apple';
        const sub = await verifyIdToken(idToken, {
          jwksUrl: apple ? (env.APPLE_JWKS ?? APPLE_JWKS) : (env.GOOGLE_JWKS ?? GOOGLE_JWKS),
          audience: apple ? env.APPLE_CLIENT_ID : env.GOOGLE_CLIENT_ID,
          issuers: apple
            ? ['https://appleid.apple.com']
            : ['https://accounts.google.com', 'accounts.google.com'],
        });
        if (!sub) return json({ error: 'invalid_token' }, 401, origin);

        const name = await displayNameFor(env, sub);
        const sessionToken = await signSession(
          env.SESSION_SECRET,
          sub,
          name,
          Math.floor(Date.now() / 1000),
        );
        return json({ sessionToken, displayName: name }, 200, origin);
      }

      // bundan sonrası oturum ister
      const token = bearer(req);
      const payload = token ? await verifySession(env.SESSION_SECRET, token, Math.floor(Date.now() / 1000)) : null;
      if (!payload) return json({ error: 'unauthorized' }, 401, origin);

      if (!limiter.allow(payload.sub, Date.now())) {
        return json({ error: 'rate_limited' }, 429, origin);
      }

      if (req.method === 'GET' && path === '/me') {
        return json({ sub: payload.sub, name: payload.name }, 200, origin);
      }

      /* ---------------------------- skorlar ---------------------------- */
      if (req.method === 'POST' && path === '/score') {
        const body = (await req.json().catch(() => null)) as { entries?: unknown } | null;
        const entries = Array.isArray(body?.entries) ? body!.entries : [];
        let accepted = 0;
        for (const raw of entries) {
          const e = raw as { board?: string; day?: number; score?: unknown };
          const board: Board = e.board === 'endless' ? 'endless' : 'daily';
          const score = sanitizeScore(board, e.score);
          if (score === null) continue;
          // gün SUNUCUDA UTC hesaplanır (istemci günü yok sayılır) — C-007
          const day = board === 'daily' ? utcDay(Date.now()) : -1;
          const current = await env.DB.prepare(
            'SELECT score FROM scores WHERE sub = ?1 AND board = ?2 AND day = ?3',
          )
            .bind(payload.sub, board, day)
            .first<{ score: number }>();
          if (!shouldReplace(current?.score ?? null, score)) continue;
          await env.DB.prepare(
            'INSERT INTO scores (sub, board, day, score, updated_at) VALUES (?1, ?2, ?3, ?4, ?5) ' +
              'ON CONFLICT(sub, board, day) DO UPDATE SET score = excluded.score, updated_at = excluded.updated_at ' +
              'WHERE excluded.score > scores.score',
          )
            .bind(payload.sub, board, day, score, Date.now())
            .run();
          accepted++;
        }
        return json({ accepted }, 200, origin);
      }

      if (req.method === 'GET' && path === '/leaderboard') {
        const board: Board = url.searchParams.get('board') === 'endless' ? 'endless' : 'daily';
        const day = board === 'daily'
          ? Number(url.searchParams.get('day') ?? utcDay(Date.now()))
          : -1;
        const rows = await env.DB.prepare(
          'SELECT u.display_name AS name, s.score AS score, s.sub AS sub FROM scores s ' +
            'JOIN users u ON u.sub = s.sub WHERE s.board = ?1 AND s.day = ?2 ' +
            'ORDER BY s.score DESC, u.display_name ASC LIMIT 100',
        )
          .bind(board, day)
          .all<{ name: string; score: number; sub: string }>();
        const list = (rows.results ?? []).map((r) => ({
          name: r.name,
          score: r.score,
          me: r.sub === payload.sub,
        }));
        const ranked = rankRows(list.map((r) => ({ name: r.name, score: r.score })), undefined);
        const mine = list.find((r) => r.me);
        return json(
          {
            board,
            day,
            rows: ranked.rows.map((r) => ({
              ...r,
              me: mine?.name === r.name && mine?.score === r.score,
            })),
            rank: mine ? ranked.rows.findIndex((r) => r.name === mine.name && r.score === mine.score) + 1 : null,
            score: mine?.score ?? null,
          },
          200,
          origin,
        );
      }

      if (req.method === 'DELETE' && path === '/account') {
        await env.DB.prepare('DELETE FROM scores WHERE sub = ?1').bind(payload.sub).run();
        await env.DB.prepare('DELETE FROM users WHERE sub = ?1').bind(payload.sub).run();
        return json({ deleted: true }, 200, origin);
      }

      return json({ error: 'not_found' }, 404, origin);
    } catch (err) {
      return json({ error: 'server_error' }, 500, origin);
    }
  },
};
