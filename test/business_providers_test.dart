import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/businesses/data/local_business_repository.dart';
import 'package:via_justa/features/businesses/data/supabase_business_repository.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_detail.dart';
import 'package:via_justa/features/businesses/domain/business_filter.dart';
import 'package:via_justa/features/businesses/domain/business_rating.dart';
import 'package:via_justa/features/businesses/domain/business_repository.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';

class _PaginatedMockBusinessRepository implements BusinessRepository {
  _PaginatedMockBusinessRepository(this.allItems);

  final List<Business> allItems;
  final requestedOffsets = <int>[];

  @override
  Future<List<Business>> getBusinesses({
    BusinessCategory? category,
    String? searchQuery,
    String localeCode = 'es',
    int limit = kBusinessCatalogPageSize,
    int offset = 0,
  }) async {
    requestedOffsets.add(offset);
    final filtered = filterBusinesses(
      allItems,
      category: category,
      query: searchQuery,
    );
    // Simula el tope de servidor de 50 registros por consulta.
    final serverCap = limit > 50 ? 50 : limit;
    return paginateBusinesses(filtered, limit: serverCap, offset: offset);
  }

  @override
  Future<BusinessDetail> getBusinessDetail(
    String businessId, {
    String localeCode = 'es',
  }) async {
    final match = allItems.firstWhere((item) => item.id == businessId);
    return BusinessDetail.fromBusiness(match, localeCode: localeCode);
  }

  @override
  Future<BusinessRatingSummary> rateBusiness({
    required String businessId,
    required int stars,
  }) async {
    return BusinessRatingSummary(
      businessId: businessId,
      myRating: stars,
      ratingAverage: stars.toDouble(),
      ratingCount: 1,
    );
  }
}

void main() {
  test(
    'businessCatalogProvider pagina por bloques de offset superando el tope de 50 negocios de Supabase',
    () async {
      final seeded = List.generate(
        55,
        (index) => Business(
          id: 'biz-$index',
          name: 'Comercio $index',
          category: BusinessCategory.food,
          address: 'Calle $index',
          phone: '30000000$index',
          municipalityCode: '20001',
        ),
      );
      final repo = _PaginatedMockBusinessRepository(seeded);
      final container = ProviderContainer(
        overrides: [businessRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      // Bloque 1: offset 0 -> 20 items
      final page1 = await container.read(businessCatalogProvider.future);
      expect(page1.items.length, 20);
      expect(container.read(canLoadMoreBusinessesProvider), isTrue);

      // Bloque 2: offset 20 -> 40 items
      await container.read(businessCatalogProvider.notifier).loadMore();
      expect(
        container.read(filteredBusinessesProvider).value?.length,
        40,
      );
      expect(container.read(canLoadMoreBusinessesProvider), isTrue);

      // Bloque 3: offset 40 -> 55 items (fin del catálogo, supera los 50)
      await container.read(businessCatalogProvider.notifier).loadMore();
      expect(
        container.read(filteredBusinessesProvider).value?.length,
        55,
      );
      expect(container.read(canLoadMoreBusinessesProvider), isFalse);
      expect(repo.requestedOffsets, [0, 20, 40]);
    },
  );

  test(
    'filteredBusinessesProvider combina repositorio, consulta, categoría y reinicia al filtrar',
    () async {
      const sample = [
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
        Business(
          id: '3',
          name: 'Hotel del Cesar',
          category: BusinessCategory.lodging,
          address: 'Plaza Alfonso López',
          phone: '333',
          municipalityCode: '20001',
        ),
      ];
      final repo = _PaginatedMockBusinessRepository(sample);
      final container = ProviderContainer(
        overrides: [
          businessRepositoryProvider.overrideWithValue(repo),
          businessCatalogPageSizeProvider.overrideWithValue(2),
        ],
      );
      addTearDown(container.dispose);

      final initialState = await container.read(businessCatalogProvider.future);
      expect(initialState.items.length, 2);
      expect(container.read(canLoadMoreBusinessesProvider), isTrue);

      await container.read(businessCatalogProvider.notifier).loadMore();
      expect(container.read(filteredBusinessesProvider).value?.length, 3);
      expect(container.read(canLoadMoreBusinessesProvider), isFalse);

      container
          .read(businessCategoryProvider.notifier)
          .selectCategory(BusinessCategory.food);
      await container.read(businessCatalogProvider.future);

      final filtered = container.read(filteredBusinessesProvider).value;
      expect(filtered?.length, 1);
      expect(filtered?.first.name, 'Arepas Vallenatas');

      container
          .read(businessSearchQueryProvider.notifier)
          .updateQuery('Terminal');
      await container.read(businessCatalogProvider.future);

      final emptyFiltered = container.read(filteredBusinessesProvider).value;
      expect(emptyFiltered, isEmpty);

      container.read(businessCategoryProvider.notifier).selectCategory(null);
      await container.read(businessCatalogProvider.future);

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
    'SupabaseBusinessRepository.parseRows descarta demos y mapea catálogo paginado y pertenencia del dueño',
    () {
      final parsed = SupabaseBusinessRepository.parseRows(
        [
          {
            'id': 'demo-1',
            'name': '[DEMO] Restaurante',
            'type': 'restaurant',
            'category_group': 'food',
            'description': 'Muestra demo',
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
            'name': 'Cocina del Patio',
            'type': 'restaurant',
            'category_group': 'food',
            'description': 'Comida casera vallenata.',
            'description_es': 'Comida casera vallenata.',
            'description_en': 'Home-style vallenato food.',
            'address': 'Sector Centro',
            'whatsapp': '573001234567',
            'has_whatsapp': true,
            'whatsapp_url': 'https://wa.me/573001234567',
            'order_url': 'https://vinapp.co/cocina',
            'has_external_order': true,
            'cover_photo_path': 'owner-1/real-1/photo_0.jpg',
            'photos_count': 2,
            'dishes_count': 3,
            'min_dish_price_cop': 14000,
            'municipality_code': '20001',
            'is_demo': false,
          },
        ],
        currentOwnerId: 'owner-1',
        ownedBusinessIds: const {'real-1'},
      );

      expect(parsed.length, 1);
      expect(parsed.first.id, 'real-1');
      expect(parsed.first.ownerId, 'owner-1');
      expect(parsed.first.category, BusinessCategory.food);
      expect(parsed.first.isVerified, isTrue);
      expect(parsed.first.hasWhatsapp, isTrue);
      expect(parsed.first.hasExternalOrder, isTrue);
      expect(parsed.first.coverPhotoPath, 'owner-1/real-1/photo_0.jpg');
      expect(parsed.first.photosCount, 2);
      expect(parsed.first.dishesCount, 3);
      expect(parsed.first.minDishPriceCop, 14000);
      expect(
        parsed.first.localizedDescription('es'),
        'Comida casera vallenata.',
      );
      expect(
        parsed.first.localizedDescription('en'),
        'Home-style vallenato food.',
      );
    },
  );
}
