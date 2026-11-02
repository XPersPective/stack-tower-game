/// Stack Tower Game — ortam animasyonu kapısı.
///
/// Arka plan/ortam animasyonları (aurora, yıldız sürüklenmesi, nefes alan
/// logo) "canlı" görünür ama test ortamında devreye girmemelidir: widget
/// testlerinde `pumpAndSettle` sonsuz bir animasyonla asla "durulmaz" ve
/// test zaman aşımına düşer.
///
/// Bu yüzden ortam animasyonu uygulama açılışında (main) açılır; testlerde
/// ekranlar doğrudan pump edildiği için kapalı kalır → deterministik test.
///
/// Erişilebilirlik: `reduceMotion` ayarı bu kanalı kapatır.
library;

class AmbientMotion {
  AmbientMotion._();

  static bool _enabled = false;

  /// Ortam animasyonları açık mı?
  static bool get enabled => _enabled;

  /// Ortam animasyonlarını açar (uygulama açılışında çağrılır).
  static void enable() => _enabled = true;

  /// Ortam animasyonlarını kapatır (erişilebilirlik / düşük güç modu).
  static void disable() => _enabled = false;

  /// Testlerde determinizm için kapatır.
  static void reset() => _enabled = false;
}
