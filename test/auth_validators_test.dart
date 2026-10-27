import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/auth/domain/auth_validators.dart';

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
}
