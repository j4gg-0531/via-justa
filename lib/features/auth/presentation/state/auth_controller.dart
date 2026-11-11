import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/session/session_providers.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/auth/data/demo_auth_repository.dart';
import 'package:via_justa/features/auth/data/supabase_auth_repository.dart';
import 'package:via_justa/features/auth/domain/auth_failure.dart';
import 'package:via_justa/features/auth/domain/auth_repository.dart';
import 'package:via_justa/features/auth/domain/auth_session.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';
import 'package:via_justa/features/auth/domain/user_profile.dart';
import 'package:via_justa/features/auth/presentation/state/auth_state.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';
import 'package:via_justa/features/onboarding/presentation/state/profile_type_provider.dart';

/// Único lugar que decide qué implementación concreta se usa.
///
/// Con cliente de Supabase → backend real. Sin cliente (sin `--dart-define`) →
/// repositorio DEMO en memoria, para no romper el recorrido ni las pruebas.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client != null) {
    return SupabaseAuthRepository(client);
  }

  final demo = DemoAuthRepository();
  ref.onDispose(demo.dispose);
  return demo;
});

/// Orquesta sesión, perfil y consentimientos.
class AuthController extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.watchSession().listen(_onSessionChanged);
    ref.onDispose(subscription.cancel);

    // La sesión puede venir restaurada del almacenamiento del dispositivo.
    unawaited(_restoreSession(repository));

    return AuthState(isRestoring: true, usesDemoData: repository.usesDemoData);
  }

  /// Inicia sesión. Devuelve `false` y deja `failure` cuando falla.
  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(isBusy: true, clearFailure: true);
    try {
      final session = await _repository.signIn(email: email, password: password);
      if (!ref.mounted) return false;
      await _applySession(session);
      return true;
    } catch (error) {
      _setFailure(error);
      return false;
    }
  }

  /// Crea la cuenta y registra la aceptación de los documentos legales.
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(isBusy: true, clearFailure: true);
    try {
      final result = await _repository.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (!ref.mounted) return false;

      final session = result.session;
      if (session == null) {
        state = state.copyWith(
          isBusy: false,
          failure: const AuthFailure(AuthFailureKind.emailConfirmationRequired),
        );
        return false;
      }

      await _repository.registerConsents(
        userId: session.userId,
        documents: ConsentDocType.values,
        version: consentDocumentVersion,
      );
      if (!ref.mounted) return false;

      await _applySession(session);
      await saveDisplayName(displayName);
      return true;
    } catch (error) {
      _setFailure(error);
      return false;
    }
  }

  /// Cierra la sesión local y remota.
  Future<void> signOut() async {
    if (!ref.mounted) return;
    state = state.copyWith(isBusy: true, clearFailure: true);
    try {
      await _repository.signOut();
    } catch (_) {
      // Aunque falle el servidor, la sesión local se descarta igual.
    }
    if (!ref.mounted) return;
    state = AuthState(isRestoring: false, usesDemoData: _repository.usesDemoData);
  }

  /// Actualiza el nombre visible en el servidor y en la UI.
  Future<bool> saveDisplayName(String displayName) async {
    final session = state.session;
    final trimmed = displayName.trim();
    if (session == null || trimmed.isEmpty) return false;

    try {
      await _repository.saveDisplayName(session.userId, trimmed);
      if (!ref.mounted) return false;
      final profile = state.profile;
      if (profile != null) {
        state = state.copyWith(profile: profile.copyWith(displayName: trimmed));
      }
      ref.read(userNameProvider.notifier).setName(trimmed);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Guarda el idioma preferido.
  Future<bool> saveLanguage(String language) async {
    final session = state.session;
    if (session == null) return false;

    try {
      await _repository.saveLanguage(session.userId, language);
      if (!ref.mounted) return false;
      final profile = state.profile;
      if (profile != null) {
        state = state.copyWith(profile: profile.copyWith(language: language));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Persiste el tipo de perfil seleccionado en el servidor (D11 ratificada en migración 0006).
  Future<bool> persistProfileType(ProfileType type) async {
    final session = state.session;
    if (session == null) return true;

    try {
      await _repository.saveProfileType(session.userId, type);
      if (!ref.mounted) return false;
      final profile = state.profile ?? UserProfile(id: session.userId);
      state = state.copyWith(profile: profile.copyWith(profileType: type));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Guarda el municipio activo del usuario en su perfil.
  Future<bool> saveCurrentMunicipality(String municipalityCode) async {
    final session = state.session;
    final trimmed = municipalityCode.trim();
    if (session == null || trimmed.isEmpty) return false;

    try {
      await _repository.saveCurrentMunicipality(session.userId, trimmed);
      if (!ref.mounted) return false;
      final profile = state.profile ?? UserProfile(id: session.userId);
      state = state.copyWith(
        profile: profile.copyWith(currentMunicipalityCode: trimmed),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Limpia el último fallo (por ejemplo al cerrar el aviso en pantalla).
  void clearFailure() {
    state = state.copyWith(clearFailure: true);
  }

  void _onSessionChanged(AuthSession? session) {
    if (!ref.mounted) return;
    if (session == null) {
      state = AuthState(isRestoring: false, usesDemoData: _repository.usesDemoData);
      return;
    }
    if (!state.isRestoring) {
      unawaited(_applySession(session));
    }
  }

  Future<void> _restoreSession(AuthRepository repository) async {
    try {
      final session = await repository.currentSession();
      if (!ref.mounted) return;
      if (session != null) {
        await _applySession(session);
      }
    } catch (_) {
      // Sin sesión restaurada se continúa como visitante.
    } finally {
      if (ref.mounted && state.isRestoring) {
        state = state.copyWith(isRestoring: false);
      }
    }
  }

  Future<void> _applySession(AuthSession session) async {
    UserProfile? profile;
    try {
      profile = await _repository.fetchProfile(session.userId);
      if (profile != null && ref.mounted) {
        await _syncLocalProfile(profile);
      }
    } catch (_) {
      // La sesión sigue siendo válida aunque el perfil no se pueda leer.
    }

    if (!ref.mounted) return;
    state = state.copyWith(
      session: session,
      profile: profile ?? state.profile,
      isBusy: false,
      clearFailure: true,
    );
  }

  /// Refleja en el estado local lo que el servidor ya confirmó.
  Future<void> _syncLocalProfile(UserProfile profile) async {
    final name = profile.displayName;
    if (name != null && name.isNotEmpty) {
      ref.read(userNameProvider.notifier).setName(name);
    }
    final type = profile.profileType;
    if (type != null) {
      ref.read(profileTypeProvider.notifier).select(type);
    }
    final municipalityCode = profile.currentMunicipalityCode;
    if (municipalityCode != null && municipalityCode.isNotEmpty) {
      try {
        final repository = ref.read(municipalityRepositoryProvider);
        final municipality = await repository.getByCode(municipalityCode);
        if (municipality != null && ref.mounted) {
          ref.read(selectedMunicipalityProvider.notifier).select(municipality);
        }
      } catch (_) {}
    }
  }

  void _setFailure(Object error) {
    if (!ref.mounted) return;
    final failure = error is AuthFailure
        ? error
        : const AuthFailure(AuthFailureKind.unknown);
    state = state.copyWith(isBusy: false, failure: failure);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Correo del usuario autenticado (o `null` en modo visitante).
final authEmailProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider).email,
);