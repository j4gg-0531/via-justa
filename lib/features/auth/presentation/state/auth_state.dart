import 'package:via_justa/features/auth/domain/auth_failure.dart';
import 'package:via_justa/features/auth/domain/auth_session.dart';
import 'package:via_justa/features/auth/domain/user_profile.dart';

/// Estado observable de la sesión: quién entró, qué perfil tiene y si hay una
/// operación en curso.
class AuthState {
  const AuthState({
    this.session,
    this.profile,
    this.isBusy = false,
    this.isRestoring = false,
    this.failure,
    this.usesDemoData = false,
  });

  final AuthSession? session;
  final UserProfile? profile;

  /// `true` mientras se espera al servidor (login, registro, guardado).
  final bool isBusy;

  /// `true` durante el arranque de la app mientras se verifica si hay una
  /// sesión previa persistida en el almacenamiento local.
  final bool isRestoring;

  /// Último fallo tipado; la vista lo traduce a texto.
  final AuthFailure? failure;

  /// `true` cuando no hay backend configurado y la sesión es de ejemplo.
  final bool usesDemoData;

  bool get isAuthenticated => session != null;

  String? get email => session?.email;

  AuthState copyWith({
    AuthSession? session,
    UserProfile? profile,
    bool? isBusy,
    bool? isRestoring,
    AuthFailure? failure,
    bool clearFailure = false,
    bool? usesDemoData,
  }) {
    return AuthState(
      session: session ?? this.session,
      profile: profile ?? this.profile,
      isBusy: isBusy ?? this.isBusy,
      isRestoring: isRestoring ?? this.isRestoring,
      failure: clearFailure ? null : (failure ?? this.failure),
      usesDemoData: usesDemoData ?? this.usesDemoData,
    );
  }
}
