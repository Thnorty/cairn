import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../models/local_date.dart';
import '../models/occurrence.dart';
import '../providers.dart';
import '../repo/completion_repository.dart';
import '../services/points_service.dart';
import 'new_task_dialog.dart';

/// Phase 1 debug screen: no design system, just enough to exercise the data
/// layer. Lists today's occurrences per task, lets you mark them complete,
/// and shows per-task streak plus total altitude/rank. Real screens are
/// implemented from `design/` in later phases — this one deliberately isn't.
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

  _TaskRow({
    required this.task,
    required this.todayOccurrences,
    required this.completedSlotsToday,
    required this.currentStreak,
    required this.longestStreak,
  });
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  bool _loading = true;
  List<_TaskRow> _rows = [];
  int _totalAltitude = 0;
  Rank? _rank;

  @override
  void initState() {
    super.initState();
    _reload();
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
      ));
    }

    final altitude = await completionRepo.totalAltitude();

    if (!mounted) return;
    setState(() {
      _rows = rows;
      _totalAltitude = altitude;
      _rank = points.rankFor(altitude);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cairn — Phase 1 debug')),
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
                    : '${rank.tier.label} — ${rank.metresToNext} m to next'),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(_TaskRow row) {
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
            const SizedBox(height: 4),
            if (row.todayOccurrences.isEmpty)
              const Text('Not scheduled today')
            else
              for (final occ in row.todayOccurrences)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: row.completedSlotsToday.contains(occ.slot),
                  title: Text(occ.time ?? 'Slot ${occ.slot}'),
                  onChanged: row.completedSlotsToday.contains(occ.slot)
                      ? null
                      : (_) => _complete(row.task, occ),
                ),
          ],
        ),
      ),
    );
  }
}
