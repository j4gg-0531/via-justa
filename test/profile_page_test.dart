import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/session/session_providers.dart';
import 'package:via_justa/features/auth/domain/auth_failure.dart';
import 'package:via_justa/features/auth/domain/auth_repository.dart';
import 'package:via_justa/features/auth/domain/auth_session.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';
import 'package:via_justa/features/auth/domain/sign_up_result.dart';
import 'package:via_justa/features/auth/domain/user_profile.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';
import 'package:via_justa/features/onboarding/presentation/state/profile_type_provider.dart';
import 'package:via_justa/features/profile/presentation/pages/profile_page.dart';

class _ProfileFakeAuthRepository implements AuthRepository {
  _ProfileFakeAuthRepository({this.failDelete = false});

  final bool failDelete;
  final StreamController<AuthSession?> _sessions =
      StreamController<AuthSession?>.broadcast();
  AuthSession? _session = const AuthSession(
    userId: 'user-1',
    email: 'ana@viajusta.co',
  );
  int deleteCalls = 0;

  @override
  bool get usesDemoData => false;

  @override
  Stream<AuthSession?> watchSession() => _sessions.stream;

  @override
  Future<AuthSession?> currentSession() async => _session;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async =>
      _session!;

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async =>
      SignUpResult(session: _session);

  @override
  Future<void> signOut() async {
    _session = null;
  }

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    if (failDelete) {
      throw const AuthFailure(AuthFailureKind.network);
    }
    _session = null;
  }

  @override
  Future<UserProfile?> fetchProfile(String userId) async =>
      const UserProfile(id: 'user-1', displayName: 'Ana');

  @override
  Future<void> saveDisplayName(String userId, String displayName) async {}

  @override
  Future<void> saveLanguage(String userId, String language) async {}

  @override
  Future<void> saveProfileType(String userId, ProfileType type) async {}

  @override
  Future<void> saveCurrentMunicipality(
    String userId,
    String municipalityCode,
  ) async {}

  @override
  Future<void> registerConsents({
    required String userId,
    required List<ConsentDocType> documents,
    required String version,
  }) async {}

  void dispose() => _sessions.close();
}

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

  testWidgets('terms and privacy tiles open full Law 1581 dialogs', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_buildProfilePage(container));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('profile.terms'));
    await tester.tap(find.text('profile.terms'));
    await tester.pumpAndSettle();

    expect(find.text('legal.terms_title'), findsOneWidget);
    expect(find.text('legal.terms_body'), findsOneWidget);
    await tester.tap(find.text('common.close'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('profile.privacy'));
    await tester.tap(find.text('profile.privacy'));
    await tester.pumpAndSettle();

    expect(find.text('legal.privacy_title'), findsOneWidget);
    expect(find.text('legal.privacy_body'), findsOneWidget);
  });

  testWidgets('delete account requires checkbox confirmation and clears state on success', (
    tester,
  ) async {
    final fakeRepo = _ProfileFakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepo.dispose);

    await tester.pumpWidget(_buildProfilePage(container));
    await tester.pumpAndSettle();
    container.read(userNameProvider.notifier).setName('Ana');
    container.read(profileTypeProvider.notifier).select(ProfileType.resident);

    await tester.ensureVisible(find.text('profile.delete_account_cta'));
    await tester.tap(find.text('profile.delete_account_cta'));
    await tester.pumpAndSettle();

    expect(find.text('profile.delete_account_dialog_title'), findsOneWidget);

    // El botón destructivo sigue deshabilitado hasta marcar la casilla.
    await tester.tap(find.text('profile.delete_account_confirm_cta'));
    await tester.pump();
    expect(fakeRepo.deleteCalls, 0);

    await tester.tap(find.text('profile.delete_account_confirm_check'));
    await tester.pump();
    await tester.tap(find.text('profile.delete_account_confirm_cta'));
    await tester.pumpAndSettle();

    expect(fakeRepo.deleteCalls, 1);
    expect(container.read(authControllerProvider).isAuthenticated, isFalse);
    expect(container.read(userNameProvider), isNull);
    expect(container.read(profileTypeProvider), isNull);
  });

  testWidgets('delete account keeps session and shows error when RPC fails', (
    tester,
  ) async {
    final fakeRepo = _ProfileFakeAuthRepository(failDelete: true);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepo.dispose);

    await tester.pumpWidget(_buildProfilePage(container));
    await tester.pumpAndSettle();
    container.read(userNameProvider.notifier).setName('Ana');

    await tester.ensureVisible(find.text('profile.delete_account_cta'));
    await tester.tap(find.text('profile.delete_account_cta'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('profile.delete_account_confirm_check'));
    await tester.pump();
    await tester.tap(find.text('profile.delete_account_confirm_cta'));
    await tester.pumpAndSettle();

    expect(fakeRepo.deleteCalls, 1);
    expect(container.read(authControllerProvider).isAuthenticated, isTrue);
    expect(container.read(userNameProvider), 'Ana');
    expect(find.text('auth.error.network'), findsOneWidget);
  });

  testWidgets('profile and delete dialog have no overflow at 360dp and 2.0x text scale', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : true,
        );
    await EasyLocalization.ensureInitialized();
    final translations = jsonDecode(
      File('assets/translations/es.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          startLocale: const Locale('es'),
          path: 'assets/translations',
          assetLoader: _ProfileTestTranslations(translations),
          child: Builder(
            builder: (context) => MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 780),
                textScaler: TextScaler.linear(2.0),
              ),
              child: MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: const ProfilePage(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.text(translations['profile']['delete_account_cta'] as String),
    );
    await tester.tap(
      find.text(translations['profile']['delete_account_cta'] as String),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        translations['profile']['delete_account_dialog_title'] as String,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _ProfileTestTranslations extends AssetLoader {
  const _ProfileTestTranslations(this.data);
  final Map<String, dynamic> data;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => data;
}
