import 'package:cairn/src/ui/widgets/buttons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: child),
    );
  }

  group('PrimaryButton', () {
    testWidgets('builds and fires its callback when tapped', (tester) async {
      var tapped = false;
      await pump(
        tester,
        PrimaryButton(label: 'Prove it', onPressed: () => tapped = true),
      );

      expect(find.text('Prove it'), findsOneWidget);
      await tester.tap(find.text('Prove it'));
      expect(tapped, isTrue);
    });

    testWidgets('does not fire when disabled (onPressed null)', (
      tester,
    ) async {
      var tapped = false;
      await pump(
        tester,
        PrimaryButton(
          label: 'Try again tomorrow',
          onPressed: null,
          size: PrimaryButtonSize.large,
        ),
      );

      await tester.tap(find.text('Try again tomorrow'));
      expect(tapped, isFalse);
    });

    testWidgets('small size renders alongside the large size', (
      tester,
    ) async {
      await pump(
        tester,
        PrimaryButton(
          label: 'Prove it',
          onPressed: () {},
          size: PrimaryButtonSize.small,
          expand: false,
        ),
      );
      expect(find.text('Prove it'), findsOneWidget);
    });
  });

  group('TintedPillButton', () {
    testWidgets('builds and fires its callback when tapped', (tester) async {
      var tapped = false;
      await pump(
        tester,
        TintedPillButton(label: 'New habit', onPressed: () => tapped = true),
      );

      await tester.tap(find.text('New habit'));
      expect(tapped, isTrue);
    });
  });

  group('TextGhostButton', () {
    testWidgets('builds and fires its callback when tapped', (tester) async {
      var tapped = false;
      await pump(
        tester,
        TextGhostButton(label: 'Cancel', onPressed: () => tapped = true),
      );

      await tester.tap(find.text('Cancel'));
      expect(tapped, isTrue);
    });
  });
}
