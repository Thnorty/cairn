import 'dart:io';
import 'dart:ui' as ui;

import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/models/trail_summary.dart';
import 'package:cairn/src/ui/account/create_account_screen.dart';
import 'package:cairn/src/ui/account/enter_code_screen.dart';
import 'package:cairn/src/ui/account/forgot_password_screen.dart';
import 'package:cairn/src/ui/account/keep_which_trail_screen.dart';
import 'package:cairn/src/ui/account/set_new_password_screen.dart';
import 'package:cairn/src/ui/account/sign_in_screen.dart';
import 'package:cairn/src/ui/account/signed_in_account_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ui/account/account_test_harness.dart';
import '../support/load_app_fonts.dart';

/// Dev-only screenshot harness for the Phase 4b account-upgrade screens
/// (`Cairn Account.dc.html`) - see `home_screenshot_test.dart`'s doc comment
/// for the full rationale (no pixel-equality assertions; a quick visual
/// spot check against the canonical design frames).
void main() {
  const outputDir = 'test/screenshots/output';

  setUpAll(() async {
    await loadAppFonts();
  });

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

  Widget shell(AccountTestHarness harness, Widget home) {
    return ProviderScope(
      overrides: harness.overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RepaintBoundary(
          key: const ValueKey('screenshot-boundary'),
          child: home,
        ),
      ),
    );
  }

  testScreenshotWidgets('1. Create account', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await tester.pumpWidget(shell(
      harness,
      CreateAccountScreen(
        onClose: () {},
        onCreated: (_, __) {},
        onSignInInstead: (_) {},
      ),
    ));
    await captureAt392x846(tester, 'account_create.png');
  });

  testScreenshotWidgets('1b. Forgot password', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await tester.pumpWidget(shell(
      harness,
      ForgotPasswordScreen(
        onClose: () {},
        onBack: () {},
        initialEmail: 'ototatik@gmail.com',
        onCodeSent: (_) {},
      ),
    ));
    await captureAt392x846(tester, 'account_forgot_password.png');
  });

  testScreenshotWidgets('2. Sign in', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await tester.pumpWidget(shell(
      harness,
      SignInScreen(
        onClose: () {},
        onSignInComplete: () {},
        onNeedsTrailChoice: (_, __) {},
        onForgotPassword: (_) {},
        onCreateAccount: () {},
      ),
    ));
    await captureAt392x846(tester, 'account_sign_in.png');
  });

  testScreenshotWidgets('3. Enter code', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await tester.pumpWidget(shell(
      harness,
      const EnterCodeScreen(
        onClose: _noop,
        purpose: AccountCodePurpose.verifyEmail,
        email: 'you@example.com',
        password: 'hunter22',
        onVerified: _noop,
      ),
    ));
    await captureAt392x846(tester, 'account_enter_code.png');
  });

  testScreenshotWidgets('4. Set a new password', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await tester.pumpWidget(shell(
      harness,
      const SetNewPasswordScreen(
        onClose: _noop,
        email: 'you@example.com',
        onSaved: _noop,
      ),
    ));
    await captureAt392x846(tester, 'account_set_new_password.png');
  });

  testScreenshotWidgets('5. Keep which trail', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await tester.pumpWidget(shell(
      harness,
      KeepWhichTrailScreen(
        onClose: _noop,
        local: TrailSummary(stones: 12, lastClimbAt: DateTime(2026, 7, 10, 15, 14)),
        remote: TrailSummary(stones: 48, lastClimbAt: DateTime(2026, 7, 2, 9, 30)),
        onDone: _noop,
      ),
    ));
    await captureAt392x846(tester, 'account_keep_which_trail.png');
  });

  testScreenshotWidgets('5b. Keep which trail - account side empty', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await tester.pumpWidget(shell(
      harness,
      KeepWhichTrailScreen(
        onClose: _noop,
        local: TrailSummary(stones: 12, lastClimbAt: DateTime(2026, 7, 10, 15, 14)),
        remote: const TrailSummary(stones: 0),
        onDone: _noop,
      ),
    ));
    await captureAt392x846(tester, 'account_keep_which_trail_empty.png');
  });

  testScreenshotWidgets('6. Signed-in account row (on a plain surface)', (tester) async {
    final harness = buildAccountTestHarness();
    addTearDown(harness.db.close);
    await tester.pumpWidget(shell(
      harness,
      Scaffold(
        backgroundColor: const Color(0xFFE9E1D3),
        body: const Padding(
          padding: EdgeInsets.all(18),
          child: SignedInAccountRow(email: 'you@example.com'),
        ),
      ),
    ));
    await captureAt392x846(tester, 'account_signed_in_row.png');
  });
}

void _noop() {}
