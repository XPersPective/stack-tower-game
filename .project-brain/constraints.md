# Constraints

Only rules that change decisions. One line each, with source.

- C-001: Kalite tabanı pazarlıksız: mevcut sürümün görsel/duysal/oyun kalitesinin altına düşülmeyecek; "daha iyi olabilir, daha kötü olamaz" (source: user)
- C-002: Oyun mantığı birebir: denge formülleri, ekonomi, yıldız, kilit açma, sürpriz tohumları JS kaynağıyla matematiksel olarak aynı (source: SPEC §2)
- C-003: Burada yazan hiçbir özellik atlanmayacak; yazmayan varsayılmayacak (source: SPEC başlık)
- C-004: Dikey mod her iki platformda kilitli (source: SPEC §3)
- C-005: Oyun tam çevrimdışı oynanabilir; skor asla kaybolmaz; sunucu yoksa sessizce yerel tahta ile devam (source: SPEC §6)
- C-006: Bulut servisleri yalnızca ücretsiz katman: Cloudflare Workers + D1 (source: SPEC §7.1)
- C-007: Yalnızca en yüksek skor gönderilir/puanlanır; gün UTC'de sunucuda hesaplanır; sanity tavanlar (source: SPEC §7.4)
- C-008: Marka: Stack Tower Game; kullanıcıya görünen hiçbir yerde "Neon Kule" olmayacak (source: user, ADR-001)
- C-009: Görsel yeniden keşif yasak — neon estetik sadakatle taşınır, iyileştirilebilir (source: SPEC §3)
- C-010: Reklam/analitik/3. parti paylaşım yok; gizlilik beyanları + uygulama içi hesap silme zorunlu (source: SPEC §7.6)
- C-011: iOS Guideline 4.8: Google girişiyle birlikte Apple girişi de sunulur (varsayılan karar) (source: SPEC §7.2)
- C-012: Arayüz/UX dili Türkçe kalır (orijinaldeki gibi) (source: reference/www)
- C-013: Kayıt her önemli olayda anında yazılır; şema SPEC §5 ile aynı (source: SPEC §5)
- C-014: Kimlik = sağlayıcı `sub` değeri; e-posta hiçbir yerde saklanmaz/gösterilmez (source: SPEC §7.2/§7.5)
