import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../services/proof_retry_service.dart' show ConnectivityState, isReconnectTransition;
import 'sync_service.dart';

/// Fires [SyncService.syncOnce] at [start] (so pendings from a previous
/// session resolve at launch), on app foreground, and on a genuine
/// transition into connectivity (see [isReconnectTransition]) while the app
/// is running - the same lifecycle recipe as `ProofRetryTrigger`
/// (`lib/src/services/proof_retry_service.dart`), reusing its
/// [ConnectivityState]/[isReconnectTransition] rather than duplicating them.
///
/// Every run is guarded by [isConfigured] (a live Supabase project) AND
/// [isSignedIn] (a session exists): syncing with no project configured has
/// nothing to talk to, and syncing with no signed-in user has no `auth.uid()`
/// to stamp outgoing rows with (see `SupabaseSyncTransport.push`). Both
/// guards are injected functions - not read from `AppConfig`/`AuthService`
/// directly - so this class stays unit-testable without a live Supabase
/// project or session.
///
/// [SyncService.syncOnce] never throws (see its own doc comment), but the
/// guarded run is wrapped defensively anyway so a sync failure can never take
/// the app down with it.
///
/// Takes a factory that resolves the current [SyncService] at call time,
/// rather than a fixed instance, mirroring `ProofRetryTrigger`'s rationale:
/// this trigger can be built once, with its lifecycle listener/connectivity
/// subscription started exactly once, while still always running against an
/// up-to-date service.
///
/// An in-flight flag stops overlapping triggers (e.g. a foreground resume and
/// a connectivity change landing back-to-back) from stacking concurrent sync
/// cycles.
class SyncTrigger {
  final SyncService Function() _resolveService;
  final bool Function() _isConfigured;
  final bool Function() _isSignedIn;
  AppLifecycleListener? _lifecycleListener;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _running = false;
  ConnectivityState _lastKnownState = ConnectivityState.unknown;

  SyncTrigger(
    this._resolveService, {
    required bool Function() isConfigured,
    required bool Function() isSignedIn,
  })  : _isConfigured = isConfigured,
        _isSignedIn = isSignedIn;

  /// Starts listening. Call once, typically at app start.
  ///
  /// The connectivity subscription is best-effort: on a platform/harness
  /// where connectivity_plus's platform channel isn't available (e.g. a
  /// MissingPluginException in a test harness or an unsupported platform),
  /// setting it up must not take the trigger, or the app, down with it. The
  /// foreground path alone is a fine fallback.
  void start() {
    _lifecycleListener = AppLifecycleListener(onResume: _runGuarded);

    // Deliberate: attempt a sync right away, at launch, regardless of what
    // (or whether) connectivity_plus goes on to report. Decoupled from the
    // connectivity subscription below so it isn't at the mercy of the
    // plugin's own subscribe-time emission.
    _runGuarded();

    try {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        (results) {
          final newState = results.any((r) => r != ConnectivityResult.none)
              ? ConnectivityState.connected
              : ConnectivityState.none;
          if (isReconnectTransition(_lastKnownState, newState)) {
            _runGuarded();
          }
          _lastKnownState = newState;
        },
        onError: (Object _, StackTrace _) {
          // Stream-level failure (e.g. MissingPluginException surfaced
          // asynchronously): swallow it, foreground-triggered syncs still
          // work.
        },
      );
    } catch (_) {
      // Synchronous failure obtaining the stream: same fallback as above.
      _connectivitySubscription = null;
    }
  }

  void _runGuarded() {
    if (_running) return;
    _running = true;
    unawaited(runOnce().whenComplete(() => _running = false));
  }

  /// Runs one guarded sync attempt right now: a no-op unless both
  /// [isConfigured] and [isSignedIn] say so. Exposed separately from
  /// [start]'s lifecycle wiring so the guard (and error-swallowing) logic
  /// itself is directly unit-testable without touching
  /// [AppLifecycleListener] or connectivity_plus's platform channel - the
  /// same reason `ProofRetryService.runOnce` is split out from
  /// `ProofRetryTrigger`'s lifecycle plumbing. Does not honor the in-flight
  /// guard `start()`'s callbacks use; callers driving this directly are
  /// responsible for not overlapping calls if that matters to them.
  Future<void> runOnce() async {
    if (!_isConfigured() || !_isSignedIn()) return;
    try {
      await _resolveService().syncOnce();
    } catch (_) {
      // Never let a sync failure crash the app; SyncService.syncOnce
      // already reports failures via SyncResult for anyone watching, this
      // is just a last-resort backstop.
    }
  }

  /// Stops listening and releases the lifecycle/connectivity subscriptions.
  void dispose() {
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    unawaited(_connectivitySubscription?.cancel());
    _connectivitySubscription = null;
  }
}
