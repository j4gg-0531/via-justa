import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/features/auth/domain/auth_validators.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';

/// Estado del flujo de 2 pasos para recuperar la contraseña con código OTP temporal en la app.
class ForgotPasswordFormState {
  const ForgotPasswordFormState({
    this.email = '',
    this.otpCode = '',
    this.newPassword = '',
    this.confirmPassword = '',
    this.obscureNewPassword = true,
    this.obscureConfirmPassword = true,
    this.codeSent = false,
    this.submitted = false,
  });

  final String email;
  final String otpCode;
  final String newPassword;
  final String confirmPassword;
  final bool obscureNewPassword;
  final bool obscureConfirmPassword;
  final bool codeSent;
  final bool submitted;

  EmailError? get emailError => submitted ? validateEmail(email) : null;

  OtpCodeError? get otpCodeError =>
      submitted && codeSent ? validateOtpCode(otpCode) : null;

  PasswordError? get newPasswordError =>
      submitted && codeSent ? validatePassword(newPassword) : null;

  ConfirmPasswordError? get confirmPasswordError => submitted && codeSent
      ? validateConfirmPassword(
          password: newPassword,
          confirmPassword: confirmPassword,
        )
      : null;

  bool get isEmailValid => validateEmail(email) == null;

  bool get isStepTwoValid =>
      validateEmail(email) == null &&
      validateOtpCode(otpCode) == null &&
      validatePassword(newPassword) == null &&
      validateConfirmPassword(
            password: newPassword,
            confirmPassword: confirmPassword,
          ) ==
          null;

  bool get isValid => codeSent ? isStepTwoValid : isEmailValid;

  ForgotPasswordFormState copyWith({
    String? email,
    String? otpCode,
    String? newPassword,
    String? confirmPassword,
    bool? obscureNewPassword,
    bool? obscureConfirmPassword,
    bool? codeSent,
    bool? submitted,
  }) {
    return ForgotPasswordFormState(
      email: email ?? this.email,
      otpCode: otpCode ?? this.otpCode,
      newPassword: newPassword ?? this.newPassword,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      obscureNewPassword: obscureNewPassword ?? this.obscureNewPassword,
      obscureConfirmPassword:
          obscureConfirmPassword ?? this.obscureConfirmPassword,
      codeSent: codeSent ?? this.codeSent,
      submitted: submitted ?? this.submitted,
    );
  }
}

class ForgotPasswordFormNotifier extends Notifier<ForgotPasswordFormState> {
  @override
  ForgotPasswordFormState build() => const ForgotPasswordFormState();

  void setEmail(String value) {
    state = state.copyWith(email: value);
  }

  void setOtpCode(String value) {
    state = state.copyWith(otpCode: value);
  }

  void setNewPassword(String value) {
    state = state.copyWith(newPassword: value);
  }

  void setConfirmPassword(String value) {
    state = state.copyWith(confirmPassword: value);
  }

  void toggleObscureNewPassword() {
    state = state.copyWith(obscureNewPassword: !state.obscureNewPassword);
  }

  void toggleObscureConfirmPassword() {
    state = state.copyWith(
      obscureConfirmPassword: !state.obscureConfirmPassword,
    );
  }

  void backToEmailStep() {
    state = state.copyWith(codeSent: false, submitted: false);
  }

  /// Paso 1: Solicita el envío del código OTP temporal al correo ingresado.
  Future<bool> requestCode() async {
    state = state.copyWith(submitted: true);
    if (!state.isEmailValid) return false;
    final sent = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(state.email);
    if (sent && ref.mounted) {
      state = state.copyWith(codeSent: true, submitted: false);
    }
    return sent;
  }

  /// Paso 2: Verifica el código OTP recibido en el correo y aplica la nueva contraseña.
  Future<bool> verifyOtpAndReset() async {
    state = state.copyWith(submitted: true);
    if (!state.isStepTwoValid) return false;
    return ref
        .read(authControllerProvider.notifier)
        .confirmPasswordResetWithOtp(
          email: state.email,
          token: state.otpCode,
          newPassword: state.newPassword,
        );
  }

