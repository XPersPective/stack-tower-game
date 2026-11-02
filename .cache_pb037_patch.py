import pathlib

# ============ PB-037 dalga 1: tur 9/10 şikâyetlerinin düzeltmeleri ============

# ---- 1) journey_map: teaser kapıları → ufuk ışık sütunu (kemer yok)
p = pathlib.Path('lib/map/journey_map.dart')
t = p.read_text(encoding='utf-8')
old = (
    "      final pulse = 0.5 + 0.5 * math.sin(time * 1.2 + s * 1.9);\n"
    "      final cx = size.width / 2;\n"
    "      final arch = Path()\n"
    "        ..moveTo(cx - 120, gy + 60)\n"
    "        ..lineTo(cx - 120, gy - 20)\n"
    "        ..quadraticBezierTo(cx, gy - 120, cx + 120, gy - 20)\n"
    "        ..lineTo(cx + 120, gy + 60);\n"
    "      // sisli kemer — mor gri, nabızlı\n"
    "      canvas.drawPath(\n"
    "        arch,\n"
    "        Paint()\n"
    "          ..color = Colors.white.withValues(alpha: 0.16 + 0.14 * pulse)\n"
    "          ..style = PaintingStyle.stroke\n"
    "          ..strokeWidth = 6\n"
    "          ..strokeCap = StrokeCap.round\n"
    "          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),\n"
    "      );\n"
    "      // ağır sis: kemer içini örten bulutlar (içerik sızmaz)\n"
    "      canvas.drawOval(\n"
    "        Rect.fromCenter(center: Offset(cx, gy - 10), width: 210, height: 110),\n"
    "        Paint()\n"
    "          ..color = const Color(0xFF0A0A1E).withValues(alpha: 0.72)\n"
    "          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),\n"
    "      );"
)
new = (
    "      // PB-037 (harita raporu): kemer KALDIRILDI — ufuk ışık sütunu:\n"
    "      // yukarı doğru yükselen, nabızlayan sisli ışık (içerik sızmaz)\n"
    "      final pulse = 0.5 + 0.5 * math.sin(time * 1.2 + s * 1.9);\n"
    "      final cx = size.width / 2;\n"
    "      final beam = Rect.fromLTWH(cx - 90, gy - 190, 180, 250);\n"
    "      canvas.drawRect(\n"
    "        beam,\n"
    "        Paint()\n"
    "          ..shader = LinearGradient(\n"
    "            begin: Alignment.bottomCenter,\n"
    "            end: Alignment.topCenter,\n"
    "            colors: [\n"
    "              hslColor(268, 70, 34).withValues(alpha: 0.20 + 0.10 * pulse),\n"
    "              hslColor(268, 70, 34).withValues(alpha: 0),\n"
    "            ],\n"
    "          ).createShader(beam),\n"
    "      );\n"
    "      // segment girişinde yıldız tozları — yol buradan ufka uzanır\n"
    "      final rnd = math.Random(900 + s);\n"
    "      for (var d = 0; d < 14; d++) {\n"
    "        final dx = cx + (rnd.nextDouble() - 0.5) * 260;\n"
    "        final dy = gy + 60 - rnd.nextDouble() * 200;\n"
    "        final dd = rnd.nextDouble();\n"
    "        canvas.drawCircle(\n"
    "          Offset(dx, dy),\n"
    "          0.8 + dd * 1.6,\n"
    "          Paint()\n"
    "            ..color = Colors.white\n"
    "                .withValues(alpha: (0.12 + 0.30 * pulse) * (1 - dd * 0.6)),\n"
    "        );\n"
    "      }"
)
assert old in t, 'gate anchor'
t = t.replace(old, new, 1)

