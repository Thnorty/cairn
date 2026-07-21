import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, SupabaseClient;

import '../db/database.dart';
import '../models/local_date.dart';
import 'sync_transport.dart';

/// The subset of Postgrest table operations [SupabaseSyncTransport] needs:
/// fetch every row changed since a cursor, and upsert a batch of rows.
///
/// Kept as its own tiny interface, rather than [SupabaseSyncTransport]
/// driving `SupabaseClient.from(...)` calls inline, so a transport-level
/// test can exercise [SupabaseSyncTransport.pull]/[push] against a thin,
/// in-memory fake exposing exactly this `select`/`upsert`-shaped seam -
/// never a real network, and without constructing a real [SupabaseClient]
/// (which spins up its own background JSON isolate, auth client, etc.).
/// Same "seam behind the real SDK call" idea as `ProofInvoker` in
/// `supabase_proof_verifier.dart`. [_RealSyncPostgrest] is the only
/// production implementation.
abstract class SyncPostgrest {
  /// `client.from(table).select().gt('updated_at', cursor).order('updated_at')`.
  Future<List<Map<String, dynamic>>> selectUpdatedAfter(
    String table,
    int cursor,
  );

  /// `client.from(table).upsert(rows)`. Only ever called with a non-empty
  /// [rows] - see [SupabaseSyncTransport.push].
  Future<void> upsert(String table, List<Map<String, dynamic>> rows);
}

/// Wraps a real [SupabaseClient] (resolved lazily via [resolveClient], never
/// at construction time) to satisfy [SyncPostgrest].
class _RealSyncPostgrest implements SyncPostgrest {
  final SupabaseClient Function() resolveClient;

  const _RealSyncPostgrest(this.resolveClient);

  @override
  Future<List<Map<String, dynamic>>> selectUpdatedAfter(
    String table,
    int cursor,
  ) {
    return resolveClient()
        .from(table)
        .select()
        .gt('updated_at', cursor)
        .order('updated_at');
  }

  @override
  Future<void> upsert(String table, List<Map<String, dynamic>> rows) async {
    await resolveClient().from(table).upsert(rows);
  }
}

/// Reads a Postgres integer column (bigint `*_at` columns) that PostgREST
/// hands back as a JSON number. Defensive against it arriving as a numeric
/// string too, since that's a legal JSON representation this client doesn't
/// control.
int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.parse(value);
  throw FormatException('Expected an int, got $value (${value.runtimeType})');
}

int? _asIntOrNull(Object? value) => value == null ? null : _asInt(value);

/// Maps a [Task] row to the JSON body `public.tasks` expects on push: the
/// same raw SQLite representation the column's `TypeConverter` already
/// produces (ISO date strings, JSON-array strings, the enum's stored name),
/// keyed by the migration's snake_case column names, with `dirty` dropped
/// (it's a client-only column, meaningless server-side - see the migration's
/// comment) and `user_id` stamped with the caller's own id so the RLS
/// `with check (user_id = auth.uid())` passes even for a row whose local
/// `user_id` was null.
Map<String, dynamic> taskToPushJson(Task task, {required String userId}) {
  return {
    'id': task.id,
    'title': task.title,
    'description': task.description,
    'recurrence_type': task.recurrenceType.name,
    'weekly_days': task.weeklyDays == null
        ? null
        : const IntListConverter().toSql(task.weeklyDays!),
    'monthly_mode': task.monthlyMode == null
        ? null
        : const MonthlyModeConverter().toSql(task.monthlyMode!),
    'month_day': task.monthDay,
    'month_nth': task.monthNth,
    'month_weekday': task.monthWeekday,
    'due_date': task.dueDate?.toIso(),
    'due_times': const StringListConverter().toSql(task.dueTimes),
    'start_date': task.startDate.toIso(),
    'end_date': task.endDate?.toIso(),
    'archived': task.archived,
    'user_id': userId,
    'created_at': task.createdAt,
    'updated_at': task.updatedAt,
    'deleted_at': task.deletedAt,
  };
}

