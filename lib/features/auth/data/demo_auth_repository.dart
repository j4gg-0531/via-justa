import 'dart:async';

import 'package:via_justa/features/auth/domain/auth_repository.dart';
import 'package:via_justa/features/auth/domain/auth_session.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';
import 'package:via_justa/features/auth/domain/sign_up_result.dart';
import 'package:via_justa/features/auth/domain/user_profile.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';

/// Repositorio de ejemplo, en memoria, para cuando la app corre sin
/// `SUPABASE_URL`/`SUPABASE_ANON_KEY`.
///
/// Existe para que el recorrido del primer avance siga funcionando sin backend.
/// `usesDemoData` es `true` y las pantallas rotulan el acceso como DEMO. No
/// persiste nada entre reinicios y no valida credenciales reales.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository();

  /// Identificador ficticio; nunca se envía a un servidor.
  static const String demoUserId = 'demo-user';

  final StreamController<AuthSession?> _sessions =
      StreamController<AuthSession?>.broadcast();

  AuthSession? _session;
  UserProfile? _profile;
  final Set<String> _acceptedConsents = <String>{};

  @override
  bool get usesDemoData => true;

  @override
  Stream<AuthSession?> watchSession() {
    return Stream<AuthSession?>.multi((controller) {
      controller.add(_session);
      final subscription = _sessions.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<AuthSession?> currentSession() async => _session;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final session = AuthSession(userId: demoUserId, email: email);
    _session = session;
    _profile ??= UserProfile(id: demoUserId);
    _markAllConsentsAccepted(consentDocumentVersion);
    _sessions.add(session);
    return session;
  }

  @override
  Future<bool> signInWithGoogle() async {
    const session = AuthSession(
      userId: demoUserId,
      email: 'google.demo@viajusta.co',
      isExternalProvider: true,
      suggestedDisplayName: 'Usuario Google Demo',
    );
    _session = session;
    _profile ??= const UserProfile(
      id: demoUserId,
      displayName: 'Usuario Google Demo',
    );
    _sessions.add(session);
    return true;
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final session = AuthSession(userId: demoUserId, email: email);
    _session = session;
    _profile = UserProfile(id: demoUserId, displayName: displayName);
    _markAllConsentsAccepted(consentDocumentVersion);
    _sessions.add(session);
    return SignUpResult(session: session);
  }

  @override
  Future<void> signOut() async {
    _session = null;
    _profile = null;
    _acceptedConsents.clear();
    _sessions.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    await signOut();
  }

  @override
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // En modo DEMO la actualización de contraseña se simula en memoria.
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    // En modo DEMO el envío de código de recuperación se simula sin red.
  }

  @override
  Future<void> verifyRecoveryOtpAndResetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    // En modo DEMO la verificación del código OTP y cambio de clave se simula en memoria.
  }

  @override
  Future<UserProfile?> fetchProfile(String userId) async => _profile;

  @override
  Future<void> saveDisplayName(String userId, String displayName) async {
    _profile = (_profile ?? UserProfile(id: userId)).copyWith(
      displayName: displayName,
    );
  }

  @override
  Future<void> saveLanguage(String userId, String language) async {
    _profile = (_profile ?? UserProfile(id: userId)).copyWith(
      language: language,
    );
  }

  @override
  Future<void> saveProfileType(String userId, ProfileType type) async {
    _profile = (_profile ?? UserProfile(id: userId)).copyWith(profileType: type);
  }

  @override
  Future<void> saveCurrentMunicipality(
    String userId,
    String municipalityCode,
  ) async {
    _profile = (_profile ?? UserProfile(id: userId)).copyWith(
      currentMunicipalityCode: municipalityCode,
    );
  }

  @override
  Future<void> registerConsents({
    required String userId,
    required List<ConsentDocType> documents,
    required String version,
  }) async {
    for (final document in documents) {
      _acceptedConsents.add('${version}_${document.wireValue}');
    }
  }

  @override
  Future<bool> hasAcceptedConsents({
    required String userId,
    required List<ConsentDocType> documents,
    required String version,
  }) async {
    return documents.every(
      (document) => _acceptedConsents.contains('${version}_${document.wireValue}'),
    );
  }

  void _markAllConsentsAccepted(String version) {
    for (final document in ConsentDocType.values) {
      _acceptedConsents.add('${version}_${document.wireValue}');
    }
  }

  /// Libera el stream al destruir el contenedor de pruebas.
  void dispose() {
    _sessions.close();
  }
}
