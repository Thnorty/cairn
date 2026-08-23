import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/db/database.dart';
import 'package:cairn/src/models/stone_style.dart';
import 'package:cairn/src/providers.dart';
import 'package:cairn/src/repo/settings_repository.dart';
import 'package:cairn/src/ui/premium/premium_screen.dart';
import 'package:cairn/src/ui/proof/verification_chrome.dart' show CloseCircleButton;
import 'package:cairn/src/ui/stone_style/stone_style_screen.dart';
import 'package:cairn/src/ui/theme/app_colors.dart';
import 'package:cairn/src/ui/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

void main() {
  Widget wrap({
    required AppDatabase db,
    bool? isPremiumOverride,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        if (isPremiumOverride != null)
          debugPremiumOverrideProvider.overrideWith((_) => isPremiumOverride),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => openStoneStyleScreen(context),
                child: const Text('Open Stone Style'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<AppDatabase> pumpStoneStyle(
    WidgetTester tester, {
    bool? isPremiumOverride,
    Future<void> Function(AppDatabase db)? seed,
  }) async {
    final db = inMemoryDatabase();
    if (seed != null) await seed(db);
    await tester.pumpWidget(wrap(db: db, isPremiumOverride: isPremiumOverride));
    await tester.tap(find.text('Open Stone Style'));
    await tester.pumpAndSettle();
    return db;
  }

  bool isTileSelected(WidgetTester tester, StoneStyle style) {
    final tileFinder = find.byKey(ValueKey('stone-style-tile-${style.name}'));
    final animatedContainerFinder = find.descendant(
      of: tileFinder,
      matching: find.byType(AnimatedContainer),
    );
    if (animatedContainerFinder.evaluate().isNotEmpty) {
      final container = tester.widget<AnimatedContainer>(animatedContainerFinder.first);
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      return border.top.color == AppColors.sage;
    }
    final decoratedBox = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: tileFinder,
            matching: find.byType(DecoratedBox),
          ),
        )
        .first;
    final decoration = decoratedBox.decoration as BoxDecoration;
    final border = decoration.border as Border;
    return border.top.color == AppColors.sage;
  }

  double tilePreviewOpacity(WidgetTester tester, StoneStyle style) {
    return tester
        .widget<Opacity>(
          find.descendant(
            of: find.byKey(ValueKey('stone-style-tile-${style.name}')),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
  }

  Future<void> tapTile(WidgetTester tester, StoneStyle style) async {
    await tester.ensureVisible(find.byKey(ValueKey('stone-style-tile-${style.name}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('stone-style-tile-${style.name}')));
    await tester.pumpAndSettle();
  }

  group('free (non-premium) state', () {
    testWidgets('River is selected, the other three are locked at reduced '
        'opacity, and there is no PREMIUM pill', (tester) async {
      await pumpStoneStyle(tester, isPremiumOverride: false);

      expect(find.text('PREMIUM'), findsNothing);

      expect(isTileSelected(tester, StoneStyle.river), isTrue);
      expect(isTileSelected(tester, StoneStyle.granite), isFalse);

      expect(tilePreviewOpacity(tester, StoneStyle.river), 1.0);
      expect(tilePreviewOpacity(tester, StoneStyle.granite), 0.68);
      expect(tilePreviewOpacity(tester, StoneStyle.slate), 0.68);
      expect(tilePreviewOpacity(tester, StoneStyle.basalt), 0.68);
    });

    testWidgets('shows the Unlock with Premium CTA and the free caption, no '
        'Apply button', (tester) async {
      await pumpStoneStyle(tester, isPremiumOverride: false);

      expect(find.text('Unlock with Premium'), findsOneWidget);
      expect(find.text('River is yours for keeps.'), findsOneWidget);
      expect(find.textContaining('Apply '), findsNothing);
    });

    testWidgets('tapping a locked tile opens the paywall rather than '
        'selecting it', (tester) async {
      await pumpStoneStyle(tester, isPremiumOverride: false);

      await tapTile(tester, StoneStyle.granite);

      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(find.byType(StoneStyleScreen), findsNothing);
    });

    testWidgets('tapping Unlock with Premium opens the paywall', (tester) async {
      await pumpStoneStyle(tester, isPremiumOverride: false);

      await tester.tap(find.text('Unlock with Premium'));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumScreen), findsOneWidget);
    });
  });

  group('entitled (premium) state', () {
    testWidgets('shows the PREMIUM pill and no lock badges/opacity on any '
        'tile', (tester) async {
      await pumpStoneStyle(tester, isPremiumOverride: true);

      expect(find.text('PREMIUM'), findsOneWidget);

      for (final style in StoneStyle.values) {
        expect(tilePreviewOpacity(tester, style), 1.0);
      }
    });

    testWidgets('River starts applied/selected, and Apply is disabled until '
        'the selection changes', (tester) async {
      await pumpStoneStyle(tester, isPremiumOverride: true);

      expect(isTileSelected(tester, StoneStyle.river), isTrue);

      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('tapping an unlocked tile selects it and enables Apply with '
        'the style name in its label', (tester) async {
      await pumpStoneStyle(tester, isPremiumOverride: true);

      await tapTile(tester, StoneStyle.slate);

      expect(isTileSelected(tester, StoneStyle.slate), isTrue);
      expect(isTileSelected(tester, StoneStyle.river), isFalse);
      expect(find.text('Apply Slate'), findsOneWidget);

      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping Apply persists the tapped style and pops the screen',
        (tester) async {
      final db = await pumpStoneStyle(tester, isPremiumOverride: true);

      await tapTile(tester, StoneStyle.basalt);
      await tester.tap(find.text('Apply Basalt'));
      await tester.pumpAndSettle();

      expect(find.byType(StoneStyleScreen), findsNothing);
      expect(await SettingsRepository(db).stoneStyle(), StoneStyle.basalt);
    });

    testWidgets('re-tapping the already-applied style disables Apply again',
        (tester) async {
      await pumpStoneStyle(tester, isPremiumOverride: true);

      await tapTile(tester, StoneStyle.granite);
      var button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.onPressed, isNotNull);

      await tapTile(tester, StoneStyle.river);
      button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.onPressed, isNull);
    });

    testWidgets(
        'backing out via the close-X without tapping Apply persists nothing',
        (tester) async {
      final db = await pumpStoneStyle(tester, isPremiumOverride: true);

      await tapTile(tester, StoneStyle.slate);
      // Selection changed locally but never applied.
      expect(find.text('Apply Slate'), findsOneWidget);

      await tester.tap(find.byType(CloseCircleButton));
      await tester.pumpAndSettle();

      expect(find.byType(StoneStyleScreen), findsNothing);
      expect(await SettingsRepository(db).stoneStyle(), StoneStyle.river);
    });
  });

  group('lapse case', () {
    testWidgets(
        'a stored premium style while NOT entitled renders as the free '
        'state (River checked, everything else locked), not with the '
        'stored style checked and locked at once', (tester) async {
      await pumpStoneStyle(
        tester,
        isPremiumOverride: false,
        seed: (db) => SettingsRepository(db).setStoneStyle(StoneStyle.basalt),
      );

      expect(isTileSelected(tester, StoneStyle.river), isTrue);
      expect(isTileSelected(tester, StoneStyle.basalt), isFalse);
      expect(tilePreviewOpacity(tester, StoneStyle.basalt), 0.68);
    });
  });
}
