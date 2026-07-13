import 'package:cairn/src/models/proof_verdict.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProofPolicy.isVerified', () {
    const policy = ProofPolicy();

    ProofVerdict verdict({
      bool taskShown = true,
      double confidence = 1.0,
      bool isScreenshotOrScreen = false,
      bool screenIsPlausibleProof = false,
      String reason = 'looks right',
    }) =>
        ProofVerdict(
          taskShown: taskShown,
          confidence: confidence,
          isScreenshotOrScreen: isScreenshotOrScreen,
          screenIsPlausibleProof: screenIsPlausibleProof,
          reason: reason,
        );

    test('confidence exactly at the default threshold (0.6) passes', () {
      expect(policy.isVerified(verdict(confidence: 0.6)), isTrue);
    });

    test('confidence just under the default threshold fails', () {
      expect(policy.isVerified(verdict(confidence: 0.59)), isFalse);
    });

    test('taskShown false never passes, even at confidence 1.0', () {
      expect(
        policy.isVerified(verdict(taskShown: false, confidence: 1.0)),
        isFalse,
      );
    });

    test('a screenshot with plausible screen content passes', () {
      expect(
        policy.isVerified(verdict(
          isScreenshotOrScreen: true,
          screenIsPlausibleProof: true,
        )),
        isTrue,
      );
    });

    test('a screenshot that is not plausible proof fails', () {
      expect(
        policy.isVerified(verdict(
          isScreenshotOrScreen: true,
          screenIsPlausibleProof: false,
        )),
        isFalse,
      );
    });

    test(
        'a non-screenshot still passes even when screenIsPlausibleProof is '
        'false (the flag only matters for screens)', () {
      expect(
        policy.isVerified(verdict(
          isScreenshotOrScreen: false,
          screenIsPlausibleProof: false,
        )),
        isTrue,
      );
    });

    test('a custom confidence threshold is honoured', () {
      const strict = ProofPolicy(confidenceThreshold: 0.9);
      expect(strict.isVerified(verdict(confidence: 0.85)), isFalse);
      expect(strict.isVerified(verdict(confidence: 0.9)), isTrue);
    });
  });

  group('ProofVerdict JSON round-trip', () {
    test('toJson uses snake_case wire keys and fromJson round-trips', () {
      const verdict = ProofVerdict(
        taskShown: true,
        confidence: 0.87,
        isScreenshotOrScreen: true,
        screenIsPlausibleProof: true,
        reason: 'step counter shows 5,200 steps',
      );

      final json = verdict.toJson();
      expect(json, {
        'task_shown': true,
        'confidence': 0.87,
        'is_screenshot_or_screen': true,
        'screen_is_plausible_proof': true,
        'reason': 'step counter shows 5,200 steps',
      });

      final roundTripped = ProofVerdict.fromJson(json);
      expect(roundTripped.taskShown, verdict.taskShown);
      expect(roundTripped.confidence, verdict.confidence);
      expect(roundTripped.isScreenshotOrScreen, verdict.isScreenshotOrScreen);
      expect(
        roundTripped.screenIsPlausibleProof,
        verdict.screenIsPlausibleProof,
      );
      expect(roundTripped.reason, verdict.reason);
    });
  });
}