# ---- 2) düğüm kenar ışıltısı: dış kontur boyunca dönen 2 parıltı burnu
old2 = (
    "      // çift kontur: yumuşak dış + keskin iç\n"
    "      canvas.drawCircle(\n"
    "        p,\n"
    "        r * 1.1,\n"
    "        Paint()\n"
    "          ..color = glow.withValues(alpha: 0.25)\n"
    "          ..style = PaintingStyle.stroke\n"
    "          ..strokeWidth = 4,\n"
    "      );\n"
    "      canvas.drawCircle(\n"
    "        p,\n"
    "        r,\n"
    "        Paint()\n"
    "          ..color = glow\n"
    "          ..style = PaintingStyle.stroke\n"
    "          ..strokeWidth = 2.6,\n"
    "      );\n"
    "      _paintKindGlyph(canvas, n.def.kind, p, glow);"
)
new2 = (
    "      // çift kontur: yumuşak dış + keskin iç\n"
    "      canvas.drawCircle(\n"
    "        p,\n"
    "        r * 1.1,\n"
    "        Paint()\n"
    "          ..color = glow.withValues(alpha: 0.25)\n"
    "          ..style = PaintingStyle.stroke\n"
    "          ..strokeWidth = 4,\n"
    "      );\n"
    "      canvas.drawCircle(\n"
    "        p,\n"
    "        r,\n"
    "        Paint()\n"
    "          ..color = glow\n"
    "          ..style = PaintingStyle.stroke\n"
    "          ..strokeWidth = 2.6,\n"
    "      );\n"
    "      // PB-037: kenar ışıltısı — kontur üzerinde dönen 2 parıltı burnu\n"
    "      for (var gIdx = 0; gIdx < 2; gIdx++) {\n"
    "        final ga = time * 1.8 + gIdx * math.pi + n.i * 0.5;\n"
    "        final gp = Offset(\n"
    "            p.dx + math.cos(ga) * r * 1.1, p.dy + math.sin(ga) * r * 1.1);\n"
    "        canvas.drawCircle(\n"
    "          gp,\n"
    "          3.2,\n"
    "          Paint()\n"
    "            ..color = Colors.white.withValues(alpha: 0.9)\n"
    "            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),\n"
    "        );\n"
    "      }\n"
    "      _paintKindGlyph(canvas, n.def.kind, p, glow);"
)
assert old2 in t, 'node anchor'
t = t.replace(old2, new2, 1)

# ---- 3) yıldız parlaması: paralaks yıldızlara çapraz ışın (parlak olanlar)
old3 = (
    "      final tw = 0.3 + 0.5 * (0.5 + 0.5 * math.sin(time * (0.4 + rnd.nextDouble()) + i));\n"
    "      canvas.drawCircle(\n"
    "        Offset(sx, yy),\n"
    "        0.5 + rnd.nextDouble() * 1.5,\n"
    "        Paint()..color = Colors.white.withValues(alpha: tw * 0.55),\n"
    "      );\n"
    "    }\n"
    "  }"
)
new3 = (
    "      final tw = 0.3 + 0.5 * (0.5 + 0.5 * math.sin(time * (0.4 + rnd.nextDouble()) + i));\n"
    "      final rr = 0.5 + rnd.nextDouble() * 1.5;\n"
    "      canvas.drawCircle(\n"
    "        Offset(sx, yy),\n"
    "        rr,\n"
    "        Paint()..color = Colors.white.withValues(alpha: tw * 0.55),\n"
    "      );\n"
    "      // PB-037: parlak yıldızlara çapraz ışın (twinkle hissi)\n"
    "      if (rr > 1.6 && tw > 0.7) {\n"
    "        final ray = Paint()..color = Colors.white.withValues(alpha: tw * 0.5);\n"
    "        canvas.drawRect(Rect.fromLTWH(sx - rr * 3, yy - 0.5, rr * 6, 1), ray);\n"
    "        canvas.drawRect(Rect.fromLTWH(sx - 0.5, yy - rr * 3, 1, rr * 6), ray);\n"
    "      }\n"
    "    }\n"
    "  }"
)
assert old3 in t, 'star anchor'
t = t.replace(old3, new3, 1)
p.write_text(t, encoding='utf-8')
print('journey map PB-037 patch ok')

# ---- 4) map_screen: KABUS gate büyüt + yazı kayması düzelt
p2 = pathlib.Path('lib/screens/map_screen.dart')
t2 = p2.read_text(encoding='utf-8')
t2 = t2.replace("        icon: Icons.dark_mode_rounded,\n        expand: true,\n        height: 42,",
                "        icon: Icons.dark_mode_rounded,\n        expand: true,\n        height: 54,")
t2 = t2.replace("""        label: active
            ? 'KABUS KULESİ · $left HAK'
            : 'KABUS BU HAFTA BİTTİ · REKOR $best',""",
"""        label: active ? 'KABUS KULESİ · $left HAK' : 'KABUS BU HAFTA BİTTİ',""")
p2.write_text(t2, encoding='utf-8')
print('gate fixed')
