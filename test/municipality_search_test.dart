import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/utils/text_normalizer.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/domain/municipality_search.dart';

void main() {
  group('normalizeForSearch', () {
    test('removes accents and diacritics', () {
      expect(normalizeForSearch('Agustín'), 'agustin');
      expect(normalizeForSearch('Córdoba'), 'cordoba');
      expect(normalizeForSearch('Niño'), 'nino');
      expect(normalizeForSearch('Pingüino'), 'pinguino');
    });

    test('handles ñ', () {
      expect(normalizeForSearch('Ñandú'), 'nandu');
      expect(normalizeForSearch('cañón'), 'canon');
    });

    test('trims and lowercases', () {
      expect(normalizeForSearch('  VALLEDUPAR  '), 'valledupar');
      expect(normalizeForSearch('  ÑANDÚ  '), 'nandu');
    });

    test('handles empty string', () {
      expect(normalizeForSearch(''), '');
      expect(normalizeForSearch('   '), '');
    });
  });

  group('searchMunicipalities', () {
    final testMunicipalities = [
      const Municipality(
        code: '20001',
        name: 'Valledupar',
        departmentCode: '20',
        isPilot: true,
      ),
      const Municipality(
        code: '20013',
        name: 'Agustín Codazzi',
        departmentCode: '20',
        isPilot: false,
      ),
      const Municipality(
        code: '20011',
        name: 'Aguachica',
        departmentCode: '20',
        isPilot: false,
      ),
    ];

    test('empty query returns all', () {
      final result = searchMunicipalities(testMunicipalities, '');
      expect(result.length, 3);
    });

    test('query with only whitespace returns all', () {
      final result = searchMunicipalities(testMunicipalities, '   ');
      expect(result.length, 3);
    });

    test('finds by partial match case-insensitive', () {
      final result = searchMunicipalities(testMunicipalities, 'val');
      expect(result.length, 1);
      expect(result.first.name, 'Valledupar');
    });

    test('finds ignoring accents', () {
      final result = searchMunicipalities(testMunicipalities, 'AGUSTIN');
      expect(result.length, 1);
      expect(result.first.name, 'Agustín Codazzi');
    });

    test('finds ignoring accents in query', () {
      final result = searchMunicipalities(testMunicipalities, 'agustin');
      expect(result.length, 1);
      expect(result.first.name, 'Agustín Codazzi');
    });

    test('no matches returns empty list', () {
      final result = searchMunicipalities(testMunicipalities, 'xyz');
      expect(result, isEmpty);
    });

    test('finds multiple matches', () {
      final result = searchMunicipalities(testMunicipalities, 'a');
      expect(result.length, 3); // All have 'a'
    });
  });
}