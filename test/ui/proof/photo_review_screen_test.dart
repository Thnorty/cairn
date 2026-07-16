import 'dart:io';

import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/ui/proof/photo_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_proof_pipeline.dart';

/// Direct widget tests for [PhotoReviewScreen] in isolation, decoupled from
/// the two screens that show it ([CameraCaptureScreen]/
/// [CameraUnavailableScreen] - see their own test files for the full
/// capture-then-review-then-submit journeys).
///
/// Uses a real temporary file with real (decodable) image bytes so
/// [Image.file] genuinely exercises the "shows the REAL captured/picked
/// image" requirement, without touching any plugin - `dart:io` file I/O is
/// plain Dart, not a platform channel, so it's safe under `flutter test`.
void main() {
  late Directory tempDir;
  late String imagePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('photo_review_test');
    final file = File('${tempDir.path}${Platform.pathSeparator}proof.jpg');
    await file.writeAsBytes(kFakeImageBytes);
    imagePath = file.path;
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    String secondaryLabel = 'Retake',
    VoidCallback? onUsePhoto,
    VoidCallback? onSecondaryAction,
    VoidCallback? onClose,
  }) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PhotoReviewScreen(
        imagePath: imagePath,
        taskTitle: 'Read 20 pages',
        secondaryLabel: secondaryLabel,
        onUsePhoto: onUsePhoto,
        onSecondaryAction: onSecondaryAction,
        onClose: onClose ?? () {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'renders the task pill, review prompt, and both footer actions',
      (tester) async {
    await pumpScreen(tester, onUsePhoto: () {}, onSecondaryAction: () {});

    expect(find.text('PROVING'), findsOneWidget);
    expect(find.text('Read 20 pages'), findsOneWidget);
    expect(find.text('Does this show your proof clearly?'), findsOneWidget);
    expect(find.text('Use this photo'), findsOneWidget);
    expect(find.text('Retake'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping "Use this photo" calls onUsePhoto exactly once',
      (tester) async {
    var calls = 0;
    await pumpScreen(tester, onUsePhoto: () => calls++, onSecondaryAction: () {});

    await tester.tap(find.byKey(const ValueKey('photo-review-use')));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets(
      'tapping the secondary action calls onSecondaryAction exactly once, '
      'and shows "Choose another" (not "Retake") when configured for the '
      'gallery path', (tester) async {
    var calls = 0;
    await pumpScreen(
      tester,
      secondaryLabel: 'Choose another',
      onUsePhoto: () {},
      onSecondaryAction: () => calls++,
    );

    expect(find.text('Choose another'), findsOneWidget);
    expect(find.text('Retake'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('photo-review-secondary')));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets('tapping close (X) calls onClose exactly once', (tester) async {
    var calls = 0;
    await pumpScreen(tester, onClose: () => calls++);

    await tester.tap(find.byKey(const ValueKey('camera-close')));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets(
      'null onUsePhoto/onSecondaryAction disables both actions rather than '
      'crashing or calling anything', (tester) async {
    await pumpScreen(tester); // onUsePhoto/onSecondaryAction both null

    await tester.tap(find.byKey(const ValueKey('photo-review-use')));
    await tester.tap(find.byKey(const ValueKey('photo-review-secondary')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a photo path that cannot be read degrades to a plain fill rather '
      'than throwing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PhotoReviewScreen(
        imagePath: '/definitely/not/a/real/path.jpg',
        taskTitle: 'Read 20 pages',
        secondaryLabel: 'Retake',
        onUsePhoto: () {},
        onSecondaryAction: () {},
        onClose: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Use this photo'), findsOneWidget);
  });
}
