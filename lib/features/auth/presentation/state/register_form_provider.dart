import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/session/session_providers.dart';
import 'package:via_justa/features/auth/domain/auth_validators.dart';
import 'package:via_justa/features/auth/domain/display_name.dart';

/// Estado del formulario de creación de cuenta.
class RegisterFormState {
  const RegisterFormState({
    this.name = '',
    this.email = '',
    this.password = '',
    this.termsAccepted = false,
    this.obscurePassword = true,
    this.submitted = false,
  });

  final String name;
  final String email;
  final String password;
  final bool termsAccepted;
  final bool obscurePassword;
  final bool submitted;

  /// Error de nombre; solo se expone después del primer intento de envío.
  NameError? get nameError => submitted ? validateName(name) : null;

  /// Error de correo; solo se expone después del primer intento de envío.
  EmailError? get emailError => submitted ? validateEmail(email) : null;

  /// Error de contraseña; solo se expone después del primer intento de envío.
  PasswordError? get passwordError =>
      submitted ? validatePassword(password) : null;

  /// Los términos solo se exigen después del primer intento de envío.
  bool get termsError => submitted && !termsAccepted;

  /// El formulario es válido sin depender de si ya se intentó enviar.
  bool get isValid =>
      validateName(name) == null &&
      validateEmail(email) == null &&
      validatePassword(password) == null &&
      termsAccepted;

  RegisterFormState copyWith({
    String? name,
    String? email,
    String? password,
    bool? termsAccepted,
    bool? obscurePassword,
    bool? submitted,
  }) {
    return RegisterFormState(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      submitted: submitted ?? this.submitted,
    );
  }
}

class _RegisterFormNotifier extends Notifier<RegisterFormState> {
  @override
  RegisterFormState build() => const RegisterFormState();

  void setName(String value) {
    state = state.copyWith(name: value);
  }

  void setEmail(String value) {
    state = state.copyWith(email: value);
  }

  void setPassword(String value) {
    state = state.copyWith(password: value);
  }

  void setTermsAccepted(bool value) {
    state = state.copyWith(termsAccepted: value);
  }

  void toggleObscurePassword() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  /// Marca el intento de envío y, si todo es válido, guarda el primer nombre.
  bool submit() {
    state = state.copyWith(submitted: true);
    if (!state.isValid) return false;

    ref.read(userNameProvider.notifier).setName(firstName(state.name));
    return true;
  }
}

final registerFormProvider =
    NotifierProvider.autoDispose<_RegisterFormNotifier, RegisterFormState>(
      _RegisterFormNotifier.new,
    );
