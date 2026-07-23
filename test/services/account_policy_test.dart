import 'package:cairn/src/services/account_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('meetsPasswordPolicy', () {
    test('too short (< 8 chars) fails', () {
      expect(meetsPasswordPolicy('Ab1'), isFalse);
      expect(meetsPasswordPolicy('Abcdef1'), isFalse); // 7 chars
    });

    test('8+ chars but all-lowercase fails', () {
      expect(meetsPasswordPolicy('abcdefgh'), isFalse);
      expect(meetsPasswordPolicy('abcdefg1'), isFalse);
    });

    test('missing a digit fails', () {
      expect(meetsPasswordPolicy('Abcdefgh'), isFalse);
      expect(meetsPasswordPolicy('Password'), isFalse);
    });

    test('missing an uppercase letter fails', () {
      expect(meetsPasswordPolicy('abcdefg1'), isFalse);
      expect(meetsPasswordPolicy('pass1234'), isFalse);
    });

    test('valid password (8+ chars, upper, lower, digit) passes', () {
      expect(meetsPasswordPolicy('Abcdefg1'), isTrue);
      expect(meetsPasswordPolicy('SecureP4ssword!'), isTrue);
    });
  });
}
