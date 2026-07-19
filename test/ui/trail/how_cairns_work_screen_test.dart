import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/ui/trail/how_cairns_work_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Navigator(
        onGenerateRoute: (settings) => MaterialPageRoute<void>(builder: (_) => child),
      ),
    );
  }

  testWidgets(
      'renders the title, the three legend labels, all four explainer row '
      'titles, and the Got it button', (tester) async {
    await tester.pumpWidget(wrap(const HowCairnsWorkScreen()));
    await tester.pumpAndSettle();

    expect(find.text('HOW CAIRNS WORK'), findsOneWidget);
    expect(find.text('Every stone builds a cairn'), findsOneWidget);
    expect(
      find.text('A cairn is a stack of stones that marks a trail. Yours '
          'grows one proof at a time.'),
      findsOneWidget,
    );

    expect(find.text('Growing'), findsOneWidget);
    expect(find.text('Capped'), findsOneWidget);
    expect(find.text('Broken'), findsOneWidget);

    expect(find.text('One proof, one stone'), findsOneWidget);
    expect(find.text('Ten stones cap a cairn'), findsOneWidget);
    expect(find.text('A missed day breaks it'), findsOneWidget);
    expect(find.text('Stones lift your rank'), findsOneWidget);

    // The cap-bonus figure in row 2's body is wired to PointsService, not
    // hardcoded, so it shows the real bonus amount.
    expect(find.textContaining('+25 m'), findsOneWidget);

    expect(find.text('Got it'), findsOneWidget);
  });

  testWidgets('tapping Got it pops the sheet', (tester) async {
    await tester.pumpWidget(wrap(const HowCairnsWorkScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.byType(HowCairnsWorkScreen), findsNothing);
  });
}
