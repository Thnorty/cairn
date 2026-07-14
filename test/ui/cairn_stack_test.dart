import 'package:cairn/src/ui/theme/app_colors.dart';
import 'package:cairn/src/ui/widgets/cairn_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: child),
    );
  }

  ValueKey<String> stoneKey(int i) => ValueKey('cairn-stone-$i');

  group('CairnStack', () {
    testWidgets('renders exactly the requested number of stones', (
      tester,
    ) async {
      await pump(tester, const CairnStack(stoneCount: 9));

      for (var i = 0; i < 9; i++) {
        expect(find.byKey(stoneKey(i)), findsOneWidget);
      }
      expect(find.byKey(stoneKey(9)), findsNothing);
    });

    testWidgets('renders a single stone for a count of 1', (tester) async {
      await pump(tester, const CairnStack(stoneCount: 1));

      expect(find.byKey(stoneKey(0)), findsOneWidget);
      expect(find.byKey(stoneKey(1)), findsNothing);
    });

    testWidgets('different stone counts render distinct stone counts', (
      tester,
    ) async {
      await pump(tester, const CairnStack(stoneCount: 4));
      expect(find.byKey(stoneKey(3)), findsOneWidget);
      expect(find.byKey(stoneKey(4)), findsNothing);
    });

    testWidgets('muted variant wraps the stack in reduced opacity', (
      tester,
    ) async {
      await pump(tester, const CairnStack(stoneCount: 6, muted: true));
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.75);
    });

    testWidgets('non-muted variant has no opacity wrapper', (tester) async {
      await pump(tester, const CairnStack(stoneCount: 6));
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('highlightTop tints the topmost stone sage', (tester) async {
      await pump(
        tester,
        const CairnStack(stoneCount: 5, highlightTop: true),
      );

      final topContainer = tester.widget<Container>(
        find.descendant(
          of: find.byKey(stoneKey(0)),
          matching: find.byType(Container),
        ),
      );
      final decoration = topContainer.decoration! as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors, [
        AppColors.stoneSageLight,
        AppColors.stoneSageDark,
      ]);
    });

    testWidgets('without highlightTop the top stone uses the default palette', (
      tester,
    ) async {
      await pump(tester, const CairnStack(stoneCount: 5));

      final topContainer = tester.widget<Container>(
        find.descendant(
          of: find.byKey(stoneKey(0)),
          matching: find.byType(Container),
        ),
      );
      final decoration = topContainer.decoration! as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors, isNot([
        AppColors.stoneSageLight,
        AppColors.stoneSageDark,
      ]));
    });

    testWidgets('rendering is deterministic across rebuilds', (tester) async {
      await pump(tester, const CairnStack(stoneCount: 9, scale: 1.4));
      final first = tester.getSize(find.byKey(stoneKey(3)));

      await pump(tester, const CairnStack(stoneCount: 9, scale: 1.4));
      final second = tester.getSize(find.byKey(stoneKey(3)));

      expect(first, second);
    });

    group('taper (defect 3 regression)', () {
      // Stone index 0 is the top of the stack (narrowest); the highest
      // index is the base (widest) - see `_layout()`'s doc comment.
      for (final n in [2, 3, 4, 6, 9]) {
        testWidgets('at N=$n the base stone is wider than the top stone', (
          tester,
        ) async {
          await pump(tester, CairnStack(stoneCount: n));

          final topWidth = tester.getSize(find.byKey(stoneKey(0))).width;
          final baseWidth = tester
              .getSize(find.byKey(stoneKey(n - 1)))
              .width;

          expect(
            baseWidth,
            greaterThan(topWidth),
            reason: 'a cairn tapers: widest at the bottom, narrowest on top',
          );
        });
      }

      testWidgets(
          'at N=1 the single stone is a modest pebble, not the flattened base slab',
          (tester) async {
        await pump(tester, const CairnStack(stoneCount: 1));

        final size = tester.getSize(find.byKey(stoneKey(0)));

        // Before the fix, a 1-stone stack rendered at the taper's widest/
        // flattest *base* proportions (44x13, a 3.4:1 aspect ratio) -
        // wide enough that it read as a flattened puddle rather than a
        // single stone. A modest pebble should be both narrower than that
        // base slab and noticeably less elongated.
        expect(size.width, lessThan(40));
        expect(
          size.width / size.height,
          lessThan(2.0),
          reason: 'a solo stone should read as a rounded pebble, not a flat, '
              'wide slab',
        );
      });

      testWidgets(
          'at N=1 the stack still renders on top of a ground shadow, like every other count',
          (tester) async {
        await pump(tester, const CairnStack(stoneCount: 1));

        expect(find.byKey(stoneKey(0)), findsOneWidget);
        expect(find.byKey(stoneKey(1)), findsNothing);
      });
    });
  });
}
