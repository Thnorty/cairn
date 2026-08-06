import 'dart:async';

import 'package:flutter/widgets.dart';

import '../db/database.dart';
import '../services/notification_planner.dart';
import 'notification_scheduler.dart';

/// Fires a fresh `NotificationPlanner.plan()` -> `NotificationScheduler.scheduleAll()`
/// cycle at [start] (so the schedule is current for whatever session is
/// beginning), on every app foreground - the same lifecycle recipe
/// `ProofRetryTrigger`/`SyncTrigger` already use (`AppLifecycleListener(onResume: ...)`)
/// - and reactively whenever the `tasks` or `completions` tables change.
///
/// That last part is what covers "re-plan after a completion and after any
/// task create/edit/archive/delete" without a single call-site change
/// anywhere else in the app: every write to either table already goes
/// through `TaskRepository`/`CompletionRepository`, and a plain
/// `db.customSelect('SELECT 1', readsFrom: {...}).watch()` re-emits on every
/// one of those writes - the exact same reactivity recipe
/// `HomeService.watchToday`/`StatsService.watchStats`/`TrailService.watchTrail`
/// already rely on, reused here instead of duplicated. `connectivity_plus`
/// is deliberately not involved (unlike `SyncTrigger`): scheduling is
/// entirely local, nothing here depends on network reachability.
///
/// [NotificationPlanner.plan] never throws by design (see its own doc
/// comment), but [runOnce] wraps the whole cycle defensively anyway - the
/// same last-resort backstop `SyncTrigger.runOnce` applies around
/// `SyncService.syncOnce` - so a planning or scheduling failure can never
/// take the app down with it.
///
/// Takes factories that resolve the current `NotificationPlanner`/
/// `NotificationScheduler` at call time, rather than fixed instances,
/// mirroring `ProofRetryTrigger`/`SyncTrigger`'s own rationale: this trigger
/// is built once, with its lifecycle listener/database subscription started
/// exactly once, while always running against up-to-date dependencies.
///
/// An in-flight flag stops overlapping triggers (e.g. a foreground resume
/// landing while a database-change replan is still running) from stacking
/// concurrent planning cycles.
class NotificationTrigger {
  final AppDatabase _db;
  final NotificationPlanner Function() _resolvePlanner;
  final NotificationScheduler Function() _resolveScheduler;

  AppLifecycleListener? _lifecycleListener;
  StreamSubscription<void>? _dbSubscription;
  bool _running = false;

  NotificationTrigger(
    this._db,
    this._resolvePlanner,
    this._resolveScheduler,
  );

  /// Starts listening. Call once, typically at app start.
  void start() {
    _lifecycleListener = AppLifecycleListener(onResume: _runGuarded);

    // Deliberate: plan right away, at launch, regardless of what (or
    // whether) the database-change subscription below goes on to emit -
    // the same "don't wait on the other trigger source" rationale
    // ProofRetryTrigger/SyncTrigger already document for their own
    // immediate start-of-day call.
    _runGuarded();

    _dbSubscription = _db
        .customSelect('SELECT 1', readsFrom: {_db.tasks, _db.completions})
        .watch()
        .listen(
          (_) => _runGuarded(),
          onError: (Object _, StackTrace _) {
            // Stream-level failure: swallow it, the foreground path above
            // still keeps the schedule reasonably current.
          },
        );
  }

  void _runGuarded() {
    if (_running) return;
    _running = true;
    unawaited(runOnce().whenComplete(() => _running = false));
  }

  /// Runs one planning cycle right now. Exposed separately from [start]'s
  /// lifecycle wiring so it is directly unit-testable without touching
  /// [AppLifecycleListener] or a live database-change subscription - the
  /// same reason `SyncTrigger.runOnce` is split out from its own lifecycle
  /// plumbing. Does not honor the in-flight guard [start]'s callbacks use;
  /// callers driving this directly are responsible for not overlapping
  /// calls if that matters to them.
  Future<void> runOnce() async {
    try {
      final plan = await _resolvePlanner().plan();
      await _resolveScheduler().scheduleAll(plan);
    } catch (_) {
      // Never let a planning/scheduling failure crash the app.
    }
  }

  /// Stops listening and releases the lifecycle/database subscriptions.
  void dispose() {
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    unawaited(_dbSubscription?.cancel());
    _dbSubscription = null;
  }
}
