import 'package:cairn/src/l10n/date_number_formatting.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';

void main() {
  // DateFormat's named constructors (EEEE, MMMd, jm, ...) need a locale's
  // date symbol data loaded before first use, or they throw
  // LocaleDataException. In a running app this happens as a side effect of
  // GlobalMaterialLocalizations.delegate.load() when the widget tree
  // resolves its locale (see main.dart's localizationsDelegates); these
  // tests call the formatting helpers directly with no widget tree, so they
  // need the same one-time setup themselves.
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  group('formatWeekdayMonthDayHeader', () {
    test('formats and uppercases a weekday + short month/day for en', () {
      // 2024-01-01 was a Monday.
      final header = formatWeekdayMonthDayHeader(
        d(2024, 1, 1),
        const Locale('en'),
      );
      expect(header, 'MONDAY · JAN 1');
    });

    test('never hand-builds the separator or casing from raw components', () {
      // A second, different date to guard against a hardcoded return value.
      final header = formatWeekdayMonthDayHeader(
        d(2026, 7, 15),
        const Locale('en'),
      );
      expect(header, 'WEDNESDAY · JUL 15');
    });
  });

  group('formatTimeOfDay', () {
    // intl's current CLDR data separates the time from the AM/PM marker with
    // a narrow no-break space (U+202F), not a plain ASCII space -- another
    // reason to always go through intl rather than hand-building "$h:$m AM".
    const narrowNoBreakSpace = ' ';

    test('formats a short 12-hour time for en', () {
      final time = formatTimeOfDay(
        DateTime(2026, 7, 15, 7, 14),
        const Locale('en'),
      );
      expect(time, '7:14${narrowNoBreakSpace}AM');
    });

    test('formats a PM time for en', () {
      final time = formatTimeOfDay(
        DateTime(2026, 7, 15, 20, 0),
        const Locale('en'),
      );
      expect(time, '8:00${narrowNoBreakSpace}PM');
    });
  });

  group('formatMetresNumber', () {
    test('adds thousands separators for en', () {
      expect(formatMetresNumber(1100, const Locale('en')), '1,100');
      expect(formatMetresNumber(8849, const Locale('en')), '8,849');
    });

    test('does not add a separator below 1000', () {
      expect(formatMetresNumber(26, const Locale('en')), '26');
      expect(formatMetresNumber(0, const Locale('en')), '0');
    });
  });

  group('narrowWeekdayLabel', () {
    test('returns the Sunday-first-indexed narrow symbol for en', () {
      // 1=Mon..7=Sun per this app's ISO weekday convention.
      expect(narrowWeekdayLabel(1, const Locale('en')), 'M');
      expect(narrowWeekdayLabel(2, const Locale('en')), 'T');
      expect(narrowWeekdayLabel(3, const Locale('en')), 'W');
      expect(narrowWeekdayLabel(4, const Locale('en')), 'T');
      expect(narrowWeekdayLabel(5, const Locale('en')), 'F');
      expect(narrowWeekdayLabel(6, const Locale('en')), 'S');
      expect(narrowWeekdayLabel(7, const Locale('en')), 'S');
    });
  });

  group('weekdayFullName', () {
    test('returns the full weekday name for each ISO weekday for en', () {
      expect(weekdayFullName(1, const Locale('en')), 'Monday');
      expect(weekdayFullName(5, const Locale('en')), 'Friday');
      expect(weekdayFullName(7, const Locale('en')), 'Sunday');
    });
  });

  group('formatShortWeekdayMonthDay', () {
    test('formats an abbreviated weekday + month/day for en', () {
      // 2026-07-15 is a Wednesday (see formatWeekdayMonthDayHeader's own
      // fixture above); 2026-07-18 is therefore a Saturday.
      expect(
        formatShortWeekdayMonthDay(d(2026, 7, 18), const Locale('en')),
        'Sat, Jul 18',
      );
    });
  });

  group('localeAwareToUpperCase (the Turkish dotted/dotless-i trap)', () {
    test('uppercases a plain "i" as a regular "I" for en', () {
      expect(localeAwareToUpperCase('istanbul', const Locale('en')), 'ISTANBUL');
    });

    test('uppercases a plain "i" as dotted "İ" for tr, not "I"', () {
      final result = localeAwareToUpperCase('istanbul', const Locale('tr'));
      expect(result, 'İSTANBUL');
      // Guard against the exact bug this function exists to avoid: Dart's
      // bare String.toUpperCase() would produce "ISTANBUL" here instead.
      expect(result, isNot('ISTANBUL'));
    });

    test('uppercases dotless "ı" as plain "I" for tr', () {
      expect(localeAwareToUpperCase('kısa', const Locale('tr')), 'KISA');
    });
  });
}
