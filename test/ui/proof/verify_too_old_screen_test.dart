import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/ui/proof/verify_too_old_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_proof_pipeline.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  testWidgets(
      "renders the age badge and the photo's own 'taken HH:MM' time, not "
      'the rejection/now time', (tester) async {
    final photoTakenAt = DateTime(2026, 7, 10, 7, 15).millisecondsSinceEpoch;

    await tester.pumpWidget(wrap(VerifyTooOldScreen(
      taskTitle: 'Read 20 pages',
      photoTakenAtMillis: photoTakenAt,
      ageMinutes: 17,
      imageBytes: kFakeImageBytes,
      attemptsRemaining: 3,
      recencyWindowMinutes: 15,
      onRetake: () {},
      onCancel: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('This photo is too old'), findsOneWidget);
    expect(find.text('Read 20 pages · taken 7:15 AM'), findsOneWidget);
    expect(find.text('17 min old'), findsOneWidget);
    expect(
      find.text(
        "Proof has to be taken in the moment. Photos more than 15 minutes "
        "old can't be verified, so snap a fresh one right as you finish.",
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      "shows the user's full, un-decremented remaining-attempts count "
      "(a stale photo never burns an attempt)", (tester) async {
    await tester.pumpWidget(wrap(VerifyTooOldScreen(
      taskTitle: 'Read 20 pages',
      photoTakenAtMillis: DateTime(2026, 7, 10, 7, 15).millisecondsSinceEpoch,
      ageMinutes: 17,
      imageBytes: kFakeImageBytes,
      attemptsRemaining: 3,
      recencyWindowMinutes: 15,
      onRetake: () {},
      onCancel: () {},
    )));
    await tester.pumpAndSettle();

    expect(
      find.text("This didn't use a try. You still have 3 left today."),
      findsOneWidget,
    );
    // The forbidden character (CLAUDE.md bans it outright) never appears
    // anywhere in the rendered copy. Built from its code point (U+2014)
    // rather than typed literally, so this very file contains zero raw
    // occurrences of the character itself.
    expect(find.textContaining(String.fromCharCode(0x2014)), findsNothing);
  });

  testWidgets('a singular remaining count reads "1 left today"', (tester) async {
    await tester.pumpWidget(wrap(VerifyTooOldScreen(
      taskTitle: 'Read 20 pages',
      photoTakenAtMillis: DateTime(2026, 7, 10, 7, 15).millisecondsSinceEpoch,
      ageMinutes: 17,
      imageBytes: kFakeImageBytes,
      attemptsRemaining: 1,
      recencyWindowMinutes: 15,
      onRetake: () {},
      onCancel: () {},
    )));
    await tester.pumpAndSettle();

    expect(
      find.text("This didn't use a try. You still have 1 left today."),
      findsOneWidget,
    );
  });

  testWidgets('Take a new photo / Cancel wire up to their callbacks', (tester) async {
    var retook = false;
    var cancelled = false;
    await tester.pumpWidget(wrap(VerifyTooOldScreen(
      taskTitle: 'Read 20 pages',
      photoTakenAtMillis: DateTime(2026, 7, 10, 7, 15).millisecondsSinceEpoch,
      ageMinutes: 17,
      imageBytes: kFakeImageBytes,
      attemptsRemaining: 2,
      recencyWindowMinutes: 15,
      onRetake: () => retook = true,
      onCancel: () => cancelled = true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Take a new photo'));
    await tester.pumpAndSettle();
    expect(retook, isTrue);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cancelled, isTrue);
  });
}
