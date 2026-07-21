import 'package:cairn/src/ui/theme/app_text_styles.dart';
import 'package:cairn/src/ui/widgets/screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the shared eyebrow+title header every main tab screen (Home,
/// Trail, Stats, Profile) now routes through - see `screen_header.dart`'s
/// own doc comment for why this widget exists: before it, each screen
/// hand-rolled its own header and they drifted (most visibly Trail, whose
/// rank pill lived in the same `Row` as its eyebrow/title and silently
/// pushed the eyebrow down by the pill's own height).
void main() {
  // ScreenHeader carries no outer padding of its own - the caller's body
  // Padding supplies the inset (see `kScreenEdgePadding`) - so wrapping it
  // in a plain Scaffold body here mirrors how every real screen hosts it.
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  group('ScreenHeader', () {
    testWidgets('renders the eyebrow and the title', (tester) async {
      await pump(
        tester,
        const ScreenHeader(eyebrow: 'YOUR GROUND', title: 'Stats'),
      );

      expect(find.text('YOUR GROUND'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
    });

    testWidgets('renders the trailing widget when provided', (tester) async {
      await pump(
        tester,
        const ScreenHeader(
          eyebrow: 'TRAIL OF',
          title: 'Morning workout',
          trailing: Text('Ridge'),
        ),
      );

      expect(find.text('Ridge'), findsOneWidget);
    });

    testWidgets('renders no trailing widget when none is supplied',
        (tester) async {
      await pump(
        tester,
        const ScreenHeader(eyebrow: 'PROFILE', title: 'You'),
      );

      // Only the two Text widgets ScreenHeader itself renders.
      expect(find.byType(Text), findsNWidgets(2));
    });

    testWidgets(
        'the eyebrow stays top-aligned even with a trailing widget much '
        'taller than the eyebrow+title column - the exact drift Trail\'s '
        'own rank pill used to cause (see screen_header.dart doc comment)',
        (tester) async {
      await pump(
        tester,
        const ScreenHeader(eyebrow: 'TRAIL OF', title: 'Morning workout'),
      );
      final noTrailingY = tester.getTopLeft(find.text('TRAIL OF')).dy;

      await pump(
        tester,
        ScreenHeader(
          eyebrow: 'TRAIL OF',
          title: 'Morning workout',
          trailing: Container(width: 60, height: 120, color: Colors.red),
        ),
      );
      final withTrailingY = tester.getTopLeft(find.text('TRAIL OF')).dy;

      expect(withTrailingY, noTrailingY);
    });

    testWidgets('the title uses AppTextStyles.screenTitle by default',
        (tester) async {
      await pump(
        tester,
        const ScreenHeader(eyebrow: 'PROFILE', title: 'You'),
      );

      final text = tester.widget<Text>(find.text('You'));
      expect(text.style, AppTextStyles.screenTitle);
    });

    testWidgets('titleStyle overrides the default title style',
        (tester) async {
      await pump(
        tester,
        const ScreenHeader(
          eyebrow: 'Wed, Jul 22',
          title: 'Good morning, Sam',
          titleStyle: AppTextStyles.greeting,
        ),
      );

      final text = tester.widget<Text>(find.text('Good morning, Sam'));
      expect(text.style, AppTextStyles.greeting);
    });
  });
}
