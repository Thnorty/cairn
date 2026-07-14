import '../clock.dart';
import '../db/database.dart';
import '../models/local_date.dart';
import '../repo/completion_repository.dart';
import '../repo/task_repository.dart';
import 'occurrence_generator.dart';

/// The four card states the Home screen renders, mapping exactly onto the
/// domain (see `CLAUDE.md`'s pending-completion decision):
///
/// - [verified]: a live completion exists and its verdict is in.
/// - [awaitingVerification]: a live completion exists but is still
///   `pending` - the stone is placed (it counts toward streaks/caps) but its
///   metres are withheld until the verdict lands.
/// - [due]: no completion yet, and the occurrence's due time has arrived (or
///   it's untimed, which is always due).
/// - [scheduled]: no completion yet, and the due time is still ahead.
enum HomeCardStatus { verified, awaitingVerification, due, scheduled }

/// One card on the Home screen: one occurrence (task, today, slot).
class HomeOccurrenceCard {
  final String taskId;
  final String taskTitle;

  /// The task's permanent "Cairn N" ordinal (see [TaskRepository.cairnNumbers]).
  final int cairnNumber;

  /// The task's live completion count (its cairn's stone count), *after*
  /// this occurrence's own completion if it has one - a pending
  /// completion's stone is already placed, so it's included here exactly
  /// like a verified one.
  final int stoneCount;

  final int slot;

  /// The "HH:mm" due time for this slot, or null for an untimed slot.
  final String? dueTime;

  final HomeCardStatus status;

  /// Set iff [status] is [HomeCardStatus.verified] or
  /// [HomeCardStatus.awaitingVerification]: the live completion backing this
  /// card.
  final Completion? completion;

  const HomeOccurrenceCard({
    required this.taskId,
    required this.taskTitle,
    required this.cairnNumber,
    required this.stoneCount,
    required this.slot,
    required this.dueTime,
    required this.status,
    required this.completion,
  });
}

/// Everything the Home screen shows, computed fresh from the repositories.
class HomeSnapshot {
  final LocalDate today;

  /// Number of active tasks (not archived, not tombstoned), regardless of
  /// whether any are scheduled today. Drives the Empty Today state: that
  /// state is for having *no tasks at all*, not merely none due today.
  final int activeTaskCount;

  /// Occurrences today with a live completion (verified or pending alike -
  /// a pending completion's stone is already placed).
  final int doneCount;

  /// Total occurrences scheduled today across every active task.
  final int totalCount;

  /// Live completions (any task, verified or pending) in the Monday..Sunday
  /// week containing [today].
  final int stonesThisWeek;

  /// One card per occurrence scheduled today, ordered by the owning task's
  /// cairn number (creation order) and then by slot ascending within a task.
  final List<HomeOccurrenceCard> cards;

  const HomeSnapshot({
    required this.today,
    required this.activeTaskCount,
    required this.doneCount,
    required this.totalCount,
    required this.stonesThisWeek,
    required this.cards,
  });
}

/// Whether an occurrence due at [dueTime] ("HH:mm", or null for untimed) is
/// due now or earlier, as of the wall-clock instant [now].
///
/// An untimed occurrence (`dueTime == null`) has no time-of-day restriction
/// and is always due. A timed occurrence is due the instant [now] reaches
/// its due time (inclusive) and stays due afterwards; before that it's
/// still [HomeCardStatus.scheduled].
bool isOccurrenceDueBy(String? dueTime, DateTime now) {
  if (dueTime == null) return true;
  final parts = dueTime.split(':');
  final due = DateTime(
    now.year,
    now.month,
    now.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
  return !now.isBefore(due);
}

/// Builds the Home screen's [HomeSnapshot] from the repositories, and keeps
/// it live: [watchToday] re-emits a freshly-recomputed snapshot whenever the
/// tasks or completions tables change (a task added/archived, a completion
/// recorded elsewhere, or a pending proof resolving in the background via
/// `ProofRetryTrigger`), so the screen never needs a manual refresh.
///
/// Reactivity is deliberately coarse-grained: rather than combining several
/// typed drift streams by hand, this watches a trigger query whose
/// `readsFrom` covers both tables (see [AppDatabase.customSelect]'s own
/// doc comment on `readsFrom`) and, on every emission (including the first,
/// immediate one), recomputes the whole snapshot from scratch via the
/// existing, separately-tested repository methods. A full Home snapshot is
/// cheap enough (a handful of small queries) that this is simpler and far
/// less error-prone than hand-rolled stream combination, at the cost of
/// occasionally recomputing a little more than strictly changed - a
/// trade-off worth it for correctness here.
class HomeService {
  final AppDatabase _db;
  final TaskRepository _taskRepo;
  final CompletionRepository _completionRepo;
  final OccurrenceGenerator _generator;
  final Clock _clock;

  const HomeService(
    this._db,
    this._taskRepo,
    this._completionRepo,
    this._generator,
    this._clock,
  );

  Stream<HomeSnapshot> watchToday() {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.tasks, _db.completions},
        )
        .watch()
        .asyncMap((_) => _buildSnapshot());
  }

  /// One-shot equivalent of [watchToday], for callers that don't need
  /// reactivity (e.g. tests asserting a single snapshot).
  Future<HomeSnapshot> buildSnapshot() => _buildSnapshot();

  Future<HomeSnapshot> _buildSnapshot() async {
    final today = _clock.today();
    final now = DateTime.fromMillisecondsSinceEpoch(_clock.nowEpochMillis());

    final tasks = await _taskRepo.activeTasks();
    final cairnNumbers = await _taskRepo.cairnNumbers();
    final stoneCounts = await _completionRepo.liveCompletionCountsByTask();
    final todaysCompletions =
        await _completionRepo.liveCompletionsForDate(today);
    final stonesThisWeek =
        await _completionRepo.completionsCountForWeekOf(today);

    final completionByTaskSlot = <(String, int), Completion>{
      for (final c in todaysCompletions) (c.taskId, c.slot): c,
    };

    final sortedTasks = [...tasks]..sort(
        (a, b) =>
            (cairnNumbers[a.id] ?? 0).compareTo(cairnNumbers[b.id] ?? 0),
      );

    final cards = <HomeOccurrenceCard>[];
    for (final task in sortedTasks) {
      final occurrences =
          _generator.occurrencesFor(task, DateRange(today, today));
      for (final occ in occurrences) {
        final completion = completionByTaskSlot[(task.id, occ.slot)];
        cards.add(
          HomeOccurrenceCard(
            taskId: task.id,
            taskTitle: task.title,
            cairnNumber: cairnNumbers[task.id] ?? 0,
            stoneCount: stoneCounts[task.id] ?? 0,
            slot: occ.slot,
            dueTime: occ.time,
            status: _statusFor(completion, occ.time, now),
            completion: completion,
          ),
        );
      }
    }

    final doneCount = cards.where((c) => c.completion != null).length;

    return HomeSnapshot(
      today: today,
      activeTaskCount: tasks.length,
      doneCount: doneCount,
      totalCount: cards.length,
      stonesThisWeek: stonesThisWeek,
      cards: cards,
    );
  }

  HomeCardStatus _statusFor(
    Completion? completion,
    String? dueTime,
    DateTime now,
  ) {
    if (completion != null) {
      return completion.verificationStatus == VerificationStatus.verified
          ? HomeCardStatus.verified
          : HomeCardStatus.awaitingVerification;
    }
    return isOccurrenceDueBy(dueTime, now)
        ? HomeCardStatus.due
        : HomeCardStatus.scheduled;
  }
}
