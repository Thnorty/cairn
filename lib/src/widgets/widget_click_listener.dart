import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers.dart';
import '../ui/proof/proof_entry.dart';

/// Provider for incoming widget click URIs while running.
final widgetClicksProvider = StreamProvider<Uri?>((ref) {
  final updater = ref.watch(widgetUpdaterProvider);
  return updater.widgetClicks;
});

/// Listens for native home-screen widget click events and routes to the
/// appropriate flow (such as direct tap-to-camera for habit proofing).
class WidgetClickListener extends ConsumerStatefulWidget {
  const WidgetClickListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WidgetClickListener> createState() =>
      _WidgetClickListenerState();
}

class _WidgetClickListenerState extends ConsumerState<WidgetClickListener> {
  bool _routing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialLaunch();
    });
  }

  Future<void> _checkInitialLaunch() async {
    final updater = ref.read(widgetUpdaterProvider);
    final initialUri = await updater.initiallyLaunchedUri();
    if (initialUri != null && mounted) {
      await _handleUri(initialUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(widgetClicksProvider, (_, next) {
      final uri = next.asData?.value;
      if (uri != null) unawaited(_handleUri(uri));
    });
    return widget.child;
  }

  Future<void> _handleUri(Uri uri) async {
    if (_routing) return;
    _routing = true;

    try {
      if (uri.scheme == 'cairn' && uri.host == 'prove') {
        final taskId = uri.queryParameters['taskId'];
        final slot = int.tryParse(uri.queryParameters['slot'] ?? '0') ?? 0;
        if (taskId == null || taskId.isEmpty) return;

        final today = ref.read(clockProvider).today();
        final tasks = await ref.read(taskRepositoryProvider).activeTasks();
        Task? task;
        for (final candidate in tasks) {
          if (candidate.id == taskId) {
            task = candidate;
            break;
          }
        }
        if (task == null || !mounted) return;

        await startProofFlow(
          context,
          ref,
          taskId: task.id,
          taskTitle: task.title,
          occurrenceDate: today,
          slot: slot,
        );
      }
    } finally {
      _routing = false;
    }
  }
}
