import 'package:cairn/src/ui/theme/app_text_styles.dart';
import 'package:cairn/src/ui/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Chips get dropped into whichever screen/card a later run builds; a
  // plain `MaterialApp(home: ...)` with no `Scaffold` mirrors the worst
  // case a future screen might do (forgetting a `Material` ancestor)
  // rather than the bare `Directionality` this used to pump through,
  // which skipped MaterialApp's `DefaultTextStyle` entirely and couldn't
  // have caught a missing-Material-ancestor regression either way.
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: child));
  }

  /// See the identical helper in `app_shell_test.dart`: the resolved style
  /// a `Text` widget actually paints with, after merging onto whatever
  /// `DefaultTextStyle` is in scope.
  TextStyle resolvedStyle(WidgetTester tester, Finder textFinder) {
    final richText = tester.widget<RichText>(
      find.descendant(of: textFinder, matching: find.byType(RichText)),
    );
    return richText.text.style!;
  }

  void expectThemedNotFallback(TextStyle style) {
    expect(style.decoration, isNot(TextDecoration.underline));
    expect(style.decorationColor, isNot(const Color(0xFFFFFF00)));
  }

  group('StatusChip', () {
    testWidgets('verified variant shows its label', (tester) async {
      await pump(
        tester,
        const StatusChip(
          variant: StatusChipVariant.verified,
          label: 'Verified · 7:14 AM',
        ),
      );
      expect(find.text('Verified · 7:14 AM'), findsOneWidget);
    });

    testWidgets('awaiting variant (card style) shows its label', (
      tester,
    ) async {
      await pump(
        tester,
        const StatusChip(
          variant: StatusChipVariant.awaiting,
          label: 'Awaiting verification',
        ),
      );
      expect(find.text('Awaiting verification'), findsOneWidget);
    });

    testWidgets('awaiting variant (on-photo style) shows its label', (
      tester,
    ) async {
      await pump(
        tester,
        const StatusChip(
          variant: StatusChipVariant.awaiting,
          label: 'Awaiting verification',
          onPhoto: true,
        ),
      );
      expect(find.text('Awaiting verification'), findsOneWidget);
    });

    testWidgets('scheduled variant shows its label', (tester) async {
      await pump(
        tester,
        const StatusChip(
          variant: StatusChipVariant.scheduled,
          label: 'Scheduled · 8:00 PM',
        ),
      );
      expect(find.text('Scheduled · 8:00 PM'), findsOneWidget);
    });

    testWidgets('notVerified variant shows its label', (tester) async {
      await pump(
        tester,
        const StatusChip(
          variant: StatusChipVariant.notVerified,
          label: 'Not verified',
        ),
      );
      expect(find.text('Not verified'), findsOneWidget);
    });

    testWidgets(
      'renders its label with the themed style even with no Material '
      'ancestor supplied by the caller',
      (tester) async {
        await pump(
          tester,
          const StatusChip(
            variant: StatusChipVariant.verified,
            label: 'Verified · 7:14 AM',
          ),
        );

        final style = resolvedStyle(tester, find.text('Verified · 7:14 AM'));
        expectThemedNotFallback(style);
        expect(style.fontFamily, AppTextStyles.chipLabel.fontFamily);
      },
    );
  });
}
