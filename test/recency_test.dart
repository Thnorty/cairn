import 'package:cairn/src/models/proof_verdict.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProofPolicy.isRecent', () {
    test('exactly at the 15-minute boundary is recent', () {
      const policy = ProofPolicy();
      const now = 1000000000000;
      final takenAt = now - const Duration(minutes: 15).inMilliseconds;
      expect(policy.isRecent(takenAt, now), isTrue);
    });

    test('one millisecond older than the boundary is not recent', () {
      const policy = ProofPolicy();
      const now = 1000000000000;
      final takenAt = now - const Duration(minutes: 15).inMilliseconds - 1;
      expect(policy.isRecent(takenAt, now), isFalse);
    });

    test('a future timestamp (clock skew) is recent', () {
      const policy = ProofPolicy();
      const now = 1000000000000;
      final takenAt = now + const Duration(minutes: 5).inMilliseconds;
      expect(policy.isRecent(takenAt, now), isTrue);
    });

    test('null is recent when allowUnknownPhotoTime is true (the default)',
        () {
      const policy = ProofPolicy();
      expect(policy.isRecent(null, 1000000000000), isTrue);
    });

    test('null is not recent when allowUnknownPhotoTime is false', () {
      const policy = ProofPolicy(allowUnknownPhotoTime: false);
      expect(policy.isRecent(null, 1000000000000), isFalse);
    });

    test('a custom window is honoured', () {
      const policy = ProofPolicy(recencyWindow: Duration(minutes: 1));
      const now = 1000000000000;
      expect(
        policy.isRecent(now - Duration(minutes: 1).inMilliseconds, now),
        isTrue,
      );
      expect(
        policy.isRecent(now - Duration(minutes: 1).inMilliseconds - 1, now),
        isFalse,
      );
      // The default 15-minute window would have accepted this, so this
      // proves the custom (shorter) window is actually in effect.
      expect(
        policy.isRecent(now - Duration(minutes: 10).inMilliseconds, now),
        isFalse,
      );
    });
  });
}
