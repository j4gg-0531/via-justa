import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/auth/domain/display_name_resolver.dart';

void main() {
  group('resolveInitialDisplayName', () {
    test('prefers explicit display_name, then full_name, then name, then email prefix', () {
      expect(
        resolveInitialDisplayName(
          explicitDisplayName: '  Ana María  ',
          fullName: 'Ana Maria Lopez',
          metadataName: 'Ana',
          email: 'ana@gmail.com',
        ),
        'Ana María',
      );
      expect(
        resolveInitialDisplayName(
          explicitDisplayName: '   ',
          fullName: 'Juan Garcia',
          metadataName: 'Juan',
          email: 'garciagonzalezj04@gmail.com',
        ),
        'Juan Garcia',
      );
      expect(
        resolveInitialDisplayName(
          fullName: null,
          metadataName: 'Carlos Vives',
          email: 'cvives@gmail.com',
        ),
        'Carlos Vives',
      );
      expect(
        resolveInitialDisplayName(email: 'garciagonzalezj04@gmail.com'),
        'garciagonzalezj04',
      );
    });
  });

  group('resolvePreferredGoogleDisplayName', () {
    test('upgrades missing or email-prefix display name using Google real name', () {
      expect(
        resolvePreferredGoogleDisplayName(
          currentDisplayName: null,
          oauthDisplayName: 'Juan Garcia',
          email: 'garciagonzalezj04@gmail.com',
        ),
        'Juan Garcia',
      );
      expect(
        resolvePreferredGoogleDisplayName(
          currentDisplayName: 'garciagonzalezj04',
          oauthDisplayName: 'Juan Garcia',
          email: 'garciagonzalezj04@gmail.com',
        ),
        'Juan Garcia',
      );
    });

    test('preserves custom user display name and ignores redundant email prefix', () {
      expect(
        resolvePreferredGoogleDisplayName(
          currentDisplayName: 'Juancho',
          oauthDisplayName: 'Juan Garcia',
          email: 'garciagonzalezj04@gmail.com',
        ),
        isNull,
      );
      expect(
        resolvePreferredGoogleDisplayName(
          currentDisplayName: 'garciagonzalezj04',
          oauthDisplayName: 'garciagonzalezj04',
          email: 'garciagonzalezj04@gmail.com',
        ),
        isNull,
      );
    });
  });
}
