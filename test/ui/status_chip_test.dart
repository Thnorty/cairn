import 'package:cairn/src/ui/widgets/status_chip.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: child),
    );
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
  });
}
