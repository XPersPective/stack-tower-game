# Stack Tower API — Cloudflare Workers + D1

PB-012. Ücretsiz katman (C-006). Kimlik = sağlayıcı `sub`; e-posta saklanmaz.

## Uçlar
| Yöntem | Yol | Açıklama |
|---|---|---|
| POST | `/auth/google` | `{idToken}` → `{sessionToken, displayName}` |
| POST | `/auth/apple` | `{idToken}` → `{sessionToken, displayName}` |
| GET | `/me` | Oturum özeti (sub + takma ad) |
| GET | `/leaderboard?board=daily\|endless&day=n` | İlk 100 + kendi sıran |
| POST | `/score` | `{entries:[{board,day,score}]}` toplu; yalnız rekoru yükselten kabul |
| DELETE | `/account` | Kullanıcı + skorları siler |

Gün **sunucuda UTC** hesaplanır; istemcinin gönderdiği `day` yalnız günlük tahtada
sorgu için kullanılır, skor yazımında yok sayılır (C-007). Tavanlar: daily ≤2000,
endless ≤100000. Hız: kullanıcı başına ~10 istek/dk (isolate içi; üretimde Durable
Object'e taşınabilir).

## Kurulum
```bash
cd worker
npm install                 # yalnız wrangler (deploy için)
npx wrangler d1 create stack_tower
# wrangler.toml → database_id güncelle
npx wrangler d1 execute stack_tower --file=./schema.sql
npx wrangler secret put SESSION_SECRET
npx wrangler secret put GOOGLE_CLIENT_ID
npx wrangler secret put APPLE_CLIENT_ID
npx wrangler secret put ALLOWED_ORIGIN   # ör. https://app.stacktower.game
npm run deploy
```

## Testler
```bash
cd worker && npm test
```
`node --experimental-strip-types --test` kullanır (ek bağımlılık yok):
JWT imza/exp/alg=none, Google JWKS doğrulama (aud/iss/exp/imza, kid rotasyonu),
skor temizleme, upsert monotonluğu, UTC gün, hız sınırı, sıralama.

> Not: D1/miniflare entegrasyon testleri ve gerçek sağlayıcı SDK'ları bu ortamda
> (ağ yok) koşulamıyor; uç mantığı saf modüllere ayrıldı ve orada test edildi.
