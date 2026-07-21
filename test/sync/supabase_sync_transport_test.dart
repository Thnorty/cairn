import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/local_date.dart';
import 'package:cairn/src/sync/supabase_sync_transport.dart';
import 'package:cairn/src/sync/sync_transport.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every call made through [SyncPostgrest] and, for [selectUpdatedAfter],
/// applies the same `updated_at > cursor` filter a real Postgrest query would
/// apply server-side - close enough to the real thing to exercise
/// [SupabaseSyncTransport.pull]'s cursor logic honestly, without ever
/// touching a network or a real [SupabaseClient].
class _RecordedSelect {
  final String table;
  final int cursor;
  const _RecordedSelect(this.table, this.cursor);
}

class _RecordedUpsert {
  final String table;
  final List<Map<String, dynamic>> rows;
  const _RecordedUpsert(this.table, this.rows);
}

class _FakePostgrest implements SyncPostgrest {
  final Map<String, List<Map<String, dynamic>>> serverRows;
  final List<_RecordedSelect> selectCalls = [];
  final List<_RecordedUpsert> upsertCalls = [];

  _FakePostgrest([Map<String, List<Map<String, dynamic>>>? serverRows])
      : serverRows = serverRows ?? {};

  @override
  Future<List<Map<String, dynamic>>> selectUpdatedAfter(
    String table,
    int cursor,
  ) async {
    selectCalls.add(_RecordedSelect(table, cursor));
    final rows = serverRows[table] ?? const [];
    return rows.where((r) => (r['updated_at'] as int) > cursor).toList();
  }

  @override
  Future<void> upsert(String table, List<Map<String, dynamic>> rows) async {
    upsertCalls.add(_RecordedUpsert(table, rows));
  }
}

Task _fullTask({
  String id = 'task-1',
  String? description = 'Do 20 pushups',
  RecurrenceType recurrenceType = RecurrenceType.weekly,
  List<int>? weeklyDays = const [1, 3, 5],
  MonthlyMode? monthlyMode,
  int? monthDay,
  int? monthNth,
  int? monthWeekday,
  LocalDate? dueDate,
  List<String> dueTimes = const ['08:00', '20:00'],
  LocalDate? startDate,
  LocalDate? endDate,
  bool archived = false,
  String? userId,
  int createdAt = 1000,
  int updatedAt = 2000,
  int? deletedAt,
  bool dirty = true,
}) {
  return Task(
    id: id,
    title: 'Push-ups',
    description: description,
    recurrenceType: recurrenceType,
    weeklyDays: weeklyDays,
    monthlyMode: monthlyMode,
    monthDay: monthDay,
    monthNth: monthNth,
    monthWeekday: monthWeekday,
    dueDate: dueDate,
    dueTimes: dueTimes,
    startDate: startDate ?? LocalDate(2026, 7, 1),
    endDate: endDate ?? LocalDate(2026, 12, 31),
    archived: archived,
    userId: userId,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
    dirty: dirty,
  );
}

Completion _fullCompletion({
  String id = 'completion-1',
  String taskId = 'task-1',
  LocalDate? occurrenceDate,
  int slot = 0,
  int completedAt = 1111,
  String? proofPhotoPath = '/proof/photo.jpg',
  ProofSource? proofSource = ProofSource.camera,
  int? photoTakenAt = 1050,
  VerificationStatus verificationStatus = VerificationStatus.verified,
  String? verificationMeta = '{"confidence":0.9}',
  int pointsAwarded = 25,
  String? userId,
  int updatedAt = 1200,
  int? deletedAt,
  bool dirty = true,
}) {
  return Completion(
    id: id,
    taskId: taskId,
    occurrenceDate: occurrenceDate ?? LocalDate(2026, 7, 10),
    slot: slot,
    completedAt: completedAt,
    proofPhotoPath: proofPhotoPath,
    proofSource: proofSource,
    photoTakenAt: photoTakenAt,
    verificationStatus: verificationStatus,
    verificationMeta: verificationMeta,
    pointsAwarded: pointsAwarded,
    userId: userId,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
    dirty: dirty,
  );
}