  /// Ejecuta el paso activo (Paso 1 si aún no se envió el código; Paso 2 si ya se envió).
  Future<bool> submit() {
    if (!state.codeSent) {
      return requestCode();
    }
    return verifyOtpAndReset();
  }
}

final forgotPasswordFormProvider = NotifierProvider.autoDispose<
  ForgotPasswordFormNotifier,
  ForgotPasswordFormState
>(ForgotPasswordFormNotifier.new);

/// Estado del formulario de cambio de contraseña desde el perfil (exige contraseña actual).
class ChangePasswordFormState {
  const ChangePasswordFormState({
    this.currentPassword = '',
    this.newPassword = '',
    this.confirmPassword = '',
    this.obscureCurrentPassword = true,
    this.obscureNewPassword = true,
    this.obscureConfirmPassword = true,
    this.submitted = false,
  });

  final String currentPassword;
  final String newPassword;
  final String confirmPassword;
  final bool obscureCurrentPassword;
  final bool obscureNewPassword;
  final bool obscureConfirmPassword;
  final bool submitted;

  PasswordError? get currentPasswordError =>
      submitted && currentPassword.isEmpty ? PasswordError.empty : null;

  PasswordError? get newPasswordError =>
      submitted ? validatePassword(newPassword) : null;

  ConfirmPasswordError? get confirmPasswordError => submitted
      ? validateConfirmPassword(
          password: newPassword,
          confirmPassword: confirmPassword,
        )
      : null;

  bool get isValid =>
      currentPassword.isNotEmpty &&
      validatePassword(newPassword) == null &&
      validateConfirmPassword(
            password: newPassword,
            confirmPassword: confirmPassword,
          ) ==
          null;

  ChangePasswordFormState copyWith({
    String? currentPassword,
    String? newPassword,
    String? confirmPassword,
    bool? obscureCurrentPassword,
    bool? obscureNewPassword,
    bool? obscureConfirmPassword,
    bool? submitted,
  }) {
    return ChangePasswordFormState(
      currentPassword: currentPassword ?? this.currentPassword,
      newPassword: newPassword ?? this.newPassword,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      obscureCurrentPassword:
          obscureCurrentPassword ?? this.obscureCurrentPassword,
      obscureNewPassword: obscureNewPassword ?? this.obscureNewPassword,
      obscureConfirmPassword:
          obscureConfirmPassword ?? this.obscureConfirmPassword,
      submitted: submitted ?? this.submitted,
    );
  }
}

class ChangePasswordFormNotifier extends Notifier<ChangePasswordFormState> {
  @override
  ChangePasswordFormState build() => const ChangePasswordFormState();

  void setCurrentPassword(String value) {
    state = state.copyWith(currentPassword: value);
  }

  void setNewPassword(String value) {
    state = state.copyWith(newPassword: value);
  }

  void setConfirmPassword(String value) {
    state = state.copyWith(confirmPassword: value);
  }

  void toggleObscureCurrentPassword() {
    state = state.copyWith(
      obscureCurrentPassword: !state.obscureCurrentPassword,
    );
  }

  void toggleObscureNewPassword() {
    state = state.copyWith(obscureNewPassword: !state.obscureNewPassword);
  }

  void toggleObscureConfirmPassword() {
    state = state.copyWith(
      obscureConfirmPassword: !state.obscureConfirmPassword,
    );
  }

  Future<bool> submit() async {
    state = state.copyWith(submitted: true);
    if (!state.isValid) return false;
    return ref
        .read(authControllerProvider.notifier)
        .changePassword(
          currentPassword: state.currentPassword,
          newPassword: state.newPassword,
        );
  }
}

final changePasswordFormProvider = NotifierProvider.autoDispose<
  ChangePasswordFormNotifier,
  ChangePasswordFormState
>(ChangePasswordFormNotifier.new);
