import 'package:doctor_appointment_app/screens/login_screen.dart';
import 'package:doctor_appointment_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// These tests only exercise client-side validation and navigation, which run
// before any Firebase call, so Firebase does not need to be initialised.
Widget _app() =>
    MaterialApp(theme: AppTheme.lightTheme, home: const LoginScreen());

void main() {
  testWidgets('renders the login form', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('empty fields show a validation message', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    expect(find.text('Please fill in both email and password.'), findsOneWidget);
  });

  testWidgets('malformed email is rejected before any network call', (tester) async {
    await tester.pumpWidget(_app());
    await tester.enterText(find.byType(TextField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextField).at(1), 'secret12');
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    expect(find.text('Please enter a valid email address.'), findsOneWidget);
  });

  testWidgets('password visibility can be toggled', (tester) async {
    await tester.pumpWidget(_app());
    EditableText field() =>
        tester.widget<EditableText>(find.byType(EditableText).at(1));
    expect(field().obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();
    expect(field().obscureText, isFalse);
  });

  testWidgets('Register now opens the sign-up screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('Register now'));
    await tester.pumpAndSettle();
    expect(find.text('Create Account'), findsOneWidget);
  });
}
