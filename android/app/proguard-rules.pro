# Stack Tower Game — R8/ProGuard kuralları (PB-032).
#
# Flutter motoru ve eklentilerin kendi kuralları eklenir; burada yalnızca
# refleksiyon kullanan veya JNI üzerinden çağrılan sınıflar korunur.

# --- Flutter gömülü motoru ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- Kotlin eklenti sınıfları ---
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.plugins.**

# --- Native kimlik SDK'ları (PB-031) ---
# google_sign_in / sign_in_with_apple: JNI + platform kanalı üzerinden çağrılır.
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.libraries.identity.** { *; }
-keep class com.apple.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.apple.**

# --- flutter_secure_storage ---
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# --- Ses (audioplayers) ---
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# --- Kotlin metadata ---
-keepattributes *Annotation*, InnerClasses, Signature, Exceptions

# R8 optimizasyonları: kayıt tutmayan alanlar ve satır numarası dosyaları
# gereksiz yer kaplar; stack trace okunabilirliği korunur.
-dontnote
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