VerificationAttempt _fullAttempt({
  String id = 'attempt-1',
  String taskId = 'task-1',
  LocalDate? occurrenceDate,
  int slot = 1,
  int attemptedAt = 999,
  String? verdictMeta = '{"reason":"no task shown"}',
  String? userId,
  int updatedAt = 999,
  int? deletedAt,
  bool dirty = true,
}) {
  return VerificationAttempt(
    id: id,
    taskId: taskId,
    occurrenceDate: occurrenceDate ?? LocalDate(2026, 7, 10),
    slot: slot,
    attemptedAt: attemptedAt,
    verdictMeta: verdictMeta,
    userId: userId,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
    dirty: dirty,
  );
}

void main() {
  group('taskToPushJson', () {
    test('maps every column to its snake_case Postgres representation, '
        'drops dirty, and stamps user_id', () {
      final task = _fullTask(userId: 'local-user-should-be-overridden');

      final json = taskToPushJson(task, userId: 'auth-user-123');

      expect(json, {
        'id': 'task-1',
        'title': 'Push-ups',
        'description': 'Do 20 pushups',
        'recurrence_type': 'weekly',
        'weekly_days': '[1,3,5]',
        'monthly_mode': null,
        'month_day': null,
        'month_nth': null,
        'month_weekday': null,
        'due_date': null,
        'due_times': '["08:00","20:00"]',
        'start_date': '2026-07-01',
        'end_date': '2026-12-31',
        'archived': false,
        'user_id': 'auth-user-123',
        'created_at': 1000,
        'updated_at': 2000,
        'deleted_at': null,
      });
      expect(json.containsKey('dirty'), isFalse);
    });

    test('monthly day_of_month variant', () {
      final task = _fullTask(
        recurrenceType: RecurrenceType.monthly,
        weeklyDays: null,
        monthlyMode: MonthlyMode.dayOfMonth,
        monthDay: 31,
        dueTimes: const [],
        deletedAt: 9999,
      );

      final json = taskToPushJson(task, userId: 'auth-user-123');

      expect(json['recurrence_type'], 'monthly');
      expect(json['monthly_mode'], 'day_of_month');
      expect(json['month_day'], 31);
      expect(json['weekly_days'], null);
      expect(json['due_times'], '[]');
      expect(json['deleted_at'], 9999);
    });

    test('monthly nth_weekday variant', () {
      final task = _fullTask(
        recurrenceType: RecurrenceType.monthly,
        weeklyDays: null,
        monthlyMode: MonthlyMode.nthWeekday,
        monthNth: -1,
        monthWeekday: 5,
      );

      final json = taskToPushJson(task, userId: 'auth-user-123');

      expect(json['monthly_mode'], 'nth_weekday');
      expect(json['month_nth'], -1);
      expect(json['month_weekday'], 5);
    });

    test('once variant carries due_date', () {
      final task = _fullTask(
        recurrenceType: RecurrenceType.once,
        weeklyDays: null,
        dueDate: LocalDate(2026, 8, 15),
      );

      final json = taskToPushJson(task, userId: 'auth-user-123');

      expect(json['recurrence_type'], 'once');
      expect(json['due_date'], '2026-08-15');
    });
  });

  group('taskFromPullJson', () {
    test('maps a Postgres row back to a Task with dirty forced false', () {
      final json = <String, dynamic>{
        'id': 'task-1',
        'title': 'Push-ups',
        'description': 'Do 20 pushups',
        'recurrence_type': 'weekly',
        'weekly_days': '[1,3,5]',
        'monthly_mode': null,
        'month_day': null,
        'month_nth': null,
        'month_weekday': null,
        'due_date': null,
        'due_times': '["08:00","20:00"]',
        'start_date': '2026-07-01',
        'end_date': '2026-12-31',
        'archived': false,
        'user_id': 'auth-user-123',
        'created_at': 1000,
        'updated_at': 2000,
        'deleted_at': null,
      };

      final task = taskFromPullJson(json);

      expect(task.id, 'task-1');
      expect(task.recurrenceType, RecurrenceType.weekly);
      expect(task.weeklyDays, [1, 3, 5]);
      expect(task.dueTimes, ['08:00', '20:00']);
      expect(task.startDate, LocalDate(2026, 7, 1));
      expect(task.endDate, LocalDate(2026, 12, 31));
      expect(task.userId, 'auth-user-123');
      expect(task.createdAt, 1000);
      expect(task.updatedAt, 2000);
      expect(task.dirty, isFalse);
    });

    test('parses the monthly day_of_month and nth_weekday enum encodings',
        () {
      final dayOfMonth = taskFromPullJson({
        'id': 't',
        'title': 'T',
        'description': null,
        'recurrence_type': 'monthly',
        'weekly_days': null,
        'monthly_mode': 'day_of_month',
        'month_day': 31,
        'month_nth': null,
        'month_weekday': null,
        'due_date': null,
        'due_times': '[]',
        'start_date': '2026-01-01',
        'end_date': null,
        'archived': false,
        'user_id': null,
        'created_at': 1,
        'updated_at': 1,
        'deleted_at': null,
      });
      expect(dayOfMonth.monthlyMode, MonthlyMode.dayOfMonth);

      final nthWeekday = taskFromPullJson({
        'id': 't2',
        'title': 'T2',
        'description': null,
        'recurrence_type': 'monthly',
        'weekly_days': null,
        'monthly_mode': 'nth_weekday',
        'month_day': null,
        'month_nth': -1,
        'month_weekday': 5,
        'due_date': null,
        'due_times': '[]',
        'start_date': '2026-01-01',
        'end_date': null,
        'archived': false,
        'user_id': null,
        'created_at': 1,
        'updated_at': 1,
        'deleted_at': null,
      });
      expect(nthWeekday.monthlyMode, MonthlyMode.nthWeekday);
      expect(nthWeekday.monthNth, -1);
      expect(nthWeekday.monthWeekday, 5);
    });

    test('tolerates a stringified epoch millis value (defensive)', () {
      final task = taskFromPullJson({
        'id': 't',
        'title': 'T',
        'description': null,
        'recurrence_type': 'daily',
        'weekly_days': null,
        'monthly_mode': null,
        'month_day': null,
        'month_nth': null,
        'month_weekday': null,
        'due_date': null,
        'due_times': '[]',
        'start_date': '2026-01-01',
        'end_date': null,
        'archived': false,
        'user_id': null,
        'created_at': '1000',
        'updated_at': '2000',
        'deleted_at': null,
      });
      expect(task.createdAt, 1000);
      expect(task.updatedAt, 2000);
    });
  });

  group('completionToPushJson / completionFromPullJson', () {
    test('round-trips every column including the nullable converter columns',
        () {
      final completion = _fullCompletion(userId: 'local-user');

      final json = completionToPushJson(completion, userId: 'auth-user-123');
      expect(json, {
        'id': 'completion-1',
        'task_id': 'task-1',
        'occurrence_date': '2026-07-10',
        'slot': 0,
        'completed_at': 1111,
        'proof_photo_path': '/proof/photo.jpg',
        'proof_source': 'camera',
        'photo_taken_at': 1050,
        'verification_status': 'verified',
        'verification_meta': '{"confidence":0.9}',
        'points_awarded': 25,
        'user_id': 'auth-user-123',
        'updated_at': 1200,
        'deleted_at': null,
      });
      expect(json.containsKey('dirty'), isFalse);

      final pulled = completionFromPullJson(json);
      expect(pulled.id, completion.id);
      expect(pulled.proofSource, ProofSource.camera);
      expect(pulled.verificationStatus, VerificationStatus.verified);
      expect(pulled.pointsAwarded, 25);
      expect(pulled.dirty, isFalse);
    });

    test('nullable proof columns and a gallery/pending/rejected/tombstoned '
        'row', () {
      final completion = _fullCompletion(
        proofPhotoPath: null,
        proofSource: null,
        photoTakenAt: null,
        verificationStatus: VerificationStatus.pending,
        verificationMeta: null,
        pointsAwarded: 0,
        deletedAt: 5000,
      );

      final json = completionToPushJson(completion, userId: 'auth-user-123');
      expect(json['proof_photo_path'], null);
      expect(json['proof_source'], null);
      expect(json['photo_taken_at'], null);
      expect(json['verification_status'], 'pending');
      expect(json['deleted_at'], 5000);

      final pulled = completionFromPullJson(json);
      expect(pulled.proofSource, isNull);
      expect(pulled.verificationStatus, VerificationStatus.pending);
      expect(pulled.deletedAt, 5000);
    });

    test('gallery source and rejected status', () {
      final completion = _fullCompletion(
        proofSource: ProofSource.gallery,
        verificationStatus: VerificationStatus.rejected,
      );
      final json = completionToPushJson(completion, userId: 'u');
      expect(json['proof_source'], 'gallery');
      expect(json['verification_status'], 'rejected');
      final pulled = completionFromPullJson(json);
      expect(pulled.proofSource, ProofSource.gallery);
      expect(pulled.verificationStatus, VerificationStatus.rejected);
    });
  });

  group('verificationAttemptToPushJson / verificationAttemptFromPullJson', () {
    test('round-trips every column, drops dirty, stamps user_id', () {
      final attempt = _fullAttempt(userId: 'local-user');

      final json = verificationAttemptToPushJson(attempt, userId: 'auth-user-123');
      expect(json, {
        'id': 'attempt-1',
        'task_id': 'task-1',
        'occurrence_date': '2026-07-10',
        'slot': 1,
        'attempted_at': 999,
        'verdict_meta': '{"reason":"no task shown"}',
        'user_id': 'auth-user-123',
        'updated_at': 999,
        'deleted_at': null,
      });
      expect(json.containsKey('dirty'), isFalse);

      final pulled = verificationAttemptFromPullJson(json);
      expect(pulled.id, attempt.id);
      expect(pulled.verdictMeta, attempt.verdictMeta);
      expect(pulled.dirty, isFalse);
    });

    test('nullable verdict_meta and a tombstoned row', () {
      final attempt = _fullAttempt(verdictMeta: null, deletedAt: 4242);
      final json = verificationAttemptToPushJson(attempt, userId: 'u');
      expect(json['verdict_meta'], null);
      expect(json['deleted_at'], 4242);
      final pulled = verificationAttemptFromPullJson(json);
      expect(pulled.verdictMeta, isNull);
      expect(pulled.deletedAt, 4242);
    });
  });

  group('SupabaseSyncTransport.pull', () {
    test('issues an updated_at > cursor select per table and returns the '
        'mapped rows with the max updatedAt as the new cursor', () async {
      final taskJson = taskToPushJson(
        _fullTask(id: 'task-a', updatedAt: 1500),
        userId: 'auth-user-123',
      );
      final completionJson = completionToPushJson(
        _fullCompletion(id: 'completion-a', updatedAt: 2500),
        userId: 'auth-user-123',
      );
      final attemptJson = verificationAttemptToPushJson(
        _fullAttempt(id: 'attempt-a', updatedAt: 1800),
        userId: 'auth-user-123',
      );

      final fake = _FakePostgrest({
        SupabaseSyncTransport.tasksTable: [taskJson],
        SupabaseSyncTransport.completionsTable: [completionJson],
        SupabaseSyncTransport.verificationAttemptsTable: [attemptJson],
      });
      final transport = SupabaseSyncTransport(
        postgrest: fake,
        currentUserId: () => 'auth-user-123',
      );

      final result = await transport.pull(cursor: 1000);

      expect(fake.selectCalls, hasLength(3));
      expect(
        fake.selectCalls.map((c) => c.table).toSet(),
        {
          SupabaseSyncTransport.tasksTable,
          SupabaseSyncTransport.completionsTable,
          SupabaseSyncTransport.verificationAttemptsTable,
        },
      );
      expect(fake.selectCalls.every((c) => c.cursor == 1000), isTrue);

      expect(result.tasks.single.id, 'task-a');
      expect(result.completions.single.id, 'completion-a');
      expect(result.verificationAttempts.single.id, 'attempt-a');
      expect(result.newCursor, 2500);
    });

    test('the cursor stays at the incoming value when nothing changed',
        () async {
      final fake = _FakePostgrest();
      final transport = SupabaseSyncTransport(
        postgrest: fake,
        currentUserId: () => 'auth-user-123',
      );

      final result = await transport.pull(cursor: 4242);

      expect(result.tasks, isEmpty);
      expect(result.completions, isEmpty);
      expect(result.verificationAttempts, isEmpty);
      expect(result.newCursor, 4242);
    });

    test('a row already at or before the cursor is not returned (the fake '
        'applies the same > cursor filter a real Postgrest query would)',
        () async {
      final atCursor = taskToPushJson(
        _fullTask(id: 'at-cursor', updatedAt: 1000),
        userId: 'u',
      );
      final afterCursor = taskToPushJson(
        _fullTask(id: 'after-cursor', updatedAt: 1001),
        userId: 'u',
      );
      final fake = _FakePostgrest({
        SupabaseSyncTransport.tasksTable: [atCursor, afterCursor],
      });
      final transport =
          SupabaseSyncTransport(postgrest: fake, currentUserId: () => 'u');

      final result = await transport.pull(cursor: 1000);

      expect(result.tasks, hasLength(1));
      expect(result.tasks.single.id, 'after-cursor');
    });
  });

  group('SupabaseSyncTransport.push', () {
    test('upserts the mapped rows only for non-empty tables, stamping '
        'user_id from currentUserId', () async {
      final fake = _FakePostgrest();
      final transport = SupabaseSyncTransport(
        postgrest: fake,
        currentUserId: () => 'auth-user-123',
      );

      final task = _fullTask();
      final attempt = _fullAttempt();

      await transport.push(SyncPushBatch(tasks: [task], verificationAttempts: [attempt]));

      expect(fake.upsertCalls, hasLength(2));
      final tasksCall =
          fake.upsertCalls.firstWhere((c) => c.table == SupabaseSyncTransport.tasksTable);
      expect(tasksCall.rows.single['id'], task.id);
      expect(tasksCall.rows.single['user_id'], 'auth-user-123');
      expect(tasksCall.rows.single.containsKey('dirty'), isFalse);

      final attemptsCall = fake.upsertCalls
          .firstWhere((c) => c.table == SupabaseSyncTransport.verificationAttemptsTable);
      expect(attemptsCall.rows.single['id'], attempt.id);
      expect(attemptsCall.rows.single['user_id'], 'auth-user-123');

      expect(
        fake.upsertCalls.any((c) => c.table == SupabaseSyncTransport.completionsTable),
        isFalse,
      );
    });

    test('an empty batch triggers no upsert calls at all', () async {
      final fake = _FakePostgrest();
      final transport = SupabaseSyncTransport(
        postgrest: fake,
        currentUserId: () => 'auth-user-123',
      );

      await transport.push(const SyncPushBatch());

      expect(fake.upsertCalls, isEmpty);
    });

    test('throws when there is no signed-in user id', () async {
      final fake = _FakePostgrest();
      final transport = SupabaseSyncTransport(
        postgrest: fake,
        currentUserId: () => null,
      );

      // Specifically a TypeError from the null-check operator, and NOT some
      // other error from falling through to the real Supabase.instance
      // client (which isn't initialised in this test process): proves the
      // currentUserId override, once supplied, is trusted even when it
      // itself resolves to null, rather than treated as "no override" and
      // silently falling back to the real client.
      expect(
        () => transport.push(SyncPushBatch(tasks: [_fullTask()])),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('UnconfiguredSyncTransport', () {
    test('pull always throws', () {
      expect(
        () => const UnconfiguredSyncTransport().pull(cursor: 0),
        throwsStateError,
      );
    });

    test('push always throws', () {
      expect(
        () => const UnconfiguredSyncTransport().push(const SyncPushBatch()),
        throwsStateError,
      );
    });
  });
}
