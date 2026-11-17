import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/businesses/data/local_business_repository.dart';
import 'package:via_justa/features/businesses/data/supabase_business_repository.dart';
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
  test(
    'filteredBusinessesProvider combines repository data, query and category',
    () async {
      final container = ProviderContainer(
        overrides: [
          businessRepositoryProvider.overrideWithValue(
            const _MockBusinessRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(filteredBusinessesProvider),
        isA<AsyncLoading>(),
      );

      final initialList = await container.read(allBusinessesProvider.future);
      expect(initialList.length, 2);

      container
          .read(businessCategoryProvider.notifier)
          .selectCategory(BusinessCategory.food);

      final filtered = container.read(filteredBusinessesProvider).value;
      expect(filtered?.length, 1);
      expect(filtered?.first.name, 'Arepas Vallenatas');

      container
          .read(businessSearchQueryProvider.notifier)
          .updateQuery('Terminal');

      final emptyFiltered = container.read(filteredBusinessesProvider).value;
      expect(emptyFiltered, isEmpty);

      container.read(businessCategoryProvider.notifier).selectCategory(null);

      final transportFiltered =
          container.read(filteredBusinessesProvider).value;
      expect(transportFiltered?.length, 1);
      expect(transportFiltered?.first.name, 'Transportes del Norte');
    },
  );

  test(
    'LocalBusinessRepository devuelve lista vacía sin comercios de demostración',
    () async {
      const repo = LocalBusinessRepository();
      expect(await repo.getBusinesses(), isEmpty);
    },
  );

  test(
    'SupabaseBusinessRepository.parseRows descarta demos y no aprobados y resuelve descripción por idioma',
    () {
      final parsed = SupabaseBusinessRepository.parseRows([
        {
          'id': 'demo-1',
          'owner_id': null,
          'name': '[DEMO] Restaurante',
          'type': 'restaurant',
          'description_es': 'Muestra demo',
          'status': 'approved',
          'is_demo': true,
        },
        {
          'id': 'pending-1',
          'owner_id': 'owner-1',
          'name': 'En preparación',
          'type': 'restaurant',
          'description_es': 'Todavía pendiente',
          'status': 'pending',
          'is_demo': false,
        },
        {
          'id': 'real-1',
          'owner_id': 'owner-1',
          'name': 'Cocina del Patio',
          'type': 'restaurant',
          'description_es': 'Comida casera vallenata.',
          'description_en': 'Home-style vallenato food.',
          'address': 'Sector Centro',
          'whatsapp': '573001234567',
          'municipality_code': '20001',
          'status': 'approved',
          'is_demo': false,
        },
      ]);

      expect(parsed.length, 1);
      expect(parsed.first.id, 'real-1');
      expect(parsed.first.ownerId, 'owner-1');
      expect(parsed.first.isVerified, isTrue);
      expect(parsed.first.localizedDescription('es'), 'Comida casera vallenata.');
      expect(parsed.first.localizedDescription('en'), 'Home-style vallenato food.');
    },
  );
}
