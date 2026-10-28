import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/prices/data/local_price_map_repository.dart';
import 'package:via_justa/features/prices/domain/price_map_filter.dart';
import 'package:via_justa/features/prices/domain/price_map_item.dart';
import 'package:via_justa/features/prices/domain/price_map_repository.dart';

/// Provider del repositorio del mapa de precios y servicios (M08).
final priceMapRepositoryProvider = Provider<PriceMapRepository>((ref) {
  return const LocalPriceMapRepository();
});

/// Notifier para la categoría activa en el filtro del mapa local.
class PriceMapCategoryNotifier extends Notifier<PriceMapCategory?> {
  @override
  PriceMapCategory? build() => null;

  void selectCategory(PriceMapCategory? category) {
    state = category;
  }

  /// Alterna una categoría: si ya estaba seleccionada, vuelve a mostrar todas (`null`).
  void toggleCategory(PriceMapCategory category) {
    state = state == category ? null : category;
  }

  void clear() {
    state = null;
  }
}

/// Provider de la categoría activa en el mapa local (`Precios`, `Servicios`, `Consulados` o `null`).
final priceMapCategoryProvider =
    NotifierProvider<PriceMapCategoryNotifier, PriceMapCategory?>(
  PriceMapCategoryNotifier.new,
);

/// Notifier para el texto de búsqueda en el mapa local.
class PriceMapSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

/// Provider de la consulta de búsqueda en el mapa local.
final priceMapSearchQueryProvider =
    NotifierProvider<PriceMapSearchQueryNotifier, String>(
  PriceMapSearchQueryNotifier.new,
);

/// Provider que carga los puntos del mapa local para el municipio seleccionado.
final allPriceMapItemsProvider = FutureProvider<List<PriceMapItem>>((ref) async {
  final repository = ref.watch(priceMapRepositoryProvider);
  final municipality = ref.watch(selectedMunicipalityProvider);
  final code = municipality?.code ?? '20001';
  return repository.getMapItems(municipalityCode: code);
});

/// Provider que devuelve los puntos filtrados por categoría y texto mediante la función pura de dominio.
final filteredPriceMapItemsProvider =
    Provider<AsyncValue<List<PriceMapItem>>>((ref) {
  final itemsAsync = ref.watch(allPriceMapItemsProvider);
  final category = ref.watch(priceMapCategoryProvider);
  final query = ref.watch(priceMapSearchQueryProvider);

  return itemsAsync.whenData((items) {
    return filterPriceMapItems(
      items,
      category: category,
      query: query,
    );
  });
});

/// Provider de la clave de traducción para el título de la hoja inferior del mapa.
final priceMapSectionTitleKeyProvider = Provider<String>((ref) {
  final category = ref.watch(priceMapCategoryProvider);
  return sectionTitleKeyForMapCategory(category);
});
