import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  RateLimiter,
  rankRows,
  sanitizeScore,
  shouldReplace,
  utcDay,
  DAILY_MAX,
  ENDLESS_MAX,
} from '../src/logic.ts';

test('skor temizleme: negatif/tavan/tip', () => {
  assert.equal(sanitizeScore('daily', 42), 42);
  assert.equal(sanitizeScore('daily', '17'), 17);
  assert.equal(sanitizeScore('daily', -1), null);
  assert.equal(sanitizeScore('daily', DAILY_MAX + 1), null);
  assert.equal(sanitizeScore('endless', ENDLESS_MAX), ENDLESS_MAX);
  assert.equal(sanitizeScore('endless', ENDLESS_MAX + 1), null);
  assert.equal(sanitizeScore('daily', 'abc'), null);
  assert.equal(sanitizeScore('daily', 3.9), 3);
});

test('upsert kuralı: yalnız daha yüksek skor rekoru günceller', () => {
  assert.equal(shouldReplace(null, 10), true);
  assert.equal(shouldReplace(10, 10), false, 'eşit skor rekoru düşürmez');
  assert.equal(shouldReplace(10, 11), true);
  assert.equal(shouldReplace(10, 9), false);
});

test('gün UTC epoch gün olarak hesaplanır', () => {
  const ms = Date.UTC(2026, 9, 29, 23, 59, 59);
  assert.equal(utcDay(ms), Math.floor(ms / 86400000));
  assert.equal(utcDay(ms + 1000) - utcDay(ms), 1, 'gece yarısı gün değişir');
});

test('hız sınırı: dakikada 10 istek', () => {
  const rl = new RateLimiter(10);
  const t0 = 1_000_000;
  for (let i = 0; i < 10; i++) {
    assert.equal(rl.allow('user', t0 + i), true, `istek ${i}`);
  }
  assert.equal(rl.allow('user', t0 + 11), false, '11. istek reddedilir');
  assert.equal(rl.allow('user', t0 + 61_000), true, 'pencere kayınca açılır');
  assert.equal(rl.allow('other', t0 + 12), true, 'kullanıcılar bağımsız');
});

test('sıralama: skor azalan, eşitlikte ad; ilk 100', () => {
  const rows = [
    { name: 'B', score: 50 },
    { name: 'A', score: 50 },
    { name: 'C', score: 90 },
  ];
  const r = rankRows(rows, 'B');
  assert.deepEqual(r.rows.map((x) => x.name), ['C', 'A', 'B']);
  assert.equal(r.rank, 3);
  assert.equal(rankRows(rows, 'yok').rank, null);
  const many = Array.from({ length: 150 }, (_, i) => ({ name: `p${i}`, score: i }));
  assert.equal(rankRows(many).rows.length, 100);
});
