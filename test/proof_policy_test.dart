import 'package:cairn/src/models/proof_verdict.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProofPolicy.isVerified', () {
    const policy = ProofPolicy();

    ProofVerdict verdict({
      bool taskShown = true,
      double confidence = 1.0,
      bool isScreenshotOrScreen = false,
      String reason = 'looks right',
    }) =>
        ProofVerdict(
          taskShown: taskShown,
          confidence: confidence,
          isScreenshotOrScreen: isScreenshotOrScreen,
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

    test('a custom confidence threshold is honoured', () {
      const strict = ProofPolicy(confidenceThreshold: 0.9);
      expect(strict.isVerified(verdict(confidence: 0.85)), isFalse);
      expect(strict.isVerified(verdict(confidence: 0.9)), isTrue);
    });

    test(
        'a screenshot is no longer by itself a rejection reason: taskShown '
        'true at/above threshold is verified regardless of '
        'isScreenshotOrScreen', () {
      expect(
        policy.isVerified(verdict(
          isScreenshotOrScreen: true,
          confidence: 0.6,
        )),
        isTrue,
      );
    });

    test(
        'a non-screenshot at the same confidence is verified identically '
        '(isScreenshotOrScreen never changes the outcome)', () {
      expect(
        policy.isVerified(verdict(
          isScreenshotOrScreen: false,
          confidence: 0.6,
        )),
        isTrue,
      );
    });
  });

  group('ProofVerdict JSON round-trip', () {
    test(
        'toJson uses snake_case wire keys, no longer carries the removed '
        'screen-plausibility key, and fromJson round-trips', () {
      const verdict = ProofVerdict(
        taskShown: true,
        confidence: 0.87,
        isScreenshotOrScreen: true,
        reason: 'step counter shows 5,200 steps',
      );

      final json = verdict.toJson();
      expect(json, {
        'task_shown': true,
        'confidence': 0.87,
        'is_screenshot_or_screen': true,
        'reason': 'step counter shows 5,200 steps',
      });
      expect(json.containsKey('screen_is_plausible_proof'), isFalse);

      final roundTripped = ProofVerdict.fromJson(json);
      expect(roundTripped.taskShown, verdict.taskShown);
      expect(roundTripped.confidence, verdict.confidence);
      expect(roundTripped.isScreenshotOrScreen, verdict.isScreenshotOrScreen);
      expect(roundTripped.reason, verdict.reason);
    });

    test(
        'fromJson tolerates a raw JSON map that still contains the removed '
        'legacy key (simulating a not-yet-redeployed Edge Function)', () {
      // Deliberately a raw Map<String, dynamic> literal, not a toJson()
      // output: this is the one place the removed key's string may still
      // appear in test source, since it's testing backward tolerance for a
      // currently-deployed Edge Function payload shape.
      final rawJsonWithExtraKey = <String, dynamic>{
        'task_shown': true,
        'confidence': 0.72,
        'is_screenshot_or_screen': true,
        'screen_is_plausible_proof': true,
        'reason': 'step counter shows 5,200 steps',
      };

      final verdict = ProofVerdict.fromJson(rawJsonWithExtraKey);

      expect(verdict.taskShown, true);
      expect(verdict.confidence, 0.72);
      expect(verdict.isScreenshotOrScreen, true);
      expect(verdict.reason, 'step counter shows 5,200 steps');
    });
  });
}
