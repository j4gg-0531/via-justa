import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/businesses/data/device_business_external_launcher.dart';
import 'package:via_justa/features/businesses/data/local_business_repository.dart';
import 'package:via_justa/features/businesses/data/supabase_business_repository.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_detail.dart';
import 'package:via_justa/features/businesses/domain/business_external_actions.dart';
import 'package:via_justa/features/businesses/domain/business_filter.dart';
import 'package:via_justa/features/businesses/domain/business_rating.dart';
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

/// Tamaño de cada página solicitada al catálogo de negocios.
final businessCatalogPageSizeProvider = Provider<int>(
  (ref) => kBusinessCatalogPageSize,
);

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
      ref.invalidate(businessCatalogProvider);
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

/// Notifier para la categoría seleccionada en el filtro.
class BusinessCategoryNotifier extends Notifier<BusinessCategory?> {
  @override
  BusinessCategory? build() => null;

  void selectCategory(BusinessCategory? category) {
    if (state == category) return;
    state = category;
  }

  void clear() {
    if (state == null) return;
    state = null;
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
  }

  void clear() {
    if (state.isEmpty) return;
    state = '';
  }
}

/// Provider de la consulta de texto para filtrar negocios.
final businessSearchQueryProvider =
    NotifierProvider<BusinessSearchQueryNotifier, String>(
      BusinessSearchQueryNotifier.new,
    );

/// Estado paginado del catálogo de negocios (acumula bloques por `offset`).
class BusinessCatalogState {
  const BusinessCatalogState({
    this.items = const <Business>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreError = false,
  });

  final List<Business> items;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreError;

  BusinessCatalogState copyWith({
    List<Business>? items,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreError,
  }) {
    return BusinessCatalogState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: loadMoreError ?? this.loadMoreError,
    );
  }
}

/// Notifier asíncrono que carga y acumula páginas reales mediante `offset` y `limit`.
class BusinessCatalogNotifier extends AsyncNotifier<BusinessCatalogState> {
  int _generation = 0;

  @override
  Future<BusinessCatalogState> build() async {
    _generation++;
    final repository = ref.watch(businessRepositoryProvider);
    final category = ref.watch(businessCategoryProvider);
    final query = ref.watch(businessSearchQueryProvider);
    final pageSize = ref.watch(businessCatalogPageSizeProvider);

    final firstPage = await repository.getBusinesses(
      category: category,
      searchQuery: query,
      limit: pageSize,
      offset: 0,
    );

    final merged = mergeBusinessPage(const <Business>[], firstPage);
    return BusinessCatalogState(
      items: merged.items,
      hasMore: firstPage.length >= pageSize,
    );
  }

  /// Carga el siguiente bloque usando el tamaño acumulado como `offset` real.
  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    final generation = _generation;
    final repository = ref.read(businessRepositoryProvider);
    final category = ref.read(businessCategoryProvider);
    final query = ref.read(businessSearchQueryProvider);
    final pageSize = ref.read(businessCatalogPageSizeProvider);

    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreError: false),
    );

    try {
      final nextPage = await repository.getBusinesses(
        category: category,
        searchQuery: query,
        limit: pageSize,
        offset: current.items.length,
      );
      if (!ref.mounted || generation != _generation) return;

      final merged = mergeBusinessPage(current.items, nextPage);
      state = AsyncData(
        BusinessCatalogState(
          items: merged.items,
          hasMore: nextPage.length >= pageSize && merged.addedCount > 0,
        ),
      );
    } catch (_) {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreError: true),
      );
    }
  }
}

/// Provider principal del catálogo paginado de negocios.
final businessCatalogProvider =
    AsyncNotifierProvider<BusinessCatalogNotifier, BusinessCatalogState>(
      BusinessCatalogNotifier.new,
    );

/// Lista acumulada de comercios cargados desde el repositorio.
final allBusinessesProvider = Provider<AsyncValue<List<Business>>>((ref) {
  return ref.watch(businessCatalogProvider).whenData((catalog) => catalog.items);
});

/// Provider que combina la lista cargada, la consulta y la categoría mediante la función pura de dominio.
final filteredBusinessesProvider = Provider<AsyncValue<List<Business>>>((ref) {
  final businessesAsync = ref.watch(allBusinessesProvider);
  final query = ref.watch(businessSearchQueryProvider);
  final category = ref.watch(businessCategoryProvider);

  return businessesAsync.whenData((businesses) {
    return filterBusinesses(
      businesses,
      query: query,
      category: category,
    );
  });
});

/// Indica si hay más páginas disponibles para cargar en el directorio.
final canLoadMoreBusinessesProvider = Provider<bool>((ref) {
  return ref.watch(businessCatalogProvider).asData?.value.hasMore ?? false;
});

/// Indica si actualmente se está solicitando la página siguiente del directorio.
final isLoadingMoreBusinessesProvider = Provider<bool>((ref) {
  return ref.watch(businessCatalogProvider).asData?.value.isLoadingMore ?? false;
});

