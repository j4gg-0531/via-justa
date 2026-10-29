import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/auth/data/auth_failure_mapper.dart';
import 'package:via_justa/features/auth/data/profile_mapper.dart';
import 'package:via_justa/features/auth/domain/auth_failure.dart';
import 'package:via_justa/features/auth/domain/consent_document.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';

void main() {
  group('toAuthFailure', () {
    test('maps invalid credentials', () {
      final failure = toAuthFailure(
        const AuthException('bad', code: 'invalid_credentials'),
      );
      expect(failure.kind, AuthFailureKind.invalidCredentials);
    });

    test('maps an existing email', () {
      expect(
        toAuthFailure(
          const AuthException('exists', code: 'user_already_exists'),
        ).kind,
        AuthFailureKind.emailAlreadyRegistered,
      );
      expect(
        toAuthFailure(const AuthException('exists', code: 'email_exists')).kind,
        AuthFailureKind.emailAlreadyRegistered,
      );
    });

    test('maps an unconfirmed email', () {
      expect(
        toAuthFailure(
          const AuthException('confirm', code: 'email_not_confirmed'),
        ).kind,
        AuthFailureKind.emailNotConfirmed,
      );
    });

    test('maps rate limiting by code and by status', () {
      expect(
        toAuthFailure(
          const AuthException('slow', code: 'over_request_rate_limit'),
        ).kind,
        AuthFailureKind.rateLimited,
      );
      expect(
        toAuthFailure(const AuthException('slow', statusCode: '429')).kind,
        AuthFailureKind.rateLimited,
      );
    });

    test('maps retryable fetch errors to network', () {
      expect(
        toAuthFailure(AuthRetryableFetchException()).kind,
        AuthFailureKind.network,
      );
      expect(
        toAuthFailure(const AuthException('offline', statusCode: '0')).kind,
        AuthFailureKind.network,
      );
    });

    test('keeps an existing AuthFailure untouched', () {
      const original = AuthFailure(AuthFailureKind.weakPassword);
      expect(toAuthFailure(original).kind, AuthFailureKind.weakPassword);
    });

    test('falls back to unknown for unclassified errors', () {
      expect(toAuthFailure(StateError('boom')).kind, AuthFailureKind.unknown);
    });
  });

  group('profileFromRow', () {
    test('maps a complete row', () {
      final profile = profileFromRow({
        'id': 'user-1',
        'display_name': 'Ana María',
        'language': 'en',
        'profile_type': 'settler',
        'origin_country': 'VE',
        'current_municipality_code': '20001',
      });

      expect(profile, isNotNull);
      expect(profile!.id, 'user-1');
      expect(profile.displayName, 'Ana María');
      expect(profile.language, 'en');
      expect(profile.profileType, ProfileType.settler);
      expect(profile.originCountry, 'VE');
      expect(profile.currentMunicipalityCode, '20001');
    });

    test('returns null without a usable id', () {
      expect(profileFromRow(null), isNull);
      expect(profileFromRow({'display_name': 'X'}), isNull);
      expect(profileFromRow({'id': ''}), isNull);
    });

    test('normalizes unknown language and profile type', () {
      final profile = profileFromRow({
        'id': 'user-2',
        'language': 'fr',
        'profile_type': 'unknown',
      });

      expect(profile!.language, 'es');
      expect(profile.profileType, isNull);
    });

    test('turns blank text into null', () {
      final profile = profileFromRow({'id': 'user-3', 'display_name': '   '});
      expect(profile!.displayName, isNull);
    });
  });

  group('ProfileType wire values', () {
    test('round-trips the values allowed by the database', () {
      expect(ProfileType.visitor.wireValue, 'visitor');
      expect(ProfileType.settler.wireValue, 'settler');
      expect(ProfileType.fromWire('settler'), ProfileType.settler);
      expect(ProfileType.fromWire(null), isNull);
      expect(ProfileType.fromWire(42), isNull);
    });

    test('marks only resident as non persistable', () {
      expect(ProfileType.visitor.isPersistable, isTrue);
      expect(ProfileType.settler.isPersistable, isTrue);
      expect(ProfileType.resident.isPersistable, isFalse);
    });
  });

  test('consent wire values match the contract', () {
    expect(ConsentDocType.termsAndConditions.wireValue, 'terms_and_conditions');
    expect(ConsentDocType.privacyPolicy.wireValue, 'privacy_policy');
    expect(consentDocumentVersion, 'v1.0');
  });
}
