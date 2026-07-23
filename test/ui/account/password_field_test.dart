import 'package:cairn/src/ui/account/password_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('starts obscured, and the eye toggle shows/hides the password',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      wrap(PasswordField(label: 'Password', controller: controller)),
    );
    await tester.enterText(find.byType(TextField), 'hunter2');

    TextField field() => tester.widget<TextField>(find.byType(TextField));
    expect(field().obscureText, isTrue);

    await tester.tap(find.bySemanticsLabel('Show password'));
    await tester.pump();
    expect(field().obscureText, isFalse);

    await tester.tap(find.bySemanticsLabel('Hide password'));
    await tester.pump();
    expect(field().obscureText, isTrue);
  });

  testWidgets('renders the error row when error is given', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      wrap(PasswordField(
        label: 'Password',
        controller: controller,
        error: const Text('Password needs at least 6 characters.'),
      )),
    );

    expect(find.text('Password needs at least 6 characters.'), findsOneWidget);
  });

  testWidgets('disabled when enabled is false', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      wrap(PasswordField(
        label: 'Password',
        controller: controller,
        enabled: false,
      )),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
  });
}
