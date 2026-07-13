import 'dart:typed_data';

import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/proof_verdict.dart';
import 'package:cairn/src/repo/completion_repository.dart';
import 'package:cairn/src/repo/task_repository.dart';
import 'package:cairn/src/services/photo_capture.dart';
import 'package:cairn/src/services/proof_flow.dart';
import 'package:cairn/src/services/proof_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _FakePhotoCapture implements PhotoCapture {
  final CapturedPhoto? Function(ProofSource source) handler;
  int callCount = 0;

  _FakePhotoCapture(this.handler);

  @override
  Future<CapturedPhoto?> capture(ProofSource source) async {
    callCount++;
    return handler(source);
  }
}

class _FakeImageCompressor implements ImageCompressor {
  int callCount = 0;

  @override
  Future<Uint8List> compress(String path) async {
    callCount++;
    return Uint8List.fromList('compressed:$path'.codeUnits);
  }
}

/// In-memory [ProofPhotoStore]: no real file I/O, so it's safe under
/// `flutter test` and lets tests assert exactly which paths were saved vs.
/// deleted.
class _FakeProofPhotoStore implements ProofPhotoStore {
  final Map<String, Uint8List> _files = {};
  int _nextId = 0;
  final List<String> saved = [];
  final List<String> deleted = [];

  @override
  Future<String> save(Uint8List bytes) async {
    final path = '/fake/proofs/${_nextId++}.jpg';
    _files[path] = bytes;
    saved.add(path);
    return path;
  }

  @override
  Future<Uint8List?> load(String path) async => _files[path];

  @override
  Future<void> delete(String path) async {
    _files.remove(path);
    deleted.add(path);
  }
}

const _passingVerdict = ProofVerdict(
  taskShown: true,
  confidence: 0.9,
  isScreenshotOrScreen: false,
  screenIsPlausibleProof: false,
  reason: 'looks right',
);

