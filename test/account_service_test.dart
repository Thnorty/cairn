import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/settings_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/account_error.dart';
import 'package:cairn/src/services/account_service.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/fake_account_deleter.dart';
import 'support/fake_auth_service.dart';
import 'support/fake_premium_service.dart';
import 'support/fake_sync_transport.dart';

void main() {
  group('create-account flow', () {
    test('startCreateAccount holds the password; confirmCreateAccount '
        'verifies the code then sets the held password', () async {
      final auth = FakeAuthService();
      final db = inMemoryDatabase();
      final transport = FakeSyncTransport();
      final clock = FixedClock(d(2026, 7, 10));
      final service = AccountService(
        auth: auth,
        sync: SyncService(db, transport),
        completions: CompletionRepository(
          db,
          clock,
          verifier: FakeProofVerifier(),
        ),
        tasks: TaskRepository(db, clock),
      );

      await service.startCreateAccount(
        email: 'new@example.com',
        password: 'held-secret',
      );
      expect(auth.startEmailUpgradeCalls, ['new@example.com']);
      // Nothing set yet: the password is held, not applied.
      expect(auth.setPasswordCalls, isEmpty);

      await service.confirmCreateAccount('123456');
      expect(auth.verifyEmailCodeCalls, ['123456']);
      expect(auth.setPasswordCalls, ['held-secret']);

      await db.close();
    });

    test('confirmCreateAccount with no prior startCreateAccount throws '
        'StateError and never touches the auth service', () async {
      final auth = FakeAuthService();
      final db = inMemoryDatabase();
      final transport = FakeSyncTransport();
      final clock = FixedClock(d(2026, 7, 10));
      final service = AccountService(
        auth: auth,
        sync: SyncService(db, transport),
        completions: CompletionRepository(
          db,
          clock,
          verifier: FakeProofVerifier(),
        ),
        tasks: TaskRepository(db, clock),
      );

      await expectLater(
        service.confirmCreateAccount('123456'),
        throwsA(isA<StateError>()),
      );
      expect(auth.verifyEmailCodeCalls, isEmpty);

      await db.close();
    });

    test('a failed startCreateAccount does not hold the password: a later '
        'confirmCreateAccount still throws StateError', () async {
      final auth = FakeAuthService()
        ..startEmailUpgradeError =
            const AccountException(AccountError.emailInUse);
      final db = inMemoryDatabase();
      final transport = FakeSyncTransport();
      final clock = FixedClock(d(2026, 7, 10));
      final service = AccountService(
        auth: auth,
        sync: SyncService(db, transport),
        completions: CompletionRepository(
          db,
          clock,
          verifier: FakeProofVerifier(),
        ),
        tasks: TaskRepository(db, clock),
      );

      await expectLater(
        service.startCreateAccount(email: 'taken@example.com', password: 'x'),
        throwsA(isA<AccountException>()),
      );

      await expectLater(
        service.confirmCreateAccount('123456'),
        throwsA(isA<StateError>()),
      );
      expect(auth.verifyEmailCodeCalls, isEmpty);

      await db.close();
    });
  });

  group('sign-in flow', () {
    test('local has no stones and no live tasks: signs in, replaces local '
        'with the cloud, and reports SignInComplete', () async {
      final transport = FakeSyncTransport();

      // Seed the account's cloud data via a separate device/db.
      final dbCloud = inMemoryDatabase();
      final cloudClock = FixedClock(d(2026, 7, 10), nowMillis: 1000);
      final taskRepoCloud = TaskRepository(dbCloud, cloudClock);
      final completionRepoCloud = CompletionRepository(
        dbCloud,
        cloudClock,
        verifier: FakeProofVerifier(),
      );
      final cloudTask = await taskRepoCloud.createTask(
        title: 'Cloud task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await completionRepoCloud.completeOccurrence(
        taskId: cloudTask.id,
        occurrenceDate: d(2026, 7, 10),
      );
      await SyncService(dbCloud, transport).syncOnce();

      // This device: a fresh install, no local data at all.
      final dbA = inMemoryDatabase();
      final localClock = FixedClock(d(2026, 7, 10));
      final auth = FakeAuthService(userId: 'anon-user', isAnonymousUser: true);
      final service = AccountService(
        auth: auth,
        sync: SyncService(dbA, transport),
        completions: CompletionRepository(
          dbA,
          localClock,
          verifier: FakeProofVerifier(),
        ),
        tasks: TaskRepository(dbA, localClock),
      );

      final outcome =
          await service.signIn(email: 'a@b.com', password: 'hunter2');

      expect(outcome, isA<SignInComplete>());
      expect((outcome as SignInComplete).syncResult.isFullSuccess, isTrue);
      expect(auth.signInWithPasswordCalls, hasLength(1));
      expect(auth.signInWithPasswordCalls.single.email, 'a@b.com');

      final localTasks = await dbA.select(dbA.tasks).get();
      expect(localTasks.map((t) => t.id).toSet(), {cloudTask.id});

      await dbCloud.close();
      await dbA.close();
    });

    test('local has stones: signs in but applies nothing, reporting '
        'SignInNeedsTrailChoice with both summaries', () async {
      final transport = FakeSyncTransport();

      final dbA = inMemoryDatabase();
      final localClock = FixedClock(d(2026, 7, 10), nowMillis: 500);
      final taskRepoA = TaskRepository(dbA, localClock);
      final completionRepoA = CompletionRepository(
        dbA,
        localClock,
        verifier: FakeProofVerifier(),
      );
      final localTask = await taskRepoA.createTask(
        title: 'Local task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await completionRepoA.completeOccurrence(
        taskId: localTask.id,
        occurrenceDate: d(2026, 7, 10),
      );

      final auth = FakeAuthService();
      final service = AccountService(
        auth: auth,
        sync: SyncService(dbA, transport),
        completions: completionRepoA,
        tasks: taskRepoA,
      );

      final outcome =
          await service.signIn(email: 'a@b.com', password: 'hunter2');

      expect(outcome, isA<SignInNeedsTrailChoice>());
      final choice = outcome as SignInNeedsTrailChoice;
      expect(choice.local.stones, 1);
      expect(
        choice.local.lastClimbAt,
        DateTime.fromMillisecondsSinceEpoch(500),
      );
      expect(choice.remote.stones, 0); // cloud is empty in this scenario

      // Nothing applied yet: the local task must still be exactly what it
      // was before signIn.
      final localTasks = await dbA.select(dbA.tasks).get();
      expect(localTasks.map((t) => t.id).toSet(), {localTask.id});

      await dbA.close();
    });

    test('local has a live task but 0 stones: signs in but applies nothing, '
        'still reporting SignInNeedsTrailChoice (a locally-created habit '
        'must never be silently wiped)', () async {
      final transport = FakeSyncTransport();

      final dbA = inMemoryDatabase();
      final localClock = FixedClock(d(2026, 7, 10), nowMillis: 500);
      final taskRepoA = TaskRepository(dbA, localClock);
      final completionRepoA = CompletionRepository(
        dbA,
        localClock,
        verifier: FakeProofVerifier(),
      );
      // Created, but never completed: local.stones is 0.
      final localTask = await taskRepoA.createTask(
        title: 'Freshly created habit',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final auth = FakeAuthService();
      final service = AccountService(
        auth: auth,
        sync: SyncService(dbA, transport),
        completions: completionRepoA,
        tasks: taskRepoA,
      );

      final outcome =
          await service.signIn(email: 'a@b.com', password: 'hunter2');

      expect(outcome, isA<SignInNeedsTrailChoice>());
      final choice = outcome as SignInNeedsTrailChoice;
      expect(choice.local.stones, 0);
      expect(choice.remote.stones, 0);

      // Nothing applied yet: the local task must still exist.
      final localTasks = await dbA.select(dbA.tasks).get();
      expect(localTasks.map((t) => t.id).toSet(), {localTask.id});

      await dbA.close();
    });

    test('keepThisDevice delegates to SyncService.replaceCloudWithLocal',
        () async {
      final transport = FakeSyncTransport();
      final dbA = inMemoryDatabase();
      final clock = FixedClock(d(2026, 7, 10), nowMillis: 2000);
      final taskRepoA = TaskRepository(dbA, clock);
      final task = await taskRepoA.createTask(
        title: 'Local task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

      final service = AccountService(
        auth: FakeAuthService(),
        sync: SyncService(dbA, transport, clock: clock),
        completions: CompletionRepository(dbA, clock, verifier: FakeProofVerifier()),
        tasks: taskRepoA,
      );

      final result = await service.keepThisDevice();
      expect(result.isFullSuccess, isTrue);
      expect(transport.taskById(task.id), isNotNull);
      expect(transport.taskById(task.id)!.deletedAt, isNull);

      await dbA.close();
    });

    test('useAccount delegates to SyncService.replaceLocalWithCloud',
        () async {
      final transport = FakeSyncTransport();

      final dbCloud = inMemoryDatabase();
      final cloudClock = FixedClock(d(2026, 7, 10), nowMillis: 1000);
      final taskRepoCloud = TaskRepository(dbCloud, cloudClock);
      final cloudTask = await taskRepoCloud.createTask(
        title: 'Cloud task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await SyncService(dbCloud, transport).syncOnce();

      final dbA = inMemoryDatabase();
      final localClock = FixedClock(d(2026, 7, 10));
      final service = AccountService(
        auth: FakeAuthService(),
        sync: SyncService(dbA, transport),
        completions: CompletionRepository(
          dbA,
          localClock,
          verifier: FakeProofVerifier(),
        ),
        tasks: TaskRepository(dbA, localClock),
      );

      final result = await service.useAccount();
      expect(result.isFullSuccess, isTrue);
      final localTasks = await dbA.select(dbA.tasks).get();
      expect(localTasks.map((t) => t.id).toSet(), {cloudTask.id});

      await dbCloud.close();
      await dbA.close();
    });
  });

  group('password-reset flow', () {
    test('forwards each step to AuthService with the right arguments',
        () async {
      final auth = FakeAuthService();
      final db = inMemoryDatabase();
      final transport = FakeSyncTransport();
      final clock = FixedClock(d(2026, 7, 10));
      final service = AccountService(
        auth: auth,
        sync: SyncService(db, transport),
        completions: CompletionRepository(
          db,
          clock,
          verifier: FakeProofVerifier(),
        ),
        tasks: TaskRepository(db, clock),
      );

      await service.sendPasswordResetCode('a@b.com');
      expect(auth.sendPasswordResetCodeCalls, ['a@b.com']);

      await service.verifyPasswordResetCode(email: 'a@b.com', code: '111111');
      expect(auth.verifyPasswordResetCodeCalls, hasLength(1));
      expect(auth.verifyPasswordResetCodeCalls.single.email, 'a@b.com');
      expect(auth.verifyPasswordResetCodeCalls.single.code, '111111');

      await service.setNewPassword('new-secret');
      expect(auth.setPasswordCalls, ['new-secret']);

      await db.close();
    });
  });

  group('sign-out', () {
    test('forwards to AuthService.signOut and calls PremiumService.logOut', () async {
      final auth = FakeAuthService(userId: 'real-user', isAnonymousUser: false);
      final fakePremium = FakePremiumService();
      final db = inMemoryDatabase();
      final transport = FakeSyncTransport();
      final clock = FixedClock(d(2026, 7, 10));
      final service = AccountService(
        auth: auth,
        sync: SyncService(db, transport),
        completions: CompletionRepository(
          db,
          clock,
          verifier: FakeProofVerifier(),
        ),
        tasks: TaskRepository(db, clock),
        premium: fakePremium,
      );

      await service.signOut();
      expect(fakePremium.logOutCount, 1);
      expect(auth.signOutCallCount, 1);
      expect(service.isAnonymous, isTrue);

      await db.close();
    });
  });

  group('display name carry-up/adoption (Cairn Onboarding Name.dc.html)', () {
    test('confirmCreateAccount pushes the local stored name up to the new '
        "account's metadata best-effort", () async {
      final auth = FakeAuthService();
      final db = inMemoryDatabase();
      await SettingsRepository(db).setDisplayName('Sam');
      final transport = FakeSyncTransport();
      final clock = FixedClock(d(2026, 7, 10));
      final service = AccountService(
        auth: auth,
        sync: SyncService(db, transport),
        completions: CompletionRepository(db, clock, verifier: FakeProofVerifier()),
        tasks: TaskRepository(db, clock),
        settings: SettingsRepository(db),
      );

      await service.startCreateAccount(email: 'new@example.com', password: 'held-secret');
      await service.confirmCreateAccount('123456');

      expect(auth.setDisplayNameCalls, ['Sam']);

      await db.close();
    });

    test('confirmCreateAccount with no local name never touches '
        'setDisplayName', () async {
      final auth = FakeAuthService();
      final db = inMemoryDatabase();
      final transport = FakeSyncTransport();
      final clock = FixedClock(d(2026, 7, 10));
      final service = AccountService(
        auth: auth,
        sync: SyncService(db, transport),
        completions: CompletionRepository(db, clock, verifier: FakeProofVerifier()),
        tasks: TaskRepository(db, clock),
        settings: SettingsRepository(db),
      );

      await service.startCreateAccount(email: 'new@example.com', password: 'held-secret');
      await service.confirmCreateAccount('123456');

      expect(auth.setDisplayNameCalls, isEmpty);

      await db.close();
    });

    test('a setDisplayName failure during confirmCreateAccount is '
        'best-effort: account creation still succeeds (never fails or '
        'rolls back)', () async {
      final auth = FakeAuthService()..setDisplayNameError = Exception('offline');
      final db = inMemoryDatabase();
      await SettingsRepository(db).setDisplayName('Sam');
      final transport = FakeSyncTransport();
      final clock = FixedClock(d(2026, 7, 10));
      final service = AccountService(
        auth: auth,
        sync: SyncService(db, transport),
        completions: CompletionRepository(db, clock, verifier: FakeProofVerifier()),
        tasks: TaskRepository(db, clock),
        settings: SettingsRepository(db),
      );

      await service.startCreateAccount(email: 'new@example.com', password: 'held-secret');
      // Must not throw despite the auth fake being primed to fail
      // setDisplayName.
      await service.confirmCreateAccount('123456');
      expect(auth.setPasswordCalls, ['held-secret']); // account creation itself completed

      await db.close();
    });

    test('signIn (SignInComplete case: empty local) adopts the account\'s '
        'stored name into local settings, name included per onboarding '
        'sign-in', () async {
      final transport = FakeSyncTransport();
      final dbA = inMemoryDatabase();
      final localClock = FixedClock(d(2026, 7, 10));
      final auth = FakeAuthService(userId: 'anon-user', isAnonymousUser: true);
      final service = AccountService(
        auth: auth,
        sync: SyncService(dbA, transport),
        completions: CompletionRepository(dbA, localClock, verifier: FakeProofVerifier()),
        tasks: TaskRepository(dbA, localClock),
        settings: SettingsRepository(dbA),
      );

      // signInWithPassword on FakeAuthService doesn't itself set a
      // displayName; simulate the account already having one in its
      // metadata by setting it directly, the same shape the real gateway's
      // currentUserMetadata would already carry once signed in.
      auth.userDisplayName = 'Alex';

      final outcome = await service.signIn(email: 'a@b.com', password: 'hunter2');
      expect(outcome, isA<SignInComplete>());

      expect(await SettingsRepository(dbA).displayName(), 'Alex');

      await dbA.close();
    });

    test('signIn (SignInComplete case) with an older account that has no '
        'stored name leaves local untouched', () async {
      final transport = FakeSyncTransport();
      final dbA = inMemoryDatabase();
      final localClock = FixedClock(d(2026, 7, 10));
      final auth = FakeAuthService(userId: 'anon-user', isAnonymousUser: true);
      final service = AccountService(
        auth: auth,
        sync: SyncService(dbA, transport),
        completions: CompletionRepository(dbA, localClock, verifier: FakeProofVerifier()),
        tasks: TaskRepository(dbA, localClock),
        settings: SettingsRepository(dbA),
      );

      // auth.userDisplayName stays null: an older account with no metadata.
      final outcome = await service.signIn(email: 'a@b.com', password: 'hunter2');
      expect(outcome, isA<SignInComplete>());

      expect(await SettingsRepository(dbA).displayName(), isNull);

      await dbA.close();
    });

    test('keepThisDevice pushes the local stored name up to the account, '
        'the same "this device wins" direction as the trail data', () async {
      final transport = FakeSyncTransport();
      final dbA = inMemoryDatabase();
      await SettingsRepository(dbA).setDisplayName('Sam');
      final clock = FixedClock(d(2026, 7, 10), nowMillis: 2000);
      final taskRepoA = TaskRepository(dbA, clock);
      await taskRepoA.createTask(
        title: 'Local task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final auth = FakeAuthService();
      final service = AccountService(
        auth: auth,
        sync: SyncService(dbA, transport, clock: clock),
        completions: CompletionRepository(dbA, clock, verifier: FakeProofVerifier()),
        tasks: taskRepoA,
        settings: SettingsRepository(dbA),
      );

      await service.keepThisDevice();

      expect(auth.setDisplayNameCalls, ['Sam']);

      await dbA.close();
    });

    test('keepThisDevice with no local name never touches setDisplayName',
        () async {
      final transport = FakeSyncTransport();
      final dbA = inMemoryDatabase();
      final clock = FixedClock(d(2026, 7, 10), nowMillis: 2000);
      final taskRepoA = TaskRepository(dbA, clock);
      await taskRepoA.createTask(
        title: 'Local task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      final auth = FakeAuthService();
      final service = AccountService(
        auth: auth,
        sync: SyncService(dbA, transport, clock: clock),
        completions: CompletionRepository(dbA, clock, verifier: FakeProofVerifier()),
        tasks: taskRepoA,
        settings: SettingsRepository(dbA),
      );

      await service.keepThisDevice();

      expect(auth.setDisplayNameCalls, isEmpty);

      await dbA.close();
    });

    test('useAccount adopts the account\'s stored name into local settings, '
        'the same "account wins" direction as the trail data', () async {
      final transport = FakeSyncTransport();
      final dbCloud = inMemoryDatabase();
      final cloudClock = FixedClock(d(2026, 7, 10), nowMillis: 1000);
      final taskRepoCloud = TaskRepository(dbCloud, cloudClock);
      await taskRepoCloud.createTask(
        title: 'Cloud task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await SyncService(dbCloud, transport).syncOnce();

      final dbA = inMemoryDatabase();
      final localClock = FixedClock(d(2026, 7, 10));
      final auth = FakeAuthService()..userDisplayName = 'Alex';
      final service = AccountService(
        auth: auth,
        sync: SyncService(dbA, transport),
        completions: CompletionRepository(dbA, localClock, verifier: FakeProofVerifier()),
        tasks: TaskRepository(dbA, localClock),
        settings: SettingsRepository(dbA),
      );

      await service.useAccount();

      expect(await SettingsRepository(dbA).displayName(), 'Alex');

      await dbCloud.close();
      await dbA.close();
    });

    test('useAccount with an older account that has no stored name leaves '
        'local untouched rather than clearing it', () async {
      final transport = FakeSyncTransport();
      final dbCloud = inMemoryDatabase();
      final cloudClock = FixedClock(d(2026, 7, 10), nowMillis: 1000);
      final taskRepoCloud = TaskRepository(dbCloud, cloudClock);
      await taskRepoCloud.createTask(
        title: 'Cloud task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );
      await SyncService(dbCloud, transport).syncOnce();

      final dbA = inMemoryDatabase();
      await SettingsRepository(dbA).setDisplayName('LocalName');
      final localClock = FixedClock(d(2026, 7, 10));
      // auth.userDisplayName stays null: an older account with no metadata.
      final auth = FakeAuthService();
      final service = AccountService(
        auth: auth,
        sync: SyncService(dbA, transport),
        completions: CompletionRepository(dbA, localClock, verifier: FakeProofVerifier()),
        tasks: TaskRepository(dbA, localClock),
        settings: SettingsRepository(dbA),
      );

      await service.useAccount();

      // Untouched, not cleared - the local name survives even though the
      // account itself replaced every other piece of local data.
      expect(await SettingsRepository(dbA).displayName(), 'LocalName');

      await dbCloud.close();
      await dbA.close();
    });
  });

  group('delete-account flow', () {
    test('aborts on a wrong password and destroys nothing', () async {
      final auth = FakeAuthService(
        userId: 'user-123',
        userEmail: 'ada@example.com',
        isAnonymousUser: false,
      )..signInWithPasswordError =
          const AccountException(AccountError.invalidCredentials);
      final db = inMemoryDatabase();
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(
        db,
        clock,
        verifier: FakeProofVerifier(),
      );
      final task = await taskRepo.createTask(
        title: 'My task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
        userId: 'user-123',
      );
      await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      await completionRepo.backfillUserId('user-123');

      final deleter = FakeAccountDeleter();
      final service = AccountService(
        auth: auth,
        sync: SyncService(db, FakeSyncTransport()),
        completions: completionRepo,
        tasks: taskRepo,
        deleter: deleter,
      );

      await expectLater(
        service.deleteAccount('wrong-password'),
        throwsA(
          isA<AccountException>().having(
            (e) => e.error,
            'error',
            AccountError.invalidCredentials,
          ),
        ),
      );

      expect(deleter.callCount, 0);

      // Verify local user_id was untouched
      final taskRow = await (db.select(db.tasks)..where((t) => t.id.equals(task.id))).getSingle();
      expect(taskRow.userId, 'user-123');

      final completionRows = await db.select(db.completions).get();
      expect(completionRows.single.userId, 'user-123');

      await db.close();
    });

    test('aborts if the remote delete throws, leaving local user_id untouched', () async {
      final auth = FakeAuthService(
        userId: 'user-123',
        userEmail: 'ada@example.com',
        isAnonymousUser: false,
      );
      final db = inMemoryDatabase();
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(
        db,
        clock,
        verifier: FakeProofVerifier(),
      );
      final task = await taskRepo.createTask(
        title: 'My task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
        userId: 'user-123',
      );
      await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      await completionRepo.backfillUserId('user-123');

      final deleter = FakeAccountDeleter()..errorToThrow = Exception('Server error');
      final service = AccountService(
        auth: auth,
        sync: SyncService(db, FakeSyncTransport()),
        completions: completionRepo,
        tasks: taskRepo,
        deleter: deleter,
      );

      await expectLater(
        service.deleteAccount('valid-password'),
        throwsA(isA<Exception>()),
      );

      expect(deleter.callCount, 1);
      expect(auth.signOutCallCount, 0); // Not signed out on failure

      // Verify local user_id remains untouched
      final taskRow = await (db.select(db.tasks)..where((t) => t.id.equals(task.id))).getSingle();
      expect(taskRow.userId, 'user-123');

      final completionRows = await db.select(db.completions).get();
      expect(completionRows.single.userId, 'user-123');

      await db.close();
    });

    test('on success, local tasks/completions survive AND their user_id is NULL afterwards', () async {
      final auth = FakeAuthService(
        userId: 'user-123',
        userEmail: 'ada@example.com',
        isAnonymousUser: false,
      );
      final fakePremium = FakePremiumService(isPremium: true);
      final db = inMemoryDatabase();
      final clock = FixedClock(d(2026, 7, 10));
      final taskRepo = TaskRepository(db, clock);
      final completionRepo = CompletionRepository(
        db,
        clock,
        verifier: FakeProofVerifier(),
      );
      final task = await taskRepo.createTask(
        title: 'My task',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
        userId: 'user-123',
      );
      await completionRepo.completeOccurrence(
        taskId: task.id,
        occurrenceDate: d(2026, 7, 10),
      );
      await completionRepo.backfillUserId('user-123');

      final deleter = FakeAccountDeleter();
      final service = AccountService(
        auth: auth,
        sync: SyncService(db, FakeSyncTransport()),
        completions: completionRepo,
        tasks: taskRepo,
        premium: fakePremium,
        deleter: deleter,
      );

      await service.deleteAccount('valid-password');

      expect(deleter.callCount, 1);
      expect(fakePremium.logOutCount, 1);

      // Verify task and completion survived and user_id IS NULL
      final tasks = await db.select(db.tasks).get();
      expect(tasks, hasLength(1));
      expect(tasks.single.userId, isNull);

      final completions = await db.select(db.completions).get();
      expect(completions, hasLength(1));
      expect(completions.single.userId, isNull);

      await db.close();
    });
  });
}
