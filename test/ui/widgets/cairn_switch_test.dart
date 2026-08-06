import 'package:cairn/src/ui/theme/app_colors.dart';
import 'package:cairn/src/ui/widgets/cairn_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the shared on/off switch defined by
/// `Cairn Notifications.dc.html`.
void main() {
  Future<void> pumpSwitch(
    WidgetTester tester, {
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: CairnSwitch(value: value, onChanged: onChanged)),
        ),
      ),
    );
  }

  Container track(WidgetTester tester) => tester.widget<Container>(
        find.descendant(
          of: find.byType(CairnSwitch),
          matching: find.byType(Container),
        ).first,
      );

  testWidgets('reports the value it would move to, not the one it has',
      (tester) async {
    final changes = <bool>[];
    await pumpSwitch(tester, value: false, onChanged: changes.add);

    await tester.tap(find.byType(CairnSwitch));
    await tester.pump();
    expect(changes, [true]);

    await pumpSwitch(tester, value: true, onChanged: changes.add);
    await tester.tap(find.byType(CairnSwitch));
    await tester.pump();
    expect(changes, [true, false]);
  });

  testWidgets('a null onChanged makes it non-interactive', (tester) async {
    await pumpSwitch(tester, value: false, onChanged: null);

    final gesture = tester.widget<GestureDetector>(
      find.descendant(
        of: find.byType(CairnSwitch),
        matching: find.byType(GestureDetector),
      ),
    );
    expect(gesture.onTap, isNull);

    // And a tap really is inert rather than merely unwired.
    await tester.tap(find.byType(CairnSwitch));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the knob sits at the end when on and the start when off',
      (tester) async {
    await pumpSwitch(tester, value: true, onChanged: (_) {});
    expect(track(tester).alignment, AlignmentDirectional.centerEnd);

    await pumpSwitch(tester, value: false, onChanged: (_) {});
    expect(track(tester).alignment, AlignmentDirectional.centerStart);
  });

  testWidgets('the track is the sage gradient when on and the flat recessed '
      'fill when off', (tester) async {
    await pumpSwitch(tester, value: true, onChanged: (_) {});
    var decoration = track(tester).decoration! as BoxDecoration;
    expect(decoration.gradient, isNotNull);
    expect(decoration.color, isNull);

    await pumpSwitch(tester, value: false, onChanged: (_) {});
    decoration = track(tester).decoration! as BoxDecoration;
    expect(decoration.gradient, isNull);
    expect(decoration.color, AppColors.switchTrackOff);
  });

  testWidgets('exposes its toggled state and enabled-ness to screen readers',
      (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CairnSwitch(
              value: true,
              semanticLabel: 'Habit reminders',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(CairnSwitch)),
      matchesSemantics(
        label: 'Habit reminders',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    handle.dispose();
  });
}
