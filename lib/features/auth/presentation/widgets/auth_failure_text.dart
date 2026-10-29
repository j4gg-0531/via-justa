import 'package:easy_localization/easy_localization.dart';
import 'package:via_justa/features/auth/domain/auth_failure.dart';

/// Traduce un fallo de autenticación a texto; `null` si no hay fallo.
String? authFailureText(AuthFailure? failure) => switch (failure?.kind) {
  null => null,
  AuthFailureKind.invalidCredentials => 'auth.error.invalid_credentials'.tr(),
  AuthFailureKind.emailAlreadyRegistered =>
    'auth.error.email_registered'.tr(),
  AuthFailureKind.emailNotConfirmed => 'auth.error.email_not_confirmed'.tr(),
  AuthFailureKind.weakPassword => 'auth.error.weak_password'.tr(),
  AuthFailureKind.rateLimited => 'auth.error.rate_limited'.tr(),
  AuthFailureKind.network => 'auth.error.network'.tr(),
  AuthFailureKind.emailConfirmationRequired =>
    'auth.error.email_confirmation_required'.tr(),
  AuthFailureKind.profileTypeNotSupported =>
    'auth.error.profile_type_pending'.tr(),
  AuthFailureKind.unknown => 'auth.error.unknown'.tr(),
};
