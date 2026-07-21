import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/sync/sync_service.dart';
import 'package:cairn/src/sync/sync_trigger.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fake_sync_transport.dart';

/// Counts calls instead of doing any real work, so tests can assert whether
/// [SyncTrigger.runOnce]'s guard let a sync through without depending on
/// [SyncService]'s own pull/push behaviour (already covered by
/// `test/sync/sync_service_test.dart`).
class _CountingSyncService extends SyncService {
  int callCount = 0;

  _CountingSyncService(super.db, super.transport);

  @override
  Future<SyncResult> syncOnce() async {
    callCount++;
    return const SyncResult(pulled: true, pushed: true);
  }
}

/// Simulates a transport-level (or any other) failure bubbling out of
/// syncOnce, to prove [SyncTrigger.runOnce] never lets it escape - even
/// though [SyncService.syncOnce] itself is documented to never throw, this
/// is the trigger's own last-resort backstop.
class _ThrowingSyncService extends SyncService {
  _ThrowingSyncService(super.db, super.transport);

  @override
  Future<SyncResult> syncOnce() async {
    throw StateError('simulated syncOnce failure');
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = inMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncTrigger.runOnce guard', () {
    test('runs syncOnce when configured and signed in', () async {
      final service = _CountingSyncService(db, FakeSyncTransport());
      final trigger = SyncTrigger(
        () => service,
        isConfigured: () => true,
        isSignedIn: () => true,
      );

      await trigger.runOnce();

      expect(service.callCount, 1);
    });

    test('is a no-op when not configured', () async {
      final service = _CountingSyncService(db, FakeSyncTransport());
      final trigger = SyncTrigger(
        () => service,
        isConfigured: () => false,
        isSignedIn: () => true,
      );

      await trigger.runOnce();

      expect(service.callCount, 0);
    });

    test('is a no-op when not signed in', () async {
      final service = _CountingSyncService(db, FakeSyncTransport());
      final trigger = SyncTrigger(
        () => service,
        isConfigured: () => true,
        isSignedIn: () => false,
      );

      await trigger.runOnce();

      expect(service.callCount, 0);
    });

    test('is a no-op when neither configured nor signed in', () async {
      final service = _CountingSyncService(db, FakeSyncTransport());
      final trigger = SyncTrigger(
        () => service,
        isConfigured: () => false,
        isSignedIn: () => false,
      );

      await trigger.runOnce();

      expect(service.callCount, 0);
    });

    test('swallows an error thrown out of syncOnce', () async {
      final service = _ThrowingSyncService(db, FakeSyncTransport());
      final trigger = SyncTrigger(
        () => service,
        isConfigured: () => true,
        isSignedIn: () => true,
      );

      await expectLater(trigger.runOnce(), completes);
    });
  });
}
