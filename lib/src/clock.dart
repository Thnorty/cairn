import 'package:timezone/timezone.dart' as tz;

import 'models/local_date.dart';

/// Source of "now" and "today" for all domain logic.
///
/// Domain code must never call `DateTime.now()` directly — it goes through a
/// [Clock] so tests can pin the date and simulate non-UTC timezones. The day
/// boundary is local midnight in whatever zone the clock represents.
abstract class Clock {
  /// Today's calendar date in the user's local timezone.
  LocalDate today();

  /// Current instant as epoch milliseconds (for created_at/updated_at).
  int nowEpochMillis();
}

/// Production clock: the device's local timezone.
class SystemClock implements Clock {
  const SystemClock();

  @override
  LocalDate today() => LocalDate.of(DateTime.now());

  @override
  int nowEpochMillis() => DateTime.now().millisecondsSinceEpoch;
}

/// Test clock pinned to a fixed date.
class FixedClock implements Clock {
  final LocalDate _today;
  final int _nowMillis;

  FixedClock(this._today, {int? nowMillis})
      : _nowMillis =
            nowMillis ?? _today.toUtcMidnight().millisecondsSinceEpoch;

  @override
  LocalDate today() => _today;

  @override
  int nowEpochMillis() => _nowMillis;
}

/// Clock that interprets a UTC instant in an explicit IANA timezone.
///
/// Used in tests to prove that day boundaries follow local time: the same UTC
/// instant yields different `today()` values in different zones.
class ZonedClock implements Clock {
  final tz.Location location;
  final DateTime Function() _nowUtc;

  ZonedClock(this.location, {DateTime Function()? nowUtc})
      : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  @override
  LocalDate today() => LocalDate.of(tz.TZDateTime.from(_nowUtc(), location));

  @override
  int nowEpochMillis() => _nowUtc().millisecondsSinceEpoch;
}
