import 'dart:async';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../db/database.dart';
import '../repo/completion_repository.dart';
import 'photo_capture.dart';

/// Runs a single batch of pending-verification retries.
///
/// Deliberately free of any lifecycle or plugin dependency (that's
/// [ProofRetryTrigger]'s job) so it stays directly unit-testable: a fake
/// [CompletionRepository] and [ProofPhotoStore] are all a test needs.
class ProofRetryService {
  final CompletionRepository _completionRepository;
  final ProofPhotoStore _photoStore;
  final StreamController<PendingRetryReport> _reportsController =
      StreamController<PendingRetryReport>.broadcast();

  ProofRetryService(this._completionRepository, this._photoStore);

  /// Emits the report from every [runOnce] call, whoever triggered it (the
  /// connectivity/foreground trigger, or a manual button), so a background
  /// retry that would otherwise be invisible can be surfaced by a listener
  /// (e.g. the debug screen).
  Stream<PendingRetryReport> get reports => _reportsController.stream;

  Future<PendingRetryReport> runOnce() async {
    final report = await _completionRepository.retryPendingVerifications(
      loadBytes: _loadBytes,
    );
    _reportsController.add(report);
    return report;
  }

  Future<Uint8List?> _loadBytes(Completion completion) async {
    final path = completion.proofPhotoPath;
    if (path == null) return null;
    return _photoStore.load(path);
  }

  /// Closes the report stream. Called from the owning provider's
  /// `ref.onDispose`.
  void dispose() {
    unawaited(_reportsController.close());
  }
}

/// Coarse connectivity classification used only to decide whether a
/// connectivity update is a real transition into connectivity.
/// Deliberately doesn't depend on connectivity_plus's own result type, so
/// [isReconnectTransition] stays a pure, directly unit-testable function;
/// [ProofRetryTrigger] is what translates a connectivity_plus emission into
/// this before calling it.
enum ConnectivityState { unknown, none, connected }

/// True iff moving from [previous] to [current] is a transition *into*
/// connectivity: the previously known state was none or unknown, and the
/// new state is connected. False for every other case, in particular an
/// unchanged connected state (which connectivity_plus can and does re-emit
/// on its own), so a retry fires only on a genuine reconnect, not on every
/// emission of the stream.
///
/// A pure function with no plugin dependency, so it's unit-testable without
/// a platform channel.
bool isReconnectTransition(
  ConnectivityState previous,
  ConnectivityState current,
) {
  if (current != ConnectivityState.connected) return false;
  return previous != ConnectivityState.connected;
}

/// Fires [ProofRetryService.runOnce] once at [start] (so pendings from a
/// previous session resolve at launch), on app foreground, and on a genuine
/// transition into connectivity (see [isReconnectTransition]) while the app
/// is running.
///
/// Takes a factory that resolves the current [ProofRetryService] at call
/// time, rather than a fixed instance, so the trigger itself can be built
/// once (e.g. by a provider with no watch dependency on anything the
/// verifier depends on) and still always run against an up-to-date
/// repository, without being torn down and rebuilt whenever that dependency
/// chain changes. Rebuilding used to re-subscribe to connectivity_plus,
/// whose Android stream emits the current network state immediately on
/// subscribe, which could run a retry with a *just-changed* verifier before
/// the caller expected it to; resolving the service lazily per call removes
/// that rebuild entirely.
///
/// An in-flight flag stops overlapping triggers (e.g. a foreground resume
/// and a connectivity change landing back-to-back) from stacking concurrent
/// retry batches.
class ProofRetryTrigger {
  final ProofRetryService Function() _resolveService;
  AppLifecycleListener? _lifecycleListener;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _running = false;
  ConnectivityState _lastKnownState = ConnectivityState.unknown;

  ProofRetryTrigger(this._resolveService);

  /// Starts listening. Call once, typically at app start.
  ///
  /// The connectivity subscription is best-effort: on a platform/harness
  /// where connectivity_plus's platform channel isn't available (e.g. a
  /// MissingPluginException in a test harness or an unsupported platform),
  /// setting it up must not take the trigger, or the app, down with it. The
  /// retry is an optimisation on top of an already-recorded, already-counted
  /// pending completion, so the foreground path alone is a fine fallback.
  void start() {
    _lifecycleListener = AppLifecycleListener(onResume: _runGuarded);

    // Deliberate: resolve pendings from a previous session right away, at
    // launch, regardless of what (or whether) connectivity_plus goes on to
    // report. This is intentionally decoupled from the connectivity
    // subscription below so it isn't at the mercy of the plugin's own
    // subscribe-time emission.
    _runGuarded();

    try {
      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen(
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
          // asynchronously): swallow it, foreground-triggered retries still
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
    unawaited(
      _resolveService().runOnce().whenComplete(() => _running = false),
    );
  }

  /// Stops listening and releases the lifecycle/connectivity subscriptions.
  void dispose() {
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    unawaited(_connectivitySubscription?.cancel());
    _connectivitySubscription = null;
  }
}
