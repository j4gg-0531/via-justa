import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_repository.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';

class _MockBusinessRepository implements BusinessRepository {
  const _MockBusinessRepository();

  @override
  Future<List<Business>> getBusinesses() async {
    return const [
      Business(
        id: '1',
        name: 'Arepas Vallenatas',
        category: BusinessCategory.food,
        address: 'Cra 9 # 10',
        phone: '111',
        municipalityCode: '20001',
      ),
      Business(
        id: '2',
        name: 'Transportes del Norte',
        category: BusinessCategory.transport,
        address: 'Terminal Taquilla 1',
        phone: '222',
        municipalityCode: '20001',
      ),
    ];
  }
}

void main() {
  test('filteredBusinessesProvider combines repository data, query and category',
      () async {
    final container = ProviderContainer(
      overrides: [
        businessRepositoryProvider.overrideWithValue(
          const _MockBusinessRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Initial state: loading
    expect(
      container.read(filteredBusinessesProvider),
      isA<AsyncLoading>(),
    );

    // Wait for data load
    final initialList =
        await container.read(allBusinessesProvider.future);
    expect(initialList.length, 2);

    // Filter by category
    container
        .read(businessCategoryProvider.notifier)
        .selectCategory(BusinessCategory.food);

    final filtered = container.read(filteredBusinessesProvider).value;
    expect(filtered?.length, 1);
    expect(filtered?.first.name, 'Arepas Vallenatas');

    // Update text query
    container
        .read(businessSearchQueryProvider.notifier)
        .updateQuery('Terminal');

    // Mismatch between food category and query 'Terminal'
    final emptyFiltered = container.read(filteredBusinessesProvider).value;
    expect(emptyFiltered, isEmpty);

    // Clear category filter
    container
        .read(businessCategoryProvider.notifier)
        .selectCategory(null);

    final transportFiltered = container.read(filteredBusinessesProvider).value;
    expect(transportFiltered?.length, 1);
    expect(transportFiltered?.first.name, 'Transportes del Norte');
  });
}
