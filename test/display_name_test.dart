import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/auth/domain/display_name.dart';

void main() {
  group('firstName', () {
    test('returns the first name of a full name', () {
      expect(firstName('Juan García'), 'Juan');
    });

    test('ignores surrounding and repeated spaces', () {
      expect(firstName('  Ana   María '), 'Ana');
    });

    test('returns the only name', () {
      expect(firstName('Ana'), 'Ana');
    });

    test('returns an empty string for an empty value', () {
      expect(firstName(''), '');
    });

    test('returns an empty string for whitespace-only value', () {
      expect(firstName('   '), '');
    });
  });
}
