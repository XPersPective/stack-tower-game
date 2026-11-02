import pathlib

p = pathlib.Path('lib/map/journey_map.dart')
t = p.read_text(encoding='utf-8')

# ---- 1) METİN ÖNBELLEĞİ
anchor = "/// Dikey yol haritası painter'ı. [scroll] = alttan kaydırma (0 = başlangıç)."
cache = (
    "/// PB-036 tur 9 KÖK-DÜZELTME: metin önbelleği — kaydırma jankının kök nedeni\n"
    "/// her karede 150+ TextPainter.layout idi. Etiket bir kez layout edilir,\n"
    "/// sonraki karelerde yalnız boyanır (60 fps kaydırma bütçesi).\n"
    "final Map<String, TextPainter> _journeyTextCache = {};\n\n"
    "TextPainter _journeyText(String key, TextSpan span) {\n"
    "  return _journeyTextCache.putIfAbsent(key, () {\n"
    "    final tp = TextPainter(text: span, textDirection: TextDirection.ltr);\n"
    "    tp.layout();\n"
    "    return tp;\n"
    "  });\n"
    "}\n\n" + anchor
)
assert anchor in t, 'anchor1'
t = t.replace(anchor, cache, 1)

# ---- 2) etiket: önbellekli + okunur
old = (
    "    // ışıltılı İSİM etiketi — düğümün altında (kullanıcı tur 6)\n"
    "    final label = TextPainter(\n"
    "      text: TextSpan(\n"
    "        text: n.label,\n"
    "        style: TextStyle(\n"
    "          fontFamily: 'Inter',\n"
    "          fontSize: n.isSpecial ? 11.5 : 10.5,\n"
    "          fontWeight: FontWeight.w800,\n"
    "          letterSpacing: 0.8,\n"
    "          color: n.isSpecial\n"
    "              ? (n.def.modifier == 'patron'\n"
    "                  ? NeonPalette.magenta\n"
    "                  : n.def.box\n"
    "                      ? NeonPalette.gold\n"
    "                      : NeonPalette.amber)\n"
    "              : Colors.white.withValues(alpha: n.done ? 0.75 : 0.55),\n"
    "          shadows: [\n"
    "            Shadow(\n"
    "                color: n.isSpecial\n"
    "                    ? hslColor(45, 95, 60).withValues(alpha: .7)\n"
    "                    : glow.withValues(alpha: .5),\n"
    "                blurRadius: 8),\n"
    "          ],\n"
    "        ),\n"
    "      ),\n"
    "      textDirection: TextDirection.ltr,\n"
    "    )..layout();\n"
    "    label.paint(canvas, Offset(p.dx - label.width / 2, p.dy + r + 4));"
)
new = (
    "    // ışıltılı İSİM etiketi — önbellekli, OKUNUR (tur 9: küçük/soluktu)\n"
    "    final labelColor = n.isSpecial\n"
    "        ? (n.def.modifier == 'patron'\n"
    "            ? NeonPalette.magenta\n"
    "            : n.def.box\n"
    "                ? NeonPalette.gold\n"
    "                : NeonPalette.amber)\n"
    "        : (n.done ? Colors.white : Colors.white.withValues(alpha: 0.85));\n"
    "    final label = _journeyText(\n"
    "      'lbl|' + n.label + '|' + n.isSpecial.toString() + '|' + n.done.toString(),\n"
    "      TextSpan(\n"
    "        text: n.label,\n"
    "        style: TextStyle(\n"
    "          fontFamily: 'Inter',\n"
    "          fontSize: n.isSpecial ? 13.5 : 12,\n"
    "          fontWeight: FontWeight.w900,\n"
    "          letterSpacing: 0.6,\n"
    "          color: labelColor,\n"
    "          shadows: [\n"
    "            Shadow(color: Colors.black.withValues(alpha: .9), blurRadius: 6),\n"
    "            Shadow(\n"
    "                color: n.isSpecial\n"
    "                    ? hslColor(45, 95, 60).withValues(alpha: .85)\n"
    "                    : glow.withValues(alpha: .7),\n"
    "                blurRadius: 10),\n"
    "          ],\n"
    "        ),\n"
    "      ),\n"
    "    );\n"
    "    label.paint(canvas, Offset(p.dx - label.width / 2, p.dy + r + 5));"
)
assert old in t, 'anchor2'
t = t.replace(old, new, 1)
p.write_text(t, encoding='utf-8')
print('part1+2 ok')
