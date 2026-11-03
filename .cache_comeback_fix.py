import pathlib

p = pathlib.Path('lib/game/game_session.dart')
t = p.read_text(encoding='utf-8')

# ---- onWin: kabus hariç ardışık kayıp serisini sıfırla (BLOCKER fix)
old = (
    "    final def = currentDef!;\n"
    "    var stars = starsFor(perfects, def.target);"
)
new = (
    "    final def = currentDef!;\n"
    "    // PB-037 X8 (inceleme BLOCKER fix): kazanç ardışık kayıp serisini sıfırlar\n"
    "    if (!state.lastLossStreak.isNaN) state.lastLossStreak = 0;\n"
    "    var stars = starsFor(perfects, def.target);"
)
assert old in t, 'onWin anchor'
t = t.replace(old, new, 1)

# ---- onLose: kabus hariç seriyi artır; 2. ardışıkta comeback boost bayrağı
old = (
    "    final rw =\n"
    "        prog.completeLevel(state, def, blocks: blocks, perfects: perfects, reached: false);\n"
    "    if (doubleCoinsThisLevel) {"
)
new = (
    "    // PB-037 X8 (inceleme BLOCKER fix): ardışık kayıp sayacı + comeback bayrağı\n"
    "    state.lastLossStreak += 1;\n"
    "    if (state.lastLossStreak >= 2) pendingComebackBoost = true;\n"
    "    final rw =\n"
    "        prog.completeLevel(state, def, blocks: blocks, perfects: perfects, reached: false);\n"
    "    if (doubleCoinsThisLevel) {"
)
assert old in t, 'onLose anchor'
t = t.replace(old, new, 1)
p.write_text(t, encoding='utf-8')
print('comeback lifecycle ok')

# ---- flow_overlays: rozet eşiği 2. ardışık kayıp (tasarımla tutarlı)
p = pathlib.Path('lib/screens/flow_overlays.dart')
t = p.read_text(encoding='utf-8')
t = t.replace(
    "    final comebackEligible = lostNormal && s.state.lastLossStreak >= 1;",
    "    final comebackEligible = lostNormal && s.state.lastLossStreak >= 2;"
)
p.write_text(t, encoding='utf-8')
print('badge threshold ok')

# ---- MINOR: glint her zaman (ateş modunda güçlü, değilse zarif)
p = pathlib.Path('lib/game/scene_painter.dart')
t = p.read_text(encoding='utf-8')
old = (
    "    // ateş modunda glint — köşede parıltı pırıltısı (PB-036)\n"
    "    if (e.fireMode && w > 30 * e.scale) {\n"
    "      final gx = x + w * (0.2 + 0.6 * ((e.time * 2.2) % 1.0));\n"
    "      final gy = y + h * 0.28;\n"
    "      canvas.drawCircle(\n"
    "        Offset(gx, gy),\n"
    "        2.2 * e.scale,\n"
    "        Paint()\n"
    "          ..color = Colors.white.withValues(alpha: 0.85)\n"
    "          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * e.scale),\n"
    "      );\n"
    "    }"
)
new = (
    "    // PB-037 (blok raporu): süpüren glint HER ZAMAN — ateş modunda güçlü\n"
    "    if (w > 30 * e.scale) {\n"
    "      final gx = x + w * (0.2 + 0.6 * ((e.time * 2.2) % 1.0));\n"
    "      final gy = y + h * 0.28;\n"
    "      final ga = e.fireMode ? 0.85 : 0.38; // ateş modunda parlak, değilse zarif\n"
    "      canvas.drawCircle(\n"
    "        Offset(gx, gy),\n"
    "        (e.fireMode ? 2.2 : 1.6) * e.scale,\n"
    "        Paint()\n"
    "          ..color = Colors.white.withValues(alpha: ga)\n"
    "          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * e.scale),\n"
    "      );\n"
    "    }"
)
assert old in t, 'glint anchor'
t = t.replace(old, new, 1)
p.write_text(t, encoding='utf-8')
print('glint always ok')

# ---- MINOR: map alt butonları viewPadding'e bağla
p = pathlib.Path('lib/screens/map_screen.dart')
t = p.read_text(encoding='utf-8')
t = t.replace("""              // tur 9 taşma düzeltmesi: nav-bar üstü güvenli boşluk
              bottom: 44,""",
"""              // tur 9 taşma düzeltmesi: nav-bar payı viewPadding'den
              bottom: MediaQuery.of(context).padding.bottom + 16,""")
p.write_text(t, encoding='utf-8')
print('bottom viewPadding ok')
