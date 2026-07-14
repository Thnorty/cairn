import 'package:cairn/src/ui/theme/app_text_styles.dart';
import 'package:cairn/src/ui/widgets/card_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Cards get dropped into whichever screen a later run builds and always
  // host arbitrary caller-supplied content (usually text); a plain
  // `MaterialApp(home: ...)` with no `Scaffold` mirrors the worst case a
  // future screen might do (forgetting a `Material` ancestor).
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

  group('CardSurface', () {
    testWidgets('renders its child', (tester) async {
      await pump(
        tester,
        const CardSurface(child: Text('Morning walk')),
      );
      expect(find.text('Morning walk'), findsOneWidget);
    });

    testWidgets(
      "its child's text renders with the themed style even with no "
      'Material ancestor supplied by the caller',
      (tester) async {
        await pump(
          tester,
          const CardSurface(
            child: Text('Morning walk', style: AppTextStyles.taskTitle),
          ),
        );

        final style = resolvedStyle(tester, find.text('Morning walk'));
        expect(style.decoration, isNot(TextDecoration.underline));
        expect(style.decorationColor, isNot(const Color(0xFFFFFF00)));
        expect(style.fontFamily, AppTextStyles.taskTitle.fontFamily);
        expect(style.color, AppTextStyles.taskTitle.color);
      },
    );

    testWidgets('dimmed variant still renders its child', (tester) async {
      await pump(
        tester,
        const CardSurface(dimmed: true, child: Text('Evening stretch')),
      );
      expect(find.text('Evening stretch'), findsOneWidget);
    });
  });
}
