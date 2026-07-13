import 'dart:typed_data';

import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/proof_verdict.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/photo_capture.dart';
import 'package:cairn/src/services/proof_retry_service.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// In-memory [ProofPhotoStore] backed by a fixed map, so tests can control
/// exactly which paths "still have" bytes on disk.
class _FakeProofPhotoStore implements ProofPhotoStore {
  final Map<String, Uint8List> _files;
  _FakeProofPhotoStore(this._files);

  @override
  Future<String> save(Uint8List bytes) => throw UnimplementedError();

  @override
  Future<Uint8List?> load(String path) async => _files[path];

  @override
  Future<void> delete(String path) async => _files.remove(path);
}

const _passingVerdict = ProofVerdict(
  taskShown: true,
  confidence: 0.95,
  isScreenshotOrScreen: false,
  screenIsPlausibleProof: false,
  reason: 'clear photo',
);

void main() {
  late AppDatabase db;

  setUp(() {
    db = inMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  test('runOnce resolves a pending whose bytes the store still has',
      () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);
    final pendingVerifier =
        FakeProofVerifier((_) => const VerifierUnavailable('offline'));
    final setupRepo =
        CompletionRepository(db, clock, verifier: pendingVerifier);

    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    final pendingResult = await setupRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: ProofData(
        imageBytes: Uint8List.fromList([9]),
        photoPath: '/fake/proofs/a.jpg',
      ),
    );
    final pending = (pendingResult as CompletionPendingVerification).completion;
    expect(pending.proofPhotoPath, '/fake/proofs/a.jpg');

    final store =
        _FakeProofPhotoStore({'/fake/proofs/a.jpg': Uint8List.fromList([9])});
    final retryVerifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final retryRepo = CompletionRepository(db, clock, verifier: retryVerifier);
    final retryService = ProofRetryService(retryRepo, store);

    final report = await retryService.runOnce();

    expect(report.verified, 1);
    expect(report.rejected, 0);
    expect(report.stillPending, 0);
    expect(report.skipped, 0);

    final rows = await db.select(db.completions).get();
    expect(rows.single.id, pending.id);
    expect(rows.single.verificationStatus, VerificationStatus.verified);
  });

  test(
      'a pending whose file is missing from the store is reported as '
      'skipped and stays pending', () async {
    final clock = FixedClock(d(2026, 7, 10));
    final taskRepo = TaskRepository(db, clock);
    final pendingVerifier =
        FakeProofVerifier((_) => const VerifierUnavailable('offline'));
    final setupRepo =
        CompletionRepository(db, clock, verifier: pendingVerifier);

    final task = await taskRepo.createTask(
      title: 'Push-ups',
      recurrenceType: RecurrenceType.daily,
      startDate: d(2026, 7, 1),
    );

    final pendingResult = await setupRepo.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      proof: ProofData(
        imageBytes: Uint8List.fromList([9]),
        photoPath: '/fake/proofs/gone.jpg',
      ),
    );
    final pending = (pendingResult as CompletionPendingVerification).completion;

    // The store has nothing for this path: the file is gone.
    final store = _FakeProofPhotoStore({});
    final retryVerifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final retryRepo = CompletionRepository(db, clock, verifier: retryVerifier);
    final retryService = ProofRetryService(retryRepo, store);

    final report = await retryService.runOnce();

    expect(report.skipped, 1);
    expect(report.verified, 0);
    expect(report.rejected, 0);
    expect(report.stillPending, 0);
    expect(retryVerifier.callCount, 0); // never reached the verifier

    final rows = await db.select(db.completions).get();
    expect(rows.single.id, pending.id);
    expect(rows.single.verificationStatus, VerificationStatus.pending);
    expect(rows.single.deletedAt, isNull);
  });
}
