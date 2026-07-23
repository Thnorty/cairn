import 'package:cairn/l10n/generated/app_localizations.dart';
import 'package:cairn/src/ui/widgets/cairn_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders title, body, icon, and action labels', (tester) async {
    await tester.pumpWidget(
      buildApp(
        const CairnDialog(
          icon: Icon(Icons.info),
          title: 'Test Title',
          body: 'Test body content goes here.',
          cancelLabel: 'Cancel',
          confirmLabel: 'Confirm',
          tone: CairnDialogTone.sage,
        ),
      ),
    );

    expect(find.text('Test Title'), findsOneWidget);
    expect(find.text('Test body content goes here.'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.byIcon(Icons.info), findsOneWidget);
  });

  testWidgets('showCairnDialog resolves to true when confirm is tapped', (tester) async {
    bool? dialogResult;

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                dialogResult = await showCairnDialog(
                  context: context,
                  title: 'Sign out?',
                  body: 'Your trail stays on this device.',
                  confirmLabel: 'Sign out',
                  tone: CairnDialogTone.clay,
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsOneWidget);
    expect(find.text('Your trail stays on this device.'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(dialogResult, isTrue);
  });

  testWidgets('showCairnDialog resolves to false when Cancel is tapped', (tester) async {
    bool? dialogResult;

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                dialogResult = await showCairnDialog(
                  context: context,
                  title: 'Sign out?',
                  body: 'Your trail stays on this device.',
                  cancelLabel: 'Keep signed in',
                  confirmLabel: 'Sign out',
                  tone: CairnDialogTone.clay,
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep signed in'));
    await tester.pumpAndSettle();

    expect(dialogResult, isFalse);
  });

  testWidgets('showCairnDialog resolves to false when barrier is tapped', (tester) async {
    bool? dialogResult;

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                dialogResult = await showCairnDialog(
                  context: context,
                  title: 'Sign out?',
                  body: 'Your trail stays on this device.',
                  confirmLabel: 'Sign out',
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap top-left corner of the screen outside the dialog card (scrim)
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(dialogResult, isFalse);
  });
}