const _rejectingVerdict = ProofVerdict(
  taskShown: false,
  confidence: 0.1,
  isScreenshotOrScreen: false,
  screenIsPlausibleProof: false,
  reason: 'no evidence',
);

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late TaskRepository taskRepo;

  setUp(() {
    db = inMemoryDatabase();
    clock = FixedClock(d(2026, 7, 10));
    taskRepo = TaskRepository(db, clock);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Task> makeTask() => taskRepo.createTask(
        title: 'Push-ups',
        recurrenceType: RecurrenceType.daily,
        startDate: d(2026, 7, 1),
      );

  test(
      'a cancelled capture returns ProofFlowCancelled and touches neither '
      'the store nor the database', () async {
    final capture = _FakePhotoCapture((_) => null);
    final compressor = _FakeImageCompressor();
    final store = _FakeProofPhotoStore();
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final completionRepo = CompletionRepository(db, clock, verifier: verifier);
    final task = await makeTask();

    final flow = ProofFlowService(
      capture: capture,
      compressor: compressor,
      store: store,
      completionRepository: completionRepo,
    );

    final result = await flow.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      source: ProofSource.camera,
    );

    expect(result, isA<ProofFlowCancelled>());
    expect(compressor.callCount, 0);
    expect(store.saved, isEmpty);
    expect(store.deleted, isEmpty);
    expect(verifier.callCount, 0);

    final completions = await db.select(db.completions).get();
    expect(completions, isEmpty);
  });

  test(
      'a passing verdict saves the photo, records a verified completion, '
      'and the stored path is on the completion row', () async {
    final capture = _FakePhotoCapture((source) => CapturedPhoto(
          tempPath: '/tmp/photo.jpg',
          source: source,
          takenAtMillis: clock.nowEpochMillis(),
        ));
    final compressor = _FakeImageCompressor();
    final store = _FakeProofPhotoStore();
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final completionRepo = CompletionRepository(db, clock, verifier: verifier);
    final task = await makeTask();

    final flow = ProofFlowService(
      capture: capture,
      compressor: compressor,
      store: store,
      completionRepository: completionRepo,
    );

    final result = await flow.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      source: ProofSource.camera,
    );

    expect(result, isA<ProofFlowCompleted>());
    final completed = (result as ProofFlowCompleted).result;
    expect(completed, isA<CompletionRecorded>());
    final completion = (completed as CompletionRecorded).completion;

    expect(compressor.callCount, 1);
    expect(store.saved, hasLength(1));
    expect(store.deleted, isEmpty);
    expect(completion.proofPhotoPath, store.saved.single);
  });

  test(
      'a verifier rejection deletes the saved file and records no '
      'completion', () async {
    final capture = _FakePhotoCapture((source) => CapturedPhoto(
          tempPath: '/tmp/photo.jpg',
          source: source,
          takenAtMillis: clock.nowEpochMillis(),
        ));
    final compressor = _FakeImageCompressor();
    final store = _FakeProofPhotoStore();
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_rejectingVerdict));
    final completionRepo = CompletionRepository(db, clock, verifier: verifier);
    final task = await makeTask();

    final flow = ProofFlowService(
      capture: capture,
      compressor: compressor,
      store: store,
      completionRepository: completionRepo,
    );

    final result = await flow.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      source: ProofSource.gallery,
    );

    final completed = (result as ProofFlowCompleted).result;
    expect(completed, isA<CompletionRejectedByVerifier>());

    expect(store.saved, hasLength(1));
    expect(store.deleted, store.saved); // the saved file was cleaned up

    final completions = await db.select(db.completions).get();
    expect(completions, isEmpty);
  });

  test(
      'a VerifierUnavailable result keeps the file and records a pending '
      'completion', () async {
    final capture = _FakePhotoCapture((source) => CapturedPhoto(
          tempPath: '/tmp/photo.jpg',
          source: source,
          takenAtMillis: clock.nowEpochMillis(),
        ));
    final compressor = _FakeImageCompressor();
    final store = _FakeProofPhotoStore();
    final verifier =
        FakeProofVerifier((_) => const VerifierUnavailable('offline'));
    final completionRepo = CompletionRepository(db, clock, verifier: verifier);
    final task = await makeTask();

    final flow = ProofFlowService(
      capture: capture,
      compressor: compressor,
      store: store,
      completionRepository: completionRepo,
    );

    final result = await flow.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      source: ProofSource.camera,
    );

    final completed = (result as ProofFlowCompleted).result;
    expect(completed, isA<CompletionPendingVerification>());

    expect(store.saved, hasLength(1));
    expect(store.deleted, isEmpty); // kept: a retry will need it
  });

  test('a stale photo deletes the file and never calls the verifier',
      () async {
    final staleTakenAt =
        clock.nowEpochMillis() - const Duration(minutes: 20).inMilliseconds;
    final capture = _FakePhotoCapture((source) => CapturedPhoto(
          tempPath: '/tmp/photo.jpg',
          source: source,
          takenAtMillis: staleTakenAt,
        ));
    final compressor = _FakeImageCompressor();
    final store = _FakeProofPhotoStore();
    final verifier =
        FakeProofVerifier((_) => const VerdictReceived(_passingVerdict));
    final completionRepo = CompletionRepository(db, clock, verifier: verifier);
    final task = await makeTask();

    final flow = ProofFlowService(
      capture: capture,
      compressor: compressor,
      store: store,
      completionRepository: completionRepo,
    );

    final result = await flow.completeWithProof(
      taskId: task.id,
      occurrenceDate: d(2026, 7, 10),
      source: ProofSource.gallery,
    );

    final completed = (result as ProofFlowCompleted).result;
    expect(completed, isA<CompletionRejectedStalePhoto>());
    expect(verifier.callCount, 0);

    expect(store.saved, hasLength(1));
    expect(store.deleted, store.saved);
  });
}