/// The inverse of [taskToPushJson]: a `public.tasks` row (snake_case JSON,
/// as PostgREST returns it) into a [Task]. Always forces `dirty: false` -
/// see [SyncService]'s doc comment: a pulled row is server truth, already in
/// sync by definition.
Task taskFromPullJson(Map<String, dynamic> json) {
  return Task(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    recurrenceType: RecurrenceType.values.byName(
      json['recurrence_type'] as String,
    ),
    weeklyDays: json['weekly_days'] == null
        ? null
        : const IntListConverter().fromSql(json['weekly_days'] as String),
    monthlyMode: json['monthly_mode'] == null
        ? null
        : const MonthlyModeConverter().fromSql(json['monthly_mode'] as String),
    monthDay: json['month_day'] as int?,
    monthNth: json['month_nth'] as int?,
    monthWeekday: json['month_weekday'] as int?,
    dueDate: json['due_date'] == null
        ? null
        : LocalDate.parse(json['due_date'] as String),
    dueTimes: const StringListConverter().fromSql(json['due_times'] as String),
    startDate: LocalDate.parse(json['start_date'] as String),
    endDate: json['end_date'] == null
        ? null
        : LocalDate.parse(json['end_date'] as String),
    archived: json['archived'] as bool,
    userId: json['user_id'] as String?,
    createdAt: _asInt(json['created_at']),
    updatedAt: _asInt(json['updated_at']),
    deletedAt: _asIntOrNull(json['deleted_at']),
    dirty: false,
  );
}

/// See [taskToPushJson]'s doc comment; identical contract for `completions`.
Map<String, dynamic> completionToPushJson(
  Completion completion, {
  required String userId,
}) {
  return {
    'id': completion.id,
    'task_id': completion.taskId,
    'occurrence_date': completion.occurrenceDate.toIso(),
    'slot': completion.slot,
    'completed_at': completion.completedAt,
    'proof_photo_path': completion.proofPhotoPath,
    'proof_source': completion.proofSource?.name,
    'photo_taken_at': completion.photoTakenAt,
    'verification_status': completion.verificationStatus.name,
    'verification_meta': completion.verificationMeta,
    'points_awarded': completion.pointsAwarded,
    'user_id': userId,
    'updated_at': completion.updatedAt,
    'deleted_at': completion.deletedAt,
  };
}

/// See [taskFromPullJson]'s doc comment; identical contract for
/// `completions`.
Completion completionFromPullJson(Map<String, dynamic> json) {
  return Completion(
    id: json['id'] as String,
    taskId: json['task_id'] as String,
    occurrenceDate: LocalDate.parse(json['occurrence_date'] as String),
    slot: _asInt(json['slot']),
    completedAt: _asInt(json['completed_at']),
    proofPhotoPath: json['proof_photo_path'] as String?,
    proofSource: json['proof_source'] == null
        ? null
        : ProofSource.values.byName(json['proof_source'] as String),
    photoTakenAt: _asIntOrNull(json['photo_taken_at']),
    verificationStatus: VerificationStatus.values.byName(
      json['verification_status'] as String,
    ),
    verificationMeta: json['verification_meta'] as String?,
    pointsAwarded: _asInt(json['points_awarded']),
    userId: json['user_id'] as String?,
    updatedAt: _asInt(json['updated_at']),
    deletedAt: _asIntOrNull(json['deleted_at']),
    dirty: false,
  );
}

/// See [taskToPushJson]'s doc comment; identical contract for
/// `verification_attempts`.
Map<String, dynamic> verificationAttemptToPushJson(
  VerificationAttempt attempt, {
  required String userId,
}) {
  return {
    'id': attempt.id,
    'task_id': attempt.taskId,
    'occurrence_date': attempt.occurrenceDate.toIso(),
    'slot': attempt.slot,
    'attempted_at': attempt.attemptedAt,
    'verdict_meta': attempt.verdictMeta,
    'user_id': userId,
    'updated_at': attempt.updatedAt,
    'deleted_at': attempt.deletedAt,
  };
}

/// See [taskFromPullJson]'s doc comment; identical contract for
/// `verification_attempts`.
VerificationAttempt verificationAttemptFromPullJson(Map<String, dynamic> json) {
  return VerificationAttempt(
    id: json['id'] as String,
    taskId: json['task_id'] as String,
    occurrenceDate: LocalDate.parse(json['occurrence_date'] as String),
    slot: _asInt(json['slot']),
    attemptedAt: _asInt(json['attempted_at']),
    verdictMeta: json['verdict_meta'] as String?,
    userId: json['user_id'] as String?,
    updatedAt: _asInt(json['updated_at']),
    deletedAt: _asIntOrNull(json['deleted_at']),
    dirty: false,
  );
}

