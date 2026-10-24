/// Stack Tower Game — neon tema token'ları.
/// Tüm sabitler `reference/www/levels.js` THEMES ve `style.css` kaynağından
/// birebir taşınmıştır (SPEC §3; görsel yeniden keşif yasak).
library;

import 'package:flutter/material.dart';

/// 10 dünya teması: palet, arka plan, glow tonu, hava efekti, siluet türü.
class WorldTheme {
  final String id;
  final String name;
  final List<int> hues;
  final Color bg1;
  final Color bg2;
  final int glow;
  final String weather; // stars | leaves | sand | snow | embers
  final String silhouette; // city | trees | dunes | ice | rocks | volcano

  const WorldTheme({
    required this.id,
    required this.name,
    required this.hues,
    required this.bg1,
    required this.bg2,
    required this.glow,
    required this.weather,
    required this.silhouette,
  });
}

/// levels.js THEMES — birebir (bg: ['#..','#..'] → bg1/bg2).
const List<WorldTheme> kThemes = [
  WorldTheme(id: 'sehir', name: 'NEON ŞEHİR', hues: [210, 268, 322], bg1: Color(0xFF0c0a20), bg2: Color(0xFF1e1046), glow: 268, weather: 'stars', silhouette: 'city'),
  WorldTheme(id: 'orman', name: 'BİYO ORMAN', hues: [130, 160, 95], bg1: Color(0xFF04140d), bg2: Color(0xFF0d2c1a), glow: 150, weather: 'leaves', silhouette: 'trees'),
  WorldTheme(id: 'col', name: 'ALTIN ÇÖL', hues: [35, 48, 22], bg1: Color(0xFF1c0f04), bg2: Color(0xFF3a2410), glow: 35, weather: 'sand', silhouette: 'dunes'),
  WorldTheme(id: 'buz', name: 'BUZ DÜNYA', hues: [195, 205, 178], bg1: Color(0xFF04121e), bg2: Color(0xFF0d2f42), glow: 195, weather: 'snow', silhouette: 'ice'),
  WorldTheme(id: 'uzay', name: 'UZAY', hues: [282, 300, 255], bg1: Color(0xFF08041a), bg2: Color(0xFF1a0b36), glow: 290, weather: 'stars', silhouette: 'rocks'),
  WorldTheme(id: 'volkan', name: 'VOLKAN', hues: [4, 25, 350], bg1: Color(0xFF1c0404), bg2: Color(0xFF3a1208), glow: 12, weather: 'embers', silhouette: 'volcano'),
  WorldTheme(id: 'bulut', name: 'BULUT ŞEHİR', hues: [205, 218, 190], bg1: Color(0xFF0a1430), bg2: Color(0xFF20406e), glow: 212, weather: 'snow', silhouette: 'dunes'),
  WorldTheme(id: 'deniz', name: 'DERİN DENİZ', hues: [188, 198, 168], bg1: Color(0xFF02101c), bg2: Color(0xFF062a3e), glow: 192, weather: 'stars', silhouette: 'trees'),
  WorldTheme(id: 'kristal', name: 'KRİSTAL MAĞARA', hues: [292, 262, 322], bg1: Color(0xFF140a26), bg2: Color(0xFF2a1450), glow: 288, weather: 'embers', silhouette: 'volcano'),
  WorldTheme(id: 'zirve', name: 'SON KULE · ZİRVE', hues: [355, 40, 200], bg1: Color(0xFF160a20), bg2: Color(0xFF3a1830), glow: 340, weather: 'embers', silhouette: 'volcano'),
];

/// Neon genel palet (style.css kökenli).
class NeonPalette {
  static const ink = Color(0xFF06040f); // koyu zemin
  static const panel = Color(0x6610102a); // yarı saydam panel
  static const cyan = Color(0xFF46e6ff);
  static const magenta = Color(0xFFff5ed2);
  static const amber = Color(0xFFffc247);
  static const text = Color(0xFFeef2ff);
  static const textDim = Color(0xFFaab4d8);
  static const gold = Color(0xFFFFD24A);
  static const star = Color(0xFFFFDE6A);
}

/// Inter değişken font ağırlık yardımcısı (wght ekseni 100-900).
FontVariation interVariation(FontWeight w) => FontVariation('wght', w.value.toDouble());

/// Uygulama teması: koyu zemin, Inter, glow vurgular.
class AppTheme {
  static ThemeData build() {
    const base = ColorScheme.dark(
      primary: NeonPalette.cyan,
      secondary: NeonPalette.magenta,
      surface: NeonPalette.ink,
      onPrimary: NeonPalette.ink,
      onSurface: NeonPalette.text,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: NeonPalette.ink,
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 2, color: NeonPalette.text),
        displayMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: NeonPalette.text),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: NeonPalette.text),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: NeonPalette.text),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: NeonPalette.text),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: NeonPalette.textDim),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: NeonPalette.text),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xEE141430),
        contentTextStyle: TextStyle(color: NeonPalette.text, fontFamily: 'Inter'),
      ),
    );
  }
}
