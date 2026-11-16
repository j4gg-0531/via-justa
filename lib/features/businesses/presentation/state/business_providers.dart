import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/businesses/data/local_business_repository.dart';
import 'package:via_justa/features/businesses/data/supabase_business_repository.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
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

/// Notifier para la categoría seleccionada en el filtro.
class BusinessCategoryNotifier extends Notifier<BusinessCategory?> {
  @override
  BusinessCategory? build() => null;

  void selectCategory(BusinessCategory? category) {
    state = category;
  }

  void clear() {
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
    state = query;
  }

  void clear() {
    state = '';
  }
}

/// Provider de la consulta de texto para filtrar negocios.
final businessSearchQueryProvider =
    NotifierProvider<BusinessSearchQueryNotifier, String>(
      BusinessSearchQueryNotifier.new,
    );

/// Provider que carga la lista completa de comercios desde el repositorio.
final allBusinessesProvider = FutureProvider<List<Business>>((ref) async {
  final repository = ref.watch(businessRepositoryProvider);
  return repository.getBusinesses();
});

/// Provider que combina la lista, la consulta y la categoría mediante la función pura de dominio.
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
