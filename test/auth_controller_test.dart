import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/session/session_providers.dart';
import 'package:via_justa/features/auth/data/demo_auth_repository.dart';
import 'package:via_justa/features/auth/domain/auth_failure.dart';
import 'package:via_justa/features/auth/domain/auth_repository.dart';
import 'package:via_justa/features/auth/domain/auth_session.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';
import 'package:via_justa/features/auth/domain/sign_up_result.dart';
import 'package:via_justa/features/auth/domain/user_profile.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';
import 'package:via_justa/features/onboarding/presentation/state/profile_type_provider.dart';

/// Repositorio falso: registra llamadas y permite forzar fallos concretos.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository();

  final StreamController<AuthSession?> _sessions =
      StreamController<AuthSession?>.broadcast();

  AuthSession? storedSession;
  UserProfile? storedProfile;
  AuthFailure? signInFailure;
  AuthFailure? signUpFailure;
  bool confirmationRequired = false;

  final List<ConsentDocType> recordedConsents = <ConsentDocType>[];
  final List<String> savedDisplayNames = <String>[];
  final List<String> savedLanguages = <String>[];
  final List<ProfileType> savedProfileTypes = <ProfileType>[];
  final List<String> savedMunicipalityCodes = <String>[];

  @override
  bool get usesDemoData => false;

  @override
  Stream<AuthSession?> watchSession() => _sessions.stream;

  void emitSession(AuthSession? session) => _sessions.add(session);

  @override
  Future<AuthSession?> currentSession() async => storedSession;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final failure = signInFailure;
    if (failure != null) throw failure;
    final session = AuthSession(userId: 'user-1', email: email);
    storedSession = session;
    return session;
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final failure = signUpFailure;
    if (failure != null) throw failure;

    if (confirmationRequired) {
      return const SignUpResult(confirmationRequired: true);
    }
    final session = AuthSession(userId: 'user-1', email: email);
    storedSession = session;
    storedProfile = UserProfile(id: 'user-1', displayName: displayName);
    return SignUpResult(session: session);
  }

  @override
  Future<void> signOut() async {
    storedSession = null;
  }

  @override
  Future<UserProfile?> fetchProfile(String userId) async => storedProfile;

  @override
  Future<void> saveDisplayName(String userId, String displayName) async {
    savedDisplayNames.add(displayName);
    storedProfile = (storedProfile ?? UserProfile(id: userId)).copyWith(
      displayName: displayName,
    );
  }

  @override
  Future<void> saveLanguage(String userId, String language) async {
    savedLanguages.add(language);
  }

  @override
  Future<void> saveProfileType(String userId, ProfileType type) async {
    savedProfileTypes.add(type);
  }

  @override
  Future<void> saveCurrentMunicipality(
    String userId,
    String municipalityCode,
  ) async {
    savedMunicipalityCodes.add(municipalityCode);
    storedProfile = (storedProfile ?? UserProfile(id: userId)).copyWith(
      currentMunicipalityCode: municipalityCode,
    );
  }

  @override
  Future<void> registerConsents({
    required String userId,
    required List<ConsentDocType> documents,
    required String version,
  }) async {
    recordedConsents.addAll(documents);
  }

  void dispose() => _sessions.close();
}

ProviderContainer _containerWith(_FakeAuthRepository repository) {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  addTearDown(repository.dispose);
  return container;
}

