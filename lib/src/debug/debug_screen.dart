import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../models/local_date.dart';
import '../models/occurrence.dart';
import '../providers.dart';
import '../repo/completion_repository.dart';
import '../services/points_service.dart';
import '../services/proof_flow.dart';
import '../services/proof_retry_service.dart';
import 'new_task_dialog.dart';

/// Phase 1 debug screen: no design system, just enough to exercise the data
/// layer. Lists today's occurrences per task, lets you mark them complete,
/// and shows per-task streak plus total altitude/rank. Real screens are
/// implemented from `design/` in later phases: this one deliberately isn't.
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _TaskRow {
  final Task task;
  final List<Occurrence> todayOccurrences;
  final Set<int> completedSlotsToday;
  final int currentStreak;
  final int longestStreak;
  final int attemptsUsedToday;

  _TaskRow({
    required this.task,
    required this.todayOccurrences,
    required this.completedSlotsToday,
    required this.currentStreak,
    required this.longestStreak,
    required this.attemptsUsedToday,
  });
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  bool _loading = true;
  List<_TaskRow> _rows = [];
  int _totalAltitude = 0;
  int _pendingAltitude = 0;
  Rank? _rank;
  int _proofsUsedToday = 0;
  StreamSubscription<PendingRetryReport>? _retryReportsSubscription;

  /// Set for the duration of [_completeWithProof]'s call into
  /// [ProofFlowService], which spans opening the camera/gallery picker
  /// through verification. Returning from the picker activity fires
  /// AppLifecycleListener.onResume, which runs an auto-retry batch; that
  /// batch's snackbar must not clobber the proof outcome snackbar the user
  /// is actually waiting for, so [_onAutoRetryReport] checks this flag and
  /// stays silent while it's set.
  bool _proofFlowInProgress = false;

  @override
  void initState() {
    super.initState();
    _reload();
    // proofRetryServiceProvider rebuilds whenever its own dependencies do
    // (e.g. the debug verifier mode), which would otherwise leave a stream
    // subscription pointed at a stale service instance whose stream has
    // stopped emitting. listenManual re-runs the callback (and so
    // re-subscribes) on every rebuild of the provider, not just once here at
    // initState time.
    ref.listenManual<ProofRetryService>(
      proofRetryServiceProvider,
      (previous, next) => _subscribeToRetryReports(next),
      fireImmediately: true,
    );
  }

  void _subscribeToRetryReports(ProofRetryService service) {
    unawaited(_retryReportsSubscription?.cancel());
    _retryReportsSubscription = service.reports.listen(_onAutoRetryReport);
  }

  /// Surfaces a retry batch that ran without the user pressing the manual
  /// button (foreground resume or a real reconnect), which would otherwise
  /// be invisible. The manual "Retry pending" button below keeps its own
  /// direct snackbar too, so a manual press may show both.
  ///
  /// Stays silent (but still reloads) when the batch was a no-op: returning
  /// from the camera/gallery picker fires onResume, which runs a retry batch
  /// that almost always has nothing to do, and an empty "verified 0,
  /// rejected 0, still pending 0, skipped 0" snackbar was drowning out the
  /// actual proof outcome. Also stays silent while a proof flow is in
  /// progress ([_proofFlowInProgress]), so that outcome snackbar always wins
  /// even when the same resume-triggered batch *does* do something.
  void _onAutoRetryReport(PendingRetryReport report) {
    if (!mounted) return;
    final didAnything = report.verified > 0 ||
        report.rejected > 0 ||
        report.stillPending > 0 ||
        report.skipped > 0;
    if (didAnything && !_proofFlowInProgress) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Auto-retry: verified ${report.verified}, rejected ${report.rejected}, '
          'still pending ${report.stillPending}, skipped ${report.skipped}',
        ),
      ));
    }
    unawaited(_reload());
  }

  @override
  void dispose() {
    unawaited(_retryReportsSubscription?.cancel());
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);

    final db = ref.read(databaseProvider);
    final clock = ref.read(clockProvider);
    final generator = ref.read(occurrenceGeneratorProvider);
    final streaks = ref.read(streakServiceProvider);
    final points = ref.read(pointsServiceProvider);
    final taskRepo = ref.read(taskRepositoryProvider);
    final completionRepo = ref.read(completionRepositoryProvider);

    final today = clock.today();
    final tasks = await taskRepo.activeTasks();

    final rows = <_TaskRow>[];
    for (final task in tasks) {
      final allCompletions = await (db.select(db.completions)
            ..where((c) => c.taskId.equals(task.id) & c.deletedAt.isNull()))
          .get();
      final doneSet = <(LocalDate, int)>{
        for (final c in allCompletions) (c.occurrenceDate, c.slot),
      };
      final completedToday = <int>{
        for (final c in allCompletions)
          if (c.occurrenceDate == today) c.slot,
      };
      final attemptsToday = await completionRepo.attemptsUsedToday(task.id);
      rows.add(_TaskRow(
        task: task,
        todayOccurrences: generator.occurrencesFor(task, DateRange(today, today)),
        completedSlotsToday: completedToday,
        currentStreak: streaks.currentStreak(
          task,
          today,
          (date, slot) => doneSet.contains((date, slot)),
        ),
        longestStreak: streaks.longestStreak(
          task,
          today,
          (date, slot) => doneSet.contains((date, slot)),
        ),
        attemptsUsedToday: attemptsToday,
      ));
    }

    final altitude = await completionRepo.totalAltitude();
    final pendingAltitude = await completionRepo.pendingAltitude();
    final proofsToday = await completionRepo.successfulProofsToday();

    if (!mounted) return;
    setState(() {
      _rows = rows;
      _totalAltitude = altitude;
      _pendingAltitude = pendingAltitude;
      _rank = points.rankFor(altitude);
      _proofsUsedToday = proofsToday;
      _loading = false;
    });
  }

  Future<void> _complete(Task task, Occurrence occ) async {
    final clock = ref.read(clockProvider);
    final completionRepo = ref.read(completionRepositoryProvider);
    final result = await completionRepo.completeOccurrence(
      taskId: task.id,
      occurrenceDate: clock.today(),
      slot: occ.slot,
    );
    if (result is! CompletionRecorded && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rejected: ${result.runtimeType}')),
      );
    }
    await _reload();
  }

  Future<void> _archive(Task task) async {
    await ref.read(taskRepositoryProvider).archiveTask(task.id);
    await _reload();
  }

  /// Phase 2a proof path: capture (camera or gallery), compress, persist,
  /// verify. Reports the outcome in a snackbar; the Phase 1 checkbox path
  /// above stays untouched.
  Future<void> _completeWithProof(
    Task task,
    Occurrence occ,
    ProofSource source,
  ) async {
    final clock = ref.read(clockProvider);
    final proofFlow = ref.read(proofFlowServiceProvider);

    final ProofFlowResult flowResult;
    _proofFlowInProgress = true;
    try {
      flowResult = await proofFlow.completeWithProof(
        taskId: task.id,
        occurrenceDate: clock.today(),
        slot: occ.slot,
        source: source,
      );
    } finally {
      _proofFlowInProgress = false;
    }

    if (mounted) {
      switch (flowResult) {
        case ProofFlowCancelled():
          break; // user backed out of the picker; nothing to report
        case ProofFlowCompleted(result: final completionResult):
          _showProofOutcome(completionResult);
      }
    }

    await _reload();
  }

  void _showProofOutcome(CompleteOccurrenceResult result) {
    final message = switch (result) {
      CompletionRecorded() => 'Verified',
      CompletionPendingVerification() =>
        'Pending (verifier unavailable, will retry)',
      CompletionRejectedByVerifier(
        :final verdict,
        :final attemptsRemaining,
      ) =>
        'Rejected: ${verdict.reason} ($attemptsRemaining attempt(s) '
            'remaining today)',
      CompletionRejectedStalePhoto() => 'Rejected: photo too old',
      CompletionRejectedAttemptsExhausted() =>
        'Rejected: no attempts remaining today for this task',
      CompletionRejectedDailyCapReached() =>
        'Rejected: daily proof cap reached',
      CompletionRejectedBackfill() => 'Rejected: cannot complete a past date',
      CompletionRejectedNotScheduled() =>
        'Rejected: not scheduled for this slot today',
      CompletionRejectedTaskNotFound() => 'Rejected: task not found',
      CompletionRejectedAlreadyCompleted() => 'Rejected: already completed',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _retryPending() async {
    final report = await ref.read(proofRetryServiceProvider).runOnce();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Retry: verified ${report.verified}, rejected ${report.rejected}, '
          'still pending ${report.stillPending}, skipped ${report.skipped}',
        ),
      ));
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final verifierMode = ref.watch(debugVerifierModeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cairn: Phase 1 debug'),
        actions: [
          PopupMenuButton<DebugVerifierMode>(
            tooltip: 'Fake verifier mode',
            initialValue: verifierMode,
            onSelected: (mode) =>
                ref.read(debugVerifierModeProvider.notifier).state = mode,
            itemBuilder: (context) => DebugVerifierMode.values
                .map((mode) => PopupMenuItem(
                      value: mode,
                      child: Text('Verifier: ${mode.name}'),
                    ))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: Text('Verifier: ${verifierMode.name}')),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Retry pending',
            onPressed: _retryPending,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showNewTaskDialog(context, ref);
          await _reload();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildAltitudeCard(),
                  const SizedBox(height: 16),
                  if (_rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No active tasks. Tap + to add one.'),
                    ),
                  for (final row in _rows) _buildTaskCard(row),
                ],
              ),
            ),
    );
  }

  Widget _buildAltitudeCard() {
    final rank = _rank;
    final dailyCap = ref.read(proofPolicyProvider).dailyCap;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Altitude: $_totalAltitude m',
                style: Theme.of(context).textTheme.titleLarge),
            Text(rank == null
                ? '-'
                : rank.metresToNext == null
                    ? '${rank.tier.label} (top rank)'
                    : '${rank.tier.label} (${rank.metresToNext} m to next)'),
            if (_pendingAltitude > 0)
              Text(
                '+$_pendingAltitude m pending verification',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            Text('Proofs today: $_proofsUsedToday/$dailyCap'),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(_TaskRow row) {
    final attemptsCap = ref.read(proofPolicyProvider).attemptsPerTaskPerDay;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(row.task.title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.archive_outlined),
                  tooltip: 'Archive',
                  onPressed: () => _archive(row.task),
                ),
              ],
            ),
            Text(
              'Streak: ${row.currentStreak}   ·   Longest: ${row.longestStreak}',
            ),
            Text('Attempts today: ${row.attemptsUsedToday}/$attemptsCap'),
            const SizedBox(height: 4),
            if (row.todayOccurrences.isEmpty)
              const Text('Not scheduled today')
            else
              for (final occ in row.todayOccurrences)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: row.completedSlotsToday.contains(occ.slot),
                      title: Text(occ.time ?? 'Slot ${occ.slot}'),
                      onChanged: row.completedSlotsToday.contains(occ.slot)
                          ? null
                          : (_) => _complete(row.task, occ),
                    ),
                    if (!row.completedSlotsToday.contains(occ.slot))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.camera_alt_outlined,
                                  size: 18),
                              label: const Text('Proof (camera)'),
                              onPressed: () => _completeWithProof(
                                row.task,
                                occ,
                                ProofSource.camera,
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.photo_library_outlined,
                                  size: 18),
                              label: const Text('Proof (gallery)'),
                              onPressed: () => _completeWithProof(
                                row.task,
                                occ,
                                ProofSource.gallery,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
