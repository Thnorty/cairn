import 'package:cairn/src/models/stone_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StoneStyle.fromStored', () {
    test('a null value falls back to river', () {
      expect(StoneStyle.fromStored(null), StoneStyle.river);
    });

    test('an empty string falls back to river', () {
      expect(StoneStyle.fromStored(''), StoneStyle.river);
    });

    test('an unrecognised value falls back to river rather than throwing', () {
      expect(StoneStyle.fromStored('marble'), StoneStyle.river);
    });

    test('each known enum name round-trips back to itself', () {
      for (final style in StoneStyle.values) {
        expect(StoneStyle.fromStored(style.toStored), style);
      }
    });
  });

  group('requiresPremium', () {
    test('river is the only style that does not require premium', () {
      expect(StoneStyle.river.requiresPremium, isFalse);
      expect(StoneStyle.granite.requiresPremium, isTrue);
      expect(StoneStyle.slate.requiresPremium, isTrue);
      expect(StoneStyle.basalt.requiresPremium, isTrue);
    });
  });
}
