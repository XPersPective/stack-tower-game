import pathlib

p = pathlib.Path('lib/screens/flow_overlays.dart')
t = p.read_text(encoding='utf-8')

# ---- X9 result-first: SONRAKİ BÖLÜM (zinciri atlayan jump) → DEVAM
# (meta şölen zincirini sürdürür: inşaat→kutu→dünya→tahta→harita)
old = (
    "              label: 'SONRAKİ BÖLÜM →',\n"
    "              icon: Icons.arrow_forward_rounded,\n"
    "              expand: true,\n"
    "              height: 54,\n"
    "              colors: const [\n"
    "                Color(0xFF2E1E86),\n"
    "                Color(0xFF12407E),\n"
    "                Color(0xFF451C7A),\n"
    "              ],\n"
    "              onTap: () => widget.onNext(levelDef(def.i + 1)),\n"
    "            ),"
)
new = (
    "              label: 'DEVAM',\n"
    "              icon: Icons.arrow_forward_rounded,\n"
    "              expand: true,\n"
    "              height: 54,\n"
    "              colors: const [\n"
    "                Color(0xFF2E1E86),\n"
    "                Color(0xFF12407E),\n"
    "                Color(0xFF451C7A),\n"
    "              ],\n"
    "              // PB-037 X9 result-first: DEVAM meta şölen zincirini\n"
    "              // sürdürür (inşaat→kutu→dünya→tahta→harita) — doruk\n"
    "              // anından düşmeden törenler yaşanır\n"
    "              onTap: _advance,\n"
    "            ),"
)
assert old in t, 'sonraki anchor'
t = t.replace(old, new, 1)
p.write_text(t, encoding='utf-8')
print('result DEVAM done')
