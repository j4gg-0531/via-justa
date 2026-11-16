import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/businesses/data/local_business_repository.dart';
import 'package:via_justa/features/businesses/data/supabase_business_repository.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_detail.dart';
import 'package:via_justa/features/businesses/domain/business_filter.dart';
import 'package:via_justa/features/businesses/domain/business_repository.dart';
import 'package:via_justa/features/businesses/presentation/state/register_business_provider.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/prices/presentation/state/price_map_providers.dart';

/// Provider del repositorio de negocios (conecta a Supabase cuando está activo).
final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final municipality = ref.watch(selectedMunicipalityProvider);
  final code = municipality?.code ?? '20001';
  if (client != null) {
    return SupabaseBusinessRepository(
      client: client,
      municipalityCode: code,
    );
  }
  return const LocalBusinessRepository();
});

/// Identificador del usuario autenticado con sesión real para acciones de dueño.
final currentBusinessOwnerIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(
    authControllerProvider.select(
      (value) => (value.session?.userId, value.usesDemoData),
    ),
  );
  final registrationRepo = ref.watch(businessRegistrationRepositoryProvider);
  if (registrationRepo == null || auth.$2) return null;
  return auth.$1;
});

/// Controlador para que el dueño retire un negocio propio desde el directorio.
class BusinessOwnerActionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> withdraw(String businessId) async {
    final ownerId = ref.read(currentBusinessOwnerIdProvider);
    final repo = ref.read(businessRegistrationRepositoryProvider);
    if (state || ownerId == null || repo == null) return false;
    state = true;
    try {
      await repo.withdraw(businessId: businessId, ownerId: ownerId);
      if (!ref.mounted) return true;
      state = false;
      ref.invalidate(allBusinessesProvider);
      ref.invalidate(allPriceMapItemsProvider);
      return true;
    } catch (_) {
      if (ref.mounted) state = false;
      return false;
    }
  }
}

final businessOwnerActionProvider =
    NotifierProvider<BusinessOwnerActionNotifier, bool>(
      BusinessOwnerActionNotifier.new,
    );

/// Notifier para el límite acumulado de paginación del catálogo de negocios.
class BusinessCatalogPageLimitNotifier extends Notifier<int> {
  @override
  int build() => kBusinessCatalogPageSize;

  void loadMore({int step = kBusinessCatalogPageSize}) {
    final safeStep = step < 1 ? kBusinessCatalogPageSize : step;
    state = state + safeStep;
  }

  void setLimit(int limit) {
    state = limit < 1 ? 1 : limit;
  }

  void reset() {
    state = kBusinessCatalogPageSize;
  }
}

/// Provider del límite actual de elementos cargados en el directorio de negocios.
final businessCatalogPageLimitProvider =
    NotifierProvider<BusinessCatalogPageLimitNotifier, int>(
      BusinessCatalogPageLimitNotifier.new,
    );

/// Notifier para la categoría seleccionada en el filtro.
class BusinessCategoryNotifier extends Notifier<BusinessCategory?> {
  @override
  BusinessCategory? build() => null;

  void selectCategory(BusinessCategory? category) {
    if (state == category) return;
    state = category;
    ref.read(businessCatalogPageLimitProvider.notifier).reset();
  }

  void clear() {
    if (state == null) return;
    state = null;
    ref.read(businessCatalogPageLimitProvider.notifier).reset();
  }
}

/// Provider de la categoría activa de negocio.
final businessCategoryProvider =
    NotifierProvider<BusinessCategoryNotifier, BusinessCategory?>(
      BusinessCategoryNotifier.new,
    );

/// Notifier para el texto de búsqueda en el directorio de negocios.
class BusinessSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String query) {
    if (state == query) return;
    state = query;
    ref.read(businessCatalogPageLimitProvider.notifier).reset();
  }

  void clear() {
    if (state.isEmpty) return;
    state = '';
    ref.read(businessCatalogPageLimitProvider.notifier).reset();
  }
}

/// Provider de la consulta de texto para filtrar negocios.
final businessSearchQueryProvider =
    NotifierProvider<BusinessSearchQueryNotifier, String>(
      BusinessSearchQueryNotifier.new,
    );

/// Provider que carga la lista paginada de comercios desde el repositorio.
final allBusinessesProvider = FutureProvider<List<Business>>((ref) async {
  final repository = ref.watch(businessRepositoryProvider);
  final category = ref.watch(businessCategoryProvider);
  final query = ref.watch(businessSearchQueryProvider);
  final limit = ref.watch(businessCatalogPageLimitProvider);
  return repository.getBusinesses(
    category: category,
    searchQuery: query,
    limit: limit,
    offset: 0,
  );
});

/// Provider que combina la lista, la consulta, la categoría y la paginación mediante funciones puras de dominio.
final filteredBusinessesProvider = Provider<AsyncValue<List<Business>>>((ref) {
  final businessesAsync = ref.watch(allBusinessesProvider);
  final query = ref.watch(businessSearchQueryProvider);
  final category = ref.watch(businessCategoryProvider);
  final limit = ref.watch(businessCatalogPageLimitProvider);

  return businessesAsync.whenData((businesses) {
    final filtered = filterBusinesses(
      businesses,
      query: query,
      category: category,
    );
    return paginateBusinesses(filtered, limit: limit);
  });
});

/// Indica si hay más páginas disponibles para cargar en el directorio.
final canLoadMoreBusinessesProvider = Provider<bool>((ref) {
  final filtered = ref.watch(filteredBusinessesProvider).asData?.value;
  final limit = ref.watch(businessCatalogPageLimitProvider);
  if (filtered == null) return false;
  return canLoadMoreBusinesses(
    currentCount: filtered.length,
    currentLimit: limit,
  );
});

/// Provider que carga la ficha completa de un negocio por su identificador.
final businessDetailProvider = FutureProvider.autoDispose
    .family<BusinessDetail, String>((ref, businessId) async {
      final repository = ref.watch(businessRepositoryProvider);
      return repository.getBusinessDetail(businessId);
    });
