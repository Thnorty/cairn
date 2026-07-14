import 'package:cairn/src/ui/theme/screen_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TopographicContourPainter', () {
    test('defaults match the design: 26dp ring period, 1dp stroke, '
        'rgba(70,60,44,.05)', () {
      const painter = TopographicContourPainter();
      expect(painter.ringSpacing, 26);
      expect(painter.strokeWidth, 1);
      expect(painter.ringColor, const Color(0x0D463C2C));
      expect(painter.origin, const Alignment(0.68, -0.92));
    });

    test('shouldRepaint is true when strokeWidth changes', () {
      const a = TopographicContourPainter();
      const b = TopographicContourPainter(strokeWidth: 2);
      expect(a.shouldRepaint(b), isTrue);
    });
  });

  group('ScreenBackground', () {
    testWidgets(
      'the contour layer is wrapped in a further 50% Opacity, matching the '
      'design\'s own opacity:.5 on top of the .05-alpha ring colour '
      '(missing this made the rings render twice as strong as intended)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ScreenBackground(child: SizedBox.shrink()),
          ),
        );

        final customPaintFinder = find.byWidgetPredicate(
          (widget) => widget is CustomPaint &&
              widget.painter is TopographicContourPainter,
        );
        expect(customPaintFinder, findsOneWidget);

        final opacity = tester.widget<Opacity>(
          find.ancestor(
            of: customPaintFinder,
            matching: find.byType(Opacity),
          ),
        );
        expect(opacity.opacity, 0.5);
      },
    );

    testWidgets('showContour: false renders no contour layer', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScreenBackground(
            showContour: false,
            child: SizedBox.shrink(),
          ),
        ),
      );

      final customPaintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint &&
            widget.painter is TopographicContourPainter,
      );
      expect(customPaintFinder, findsNothing);
    });
  });
}
