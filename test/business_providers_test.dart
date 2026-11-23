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
import 'package:via_justa/features/onboarding/domain/profile_type.dart';
import 'package:via_justa/features/onboarding/presentation/state/profile_type_provider.dart';

class _PaginatedMockBusinessRepository implements BusinessRepository {
  _PaginatedMockBusinessRepository(
    this.allItems, {
    this.myItems = const <Business>[],
  });

  final List<Business> allItems;
  final List<Business> myItems;
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

  @override
  Future<List<Business>> getMyBusinesses() async => myItems;
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

  test(
    'partitionOwnedBusinesses separa propios arriba sin duplicar, rescata propios fuera de la página 1 y respeta filtros',
    () {
      const catalogPage1 = <Business>[
        Business(
          id: 'other-a',
          ownerId: 'owner-2',
          name: 'Asadero Alpha',
          category: BusinessCategory.food,
          address: 'Calle 1',
          phone: '111',
          municipalityCode: '20001',
        ),
        Business(
          id: 'mine-in-page1',
          ownerId: 'owner-1',
          name: 'Mi Café Centro',
          category: BusinessCategory.food,
          address: 'Calle 10',
          phone: '222',
          municipalityCode: '20001',
          minDishPriceCop: 12000,
        ),
      ];
      const myFromRpc = <Business>[
        Business(
          id: 'mine-in-page1',
          ownerId: 'owner-1',
          name: 'Mi Café Centro',
          category: BusinessCategory.food,
          address: 'Calle 10',
          phone: '',
          municipalityCode: '20001',
          status: 'approved',
        ),
        Business(
          id: 'mine-page2-z',
          ownerId: 'owner-1',
          name: 'Zapatería Valle',
          category: BusinessCategory.services,
          address: 'Carrera 9',
          phone: '',
          municipalityCode: '20001',
          status: 'approved',
        ),
        Business(
          id: 'mine-pending',
          ownerId: 'owner-1',
          name: 'Nuevo Hotel',
          category: BusinessCategory.lodging,
          address: 'Calle 20',
          phone: '',
          municipalityCode: '20001',
          status: 'pending',
        ),
        Business(
          id: 'mine-other-city',
          ownerId: 'owner-1',
          name: 'Tienda Aguachica',
          category: BusinessCategory.services,
          address: 'Centro',
          phone: '',
          municipalityCode: '20011',
          status: 'approved',
        ),
      ];

      final result = partitionOwnedBusinesses(
        catalog: catalogPage1,
        ownedBusinesses: myFromRpc,
        currentOwnerId: 'owner-1',
        municipalityCode: '20001',
      );

      expect(result.owned.map((b) => b.id).toList(), [
        'mine-in-page1',
        'mine-page2-z',
      ]);
      // Conserva el registro más rico del catálogo cuando existe en ambos
      expect(result.owned.first.minDishPriceCop, 12000);
      expect(result.others.map((b) => b.id).toList(), ['other-a']);

      // Al filtrar por categoría Comida, Zapatería Valle se oculta de Tus negocios
      final foodOnly = partitionOwnedBusinesses(
        catalog: catalogPage1,
        ownedBusinesses: myFromRpc,
        currentOwnerId: 'owner-1',
        municipalityCode: '20001',
        category: BusinessCategory.food,
      );
      expect(foodOnly.owned.map((b) => b.id).toList(), ['mine-in-page1']);
      expect(foodOnly.others.map((b) => b.id).toList(), ['other-a']);

      // Sin usuario dueño, no se separa nada en owned
      final guest = partitionOwnedBusinesses(
        catalog: catalogPage1,
        ownedBusinesses: myFromRpc,
        currentOwnerId: null,
        municipalityCode: '20001',
      );
      expect(guest.hasOwned, isFalse);
      expect(guest.others.length, 2);
    },
  );

  test('shouldShowMyBusinessesInProfile solo muestra acceso a dueños o residentes', () {
    expect(
      shouldShowMyBusinessesInProfile(ownedCount: 0, isResidentProfile: false),
      isFalse,
    );
    expect(
      shouldShowMyBusinessesInProfile(ownedCount: 1, isResidentProfile: false),
      isTrue,
    );
    expect(
      shouldShowMyBusinessesInProfile(ownedCount: 0, isResidentProfile: true),
      isTrue,
    );
  });

  test('SupabaseBusinessRepository.parseMyBusinessesRows mapea estados y motivo de rechazo', () {
    final rows = SupabaseBusinessRepository.parseMyBusinessesRows(
      const [
        {
          'id': 'b1',
          'municipality_code': '20001',
          'type': 'restaurant',
          'name': 'El Fogón',
          'status': 'approved',
          'address': 'Calle 12',
          'photos_count': 2,
          'dishes_count': 4,
        },
        {
          'id': 'b2',
          'municipality_code': '20001',
          'type': 'hotel',
          'name': 'Hostal Sol',
          'status': 'rejected',
          'rejection_reason': 'Falta dirección exacta',
          'address': 'Centro',
        },
      ],
      currentOwnerId: 'owner-1',
    );

    expect(rows.length, 2);
    expect(rows[0].isApproved, isTrue);
    expect(rows[0].category, BusinessCategory.food);
    expect(rows[1].isRejected, isTrue);
    expect(rows[1].category, BusinessCategory.lodging);
    expect(rows[1].rejectionReason, 'Falta dirección exacta');
  });

  test(
    'partitionedBusinessesProvider y showMyBusinessesInProfileProvider integran repositorio y perfil',
    () async {
      const myBiz = Business(
        id: 'mine-z',
        ownerId: 'owner-1',
        name: 'Zapatería del Valle',
        category: BusinessCategory.services,
        address: 'Cra 9 #12',
        phone: '',
        municipalityCode: '20001',
      );
      const otherBiz = Business(
        id: 'other-1',
        ownerId: 'owner-2',
        name: 'Arepas Centro',
        category: BusinessCategory.food,
        address: 'Cra 5 #8',
        phone: '111',
        municipalityCode: '20001',
      );
      final repo = _PaginatedMockBusinessRepository(
        const [otherBiz],
        myItems: const [myBiz],
      );
      final container = ProviderContainer(
        overrides: [
          businessRepositoryProvider.overrideWithValue(repo),
          currentBusinessOwnerIdProvider.overrideWithValue('owner-1'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(businessCatalogProvider.future);
      await container.read(myBusinessesProvider.future);

      final partitioned = container.read(partitionedBusinessesProvider).value!;
      expect(partitioned.owned.map((b) => b.id).toList(), ['mine-z']);
      expect(partitioned.others.map((b) => b.id).toList(), ['other-1']);
      expect(container.read(myBusinessesCountProvider), 1);
      expect(container.read(showMyBusinessesInProfileProvider), isTrue);

      // Visitante sin negocios no ve el acceso en Perfil
      final guestContainer = ProviderContainer(
        overrides: [
          businessRepositoryProvider.overrideWithValue(
            _PaginatedMockBusinessRepository(const [otherBiz]),
          ),
          currentBusinessOwnerIdProvider.overrideWithValue(null),
        ],
      );
      addTearDown(guestContainer.dispose);
      await guestContainer.read(myBusinessesProvider.future);
      expect(guestContainer.read(showMyBusinessesInProfileProvider), isFalse);

      // Residente sin negocios sí ve el acceso para registrar
      guestContainer
          .read(profileTypeProvider.notifier)
          .select(ProfileType.resident);
      expect(guestContainer.read(showMyBusinessesInProfileProvider), isTrue);
    },
  );
}
