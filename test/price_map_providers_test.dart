import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/prices/data/supabase_price_map_repository.dart';
import 'package:via_justa/features/prices/domain/price_map_item.dart';
import 'package:via_justa/features/prices/domain/price_map_repository.dart';
import 'package:via_justa/features/prices/presentation/state/price_map_providers.dart';

class _FakePriceMapRepository implements PriceMapRepository {
  const _FakePriceMapRepository();

  @override
  Future<List<PriceMapItem>> getMapItems({
    String municipalityCode = '20001',
  }) async {
    return const [
      PriceMapItem(
        id: 'fake_1',
        name: '[DEMO] Clínica del Cesar',
        description: 'Urgencias médicas',
        category: PriceMapCategory.services,
        pinKind: PriceMapPinKind.hospital,
        status: PricePinStatus.info,
        pinLabel: '',
        badgeText: '1.0 km',
        normalizedX: 0.4,
        normalizedY: 0.6,
        latitude: 10.4755,
        longitude: -73.2495,
        phone: '6055700000',
        sourceType: 'business',
        municipalityCode: '20001',
      ),
      PriceMapItem(
        id: 'fake_2',
        name: '[DEMO] Taxi urbano',
        description: 'Carrera diurna',
        category: PriceMapCategory.prices,
        pinKind: PriceMapPinKind.transport,
        status: PricePinStatus.fair,
        pinLabel: r'$12k',
        badgeText: r'$12.000',
        normalizedX: 0.5,
        normalizedY: 0.4,
        latitude: 10.4742,
        longitude: -73.2436,
        sourceType: 'price_report',
        municipalityCode: '20001',
      ),
    ];
  }
}

void main() {
  test('filteredPriceMapItemsProvider filters items from fake repository', () async {
    final container = ProviderContainer(
      overrides: [
        priceMapRepositoryProvider.overrideWithValue(
          const _FakePriceMapRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Wait for initial load
    final allItems = await container.read(allPriceMapItemsProvider.future);
    expect(allItems.length, 2);

    // Filter by category (toggleCategory)
    container
        .read(priceMapCategoryProvider.notifier)
        .toggleCategory(PriceMapCategory.prices);
    expect(container.read(priceMapCategoryProvider), PriceMapCategory.prices);
    expect(
      container.read(priceMapSectionTitleKeyProvider),
      'price_map.section_prices',
    );

    final filteredByCat = container.read(filteredPriceMapItemsProvider).value!;
    expect(filteredByCat.length, 1);
    expect(filteredByCat.first.id, 'fake_2');

    // Toggling same category resets to null
    container
        .read(priceMapCategoryProvider.notifier)
        .toggleCategory(PriceMapCategory.prices);
    expect(container.read(priceMapCategoryProvider), isNull);

    // Filter by search query
    container.read(priceMapSearchQueryProvider.notifier).updateQuery('clinica');
    final filteredByQuery =
        container.read(filteredPriceMapItemsProvider).value!;
    expect(filteredByQuery.length, 1);
    expect(filteredByQuery.first.id, 'fake_1');
  });

  test('SupabasePriceMapRepository.parseRows maps price_report and business RPC rows with WGS84 coordinates', () {
    final rows = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'rep-1',
        'source_type': 'price_report',
        'name_es': 'Almuerzo ejecutivo · Zona Norte',
        'name_en': 'Standard lunch · North Zone',
        'description_es': 'Reporte ciudadano en Zona Norte',
        'description_en': 'Community report in North Zone',
        'map_category': 'prices',
        'pin_kind': 'food',
        'pin_status': 'fair',
        'pin_label': r'$15k',
        'badge_text': r'$15.000',
        'latitude': 10.488,
        'longitude': -73.253,
        'normalized_x': 0.5,
        'normalized_y': 0.2,
        'phone': null,
        'whatsapp': null,
        'address': 'Asadero Guatapurí',
        'municipality_code': '20001',
        'zone_id': 'vup_norte',
        'amount_cop': 15000,
        'is_demo': false,
      },
      <String, dynamic>{
        'id': 'biz-1',
        'source_type': 'business',
        'name_es': 'Clínica Médicos Valledupar',
        'name_en': 'Clínica Médicos Valledupar',
        'description_es': 'Urgencias y hospitalización 24 horas',
        'description_en': '24h emergency and hospital care',
        'map_category': 'services',
        'pin_kind': 'hospital',
        'pin_status': 'info',
        'pin_label': '',
        'badge_text': 'Calle 16B #19-75',
        'latitude': 10.4718,
        'longitude': -73.2562,
        'normalized_x': 0.34,
        'normalized_y': 0.72,
        'phone': '6055748400',
        'whatsapp': '576055748400',
        'address': 'Calle 16B #19-75',
        'municipality_code': '20001',
        'zone_id': 'vup_centro',
        'amount_cop': null,
        'is_demo': false,
      },
    ];

    final parsedEs = SupabasePriceMapRepository.parseRows(
      rows,
      municipalityCode: '20001',
      localeCode: 'es',
    );

    expect(parsedEs.length, 2);
    expect(parsedEs[0].category, PriceMapCategory.prices);
    expect(parsedEs[0].status, PricePinStatus.fair);
    expect(parsedEs[0].latitude, closeTo(10.488, 0.0001));
    expect(parsedEs[0].longitude, closeTo(-73.253, 0.0001));
    expect(parsedEs[0].isDemo, isFalse);
    expect(parsedEs[0].hasCallableContact, isFalse);

    expect(parsedEs[1].category, PriceMapCategory.services);
    expect(parsedEs[1].pinKind, PriceMapPinKind.hospital);
    expect(parsedEs[1].status, PricePinStatus.info);
    expect(parsedEs[1].latitude, closeTo(10.4718, 0.0001));
    expect(parsedEs[1].longitude, closeTo(-73.2562, 0.0001));
    expect(parsedEs[1].hasCallableContact, isTrue);
    expect(parsedEs[1].sourceType, 'business');
  });
}
