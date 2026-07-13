import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/local_date.dart';

part 'database.g.dart';

/// How a task repeats. Stored as TEXT: once | daily | weekly | monthly.
enum RecurrenceType { once, daily, weekly, monthly }

/// Monthly sub-mode. Stored as TEXT: day_of_month | nth_weekday.
enum MonthlyMode { dayOfMonth, nthWeekday }

/// Where a proof photo came from. Stored as TEXT: camera | gallery.
enum ProofSource { camera, gallery }

/// Gemini verification state. Stored as TEXT: none | pending | verified | rejected.
enum VerificationStatus { none, pending, verified, rejected }

class MonthlyModeConverter extends TypeConverter<MonthlyMode, String> {
  const MonthlyModeConverter();

  @override
  MonthlyMode fromSql(String fromDb) => switch (fromDb) {
        'day_of_month' => MonthlyMode.dayOfMonth,
        'nth_weekday' => MonthlyMode.nthWeekday,
        _ => throw ArgumentError('Unknown monthly_mode: $fromDb'),
      };

  @override
  String toSql(MonthlyMode value) => switch (value) {
        MonthlyMode.dayOfMonth => 'day_of_month',
        MonthlyMode.nthWeekday => 'nth_weekday',
      };
}

class LocalDateConverter extends TypeConverter<LocalDate, String> {
  const LocalDateConverter();

  @override
  LocalDate fromSql(String fromDb) => LocalDate.parse(fromDb);

  @override
  String toSql(LocalDate value) => value.toIso();
}

/// JSON array of ints, e.g. weekly_days `[1,3,5]` (ISO weekdays).
class IntListConverter extends TypeConverter<List<int>, String> {
  const IntListConverter();

  @override
  List<int> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>).cast<int>();

  @override
  String toSql(List<int> value) => jsonEncode(value);
}

/// JSON array of strings, e.g. due_times `["08:00","20:00"]`.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

class Tasks extends Table {
  /// Client-generated UUID v7.
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get recurrenceType => textEnum<RecurrenceType>()();

  /// JSON array of ISO weekday ints (1=Mon..7=Sun); for weekly.
  TextColumn get weeklyDays =>
      text().map(const IntListConverter()).nullable()();

  /// For monthly.
  TextColumn get monthlyMode =>
      text().map(const MonthlyModeConverter()).nullable()();

  /// 1–31; for monthly day_of_month. Clamped to short months at generation.
  IntColumn get monthDay => integer().nullable()();

  /// 1..4, or -1 for "Last"; for monthly nth_weekday.
  IntColumn get monthNth => integer().nullable()();

  /// ISO weekday; for monthly nth_weekday.
  IntColumn get monthWeekday => integer().nullable()();

  /// ISO date; for once.
  TextColumn get dueDate =>
      text().map(const LocalDateConverter()).nullable()();

  /// JSON array of "HH:mm" strings — the task's slots by index.
  /// `[]` = one untimed slot 0.
  TextColumn get dueTimes => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();

  TextColumn get startDate => text().map(const LocalDateConverter())();
  TextColumn get endDate =>
      text().map(const LocalDateConverter()).nullable()();

  /// User-facing archive (hidden, not deleted).
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// Owner (auth.uid()); nullable until the auth phase.
  TextColumn get userId => text().nullable()();

  /// Epoch millis. updated_at drives last-write-wins sync.
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Sync tombstone — rows are never hard-deleted.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Completions extends Table {
  /// Client-generated UUID v7.
  TextColumn get id => text()();
  TextColumn get taskId => text().references(Tasks, #id)();

  /// ISO date in the user's local timezone.
  TextColumn get occurrenceDate => text().map(const LocalDateConverter())();

  /// Index into the task's due_times (0 for untimed/single).
  IntColumn get slot => integer().withDefault(const Constant(0))();

  IntColumn get completedAt => integer()();
  TextColumn get proofPhotoPath => text().nullable()();
  TextColumn get proofSource => textEnum<ProofSource>().nullable()();

  /// From asset metadata (recency check, later phase).
  IntColumn get photoTakenAt => integer().nullable()();
  TextColumn get verificationStatus => textEnum<VerificationStatus>()
      .withDefault(const Constant('none'))();

  /// JSON from Gemini (later phase).
  TextColumn get verificationMeta => text().nullable()();

  /// Metres earned by this completion.
  IntColumn get pointsAwarded => integer().withDefault(const Constant(0))();

  TextColumn get userId => text().nullable()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  /// One proof per slot per day — no double-completing.
  @override
  List<Set<Column>> get uniqueKeys => [
        {taskId, occurrenceDate, slot},
      ];
}

@DriftDatabase(tables: [Tasks, Completions])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Future schema migrations go here, gated on `from`/`to`.
        },
      );
}
