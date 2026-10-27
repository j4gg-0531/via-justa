import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/session/session_providers.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';
import 'package:via_justa/features/onboarding/presentation/state/profile_type_provider.dart';
import 'package:via_justa/features/profile/presentation/pages/profile_page.dart';

Widget _buildProfilePage(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: ProfilePage(),
    ),
  );
}

void main() {
  testWidgets('renders user profile details and settings sections', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(userNameProvider.notifier).setName('Carlos Vives');

    await tester.pumpWidget(_buildProfilePage(container));
    await tester.pumpAndSettle();

    expect(find.text('profile.title'), findsOneWidget);
    expect(find.text('profile.subtitle'), findsOneWidget);
    expect(find.text('Carlos Vives'), findsOneWidget);
    expect(find.text('profile.user_email'), findsOneWidget);
    expect(find.text('profile.section_profile'), findsOneWidget);
    expect(find.text('profile.section_location'), findsOneWidget);
    expect(find.text('profile.section_language'), findsOneWidget);
    expect(find.text('profile.lang_es'), findsOneWidget);
    expect(find.text('profile.lang_en'), findsOneWidget);
    expect(find.text('profile.sign_out'), findsOneWidget);
  });

  testWidgets('change profile dialog updates profileTypeProvider', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildProfilePage(container));
    await tester.pumpAndSettle();

    // Default profile is null / visitor
    expect(container.read(profileTypeProvider), isNull);

    // Tap change profile button
    await tester.tap(find.text('home.change_city').first);
    await tester.pumpAndSettle();

    expect(find.text('profile.dialog_profile_title'), findsOneWidget);
    expect(find.text('onboarding.settler.title'), findsOneWidget);

    // Select settler
    await tester.tap(find.text('onboarding.settler.title'));
    await tester.pumpAndSettle();

    expect(container.read(profileTypeProvider), ProfileType.settler);
  });

  testWidgets('sign out clears complete user session state', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Prepopulate user state
    container.read(userNameProvider.notifier).setName('María');
    container.read(profileTypeProvider.notifier).select(ProfileType.settler);
    container.read(selectedMunicipalityProvider.notifier).select(
          const Municipality(
            code: '20001',
            name: 'Valledupar',
            departmentCode: '20',
            isPilot: true,
          ),
        );
    container.read(municipalityInterestProvider.notifier).register('20001');
    container.read(businessSearchQueryProvider.notifier).updateQuery('Pan');
    container
        .read(businessCategoryProvider.notifier)
        .selectCategory(BusinessCategory.food);

    expect(container.read(userNameProvider), 'María');
    expect(container.read(profileTypeProvider), ProfileType.settler);
    expect(container.read(selectedMunicipalityProvider)?.code, '20001');
    expect(container.read(municipalityInterestProvider), contains('20001'));
    expect(container.read(businessSearchQueryProvider), 'Pan');
    expect(container.read(businessCategoryProvider), BusinessCategory.food);

    await tester.pumpWidget(_buildProfilePage(container));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('profile.sign_out'));
    await tester.tap(find.text('profile.sign_out'));
    await tester.pumpAndSettle();

    // Verify all session state was reset
    expect(container.read(userNameProvider), isNull);
    expect(container.read(profileTypeProvider), isNull);
    expect(container.read(selectedMunicipalityProvider), isNull);
    expect(container.read(municipalityInterestProvider), isEmpty);
    expect(container.read(businessSearchQueryProvider), isEmpty);
    expect(container.read(businessCategoryProvider), isNull);
  });
}
