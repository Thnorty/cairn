/// English ordinal-suffix formatting for the New Habit screen's monthly
/// controls (the monthly-mode toggle's day-of-month summary, and the
/// "Which week" 1st/2nd/3rd/4th chips).
///
/// Deliberately English-only: the `intl` package exposes no public
/// ordinal-number API (ICU's `selectordinal` exists for exactly this, but
/// `intl` only uses it internally for date parsing, not as something a
/// caller can invoke), and this app currently ships a single "en" locale
/// (see `l10n.yaml`'s one `app_en.arb` template). Most languages don't even
/// form ordinals with a numeric suffix the way English does, so if a
/// second locale is ever added this must become a real per-locale
/// implementation (or an ARB `selectordinal` message, if `flutter
/// gen-l10n` ever supports one) rather than generalized in place.
String englishOrdinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}
