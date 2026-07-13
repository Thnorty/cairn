import 'dart:convert';
import 'dart:typed_data';

import 'package:cairn/src/services/proof_verifier.dart';
import 'package:cairn/src/services/supabase_proof_verifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

ProofRequest _request({
  List<int> bytes = const [1, 2, 3],
  String title = 'Push-ups',
  String? description = 'Do 20 push-ups',
}) =>
    ProofRequest(
      imageBytes: Uint8List.fromList(bytes),
      taskTitle: title,
      taskDescription: description,
    );

const _validJson = {
  'task_shown': true,
  'confidence': 0.87,
  'is_screenshot_or_screen': false,
  'screen_is_plausible_proof': false,
  'reason': 'clear photo of push-ups',
};

void main() {
  group('SupabaseProofVerifier.verify - the injectable seam, no network', () {
    test('a well-formed verdict JSON maps to VerdictReceived with the right '
        'fields', () async {
      final verifier = SupabaseProofVerifier(
        invoke: (_) async => Map<String, dynamic>.from(_validJson),
      );

      final result = await verifier.verify(_request());

      expect(result, isA<VerdictReceived>());
      final verdict = (result as VerdictReceived).verdict;
      expect(verdict.taskShown, true);
      expect(verdict.confidence, 0.87);
      expect(verdict.isScreenshotOrScreen, false);
      expect(verdict.screenIsPlausibleProof, false);
      expect(verdict.reason, 'clear photo of push-ups');
    });

    test('malformed (non-parseable) content maps to VerifierUnavailable',
        () async {
      final verifier = SupabaseProofVerifier(
        invoke: (_) async => throw const FormatException('not valid JSON'),
      );

      final result = await verifier.verify(_request());

      expect(result, isA<VerifierUnavailable>());
    });

    test('JSON missing a required field maps to VerifierUnavailable',
        () async {
      final incomplete = Map<String, dynamic>.from(_validJson)
        ..remove('confidence');
      final verifier = SupabaseProofVerifier(invoke: (_) async => incomplete);

      final result = await verifier.verify(_request());

      expect(result, isA<VerifierUnavailable>());
    });

    test('JSON with a field of the wrong type maps to VerifierUnavailable',
        () async {
      final wrongType = Map<String, dynamic>.from(_validJson);
      wrongType['task_shown'] = 'yes'; // should be a bool
      final verifier = SupabaseProofVerifier(invoke: (_) async => wrongType);

      final result = await verifier.verify(_request());

      expect(result, isA<VerifierUnavailable>());
    });

    for (final status in [401, 429, 500, 502]) {
      test('a non-2xx ($status) FunctionException maps to VerifierUnavailable',
          () async {
        final verifier = SupabaseProofVerifier(
          invoke: (_) async => throw FunctionException(
            status: status,
            reasonPhrase: 'error',
          ),
        );

        final result = await verifier.verify(_request());

        expect(result, isA<VerifierUnavailable>());
        expect(
          (result as VerifierUnavailable).reason,
          contains('$status'),
        );
      });
    }

    test('a thrown network error maps to VerifierUnavailable', () async {
      final verifier = SupabaseProofVerifier(
        invoke: (_) async => throw Exception('socket closed'),
      );

      final result = await verifier.verify(_request());

      expect(result, isA<VerifierUnavailable>());
    });

    test('a timeout maps to VerifierUnavailable', () async {
      final verifier = SupabaseProofVerifier(
        invoke: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return Map<String, dynamic>.from(_validJson);
        },
        timeout: const Duration(milliseconds: 5),
      );

      final result = await verifier.verify(_request());

      expect(result, isA<VerifierUnavailable>());
    });

    test(
        'sends the request payload: task title, description, base64 image '
        'and mime type', () async {
      Map<String, dynamic>? captured;
      final verifier = SupabaseProofVerifier(
        invoke: (payload) async {
          captured = payload;
          return Map<String, dynamic>.from(_validJson);
        },
      );

      final imageBytes = [10, 20, 30, 40];
      await verifier.verify(_request(
        bytes: imageBytes,
        title: 'Meditate',
        description: '10 minutes, eyes closed',
      ));

      expect(captured, isNotNull);
      expect(captured!['task_title'], 'Meditate');
      expect(captured!['task_description'], '10 minutes, eyes closed');
      expect(captured!['image_base64'], base64Encode(imageBytes));
      expect(captured!['mime_type'], 'image/jpeg');
    });

    test('a null task description is sent through as null, not a string',
        () async {
      Map<String, dynamic>? captured;
      final verifier = SupabaseProofVerifier(
        invoke: (payload) async {
          captured = payload;
          return Map<String, dynamic>.from(_validJson);
        },
      );

      await verifier.verify(_request(description: null));

      expect(captured!['task_description'], isNull);
    });
  });
}
