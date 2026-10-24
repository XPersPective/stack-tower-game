import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stack_tower_game/main.dart';
import 'package:stack_tower_game/theme/tokens.dart';

void main() {
  testWidgets('Placeholder menü STACK TOWER başlığını Inter ile gösterir', (tester) async {
    await tester.pumpWidget(const StackTowerApp());

    expect(find.text('STACK TOWER'), findsOneWidget);
    expect(find.text('G A M E'), findsOneWidget);
  });

  test('Tema tokenları: 10 dünya, levels.js THEMES ile birebir', () {
    expect(kThemes.length, 10);
    expect(kThemes[0].id, 'sehir');
    expect(kThemes[0].name, 'NEON ŞEHİR');
    expect(kThemes[0].hues, [210, 268, 322]);
    expect(kThemes[0].glow, 268);
    expect(kThemes[0].weather, 'stars');
    expect(kThemes[0].silhouette, 'city');
    expect(kThemes[9].id, 'zirve');
    expect(kThemes[9].name, 'SON KULE · ZİRVE');
    expect(kThemes[9].glow, 340);
    // bg renkleri hex birebir
    expect(kThemes[0].bg1, const Color(0xFF0c0a20));
    expect(kThemes[0].bg2, const Color(0xFF1e1046));
    expect(kThemes[4].bg1, const Color(0xFF08041a));
  });
}
