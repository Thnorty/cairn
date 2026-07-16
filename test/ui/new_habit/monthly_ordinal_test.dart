import 'package:cairn/src/ui/new_habit/monthly_ordinal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('englishOrdinal', () {
    test('1st/2nd/3rd/4th', () {
      expect(englishOrdinal(1), '1st');
      expect(englishOrdinal(2), '2nd');
      expect(englishOrdinal(3), '3rd');
      expect(englishOrdinal(4), '4th');
    });

    test('5th..9th all use "th"', () {
      for (var n = 5; n <= 9; n++) {
        expect(englishOrdinal(n), '${n}th');
      }
    });

    test('11th/12th/13th are "th" even though they end in 1/2/3', () {
      expect(englishOrdinal(11), '11th');
      expect(englishOrdinal(12), '12th');
      expect(englishOrdinal(13), '13th');
    });

    test('21st/22nd/23rd resume the normal suffix pattern', () {
      expect(englishOrdinal(21), '21st');
      expect(englishOrdinal(22), '22nd');
      expect(englishOrdinal(23), '23rd');
    });

    test('31st (the day-of-month grid\'s highest value)', () {
      expect(englishOrdinal(31), '31st');
    });
  });
}