void main() {
  group('AuthController', () {
    test('signIn stores the session and hydrates the local profile', () async {
      final repository = _FakeAuthRepository()
        ..storedProfile = const UserProfile(
          id: 'user-1',
          displayName: 'Ana María',
          profileType: ProfileType.settler,
        );
      final container = _containerWith(repository);

      final ok = await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'ana@example.test', password: 'secreto123');

      final state = container.read(authControllerProvider);
      expect(ok, isTrue);
      expect(state.isAuthenticated, isTrue);
      expect(state.email, 'ana@example.test');
      expect(state.profile?.displayName, 'Ana María');
      expect(container.read(userNameProvider), 'Ana María');
      expect(container.read(profileTypeProvider), ProfileType.settler);
    });

    test('signIn exposes a typed failure without a session', () async {
      final repository = _FakeAuthRepository()
        ..signInFailure = const AuthFailure(AuthFailureKind.invalidCredentials);
      final container = _containerWith(repository);

      final ok = await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'ana@example.test', password: 'mala');

      final state = container.read(authControllerProvider);
      expect(ok, isFalse);
      expect(state.isAuthenticated, isFalse);
      expect(state.isBusy, isFalse);
      expect(state.failure?.kind, AuthFailureKind.invalidCredentials);
    });

    test('signUp registers both consents and the display name', () async {
      final repository = _FakeAuthRepository();
      final container = _containerWith(repository);

      final ok = await container
          .read(authControllerProvider.notifier)
          .signUp(
            email: 'ana@example.test',
            password: 'secreto123',
            displayName: 'Ana María',
          );

      expect(ok, isTrue);
      expect(repository.recordedConsents, [
        ConsentDocType.termsAndConditions,
        ConsentDocType.privacyPolicy,
      ]);
      expect(repository.savedDisplayNames, ['Ana María']);
      expect(container.read(userNameProvider), 'Ana María');
      expect(container.read(authControllerProvider).email, 'ana@example.test');
    });

    test('signUp reports a pending email confirmation', () async {
      final repository = _FakeAuthRepository()..confirmationRequired = true;
      final container = _containerWith(repository);

      final ok = await container
          .read(authControllerProvider.notifier)
          .signUp(
            email: 'ana@example.test',
            password: 'secreto123',
            displayName: 'Ana',
          );

      expect(ok, isFalse);
      expect(repository.recordedConsents, isEmpty);
      expect(
        container.read(authControllerProvider).failure?.kind,
        AuthFailureKind.emailConfirmationRequired,
      );
    });

    test('signOut clears the session', () async {
      final repository = _FakeAuthRepository();
      final container = _containerWith(repository);
      final controller = container.read(authControllerProvider.notifier);

      await controller.signIn(email: 'ana@example.test', password: 'secreto123');
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);

      await controller.signOut();
      expect(container.read(authControllerProvider).isAuthenticated, isFalse);
    });

    test('a session event with null signs the user out', () async {
      final repository = _FakeAuthRepository();
      final container = _containerWith(repository);
      final controller = container.read(authControllerProvider.notifier);

      await controller.signIn(email: 'ana@example.test', password: 'secreto123');

      repository.emitSession(null);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authControllerProvider).isAuthenticated, isFalse);
    });

    test('persistProfileType saves visitor, settler and resident (D11 ratified)', () async {
      final repository = _FakeAuthRepository();
      final container = _containerWith(repository);
      final controller = container.read(authControllerProvider.notifier);
      await controller.signIn(email: 'ana@example.test', password: 'secreto123');

      expect(await controller.persistProfileType(ProfileType.visitor), isTrue);
      expect(await controller.persistProfileType(ProfileType.settler), isTrue);
      expect(await controller.persistProfileType(ProfileType.resident), isTrue);
      expect(repository.savedProfileTypes, [
        ProfileType.visitor,
        ProfileType.settler,
        ProfileType.resident,
      ]);
    });

    test('saveCurrentMunicipality reaches the repository and updates profile', () async {
      final repository = _FakeAuthRepository();
      final container = _containerWith(repository);
      final controller = container.read(authControllerProvider.notifier);
      await controller.signIn(email: 'ana@example.test', password: 'secreto123');

      expect(await controller.saveCurrentMunicipality('20001'), isTrue);
      expect(repository.savedMunicipalityCodes, ['20001']);
      expect(
        container.read(authControllerProvider).profile?.currentMunicipalityCode,
        '20001',
      );
    });

    test('saveDisplayName and saveLanguage reach the repository', () async {
      final repository = _FakeAuthRepository();
      final container = _containerWith(repository);
      final controller = container.read(authControllerProvider.notifier);
      await controller.signIn(email: 'ana@example.test', password: 'secreto123');

      expect(await controller.saveDisplayName('  Carla  '), isTrue);
      expect(await controller.saveLanguage('en'), isTrue);

      expect(repository.savedDisplayNames, ['Carla']);
      expect(repository.savedLanguages, ['en']);
      expect(container.read(userNameProvider), 'Carla');
    });
  });

  group('DemoAuthRepository', () {
    test('keeps an in-memory session labelled as demo', () async {
      final repository = DemoAuthRepository();
      addTearDown(repository.dispose);

      expect(repository.usesDemoData, isTrue);
      expect(await repository.currentSession(), isNull);

      final result = await repository.signUp(
        email: 'demo@example.test',
        password: 'secreto123',
        displayName: 'Demo',
      );

      expect(result.isSignedIn, isTrue);
      expect(await repository.currentSession(), isNotNull);
      expect((await repository.fetchProfile('x'))?.displayName, 'Demo');

      await repository.signOut();
      expect(await repository.currentSession(), isNull);
    });

    test('accepts resident as a persistable profile type (D11 ratified)', () async {
      final repository = DemoAuthRepository();
      addTearDown(repository.dispose);

      await repository.saveProfileType('demo', ProfileType.resident);
      final profile = await repository.fetchProfile('demo');
      expect(profile?.profileType, ProfileType.resident);
    });

    test('saveCurrentMunicipality saves municipality in DemoAuthRepository', () async {
      final repository = DemoAuthRepository();
      addTearDown(repository.dispose);

      await repository.saveCurrentMunicipality('demo', '20001');
      final profile = await repository.fetchProfile('demo');
      expect(profile?.currentMunicipalityCode, '20001');
    });
  });
}
