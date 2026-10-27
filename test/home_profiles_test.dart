import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/home/presentation/pages/home_page.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';
import 'package:via_justa/features/onboarding/presentation/state/profile_type_provider.dart';

class _FakeProfileTypeNotifier extends ProfileTypeNotifier {
  _FakeProfileTypeNotifier(this._initial);
  final ProfileType? _initial;

  @override
  ProfileType? build() => _initial;
}

Widget _buildHome(ProfileType? profile) {
  return ProviderScope(
    overrides: [
      profileTypeProvider.overrideWith(() => _FakeProfileTypeNotifier(profile)),
    ],
    child: const MaterialApp(
      home: HomePage(),
    ),
  );
}

void main() {
  testWidgets('renders visitor view by default or when visitor profile is active',
      (tester) async {
    await tester.pumpWidget(_buildHome(ProfileType.visitor));
    await tester.pumpAndSettle();

    expect(find.text('home.visitor_banner_title'), findsOneWidget);
    expect(find.text('home.visitor_banner_badge'), findsOneWidget);
    expect(find.text('home.profile_tag_visitor'), findsOneWidget);
    expect(find.text('home.tools_title'), findsOneWidget);
  });

  testWidgets('renders settler view with procedures and documents cards',
      (tester) async {
    await tester.pumpWidget(_buildHome(ProfileType.settler));
    await tester.pumpAndSettle();

    expect(find.text('home.settler_card_title'), findsOneWidget);
    expect(find.text('home.settler_card_badge'), findsOneWidget);
    expect(find.text('home.profile_tag_settler'), findsOneWidget);
    expect(find.text('home.procedures_title'), findsOneWidget);
    expect(find.text('home.documents_title'), findsOneWidget);

    // Tapping procedures card opens feature dialog
    await tester.tap(find.text('home.procedures_title'));
    await tester.pumpAndSettle();

    expect(find.text('home.feature_dialog_body'), findsOneWidget);
    await tester.tap(find.text('common.close'));
    await tester.pumpAndSettle();
  });

  testWidgets('renders resident view with local business action',
      (tester) async {
    await tester.pumpWidget(_buildHome(ProfileType.resident));
    await tester.pumpAndSettle();

    expect(find.text('home.resident_card_title'), findsOneWidget);
    expect(find.text('home.resident_card_badge'), findsOneWidget);
    expect(find.text('home.profile_tag_resident'), findsOneWidget);
    expect(find.text('businesses.register_action'), findsOneWidget);

    // Tapping register business opens dialog
    await tester.tap(find.text('businesses.register_action'));
    await tester.pumpAndSettle();

    expect(find.text('businesses.register_dialog_body'), findsOneWidget);
    await tester.tap(find.text('common.close'));
    await tester.pumpAndSettle();
  });

  testWidgets('contribute price card opens demo dialog', (tester) async {
    await tester.pumpWidget(_buildHome(null));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('home.contribute_action_title'),
      200,
    );
    await tester.tap(find.text('home.contribute_action_title'));
    await tester.pumpAndSettle();

    expect(find.text('home.contribute_dialog_title'), findsOneWidget);
    expect(find.text('home.contribute_dialog_body'), findsOneWidget);
    await tester.tap(find.text('common.close'));
    await tester.pumpAndSettle();
  });
}
