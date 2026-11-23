import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/auth/domain/auth_validators.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';

void main() {
  group('validateName', () {
    test('empty value returns empty error', () {
      expect(validateName(''), NameError.empty);
    });

    test('whitespace-only value returns empty error', () {
      expect(validateName('   '), NameError.empty);
    });

    test('a real name is valid', () {
      expect(validateName('Ana'), isNull);
    });
  });

  group('validateEmail', () {
    test('empty value returns empty error', () {
      expect(validateEmail(''), EmailError.empty);
    });

    test('whitespace-only value returns empty error', () {
      expect(validateEmail('   '), EmailError.empty);
    });

    test('missing domain dot returns invalid error', () {
      expect(validateEmail('a@b'), EmailError.invalid);
    });

    test('internal space returns invalid error', () {
      expect(validateEmail('a b@c.co'), EmailError.invalid);
    });

    test('missing local part returns invalid error', () {
      expect(validateEmail('@c.co'), EmailError.invalid);
    });

    test('missing domain name returns invalid error', () {
      expect(validateEmail('a@.co'), EmailError.invalid);
    });

    test('a well-formed email is valid', () {
      expect(validateEmail('a@b.co'), isNull);
    });

    test('surrounding spaces are trimmed', () {
      expect(validateEmail('  a@b.co  '), isNull);
    });
  });

  group('validatePassword', () {
    test('empty value returns empty error', () {
      expect(validatePassword(''), PasswordError.empty);
    });

    test('seven characters are too short', () {
      expect(validatePassword('1234567'), PasswordError.tooShort);
    });

    test('exactly the minimum length is valid', () {
      expect(validatePassword('12345678'), isNull);
    });

    test('more than the minimum length is valid', () {
      expect(validatePassword('123456789'), isNull);
    });

    test('eight spaces are valid because the value is not trimmed', () {
      expect(validatePassword('        '), isNull);
    });
  });

  group('validateConfirmPassword', () {
    test('empty confirmation returns empty error', () {
      expect(
        validateConfirmPassword(password: '12345678', confirmPassword: ''),
        ConfirmPasswordError.empty,
      );
    });

    test('different confirmation returns mismatch error', () {
      expect(
        validateConfirmPassword(
          password: '12345678',
          confirmPassword: '12345679',
        ),
        ConfirmPasswordError.mismatch,
      );
    });

    test('matching confirmation returns null', () {
      expect(
        validateConfirmPassword(
          password: '12345678',
          confirmPassword: '12345678',
        ),
        isNull,
      );
    });
  });

  group('validateOtpCode and parseRecoveryCredential', () {
    test('empty value returns empty error', () {
      expect(validateOtpCode(''), OtpCodeError.empty);
      expect(validateOtpCode('   '), OtpCodeError.empty);
    });

    test('non-numeric or short code returns invalid error', () {
      expect(validateOtpCode('12345'), OtpCodeError.invalid);
      expect(validateOtpCode('12345a'), OtpCodeError.invalid);
    });

    test('6-digit numeric code is valid', () {
      expect(validateOtpCode('482910'), isNull);
      expect(validateOtpCode(' 482910 '), isNull);
      final parsed = parseRecoveryCredential('482910');
      expect(parsed?.kind, RecoveryCredentialKind.otpCode);
      expect(parsed?.value, '482910');
    });

    test('extracts tokenHash from Supabase Reset password email link without custom SMTP', () {
      const link =
          'https://vjehsjqmwibmiqmxlsou.supabase.co/auth/v1/verify?token=pkce_8f9a0b1c2d3e4f5a6b7c8d9e&type=recovery&redirect_to=http://localhost:3000';
      expect(validateOtpCode(link), isNull);
      final parsed = parseRecoveryCredential(link);
      expect(parsed?.kind, RecoveryCredentialKind.tokenHash);
      expect(parsed?.value, 'pkce_8f9a0b1c2d3e4f5a6b7c8d9e');
    });

    test('detects expired localhost link and returns expiredLink error', () {
      const expired =
          'http://localhost:3000/?error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired';
      expect(validateOtpCode(expired), OtpCodeError.expiredLink);
    });
  });

  group('splitLegalDocumentClauses and resolveSupportedLocaleCode', () {
    test('splits double-newline paragraphs into clauses', () {
      expect(
        splitLegalDocumentClauses('1. Cláusula uno.\n\n2. Cláusula dos.'),
        ['1. Cláusula uno.', '2. Cláusula dos.'],
      );
    });

    test('resolves supported locale code from device language', () {
      expect(resolveSupportedLocaleCode('en'), 'en');
      expect(resolveSupportedLocaleCode('en_US'), 'en');
      expect(resolveSupportedLocaleCode('es'), 'es');
      expect(resolveSupportedLocaleCode('es_CO'), 'es');
      expect(resolveSupportedLocaleCode('fr'), 'es');
      expect(resolveSupportedLocaleCode(null), 'es');
    });
  });
}
