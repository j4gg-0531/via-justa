import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/auth/presentation/pages/login_page.dart';
import 'package:via_justa/features/auth/presentation/pages/register_page.dart';
import 'package:via_justa/features/auth/presentation/pages/welcome_page.dart';

Widget _buildPage(Widget page) {
  return ProviderScope(child: MaterialApp(home: page));
}

void main() {
  testWidgets('login renders Google button, shows email/password errors and opens forgot-password dialog', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage(const LoginPage()));

    expect(find.text('login.google'), findsOneWidget);
    expect(find.text('auth.forgot_password'), findsOneWidget);

    await tester.ensureVisible(find.text('common.continue'));
    await tester.tap(find.text('common.continue'));
    await tester.pump();

    expect(find.text('auth.error.email_empty'), findsOneWidget);
    expect(find.text('auth.error.password_empty'), findsOneWidget);

    await tester.tap(find.text('auth.forgot_password'));
    await tester.pumpAndSettle();
    expect(find.text('auth.forgot_password_title'), findsOneWidget);
    await tester.tap(find.text('common.close'));
    await tester.pumpAndSettle();
  });

  testWidgets('register renders Google button and shows five errors including confirm password', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage(const RegisterPage()));

    expect(find.text('login.google'), findsOneWidget);
    expect(find.text('auth.confirm_password'), findsOneWidget);

    await tester.ensureVisible(find.text('register.submit'));
    await tester.tap(find.text('register.submit'));
    await tester.pump();

    expect(find.text('auth.error.name_empty'), findsOneWidget);
    expect(find.text('auth.error.email_empty'), findsOneWidget);
    expect(find.text('auth.error.password_empty'), findsOneWidget);
    expect(find.text('auth.error.confirm_password_empty'), findsOneWidget);
    expect(find.text('auth.error.terms_required'), findsOneWidget);
  });

  testWidgets('welcome legal links open Terms and Privacy dialogs', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage(const WelcomePage()));
    await tester.pumpAndSettle();

    await tester.tapOnText(find.textRange.ofSubstring('login.legal_terms'));
    await tester.pumpAndSettle();

    expect(find.text('legal.terms_title'), findsOneWidget);
    expect(find.text('legal.terms_body'), findsOneWidget);

    await tester.tap(find.text('common.close'));
    await tester.pumpAndSettle();

    await tester.tapOnText(find.textRange.ofSubstring('login.legal_privacy'));
    await tester.pumpAndSettle();

    expect(find.text('legal.privacy_title'), findsOneWidget);
    expect(find.text('legal.privacy_body'), findsOneWidget);
  });
}
