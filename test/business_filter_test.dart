import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_filter.dart';

void main() {
  const sampleBusinesses = [
    Business(
      id: '1',
      name: 'Restaurante El Pilón Vallenato',
      category: BusinessCategory.food,
      address: 'Calle 10 # 5-20',
      phone: '12345',
      municipalityCode: '20001',
      description: 'Chivo y sancocho',
      descriptionEs: 'Chivo y sancocho tradicional',
      descriptionEn: 'Traditional goat stew and hen soup',
    ),
    Business(
      id: '2',
      name: 'Taxi Central',
      category: BusinessCategory.transport,
      address: 'Cra 12 # 15-30',
      phone: '67890',
      municipalityCode: '20001',
      description: 'Transporte seguro',
    ),
    Business(
      id: '3',
      name: 'Hotel Plaza Upar',
      category: BusinessCategory.lodging,
      address: 'Calle 14 # 8-10',
      phone: '54321',
      municipalityCode: '20001',
      description: 'Hospedaje centro',
    ),
  ];

  group('filterBusinesses domain pure function', () {
    test('returns all businesses when query is empty and category is null', () {
      final result = filterBusinesses(sampleBusinesses);
      expect(result.length, 3);
    });

    test('filters by category accurately and maps catalogFilterValue', () {
      expect(BusinessCategory.food.catalogFilterValue, 'food');
      expect(BusinessCategory.transport.catalogFilterValue, 'transport');
      expect(BusinessCategory.lodging.catalogFilterValue, 'lodging');
      expect(BusinessCategory.services.catalogFilterValue, 'services');

      final foodResult = filterBusinesses(
        sampleBusinesses,
        category: BusinessCategory.food,
      );
      expect(foodResult.length, 1);
      expect(foodResult.first.name, 'Restaurante El Pilón Vallenato');

      final transportResult = filterBusinesses(
        sampleBusinesses,
        category: BusinessCategory.transport,
      );
      expect(transportResult.length, 1);
      expect(transportResult.first.name, 'Taxi Central');
    });

    test(
      'filters by accent-insensitive query across name, descriptions (es/en) and address',
      () {
        final accentInsensitive = filterBusinesses(
          sampleBusinesses,
          query: 'pilon',
        );
        expect(accentInsensitive.length, 1);
        expect(accentInsensitive.first.id, '1');

        final englishMatch = filterBusinesses(
          sampleBusinesses,
          query: 'goat stew',
        );
        expect(englishMatch.length, 1);
        expect(englishMatch.first.id, '1');

        final addressResult = filterBusinesses(
          sampleBusinesses,
          query: 'Cra 12',
        );
        expect(addressResult.length, 1);
        expect(addressResult.first.name, 'Taxi Central');
      },
    );

    test('filters by both category and query simultaneously', () {
      final result = filterBusinesses(
        sampleBusinesses,
        query: 'Plaza',
        category: BusinessCategory.lodging,
      );
      expect(result.length, 1);
      expect(result.first.name, 'Hotel Plaza Upar');

      final mismatchResult = filterBusinesses(
        sampleBusinesses,
        query: 'Plaza',
        category: BusinessCategory.food,
      );
      expect(mismatchResult, isEmpty);
    });
  });

  group('paginateBusinesses and canLoadMoreBusinesses', () {
    test('slices list by limit and offset and reports whether more pages exist', () {
      final firstTwo = paginateBusinesses(sampleBusinesses, limit: 2, offset: 0);
      expect(firstTwo.map((b) => b.id), ['1', '2']);
      expect(
        canLoadMoreBusinesses(currentCount: firstTwo.length, currentLimit: 2),
        isTrue,
      );

      final allThree = paginateBusinesses(sampleBusinesses, limit: 4, offset: 0);
      expect(allThree.length, 3);
      expect(
        canLoadMoreBusinesses(currentCount: allThree.length, currentLimit: 4),
        isFalse,
      );

      expect(paginateBusinesses(sampleBusinesses, limit: 2, offset: 10), isEmpty);
    });
  });
}
