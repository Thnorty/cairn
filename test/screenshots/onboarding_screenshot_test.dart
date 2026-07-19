import 'dart:io';
import 'dart:ui' as ui;

import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/ui/onboarding/onboarding_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/load_app_fonts.dart';

/// See `home_screenshot_test.dart`'s identical helper for the full
/// rationale (a drift `.watch()` subscription's teardown timer needs an
/// extra pump after the widget tree is replaced). Neither onboarding screen
/// reads a drift stream itself, but this harness keeps the same shape as
/// every other screenshot test in this directory for consistency.
void testScreenshotWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}

/// Dev-only screenshot harness for the first-launch onboarding flow
/// (`Cairn Onboarding.dc.html` / `Cairn Onboarding Verification.dc.html`) -
/// see `home_screenshot_test.dart`'s doc comment for the full rationale (no
/// pixel-equality assertions; a quick visual spot check against the
/// canonical designs).
void main() {
  const outputDir = 'test/screenshots/output';

  setUpAll(() async {
    await loadAppFonts();
  });

  Future<void> captureAt392x846(WidgetTester tester, String fileName) async {
    final view = tester.view;
    const pixelRatio = 2.0;
    view.physicalSize = const Size(392, 846) * pixelRatio;
    view.devicePixelRatio = pixelRatio;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    final boundaryFinder = find.byKey(const ValueKey('screenshot-boundary'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final dir = Directory(outputDir);
      await dir.create(recursive: true);
      final file = File('$outputDir/$fileName');
      await file.writeAsBytes(pngBytes);
      // ignore: avoid_print
      print('Wrote screenshot: ${file.absolute.path}');
    });
  }

  Widget appAt() {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FixedClock(d(2026, 7, 1))),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RepaintBoundary(
          key: const ValueKey('screenshot-boundary'),
          child: const OnboardingFlow(),
        ),
      ),
    );
  }

  testScreenshotWidgets('Onboarding, welcome screen', (tester) async {
    await tester.pumpWidget(appAt());
    await captureAt392x846(tester, 'onboarding.png');
  });

  testScreenshotWidgets('Onboarding, verification screen', (tester) async {
    await tester.pumpWidget(appAt());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start climbing'));
    await tester.pumpAndSettle();

    await captureAt392x846(tester, 'onboarding_verification.png');
  });
}
