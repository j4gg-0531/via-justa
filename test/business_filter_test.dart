import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_filter.dart';

void main() {
  const sampleBusinesses = [
    Business(
      id: '1',
      name: 'Restaurante Valledupar',
      category: BusinessCategory.food,
      address: 'Calle 10 # 5-20',
      phone: '12345',
      municipalityCode: '20001',
      description: 'Chivo y sancocho',
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

    test('filters by category accurately', () {
      final foodResult = filterBusinesses(
        sampleBusinesses,
        category: BusinessCategory.food,
      );
      expect(foodResult.length, 1);
      expect(foodResult.first.name, 'Restaurante Valledupar');

      final transportResult = filterBusinesses(
        sampleBusinesses,
        category: BusinessCategory.transport,
      );
      expect(transportResult.length, 1);
      expect(transportResult.first.name, 'Taxi Central');
    });

    test('filters by query across name, description and address', () {
      final queryResult = filterBusinesses(
        sampleBusinesses,
        query: 'sancocho',
      );
      expect(queryResult.length, 1);
      expect(queryResult.first.name, 'Restaurante Valledupar');

      final addressResult = filterBusinesses(
        sampleBusinesses,
        query: 'Cra 12',
      );
      expect(addressResult.length, 1);
      expect(addressResult.first.name, 'Taxi Central');
    });

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
}
