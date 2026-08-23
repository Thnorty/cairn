import 'package:cairn/src/ui/theme/app_text_styles.dart';
import 'package:cairn/src/ui/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Buttons get dropped into whichever screen a later run builds; a plain
  // `MaterialApp(home: ...)` with no `Scaffold` mirrors the worst case a
  // future screen might do (forgetting a `Material` ancestor) rather than
  // the bare `Directionality` this used to pump through, which skipped
  // MaterialApp's `DefaultTextStyle` entirely and couldn't have caught a
  // missing-Material-ancestor regression either way.
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

    testWidgets(
      'medium size (Empty Today\'s "+ New habit") renders with its own '
      'label style',
      (tester) async {
        var tapped = false;
        await pump(
          tester,
          PrimaryButton(
            label: 'New habit',
            onPressed: () => tapped = true,
            size: PrimaryButtonSize.medium,
            expand: false,
          ),
        );

        final style = resolvedStyle(tester, find.text('New habit'));
        expectThemedNotFallback(style);
        expect(style.fontFamily, AppTextStyles.buttonLabelMedium.fontFamily);
        expect(style.fontSize, AppTextStyles.buttonLabelMedium.fontSize);

        await tester.tap(find.text('New habit'));
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'renders its label with the themed style even with no Material '
      'ancestor supplied by the caller',
      (tester) async {
        await pump(
          tester,
          PrimaryButton(label: 'Prove it', onPressed: () {}),
        );

        final style = resolvedStyle(tester, find.text('Prove it'));
        expectThemedNotFallback(style);
        expect(style.fontFamily, AppTextStyles.buttonLabelLarge.fontFamily);
        expect(style.color, AppTextStyles.buttonLabelLarge.color);
      },
    );

    testWidgets(
      'the sage colour variant (Phase 4b account screens) renders and fires '
      'its callback the same as the default terracotta variant',
      (tester) async {
        var tapped = false;
        await pump(
          tester,
          PrimaryButton(
            label: 'Create account',
            onPressed: () => tapped = true,
            color: PrimaryButtonColor.sage,
          ),
        );

        expect(find.text('Create account'), findsOneWidget);
        await tester.tap(find.text('Create account'));
        expect(tapped, isTrue);
      },
    );
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

    testWidgets(
      'renders its label with the themed style even with no Material '
      'ancestor supplied by the caller',
      (tester) async {
        await pump(
          tester,
          TintedPillButton(label: 'New habit', onPressed: () {}),
        );

        final style = resolvedStyle(tester, find.text('New habit'));
        expectThemedNotFallback(style);
        expect(style.fontFamily, AppTextStyles.tintedPillLabel.fontFamily);
        expect(style.color, AppTextStyles.tintedPillLabel.color);
      },
    );
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

    testWidgets(
      'renders its label with the themed style even with no Material '
      'ancestor supplied by the caller',
      (tester) async {
        await pump(
          tester,
          TextGhostButton(label: 'Cancel', onPressed: () {}),
        );

        final style = resolvedStyle(tester, find.text('Cancel'));
        expectThemedNotFallback(style);
        expect(
          style.fontFamily,
          AppTextStyles.textGhostButtonLabel.fontFamily,
        );
        expect(style.color, AppTextStyles.textGhostButtonLabel.color);
      },
    );
  });

  group('Button press animation physics', () {
    testWidgets('scales down on press and returns to 1.0 on release', (
      tester,
    ) async {
      await pump(
        tester,
        PrimaryButton(label: 'Prove it', onPressed: () {}),
      );

      final animatedScaleFinder = find.byType(AnimatedScale);
      expect(animatedScaleFinder, findsOneWidget);

      AnimatedScale scaleWidget() =>
          tester.widget<AnimatedScale>(animatedScaleFinder);

      // Initially at resting scale 1.0
      expect(scaleWidget().scale, 1.0);

      // Press down
      final gesture = await tester.startGesture(tester.getCenter(find.text('Prove it')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(scaleWidget().scale, 0.97);

      // Release finger
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scaleWidget().scale, 1.0);
    });

    testWidgets('resets scale to 1.0 when gesture is canceled (drag out)', (
      tester,
    ) async {
      await pump(
        tester,
        PrimaryButton(label: 'Prove it', onPressed: () {}),
      );

      final animatedScaleFinder = find.byType(AnimatedScale);
      AnimatedScale scaleWidget() =>
          tester.widget<AnimatedScale>(animatedScaleFinder);

      // Press down
      final gesture = await tester.startGesture(tester.getCenter(find.text('Prove it')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(scaleWidget().scale, 0.97);

      // Cancel gesture (drag far away / cancel)
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(scaleWidget().scale, 1.0);
    });

    testWidgets('does not scale when disabled', (tester) async {
      await pump(
        tester,
        PrimaryButton(label: 'Prove it', onPressed: null),
      );

      final animatedScaleFinder = find.byType(AnimatedScale);
      AnimatedScale scaleWidget() =>
          tester.widget<AnimatedScale>(animatedScaleFinder);

      final gesture = await tester.startGesture(tester.getCenter(find.text('Prove it')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(scaleWidget().scale, 1.0);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(scaleWidget().scale, 1.0);
    });
  });
}
