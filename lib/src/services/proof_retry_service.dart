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

  ProofRetryService(this._completionRepository, this._photoStore);

  Future<PendingRetryReport> runOnce() {
    return _completionRepository.retryPendingVerifications(
      loadBytes: _loadBytes,
    );
  }

  Future<Uint8List?> _loadBytes(Completion completion) async {
    final path = completion.proofPhotoPath;
    if (path == null) return null;
    return _photoStore.load(path);
  }
}

/// Fires [ProofRetryService.runOnce] on app foreground and on regaining
/// connectivity (any non-`none` result), while the app is running.
///
/// An in-flight flag stops overlapping triggers (e.g. a foreground resume
/// and a connectivity change landing back-to-back) from stacking concurrent
/// retry batches.
class ProofRetryTrigger {
  final ProofRetryService _service;
  AppLifecycleListener? _lifecycleListener;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _running = false;

  ProofRetryTrigger(this._service);

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
    try {
      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen(
        (results) {
          if (results.any((result) => result != ConnectivityResult.none)) {
            _runGuarded();
          }
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
    unawaited(_service.runOnce().whenComplete(() => _running = false));
  }

  /// Stops listening and releases the lifecycle/connectivity subscriptions.
  void dispose() {
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    unawaited(_connectivitySubscription?.cancel());
    _connectivitySubscription = null;
  }
}
