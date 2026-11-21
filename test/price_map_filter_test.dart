import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/prices/domain/price_map_filter.dart';
import 'package:via_justa/features/prices/domain/price_map_item.dart';

const _sampleItems = <PriceMapItem>[
  PriceMapItem(
    id: '1',
    name: '[DEMO] Hospital Rosario Pumarejo',
    description: 'Atención urgencias 24h',
    category: PriceMapCategory.services,
    pinKind: PriceMapPinKind.hospital,
    status: PricePinStatus.info,
    pinLabel: '',
    badgeText: '2.4 km',
    normalizedX: 0.3,
    normalizedY: 0.7,
    municipalityCode: '20001',
  ),
  PriceMapItem(
    id: '2',
    name: '[DEMO] Almuerzo corriente · Centro',
    description: 'Precio dentro de la mediana',
    category: PriceMapCategory.prices,
    pinKind: PriceMapPinKind.food,
    status: PricePinStatus.fair,
    pinLabel: r'$12k',
    badgeText: r'$12.000',
    normalizedX: 0.2,
    normalizedY: 0.3,
    municipalityCode: '20001',
  ),
  PriceMapItem(
    id: '3',
    name: '[DEMO] Orientación Consular',
    description: 'Trámites migratorios',
    category: PriceMapCategory.consulates,
    pinKind: PriceMapPinKind.consulate,
    status: PricePinStatus.info,
    pinLabel: '',
    badgeText: '1.9 km',
    normalizedX: 0.5,
    normalizedY: 0.5,
    municipalityCode: '20001',
  ),
];

void main() {
  group('filterPriceMapItems', () {
    test('returns all items when category and query are null/empty', () {
      final result = filterPriceMapItems(_sampleItems);
      expect(result.length, 3);
    });

    test('filters by category', () {
      final pricesOnly = filterPriceMapItems(
        _sampleItems,
        category: PriceMapCategory.prices,
      );
      expect(pricesOnly.length, 1);
      expect(pricesOnly.first.id, '2');

      final servicesOnly = filterPriceMapItems(
        _sampleItems,
        category: PriceMapCategory.services,
      );
      expect(servicesOnly.length, 1);
      expect(servicesOnly.first.id, '1');
    });

    test('filters by accent-insensitive search query', () {
      final result = filterPriceMapItems(
        _sampleItems,
        query: 'atencion urgencias',
      );
      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('combines category and query filters', () {
      final match = filterPriceMapItems(
        _sampleItems,
        category: PriceMapCategory.consulates,
        query: 'tramites',
      );
      expect(match.length, 1);
      expect(match.first.id, '3');

      final noMatch = filterPriceMapItems(
        _sampleItems,
        category: PriceMapCategory.prices,
        query: 'hospital',
      );
      expect(noMatch, isEmpty);
    });

    test('excludes demo businesses while keeping real businesses', () {
      const mixed = <PriceMapItem>[
        PriceMapItem(
          id: 'demo_biz',
          name: '[DEMO] Comercio de muestra',
          description: 'Muestra',
          category: PriceMapCategory.services,
          pinKind: PriceMapPinKind.food,
          status: PricePinStatus.info,
          pinLabel: '',
          badgeText: '',
          normalizedX: 0.5,
          normalizedY: 0.5,
          sourceType: 'business',
          municipalityCode: '20001',
          isDemo: true,
        ),
        PriceMapItem(
          id: 'real_biz',
          name: 'Cocina del Patio',
          description: 'Comida casera',
          category: PriceMapCategory.services,
          pinKind: PriceMapPinKind.food,
          status: PricePinStatus.info,
          pinLabel: '',
          badgeText: '',
          normalizedX: 0.5,
          normalizedY: 0.5,
          sourceType: 'business',
          municipalityCode: '20001',
          isDemo: false,
        ),
      ];
      final result = filterPriceMapItems(mixed);
      expect(result.map((e) => e.id), ['real_biz']);
    });
  });

  group('sectionTitleKeyForMapCategory', () {
    test('returns expected translation keys for each category', () {
      expect(sectionTitleKeyForMapCategory(null), 'price_map.section_all');
      expect(
        sectionTitleKeyForMapCategory(PriceMapCategory.prices),
        'price_map.section_prices',
      );
      expect(
        sectionTitleKeyForMapCategory(PriceMapCategory.services),
        'price_map.section_services',
      );
      expect(
        sectionTitleKeyForMapCategory(PriceMapCategory.consulates),
        'price_map.section_consulates',
      );
    });
  });

  group('PriceMapItem alignment coordinates', () {
    test('maps normalized coordinates [0, 1] to alignment range [-1, 1]', () {
      expect(_sampleItems[0].alignmentX, closeTo(-0.4, 0.0001));
      expect(_sampleItems[0].alignmentY, closeTo(0.4, 0.0001));
      expect(_sampleItems[2].alignmentX, closeTo(0.0, 0.0001));
      expect(_sampleItems[2].alignmentY, closeTo(0.0, 0.0001));
    });
  });

  group('filterSheetPlaceItems', () {
    test(
      'excluye reportes históricos de precios y comercios demo, y prioriza elemento seleccionado',
      () {
        final result = filterSheetPlaceItems(
          _sampleItems,
          prioritizedId: '3',
        );
        expect(result.map((e) => e.id).toList(), ['3', '1']);
      },
    );

    test('filtra lugares por categoría services y consulates', () {
      expect(
        filterSheetPlaceItems(
          _sampleItems,
          category: PriceMapCategory.services,
        ).map((e) => e.id).toList(),
        ['1'],
      );
      expect(
        filterSheetPlaceItems(
          _sampleItems,
          category: PriceMapCategory.consulates,
        ).map((e) => e.id).toList(),
        ['3'],
      );
    });
  });
}
