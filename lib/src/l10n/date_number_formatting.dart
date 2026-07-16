/// Locale-aware date/number formatting helpers for the designs in `design/`.
///
/// The designs hand-build strings like "Wednesday · Jul 11" and "1,100 m".
/// Those must never be assembled from hardcoded month/weekday names or manual
/// comma insertion: this file is the one place that talks to `intl`'s
/// [DateFormat]/[NumberFormat] for those specific shapes, so screens call
/// these helpers instead of re-deriving the formatting themselves.
///
/// [DateFormat]'s named constructors (`EEEE`, `MMMd`, `jm`, ...) require a
/// locale's date symbol data to already be loaded, or they throw
/// `LocaleDataException`. In the running app this happens for free: including
/// `GlobalMaterialLocalizations.delegate` in `MaterialApp.localizationsDelegates`
/// (via `AppLocalizations.localizationsDelegates` in `main.dart`) loads it as
/// a side effect while the widget tree resolves its locale, before any screen
/// can call these helpers. Code that calls these helpers with no widget tree
/// above it (a background isolate, a pure Dart script, or a unit test) must
/// call `initializeDateFormatting(localeTag)` itself first -- see
/// `test/date_number_formatting_test.dart`'s `setUpAll` for the pattern.
library;

import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/intl.dart';

import '../models/local_date.dart';

/// Formats [date] as the uppercase "weekday · short month + day" header used
/// at the top of the Home screen, e.g. "WEDNESDAY · JUL 11" for `en`.
///
/// The result is already uppercased for display. This is one of the few
/// places in the app where runtime case conversion is genuinely unavoidable
/// (the underlying weekday/month names come from `intl`'s locale data, not
/// from a translated ARB string we could pre-uppercase by hand), so it goes
/// through [localeAwareToUpperCase] rather than the bare [String.toUpperCase]
/// -- see that function's doc comment for why the distinction matters.
String formatWeekdayMonthDayHeader(LocalDate date, Locale locale) {
  final localeTag = locale.toLanguageTag();
  // LocalDate has no time-of-day/zone component; DateTime(y, m, d) here is
  // used purely to hand y/m/d to intl for weekday/month-name lookup, not for
  // any calendar arithmetic (which must stay on LocalDate, per CLAUDE.md).
  final dt = DateTime(date.year, date.month, date.day);
  final weekday = DateFormat.EEEE(localeTag).format(dt);
  final monthDay = DateFormat.MMMd(localeTag).format(dt);
  return localeAwareToUpperCase('$weekday · $monthDay', locale);
}

/// Narrow single-letter weekday symbol for [isoWeekday] (1=Mon..7=Sun),
/// e.g. "S" for Sunday in `en`. Used by the New Habit screen's day-of-week
/// picker circles (`Cairn New Habit.dc.html`'s "S M T W T F S" row and
/// `Cairn New Habit - Monthly 3rd Weekday.dc.html`'s "M T W T F S S" row).
///
/// `DateFormat.dateSymbols.NARROWWEEKDAYS` is indexed Sunday-first (`[0]` =
/// Sunday .. `[6]` = Saturday) regardless of locale - the same convention
/// `intl` uses internally for its own weekday lookups (see its
/// `symbols.STANDALONENARROWWEEKDAYS[date.weekday % 7]` usage), which is
/// why `isoWeekday % 7` (not `isoWeekday - 1`) is the correct index here:
/// Dart's ISO weekday numbering (1=Mon..7=Sun) puts Sunday at 7, and
/// `7 % 7 == 0` lines up with NARROWWEEKDAYS' own Sunday-first index 0.
String narrowWeekdayLabel(int isoWeekday, Locale locale) {
  final symbols = DateFormat(null, locale.toLanguageTag()).dateSymbols;
  return symbols.NARROWWEEKDAYS[isoWeekday % 7];
}

/// Full weekday name for [isoWeekday] (1=Mon..7=Sun), e.g. "Friday" for
/// `en`. Used by the New Habit screen's monthly nth-weekday mode toggle
/// label ("On the 3rd Friday").
///
/// January 1st 2024 is a Monday, so `DateTime.utc(2024, 1, isoWeekday)` for
/// `isoWeekday` 1..7 lands on Monday..Sunday respectively - purely a way to
/// hand intl a real `DateTime` whose weekday matches [isoWeekday] for name
/// lookup, the same trick [formatWeekdayMonthDayHeader] uses below, not a
/// calendar computation (LocalDate is not involved because there is no
/// specific calendar date here, only an abstract weekday number).
String weekdayFullName(int isoWeekday, Locale locale) {
  final dt = DateTime.utc(2024, 1, isoWeekday);
  return DateFormat.EEEE(locale.toLanguageTag()).format(dt);
}

