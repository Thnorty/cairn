import 'package:cairn/src/ui/account/otp_code_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders 6 boxes and composes the typed code via onChanged',
      (tester) async {
    final codes = <String>[];
    await tester.pumpWidget(
      wrap(OtpCodeInput(onChanged: codes.add)),
    );

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(6));

    for (var i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), '${i + 1}');
      await tester.pump();
    }

    expect(codes.last, '123456');
  });

  testWidgets('auto-advances focus to the next box after a digit',
      (tester) async {
    await tester.pumpWidget(wrap(OtpCodeInput(onChanged: (_) {})));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '4');
    await tester.pump();

    final secondField = tester.widget<TextField>(fields.at(1));
    expect(secondField.focusNode!.hasFocus, isTrue);
  });

  testWidgets('a partial code (fewer than 6 digits) is still reported',
      (tester) async {
    final codes = <String>[];
    await tester.pumpWidget(wrap(OtpCodeInput(onChanged: codes.add)));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '4');
    await tester.pump();
    await tester.enterText(fields.at(1), '2');
    await tester.pump();

    expect(codes.last, '42');
  });
}
