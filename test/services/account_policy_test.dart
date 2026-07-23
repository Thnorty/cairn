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

  group('individual predicates', () {
    test('passwordHasMinLength', () {
      expect(passwordHasMinLength('1234567'), isFalse);
      expect(passwordHasMinLength('12345678'), isTrue);
    });

    test('passwordHasUppercase', () {
      expect(passwordHasUppercase('abc123'), isFalse);
      expect(passwordHasUppercase('aBc123'), isTrue);
    });

    test('passwordHasLowercase', () {
      expect(passwordHasLowercase('ABC123'), isFalse);
      expect(passwordHasLowercase('ABc123'), isTrue);
    });

    test('passwordHasDigit', () {
      expect(passwordHasDigit('Abcdefgh'), isFalse);
      expect(passwordHasDigit('Abcdefg1'), isTrue);
    });
  });
}
