import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/auth/data/auth_failure_mapper.dart';
import 'package:via_justa/features/auth/data/profile_mapper.dart';
import 'package:via_justa/features/auth/domain/auth_failure.dart';
import 'package:via_justa/features/auth/domain/auth_repository.dart';
import 'package:via_justa/features/auth/domain/auth_session.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';
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
    if (!type.isPersistable) {
      // D11 sigue PROPUESTA: el CHECK de la tabla rechazaría 'resident'.
      throw const AuthFailure(AuthFailureKind.profileTypeNotSupported);
    }
    await _updateProfile(userId, {'profile_type': type.wireValue});
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

  Future<void> _updateProfile(String userId, Map<String, dynamic> values) async {
    try {
      await _client.from('profiles').update(values).eq('id', userId);
    } catch (error) {
      throw toAuthFailure(error);
    }
  }

  AuthSession? _toSession(Session? session) {
    if (session == null) return null;
    return AuthSession(userId: session.user.id, email: session.user.email);
  }
}
