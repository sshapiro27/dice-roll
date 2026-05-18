import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stone_dice/main.dart';
import 'package:stone_dice/models/die.dart';

void main() {
  test('every die type rolls within its valid range', () {
    final dice = Dice();
    for (final type in DieType.values) {
      for (var i = 0; i < 2000; i++) {
        final r = dice.roll(type);
        expect(r.value, inInclusiveRange(1, type.sides));
      }
    }
  });

  test('d100 composes two d10s and maps 00+0 to 100', () {
    final dice = Dice();
    var saw100 = false;
    for (var i = 0; i < 5000; i++) {
      final r = dice.roll(DieType.d100);
      expect(r.tens, inInclusiveRange(0, 9));
      expect(r.units, inInclusiveRange(0, 9));
      final raw = r.tens! * 10 + r.units!;
      expect(r.value, raw == 0 ? 100 : raw);
      if (r.value == 100) saw100 = true;
    }
    expect(saw100, isTrue);
  });

  testWidgets('app builds and shows the roll prompt', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const StoneDiceApp());
    await tester.pump();
    expect(find.text('STONE DICE'), findsOneWidget);
    expect(find.textContaining('tap, press space'), findsOneWidget);
  });
}
