import 'dart:async';

import 'package:via_justa/features/auth/domain/auth_failure.dart';
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
    _sessions.add(session);
    return session;
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
    _sessions.add(session);
    return SignUpResult(session: session);
  }

  @override
  Future<void> signOut() async {
    _session = null;
    _profile = null;
    _sessions.add(null);
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
    if (!type.isPersistable) {
      throw const AuthFailure(AuthFailureKind.profileTypeNotSupported);
    }
    _profile = (_profile ?? UserProfile(id: userId)).copyWith(profileType: type);
  }

  @override
  Future<void> registerConsents({
    required String userId,
    required List<ConsentDocType> documents,
    required String version,
  }) async {
    // En modo DEMO no hay servidor: la aceptación solo se refleja en la UI.
  }

  /// Libera el stream al destruir el contenedor de pruebas.
  void dispose() {
    _sessions.close();
  }
}