/// Formats [date] as an abbreviated "weekday, month day" (e.g. "Sat, Jul
/// 19" for `en`), used by the New Habit screen's Once date-picker row
/// (`Cairn New Habit - Once.dc.html`). Distinct from
/// [formatWeekdayMonthDayHeader] (Home's full-weekday, uppercased, `·`-
/// separated header): this one is mixed-case with a comma separator and an
/// abbreviated weekday, matching that screen's own copy exactly.
String formatShortWeekdayMonthDay(LocalDate date, Locale locale) {
  final localeTag = locale.toLanguageTag();
  final dt = DateTime(date.year, date.month, date.day);
  final weekday = DateFormat.E(localeTag).format(dt);
  final monthDay = DateFormat.MMMd(localeTag).format(dt);
  return '$weekday, $monthDay';
}

/// Formats [date] as an abbreviated "month day" with no weekday (e.g.
/// "Apr 2" for `en`), used by the Trail screen's trailhead caption ("The
/// trailhead · Apr 2" in `Cairn Trail.dc.html`). Distinct from
/// [formatShortWeekdayMonthDay] (which also prepends the abbreviated
/// weekday): the Trail trailhead caption's canonical design omits the
/// weekday entirely.
String formatShortMonthDay(LocalDate date, Locale locale) {
  final localeTag = locale.toLanguageTag();
  final dt = DateTime(date.year, date.month, date.day);
  return DateFormat.MMMd(localeTag).format(dt);
}

/// Formats a short time-of-day (e.g. "7:14 AM" for `en`) for the `time`
/// placeholders used throughout the verification-flow ARB messages
/// (`verifiedAt`, `scheduledAt`, `taskNameAtTime`, ...). Callers pass the
/// already-formatted result in as a plain String placeholder rather than
/// letting a message's placeholder type imply its own formatting, so the
/// formatting logic lives in exactly one place.
String formatTimeOfDay(DateTime dateTime, Locale locale) {
  return DateFormat.jm(locale.toLanguageTag()).format(dateTime);
}

/// Formats [metres] with the locale's thousands separator, e.g. "1,100" for
/// `en`. Never build this by hand (manual comma insertion breaks for locales
/// that group or separate digits differently). The result is a bare number;
/// callers combine it with the localized " m" / "m held" / etc. wording via
/// the relevant ARB message (e.g. `AppLocalizations.heldMetresLabel`).
String formatMetresNumber(int metres, Locale locale) {
  return NumberFormat.decimalPattern(locale.toLanguageTag()).format(metres);
}

/// Uppercases [input] correctly for [locale].
///
/// `String.toUpperCase()` uses Dart's locale-*invariant* default Unicode
/// case mapping, which maps lowercase 'i' to 'I'. Turkish (and Azerbaijani)
/// case-fold 'i' to the dotted 'İ' (U+0130) instead, and dotless 'ı' (U+0131)
/// to plain 'I' -- the reverse of what every other Latin-script locale does.
/// Calling `.toUpperCase()` on Turkish text (or on a date formatted with
/// Turkish month/weekday names) silently produces the wrong capital letter.
///
/// This is why static uppercase UI labels are stored pre-uppercased in the
/// ARB files instead of uppercased at runtime -- see `todaySectionLabel` and
/// `provingLabel` in `lib/l10n/app_en.arb`. This function exists only for the
/// few spots where the text being uppercased is generated at runtime (dates)
/// and pre-storing isn't possible, so the locale must be threaded through
/// explicitly instead. Do not replace calls to this with a bare
/// `.toUpperCase()` "simplification" -- that reintroduces the Turkish bug.
String localeAwareToUpperCase(String input, Locale locale) {
  if (locale.languageCode == 'tr' || locale.languageCode == 'az') {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune == 0x0069) {
        // 'i' -> 'İ' (LATIN CAPITAL LETTER I WITH DOT ABOVE)
        buffer.writeCharCode(0x0130);
      } else if (rune == 0x0131) {
        // 'ı' -> 'I' (plain capital I)
        buffer.writeCharCode(0x0049);
      } else {
        buffer.write(String.fromCharCode(rune).toUpperCase());
      }
    }
    return buffer.toString();
  }
  return input.toUpperCase();
}
