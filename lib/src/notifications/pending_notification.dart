import 'dart:convert';

import '../models/local_date.dart';

/// Which of Cairn's two notification kinds a [PendingNotification] is (see
/// `NotificationPlanner`'s own doc comment,
/// `lib/src/services/notification_planner.dart`, for what each one means).
/// Part of a notification's stable-id composite key
/// ([pendingNotificationId]), so a reminder and a streak warning for the
/// same (task, date, slot) never collide.
enum NotificationKind { reminder, streakWarning }

/// What a notification tap must route into: the exact occurrence
/// (task, local date, slot) to open the camera for. Carried as an opaque
/// encoded string in the real `flutter_local_notifications` implementation
/// (a later work order), because that's exactly what the plugin's own
/// payload field is - a string that must survive a process boundary (the app
/// may have been killed between scheduling this notification and the user
/// tapping it), so a silent format change here is the kind of bug that only
/// shows up on a cold start days later. [encode]/[decode] are the one place
/// that format is defined.
class NotificationPayload {
  final String taskId;
  final LocalDate occurrenceDate;
  final int slot;

  const NotificationPayload({
    required this.taskId,
    required this.occurrenceDate,
    required this.slot,
  });

  /// Encodes this payload as a JSON string. Keys are deliberately
  /// snake_case and `occurrence_date` is [LocalDate.toIso]'s output - the
  /// same wire convention this app's other JSON payloads already use (see
  /// `ProofVerdict.toJson`).
  String encode() => jsonEncode({
        'task_id': taskId,
        'occurrence_date': occurrenceDate.toIso(),
        'slot': slot,
      });

  /// Inverse of [encode]. Deliberately does NOT swallow malformed input: a
  /// notification tap with an undecodable payload is a bug the caller needs
  /// to know about (it should never be silently routed into a guessed
  /// occurrence), so this throws [FormatException]/[TypeError] exactly like
  /// [LocalDate.parse]/`jsonDecode` already do on bad input.
  factory NotificationPayload.decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return NotificationPayload(
      taskId: json['task_id'] as String,
      occurrenceDate: LocalDate.parse(json['occurrence_date'] as String),
      slot: json['slot'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPayload &&
      other.taskId == taskId &&
      other.occurrenceDate == occurrenceDate &&
      other.slot == slot;

  @override
  int get hashCode => Object.hash(taskId, occurrenceDate, slot);

  @override
  String toString() =>
      'NotificationPayload($taskId, $occurrenceDate, slot $slot)';
}

/// One notification `NotificationPlanner` wants scheduled
/// (`lib/src/services/notification_planner.dart`).
///
/// [scheduledFor] is a naive local wall-clock [DateTime] (no timezone
/// attached) - deliberately: this seam needs no plugin/timezone type, so it
/// stays fully testable with zero platform dependencies. The real
/// `flutter_local_notifications`-backed `NotificationScheduler` (a later
/// work order) is responsible for converting it to a `TZDateTime` in the
/// device's own IANA zone before handing it to the plugin.
class PendingNotification {
  /// Stable across re-plans for the same (task, date, slot, kind) tuple -
  /// see [pendingNotificationId].
  final int id;

  /// Which of the two kinds this is. Already folded into [id] via
  /// [pendingNotificationId], but carried separately as well because the real
  /// scheduler needs it *unhashed*: each kind is posted on its own Android
  /// notification channel, so the two in-app switches on the Notifications
  /// settings screen have matching per-channel controls in Android's own
  /// notification settings (a user who silences streak warnings at the OS
  /// level should not thereby silence habit reminders).
  final NotificationKind kind;

  final DateTime scheduledFor;
  final String title;
  final String body;

  /// [NotificationPayload.encode]'s output. Kept as a plain string here
  /// (rather than the typed [NotificationPayload]) because that's exactly
  /// what the real plugin's own payload field is.
  final String payload;

  const PendingNotification({
    required this.id,
    required this.kind,
    required this.scheduledFor,
    required this.title,
    required this.body,
    required this.payload,
  });

  @override
  bool operator ==(Object other) =>
      other is PendingNotification &&
      other.id == id &&
      other.kind == kind &&
      other.scheduledFor == scheduledFor &&
      other.title == title &&
      other.body == body &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(id, kind, scheduledFor, title, body, payload);

  @override
  String toString() =>
      'PendingNotification(id: $id, scheduledFor: $scheduledFor, title: $title)';
}

/// FNV-1a 32-bit hash. Deterministic and independent of Dart's own
/// `Object.hashCode`/`String.hashCode`, which the language never guarantees
/// is stable across SDK versions or process restarts - and [pendingNotificationId]
/// MUST be, since the real scheduler replaces a previously scheduled
/// OS-level notification by id across app restarts, potentially days apart.
/// "Stable within one run" is not good enough here.
int _fnv1a32(String input) {
  const int fnvPrime = 0x01000193;
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  return hash;
}

/// Deterministic, stable integer id for a (task, date, slot, kind) tuple, so
/// re-planning replaces a previously scheduled notification instead of
/// duplicating it. A plain 32-bit FNV-1a hash of the pipe-joined composite
/// key ("$taskId|${date.toIso()}|$slot|${kind.name}"), masked into the
/// positive half of the 32-bit range: the platforms this app targets require
/// a non-negative notification id.
///
/// Collision risk accepted: a 32-bit hash has roughly a 1-in-2 birthday-bound
/// collision chance once about 77,000 distinct (task, date, slot, kind) keys
/// have ever been generated. This app schedules at most a handful of tasks
/// times a 14-day rolling window times a few slots times 2 kinds at once -
/// many orders of magnitude below that - so a collision silently
/// overwriting an unrelated notification's schedule is accepted as
/// practically negligible, not engineered around with a wider id space the
/// target platforms don't support anyway.
int pendingNotificationId(
  String taskId,
  LocalDate date,
  int slot,
  NotificationKind kind,
) {
  final key = '$taskId|${date.toIso()}|$slot|${kind.name}';
  return _fnv1a32(key) & 0x7FFFFFFF;
}