/// Provider que carga la ficha completa de un negocio por su identificador.
final businessDetailProvider = FutureProvider.autoDispose
    .family<BusinessDetail, String>((ref, businessId) async {
      final repository = ref.watch(businessRepositoryProvider);
      return repository.getBusinessDetail(businessId);
    });

/// Provider del adaptador que abre enlaces externos de negocios.
final businessExternalLauncherProvider = Provider<BusinessExternalLauncher>((
  ref,
) {
  return const DeviceBusinessExternalLauncher();
});

/// Controlador de acciones externas de un negocio (menú/pedidos, WhatsApp, Google Maps y contacto).
class BusinessExternalActionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> _launch(Uri? uri) async {
    if (uri == null || state) return false;
    state = true;
    try {
      final ok = await ref
          .read(businessExternalLauncherProvider)
          .launchExternalUri(uri);
      if (ref.mounted) state = false;
      return ok;
    } catch (_) {
      if (ref.mounted) state = false;
      return false;
    }
  }

  Future<bool> openOrder(BusinessDetail detail) {
    return _launch(resolveBusinessOrderUri(detail));
  }

  Future<bool> openWhatsapp(BusinessDetail detail, {String localeCode = 'es'}) {
    return _launch(resolveBusinessWhatsappUri(detail, localeCode: localeCode));
  }

  Future<bool> openDirections(BusinessDetail detail) {
    return _launch(resolveBusinessDirectionsUri(detail));
  }

  Future<bool> openCardContact(Business business, {String localeCode = 'es'}) {
    return _launch(resolveBusinessCardContactUri(business, localeCode: localeCode));
  }
}

final businessExternalActionProvider =
    NotifierProvider<BusinessExternalActionNotifier, bool>(
      BusinessExternalActionNotifier.new,
    );

/// Estado del formulario de valoración con estrellas en la ficha del negocio.
class BusinessRatingControllerState {
  const BusinessRatingControllerState({
    this.selectedStarsByBusiness = const <String, int>{},
    this.submitting = false,
    this.savedBusinessId,
    this.errorBusinessId,
    this.currentUserId,
    this.usesDemoData = true,
  });

  final Map<String, int> selectedStarsByBusiness;
  final bool submitting;
  final String? savedBusinessId;
  final String? errorBusinessId;
  final String? currentUserId;
  final bool usesDemoData;

  int? effectiveStarsFor(BusinessDetail detail) {
    return selectedStarsByBusiness[detail.id] ?? detail.myRating;
  }

  BusinessRatingEligibility eligibilityFor(BusinessDetail detail) {
    return evaluateBusinessRatingEligibility(
      currentUserId: currentUserId,
      usesDemoData: usesDemoData,
      businessOwnerId: detail.ownerId,
      isOwnerFlag: detail.isOwner,
    );
  }

  BusinessRatingControllerState copyWith({
    Map<String, int>? selectedStarsByBusiness,
    bool? submitting,
    String? savedBusinessId,
    String? errorBusinessId,
  }) {
    return BusinessRatingControllerState(
      selectedStarsByBusiness: Map.unmodifiable(
        selectedStarsByBusiness ?? this.selectedStarsByBusiness,
      ),
      submitting: submitting ?? this.submitting,
      savedBusinessId: savedBusinessId,
      errorBusinessId: errorBusinessId,
      currentUserId: currentUserId,
      usesDemoData: usesDemoData,
    );
  }
}

/// Controlador para seleccionar y guardar la valoración de 1 a 5 estrellas de un negocio.
class BusinessRatingController extends Notifier<BusinessRatingControllerState> {
  @override
  BusinessRatingControllerState build() {
    final auth = ref.watch(
      authControllerProvider.select(
        (value) => (value.session?.userId, value.usesDemoData),
      ),
    );
    return BusinessRatingControllerState(
      currentUserId: auth.$1,
      usesDemoData: auth.$2,
    );
  }

  void selectStars(String businessId, int stars) {
    if (state.submitting || !isValidBusinessStarRating(stars)) return;
    state = state.copyWith(
      selectedStarsByBusiness: {
        ...state.selectedStarsByBusiness,
        businessId: stars,
      },
    );
  }

  Future<bool> submitRating(BusinessDetail detail) async {
    if (state.submitting) return false;
    final eligibility = state.eligibilityFor(detail);
    final stars = state.effectiveStarsFor(detail);
    if (eligibility != BusinessRatingEligibility.allowed ||
        !isValidBusinessStarRating(stars)) {
      return false;
    }
    state = state.copyWith(submitting: true);
    try {
      await ref
          .read(businessRepositoryProvider)
          .rateBusiness(businessId: detail.id, stars: stars!);
      if (!ref.mounted) return true;
      state = state.copyWith(
        submitting: false,
        savedBusinessId: detail.id,
      );
      ref.invalidate(businessDetailProvider(detail.id));
      return true;
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          submitting: false,
          errorBusinessId: detail.id,
        );
      }
      return false;
    }
  }
}

final businessRatingControllerProvider =
    NotifierProvider.autoDispose<
      BusinessRatingController,
      BusinessRatingControllerState
    >(BusinessRatingController.new);
