import 'package:easy_localization/easy_localization.dart';
import 'package:via_justa/features/auth/domain/auth_validators.dart';

/// Traduce el error de nombre a texto; null si no hay error.
String? nameErrorText(NameError? error) => switch (error) {
  null => null,
  NameError.empty => 'auth.error.name_empty'.tr(),
};

/// Traduce el error de correo a texto; null si no hay error.
String? emailErrorText(EmailError? error) => switch (error) {
  null => null,
  EmailError.empty => 'auth.error.email_empty'.tr(),
  EmailError.invalid => 'auth.error.email_invalid'.tr(),
};

/// Traduce el error de contraseña a texto; null si no hay error.
String? passwordErrorText(PasswordError? error) => switch (error) {
  null => null,
  PasswordError.empty => 'auth.error.password_empty'.tr(),
  PasswordError.tooShort => 'auth.error.password_short'.tr(
    namedArgs: {'min': '$minPasswordLength'},
  ),
};
