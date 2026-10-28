import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
