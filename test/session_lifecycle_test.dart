import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/demo/demo_data.dart';
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

void main() {
  group('Session lifecycle and clean logout', () {
    test(
        'logging out completely resets state and new login has zero leftover data from previous user',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sessionController = container.read(sessionControllerProvider);

      // --- 1. Sesión de Usuario A ---
      container.read(userNameProvider.notifier).setName('Carlos Vives');
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
      container.read(businessSearchQueryProvider.notifier).updateQuery('Taxis');
      container
          .read(businessCategoryProvider.notifier)
          .selectCategory(BusinessCategory.transport);

      // Verificación de datos de Usuario A
      expect(container.read(userNameProvider), 'Carlos Vives');
      expect(container.read(displayNameProvider), 'Carlos Vives');
      expect(container.read(profileTypeProvider), ProfileType.settler);
      expect(container.read(selectedMunicipalityProvider)?.name, 'Valledupar');
      expect(container.read(municipalityInterestProvider), {'20001'});
      expect(container.read(businessSearchQueryProvider), 'Taxis');
      expect(
        container.read(businessCategoryProvider),
        BusinessCategory.transport,
      );

      // --- 2. Cierre de sesión (Logout centralizado) ---
      sessionController.signOut();

      // Verificación de que ningún dato de Usuario A persiste
      expect(container.read(userNameProvider), isNull);
      expect(container.read(displayNameProvider), DemoData.userName);
      expect(container.read(profileTypeProvider), isNull);
      expect(container.read(selectedMunicipalityProvider), isNull);
      expect(container.read(municipalityInterestProvider), isEmpty);
      expect(container.read(businessSearchQueryProvider), isEmpty);
      expect(container.read(businessCategoryProvider), isNull);

      // --- 3. Sesión de Usuario B (Nuevo ingreso) ---
      container.read(userNameProvider.notifier).setName('Ana María');
      container.read(profileTypeProvider.notifier).select(ProfileType.resident);
      container.read(selectedMunicipalityProvider.notifier).select(
            const Municipality(
              code: '20011',
              name: 'Aguachica',
              departmentCode: '20',
              isPilot: false,
            ),
          );
      container.read(municipalityInterestProvider.notifier).register('20011');
      container.read(businessSearchQueryProvider.notifier).updateQuery('Café');
      container
          .read(businessCategoryProvider.notifier)
          .selectCategory(BusinessCategory.food);

      // Verificación de que solo existen los datos de Usuario B sin residuos
      expect(container.read(userNameProvider), 'Ana María');
      expect(container.read(displayNameProvider), 'Ana María');
      expect(container.read(profileTypeProvider), ProfileType.resident);
      expect(container.read(selectedMunicipalityProvider)?.name, 'Aguachica');
      expect(container.read(municipalityInterestProvider), {'20011'});
      expect(
        container.read(municipalityInterestProvider),
        isNot(contains('20001')),
      );
      expect(container.read(businessSearchQueryProvider), 'Café');
      expect(
        container.read(businessCategoryProvider),
        BusinessCategory.food,
      );
    });

    test('deleteAccount clears feature state only when deletion succeeds', () async {
      final failingRepo = _SessionFakeAuthRepository(failDelete: true);
      final failingContainer = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(failingRepo)],
      );
      addTearDown(failingContainer.dispose);
      addTearDown(failingRepo.dispose);

      failingContainer.read(authControllerProvider);
      await Future<void>.delayed(Duration.zero);
      failingContainer.read(userNameProvider.notifier).setName('Ana');
      failingContainer
          .read(profileTypeProvider.notifier)
          .select(ProfileType.settler);

      final failedResult = await failingContainer
          .read(sessionControllerProvider)
          .deleteAccount();
      expect(failedResult, isFalse);
      expect(failingContainer.read(userNameProvider), 'Ana');
      expect(failingContainer.read(profileTypeProvider), ProfileType.settler);

      final successRepo = _SessionFakeAuthRepository(failDelete: false);
      final successContainer = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(successRepo)],
      );
      addTearDown(successContainer.dispose);
      addTearDown(successRepo.dispose);

      successContainer.read(authControllerProvider);
      await Future<void>.delayed(Duration.zero);
      successContainer.read(userNameProvider.notifier).setName('Ana');
      successContainer
          .read(profileTypeProvider.notifier)
          .select(ProfileType.settler);

      final okResult = await successContainer
          .read(sessionControllerProvider)
          .deleteAccount();
      expect(okResult, isTrue);
      expect(successContainer.read(userNameProvider), isNull);
      expect(successContainer.read(profileTypeProvider), isNull);
    });
  });
}

class _SessionFakeAuthRepository implements AuthRepository {
  _SessionFakeAuthRepository({required this.failDelete});

  final bool failDelete;
  final StreamController<AuthSession?> _sessions =
      StreamController<AuthSession?>.broadcast();
  AuthSession? _session = const AuthSession(
    userId: 'user-1',
    email: 'ana@viajusta.co',
  );

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
  Future<bool> signInWithGoogle() async => true;

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
    if (failDelete) throw const AuthFailure(AuthFailureKind.network);
    _session = null;
  }

  @override
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> verifyRecoveryOtpAndResetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {}

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

  @override
  Future<bool> hasAcceptedConsents({
    required String userId,
    required List<ConsentDocType> documents,
    required String version,
  }) async => true;

  void dispose() => _sessions.close();
}