/// Real remote [SyncTransport] (Phase 4b): maps the drift row types to/from
/// the `public.tasks`/`public.completions`/`public.verification_attempts`
/// Postgres wire JSON (see `supabase/migrations/20260721134845_create_sync_tables.sql`)
/// and calls out over the network via [SyncPostgrest].
///
/// [client] is resolved lazily (only inside [pull]/[push], never at
/// construction time) so building this is always safe even before
/// `Supabase.initialize()` has run - same rationale as
/// [SupabaseAuthService]/[SupabaseProofVerifier]. [postgrest] and
/// [currentUserId] are test-only seams (see [SyncPostgrest]'s doc comment);
/// production code should only ever pass [client].
class SupabaseSyncTransport implements SyncTransport {
  static const String tasksTable = 'tasks';
  static const String completionsTable = 'completions';
  static const String verificationAttemptsTable = 'verification_attempts';

  final SupabaseClient? _clientOverride;
  final SyncPostgrest? _postgrestOverride;
  final String? Function()? _currentUserIdOverride;

  SupabaseSyncTransport({
    SupabaseClient? client,
    SyncPostgrest? postgrest,
    String? Function()? currentUserId,
  })  : _clientOverride = client,
        _postgrestOverride = postgrest,
        _currentUserIdOverride = currentUserId;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  SyncPostgrest get _postgrest =>
      _postgrestOverride ?? _RealSyncPostgrest(() => _client);

  // Deliberately not `_currentUserIdOverride?.call() ?? _client...`: that
  // would fall through to the real client whenever a supplied override
  // itself returns null (e.g. a test simulating "no session"), touching
  // `Supabase.instance` in exactly the case a test is trying to avoid it.
  // Only fall back to the real client when no override was given at all.
  String? get _resolvedUserId {
    final override = _currentUserIdOverride;
    if (override != null) return override();
    return _client.auth.currentUser?.id;
  }

  @override
  Future<SyncPullResult> pull({required int cursor}) async {
    final taskRows = await _postgrest.selectUpdatedAfter(tasksTable, cursor);
    final completionRows =
        await _postgrest.selectUpdatedAfter(completionsTable, cursor);
    final attemptRows = await _postgrest.selectUpdatedAfter(
      verificationAttemptsTable,
      cursor,
    );

    final tasks = taskRows.map(taskFromPullJson).toList();
    final completions = completionRows.map(completionFromPullJson).toList();
    final attempts = attemptRows.map(verificationAttemptFromPullJson).toList();

    var newCursor = cursor;
    for (final t in tasks) {
      if (t.updatedAt > newCursor) newCursor = t.updatedAt;
    }
    for (final c in completions) {
      if (c.updatedAt > newCursor) newCursor = c.updatedAt;
    }
    for (final a in attempts) {
      if (a.updatedAt > newCursor) newCursor = a.updatedAt;
    }

    return SyncPullResult(
      tasks: tasks,
      completions: completions,
      verificationAttempts: attempts,
      newCursor: newCursor,
    );
  }

  @override
  Future<void> push(SyncPushBatch batch) async {
    // Force-unwrap: SyncTrigger only ever calls syncOnce (and so, only ever
    // reaches this push) while a session exists. A null id here means
    // something called push outside that guard, which is a bug worth
    // surfacing loudly rather than silently mislabeling rows.
    final userId = _resolvedUserId!;

    if (batch.tasks.isNotEmpty) {
      await _postgrest.upsert(
        tasksTable,
        batch.tasks.map((t) => taskToPushJson(t, userId: userId)).toList(),
      );
    }
    if (batch.completions.isNotEmpty) {
      await _postgrest.upsert(
        completionsTable,
        batch.completions
            .map((c) => completionToPushJson(c, userId: userId))
            .toList(),
      );
    }
    if (batch.verificationAttempts.isNotEmpty) {
      await _postgrest.upsert(
        verificationAttemptsTable,
        batch.verificationAttempts
            .map((a) => verificationAttemptToPushJson(a, userId: userId))
            .toList(),
      );
    }
  }
}
