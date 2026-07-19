import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/services/points_service.dart';
import 'package:cairn/src/ui/proof/cairn_complete_screen.dart';
import 'package:cairn/src/ui/proof/verification_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  testWidgets(
      'shows the eyebrow, the headline for the given cairn number, the '
      'bonus pill with the passed bonus, and the teaching line; tapping '
      'Done fires onDone', (tester) async {
    var doneCalls = 0;
    await tester.pumpWidget(wrap(CairnCompleteScreen(
      taskTitle: 'Read 20 pages',
      cairnNumber: 6,
      nextCairnNumber: 7,
      capBonusMetres: 25,
      completedAtMillis: DateTime(2026, 7, 10, 7, 16).millisecondsSinceEpoch,
      onDone: () => doneCalls++,
    )));
    await tester.pumpAndSettle();

    expect(find.text('CAIRN COMPLETE'), findsOneWidget);
    expect(find.text('Cairn 6 complete'), findsOneWidget);
    expect(find.text('Ten stones stacked and sealed.'), findsOneWidget);
    expect(find.textContaining('+25 m'), findsOneWidget);
    expect(find.textContaining('cairn bonus'), findsOneWidget);
    expect(
      find.textContaining('Every 10 stones caps a cairn and earns a bonus.'),
      findsOneWidget,
    );
    expect(find.textContaining('Cairn 7 starts with your next stone.'), findsOneWidget);
    expect(find.textContaining('Read 20 pages'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    expect(doneCalls, 1);
  });

  testWidgets('the bonus pill amount reflects PointsService.cairnCapBonus, '
      'never a hardcoded figure', (tester) async {
    await tester.pumpWidget(wrap(CairnCompleteScreen(
      taskTitle: 'Meditate',
      cairnNumber: 1,
      nextCairnNumber: 2,
      capBonusMetres: PointsService.cairnCapBonus,
      completedAtMillis: DateTime(2026, 7, 10, 7, 16).millisecondsSinceEpoch,
      onDone: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('+${PointsService.cairnCapBonus} m'), findsOneWidget);
  });

  testWidgets('tapping the close button also fires onDone (never bare pop)',
      (tester) async {
    var doneCalls = 0;
    await tester.pumpWidget(wrap(CairnCompleteScreen(
      taskTitle: 'Read 20 pages',
      cairnNumber: 1,
      nextCairnNumber: 2,
      capBonusMetres: 25,
      completedAtMillis: DateTime(2026, 7, 10, 7, 16).millisecondsSinceEpoch,
      onDone: () => doneCalls++,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CloseCircleButton));
    expect(doneCalls, 1);
  });
}
