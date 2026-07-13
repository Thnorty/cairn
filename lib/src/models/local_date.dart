/// A pure calendar date (no time, no timezone).
///
/// All domain logic (occurrence dates, streaks, day boundaries) operates on
/// the user's *local* calendar date. This type exists so that logic can never
/// accidentally pick up a UTC date or a DST-shifted time component.
class LocalDate implements Comparable<LocalDate> {
  final int year;
  final int month;
  final int day;

  const LocalDate(this.year, this.month, this.day);

  /// The calendar date of [dt] as seen in [dt]'s own zone (its year/month/day
  /// components). Pass a local-time `DateTime` to get the local date.
  factory LocalDate.of(DateTime dt) => LocalDate(dt.year, dt.month, dt.day);

  /// Parses `yyyy-MM-dd`.
  factory LocalDate.parse(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) {
      throw FormatException('Expected yyyy-MM-dd, got "$iso"');
    }
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// This date at midnight UTC. Used to talk to the `rrule` package (which
  /// requires UTC-flagged `DateTime`s) and for calendar arithmetic: UTC has
  /// no DST transitions, so day arithmetic is always exact 24-hour steps.
  DateTime toUtcMidnight() => DateTime.utc(year, month, day);

  /// ISO weekday: 1 = Monday .. 7 = Sunday.
  int get weekday => toUtcMidnight().weekday;

  LocalDate addDays(int days) {
    final d = DateTime.utc(year, month, day + days);
    return LocalDate(d.year, d.month, d.day);
  }

  static int lastDayOfMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;
  bool operator <=(LocalDate other) => compareTo(other) <= 0;
  bool operator >=(LocalDate other) => compareTo(other) >= 0;

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  String toString() => toIso();

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  static LocalDate max(LocalDate a, LocalDate b) => a.isAfter(b) ? a : b;
  static LocalDate min(LocalDate a, LocalDate b) => a.isBefore(b) ? a : b;
}

/// An inclusive range of local dates.
class DateRange {
  final LocalDate start;
  final LocalDate end;

  const DateRange(this.start, this.end);

  bool contains(LocalDate date) => start <= date && date <= end;

  @override
  String toString() => '[$start..$end]';
}
