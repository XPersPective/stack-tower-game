/**
 * PB-012 — saf iş kuralları (D1'den bağımsız, test edilebilir).
 * Gün UTC'de sunucuda hesaplanır (C-007), sanity tavanları burada.
 */

export const DAILY_MAX = 2000;
export const ENDLESS_MAX = 100000;
export const RATE_LIMIT_PER_MIN = 10;

export type Board = 'daily' | 'endless';

export interface ScoreRow {
  name: string;
  score: number;
}

/** UTC gün numarası (epoch gün). */
export function utcDay(nowMs: number): number {
  return Math.floor(nowMs / 86400000);
}

/** Skor kabul edilebilir mi? (negatif, tavan, tip) */
export function sanitizeScore(board: Board, raw: unknown): number | null {
  const n = typeof raw === 'number' ? raw : Number(raw);
  if (!Number.isFinite(n)) return null;
  const v = Math.floor(n);
  if (v < 0) return null;
  const max = board === 'daily' ? DAILY_MAX : ENDLESS_MAX;
  if (v > max) return null;
  return v;
}

/** D1 upsert kuralı: yalnız daha yüksek skor rekoru günceller. */
export function shouldReplace(current: number | null, next: number): boolean {
  return current === null || next > current;
}

/** Basit kayan pencere hız sınırı (kullanıcı başına ~10 istek/dk). */
export class RateLimiter {
  private hits = new Map<string, number[]>();
  private readonly limit: number;

  constructor(limit: number = RATE_LIMIT_PER_MIN) {
    this.limit = limit;
  }

  allow(key: string, nowMs: number): boolean {
    const from = nowMs - 60000;
    const list = (this.hits.get(key) ?? []).filter((t) => t >= from);
    if (list.length >= this.limit) {
      this.hits.set(key, list);
      return false;
    }
    list.push(nowMs);
    this.hits.set(key, list);
    return true;
  }
}

/** Satırları sıralar (skor azalan, eşitlikte ad) ve kendi sırasını bulur. */
export function rankRows(
  rows: ScoreRow[],
  me?: string,
): { rows: ScoreRow[]; rank: number | null } {
  const sorted = [...rows].sort((a, b) =>
    b.score - a.score || a.name.localeCompare(b.name),
  );
  const idx = me === undefined ? -1 : sorted.findIndex((r) => r.name === me);
  return { rows: sorted.slice(0, 100), rank: idx < 0 ? null : idx + 1 };
}
