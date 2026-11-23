import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/session/session_providers.dart';
import 'package:via_justa/features/auth/domain/auth_repository.dart';
import 'package:via_justa/features/auth/domain/auth_session.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';
import 'package:via_justa/features/auth/domain/sign_up_result.dart';
import 'package:via_justa/features/auth/domain/user_profile.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';
import 'package:via_justa/features/onboarding/presentation/pages/profile_selection_page.dart';

class _GoogleOnboardingFakeRepo implements AuthRepository {
  final StreamController<AuthSession?> _sessions =
      StreamController<AuthSession?>.broadcast();
  final Set<String> acceptedConsents = <String>{};
  int deleteCalls = 0;

  @override
  bool get usesDemoData => false;

  @override
  Stream<AuthSession?> watchSession() => _sessions.stream;

  @override
  Future<AuthSession?> currentSession() async => const AuthSession(
    userId: 'google-1',
    email: 'garciagonzalezj04@gmail.com',
    isExternalProvider: true,
    suggestedDisplayName: 'Juan Garcia',
  );

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async =>
      throw UnimplementedError();

  @override
  Future<bool> signInWithGoogle() async => true;

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
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
  Future<UserProfile?> fetchProfile(String userId) async => const UserProfile(
    id: 'google-1',
    displayName: 'Juan Garcia',
  );

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
  }) async {
    for (final doc in documents) {
      acceptedConsents.add('${version}_${doc.wireValue}');
    }
  }

  @override
  Future<bool> hasAcceptedConsents({
    required String userId,
    required List<ConsentDocType> documents,
    required String version,
  }) async {
    return documents.every(
      (doc) => acceptedConsents.contains('${version}_${doc.wireValue}'),
    );
  }

  void dispose() => _sessions.close();
}

void main() {
  testWidgets(
    'new Google account shows confirmation before onboarding and registers consents on accept',
    (tester) async {
      final repo = _GoogleOnboardingFakeRepo();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProfileSelectionPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('onboarding.google_consent.title'), findsOneWidget);
      expect(find.text('Juan Garcia'), findsOneWidget);
      expect(find.text('garciagonzalezj04@gmail.com'), findsOneWidget);
      expect(find.text('onboarding.visitor.title'), findsNothing);

      await tester.tap(find.text('onboarding.google_consent.accept_cta'));
      await tester.pumpAndSettle();

      expect(repo.acceptedConsents, hasLength(2));
      expect(find.text('onboarding.visitor.title'), findsOneWidget);
      expect(container.read(userNameProvider), 'Juan Garcia');
    },
  );

  testWidgets(
    'canceling new Google account deletes orphan account and clears state',
    (tester) async {
      final repo = _GoogleOnboardingFakeRepo();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProfileSelectionPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('onboarding.google_consent.cancel_cta'));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls, 1);
      expect(container.read(authControllerProvider).isAuthenticated, isFalse);
      expect(container.read(userNameProvider), isNull);
    },
  );

  testWidgets(
    'new Google account consent screen renders without overflow at 360dp and 2x font scale',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = _GoogleOnboardingFakeRepo();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2.0),
              ),
              child: child!,
            ),
            home: const ProfileSelectionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('onboarding.google_consent.title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
