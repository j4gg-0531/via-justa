import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/features/auth/domain/auth_validators.dart';

/// Estado del formulario de inicio de sesión.
class LoginFormState {
  const LoginFormState({
    this.email = '',
    this.password = '',
    this.obscurePassword = true,
    this.submitted = false,
  });

  final String email;
  final String password;
  final bool obscurePassword;
  final bool submitted;

  /// Error de correo; solo se expone después del primer intento de envío.
  EmailError? get emailError => submitted ? validateEmail(email) : null;

  /// Error de contraseña; solo se expone después del primer intento de envío.
  PasswordError? get passwordError =>
      submitted ? validatePassword(password) : null;

  /// El formulario es válido sin depender de si ya se intentó enviar.
  bool get isValid =>
      validateEmail(email) == null && validatePassword(password) == null;

  LoginFormState copyWith({
    String? email,
    String? password,
    bool? obscurePassword,
    bool? submitted,
  }) {
    return LoginFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      submitted: submitted ?? this.submitted,
    );
  }
}

class _LoginFormNotifier extends Notifier<LoginFormState> {
  @override
  LoginFormState build() => const LoginFormState();

  void setEmail(String value) {
    state = state.copyWith(email: value);
  }

  void setPassword(String value) {
    state = state.copyWith(password: value);
  }

  void toggleObscurePassword() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  /// Marca el intento de envío y devuelve si el formulario es válido.
  bool submit() {
    state = state.copyWith(submitted: true);
    return state.isValid;
  }
}

final loginFormProvider =
    NotifierProvider.autoDispose<_LoginFormNotifier, LoginFormState>(
      _LoginFormNotifier.new,
    );
