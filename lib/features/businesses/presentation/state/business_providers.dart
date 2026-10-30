import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/businesses/data/local_business_repository.dart';
import 'package:via_justa/features/businesses/data/supabase_business_repository.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_filter.dart';
import 'package:via_justa/features/businesses/domain/business_repository.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';

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
final filteredBusinessesProvider =
    Provider<AsyncValue<List<Business>>>((ref) {
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
