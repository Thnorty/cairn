import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLocalizations', () {
    test('resolves for the en locale', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l10n, isA<AppLocalizations>());
      expect(l10n.localeName, 'en');
    });

    test('delegate reports en as supported and other locales as unsupported', () {
      expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
      expect(AppLocalizations.delegate.isSupported(const Locale('tr')), isFalse);
    });

    test('returns expected static strings', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l10n.appTitle, 'Cairn');
      expect(l10n.navToday, 'Today');
      expect(l10n.proveItButton, 'Prove it');
      expect(l10n.emptyTodayTitle, 'Your first stone is waiting');
    });

    test('returns expected placeholder substitution', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l10n.goodMorningGreeting('Sam'), 'Good morning, Sam');
      expect(l10n.verifiedAt('7:14 AM'), 'Verified · 7:14 AM');
    });

    test('resolves the ICU plural "other" form at count 2', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l10n.stonesThisWeek(2), '2 stones this week');
      expect(l10n.triesLeftToday(2), '2 tries left today');
    });

    test('resolves the ICU plural "one" form at count 1', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l10n.stonesThisWeek(1), '1 stone this week');
      expect(l10n.triesLeftToday(1), '1 try left today');
    });

    test('resolves a plural nested inside a longer composed message', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        l10n.taskSummaryVerifiedNewStone(2, 1),
        'Cairn 2 · 1 stone · new stone placed',
      );
      expect(
        l10n.taskSummaryVerifiedNewStone(2, 9),
        'Cairn 2 · 9 stones · new stone placed',
      );
    });
  });
}
