import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/account_service.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/sync/sync_service.dart';

import '../../helpers.dart';
import '../../support/fake_auth_service.dart';
import '../../support/fake_sync_transport.dart';

/// Shared widget-test rig for the Phase 4b account-upgrade screens: a real
/// [AccountService] wired to [FakeAuthService] (WO-A's own fake, so no
/// widget test in this suite ever touches the Supabase SDK) plus a real
/// in-memory database and [FakeSyncTransport], the same recipe
/// `account_service_test.dart` uses for its own unit tests. Every account
/// screen test drives the real UI against this real (but network-free)
/// orchestration layer, rather than a hand-rolled UI-only fake.
class AccountTestHarness {
  AccountTestHarness({
    required this.db,
    required this.auth,
    required this.transport,
    required this.accountService,
    required this.taskRepository,
    required this.completionRepository,
    required this.clock,
  });

  final AppDatabase db;
  final FakeAuthService auth;
  final FakeSyncTransport transport;
  final AccountService accountService;
  final TaskRepository taskRepository;
  final CompletionRepository completionRepository;
  final Clock clock;

  /// Provider overrides wiring [accountServiceProvider]/[authServiceProvider]
  /// (and the database itself, since [TaskRepository]/[CompletionRepository]
  /// providers elsewhere in the tree - e.g. `KeepWhichTrailScreen`'s peers -
  /// resolve against the same db) to this harness.
  get overrides => [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        authServiceProvider.overrideWithValue(auth),
        accountServiceProvider.overrideWithValue(accountService),
      ];
}

AccountTestHarness buildAccountTestHarness({FakeAuthService? auth}) {
  final db = inMemoryDatabase();
  final clock = FixedClock(d(2026, 7, 10));
  final fakeAuth = auth ?? FakeAuthService();
  final transport = FakeSyncTransport();
  final taskRepo = TaskRepository(db, clock);
  final completionRepo = CompletionRepository(db, clock, verifier: FakeProofVerifier());
  final sync = SyncService(db, transport);
  final accountService = AccountService(
    auth: fakeAuth,
    sync: sync,
    completions: completionRepo,
    tasks: taskRepo,
  );
  return AccountTestHarness(
    db: db,
    auth: fakeAuth,
    transport: transport,
    accountService: accountService,
    taskRepository: taskRepo,
    completionRepository: completionRepo,
    clock: clock,
  );
}
