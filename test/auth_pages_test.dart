import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/auth/presentation/pages/login_page.dart';
import 'package:via_justa/features/auth/presentation/pages/register_page.dart';

Widget _buildPage(Widget page) {
  return ProviderScope(child: MaterialApp(home: page));
}

void main() {
  testWidgets('login shows email and password errors after an empty submit', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage(const LoginPage()));

    await tester.ensureVisible(find.text('common.continue'));
    await tester.tap(find.text('common.continue'));
    await tester.pump();

    expect(find.text('auth.error.email_empty'), findsOneWidget);
    expect(find.text('auth.error.password_empty'), findsOneWidget);
  });

  testWidgets('register shows the four errors after an empty submit', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage(const RegisterPage()));

    await tester.ensureVisible(find.text('register.submit'));
    await tester.tap(find.text('register.submit'));
    await tester.pump();

    expect(find.text('auth.error.name_empty'), findsOneWidget);
    expect(find.text('auth.error.email_empty'), findsOneWidget);
    expect(find.text('auth.error.password_empty'), findsOneWidget);
    expect(find.text('auth.error.terms_required'), findsOneWidget);
  });
}
