import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/auth/data/auth_failure_mapper.dart';
import 'package:via_justa/features/auth/data/profile_mapper.dart';
import 'package:via_justa/features/auth/domain/auth_failure.dart';
import 'package:via_justa/features/auth/domain/auth_repository.dart';
import 'package:via_justa/features/auth/domain/auth_session.dart';
import 'package:via_justa/features/auth/domain/auth_validators.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';
import 'package:via_justa/features/auth/domain/display_name_resolver.dart';
import 'package:via_justa/features/auth/domain/sign_up_result.dart';
import 'package:via_justa/features/auth/domain/user_profile.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';

/// Implementación real contra Supabase Auth y las tablas `profiles`/`consents`.
///
/// Toda la conversión de errores y de filas ocurre aquí: la app solo ve
/// entidades de dominio.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  /// Esquema deep-link registrado en `AndroidManifest.xml` para el retorno de OAuth.
  static const String oauthRedirectUri =
      'io.supabase.viajusta://login-callback/';

  GoTrueClient get _auth => _client.auth;

  @override
  bool get usesDemoData => false;

  @override
  Stream<AuthSession?> watchSession() =>
      _auth.onAuthStateChange.map((state) => _toSession(state.session));

  @override
  Future<AuthSession?> currentSession() async =>
      _toSession(_auth.currentSession);

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      final session = _toSession(response.session);
      if (session == null) {
        throw const AuthFailure(AuthFailureKind.unknown);
      }
      return session;
    } catch (error) {
      throw toAuthFailure(error);
    }
  }

  @override
  Future<bool> signInWithGoogle() async {
    try {
      final launched = await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: oauthRedirectUri,
      );
      if (!launched) {
        throw const AuthFailure(AuthFailureKind.unknown);
      }
      return true;
    } catch (error) {
      throw toAuthFailure(error);
    }
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
      final session = _toSession(response.session);
      return SignUpResult(
        session: session,
        confirmationRequired: session == null,
      );
    } catch (error) {
      throw toAuthFailure(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (error) {
      throw toAuthFailure(error);
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _client.rpc<void>('delete_my_account');
    } catch (error) {
      throw toAuthFailure(error);
    }

    try {
      await _auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // El usuario ya fue eliminado en el servidor; ignoramos errores al limpiar el caché local.
    }
  }

  @override
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final email =
          _auth.currentUser?.email ?? _auth.currentSession?.user.email;
      if (email == null || email.trim().isEmpty) {
        throw const AuthFailure(AuthFailureKind.unknown);
      }
      // Re-autenticar con la contraseña actual para confirmar que quien tiene el dispositivo es el dueño.
      await _auth.signInWithPassword(
        email: email.trim(),
        password: currentPassword,
      );
      await _auth.updateUser(UserAttributes(password: newPassword));
    } catch (error) {
      throw toAuthFailure(error);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.resetPasswordForEmail(email.trim());
    } catch (error) {
      throw toAuthFailure(error);
    }
  }

  @override
  Future<void> verifyRecoveryOtpAndResetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      final parsed = parseRecoveryCredential(token);
      if (parsed == null) {
        throw const AuthFailure(AuthFailureKind.invalidCredentials);
      }

      switch (parsed.kind) {
        case RecoveryCredentialKind.otpCode:
          await _auth.verifyOTP(
            email: email.trim(),
            token: parsed.value,
            type: OtpType.recovery,
          );
          break;
        case RecoveryCredentialKind.tokenHash:
          await _auth.verifyOTP(
            tokenHash: parsed.value,
            type: OtpType.recovery,
          );
          break;
        case RecoveryCredentialKind.redirectSessionUrl:
          await _auth.getSessionFromUrl(Uri.parse(parsed.value));
          break;
      }

      await _auth.updateUser(UserAttributes(password: newPassword));
    } catch (error) {
      throw toAuthFailure(error);
    }
  }

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return profileFromRow(row);
    } catch (error) {
      throw toAuthFailure(error);
    }
  }

  @override
  Future<void> saveDisplayName(String userId, String displayName) async {
    await _updateProfile(userId, {'display_name': displayName});
  }

  @override
  Future<void> saveLanguage(String userId, String language) async {
    if (language != 'es' && language != 'en') {
      throw const AuthFailure(AuthFailureKind.unknown);
    }
    await _updateProfile(userId, {'language': language});
  }

  @override
  Future<void> saveProfileType(String userId, ProfileType type) async {
    await _updateProfile(userId, {'profile_type': type.wireValue});
  }

  @override
  Future<void> saveCurrentMunicipality(
    String userId,
    String municipalityCode,
  ) async {
    await _updateProfile(
      userId,
      {'current_municipality_code': municipalityCode},
    );
  }

  @override
  Future<void> registerConsents({
    required String userId,
    required List<ConsentDocType> documents,
    required String version,
  }) async {
    if (documents.isEmpty) return;
    try {
      await _client.from('consents').insert([
        for (final document in documents)
          {
            'user_id': userId,
            'doc_type': document.wireValue,
            'version': version,
          },
      ]);
    } catch (error) {
      throw toAuthFailure(error);
    }
  }

  @override
  Future<bool> hasAcceptedConsents({
    required String userId,
    required List<ConsentDocType> documents,
    required String version,
  }) async {
    if (documents.isEmpty) return true;
    try {
      final rows = await _client
          .from('consents')
          .select('doc_type')
          .eq('user_id', userId)
          .eq('version', version);
      final acceptedTypes = <String>{
        for (final row in rows)
          if (row['doc_type'] is String) row['doc_type'] as String,
      };
      return documents.every((doc) => acceptedTypes.contains(doc.wireValue));
    } catch (error) {
      throw toAuthFailure(error);
    }
  }

  Future<void> _updateProfile(String userId, Map<String, dynamic> values) async {
    try {
      await _client.from('profiles').update(values).eq('id', userId);
    } catch (error) {
      throw toAuthFailure(error);
    }
  }

  AuthSession? _toSession(Session? session) {
    if (session == null) return null;
    final user = session.user;
    final metadata = user.userMetadata;
    final suggestedName = resolveInitialDisplayName(
      explicitDisplayName: _trimmedString(metadata?['display_name']),
      fullName: _trimmedString(metadata?['full_name']),
      metadataName: _trimmedString(metadata?['name']),
      email: user.email,
    );
    return AuthSession(
      userId: user.id,
      email: user.email,
      isExternalProvider: _isExternalAuthProvider(user),
      suggestedDisplayName: suggestedName,
    );
  }

  bool _isExternalAuthProvider(User user) {
    final provider = user.appMetadata['provider'];
    if (provider is String && provider.isNotEmpty && provider != 'email') {
      return true;
    }
    final providers = user.appMetadata['providers'];
    if (providers is Iterable) {
      return providers.any(
        (entry) => entry is String && entry.isNotEmpty && entry != 'email',
      );
    }
    return false;
  }

  String? _trimmedString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
