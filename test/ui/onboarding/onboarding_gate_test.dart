import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/clock.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/settings_repository.dart';
import 'package:cairn/src/ui/onboarding/onboarding_flow.dart';
import 'package:cairn/src/ui/onboarding/onboarding_gate.dart';
import 'package:cairn/src/ui/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// See `app_shell_test.dart`'s `testAppShellWidgets` for the full rationale
/// (a drift `.watch()` subscription's teardown timer needs an extra pump
/// after the widget tree is replaced) - the "onboarding complete" case here
/// renders the real [AppShell], which pumps the same Home drift stream.
void testGateWidgets(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}

void main() {
  Widget wrap(AppDatabase db, Clock clock) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OnboardingGate(),
      ),
    );
  }

  group('OnboardingGate', () {
    testGateWidgets('flag unset (fresh database) shows the onboarding flow', (tester) async {
      final db = inMemoryDatabase();
      addTearDown(db.close);

      await tester.pumpWidget(wrap(db, FixedClock(d(2026, 7, 1))));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingFlow), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(find.text('Start climbing'), findsOneWidget);
    });

    testGateWidgets('flag set shows AppShell, not the onboarding flow', (tester) async {
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await SettingsRepository(db).markOnboardingComplete();

      await tester.pumpWidget(wrap(db, FixedClock(d(2026, 7, 1))));
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(OnboardingFlow), findsNothing);
      expect(find.text('Today'), findsOneWidget);
    });
  });
}
