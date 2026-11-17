import 'package:via_justa/core/utils/text_normalizer.dart';
import 'package:via_justa/features/prices/domain/price_map_item.dart';

bool _matchesMapSearchQuery(PriceMapItem item, String normalizedQuery) {
  if (normalizedQuery.isEmpty) return true;
  return normalizeForSearch(item.name).contains(normalizedQuery) ||
      normalizeForSearch(item.description).contains(normalizedQuery) ||
      normalizeForSearch(item.pinLabel).contains(normalizedQuery) ||
      normalizeForSearch(item.badgeText).contains(normalizedQuery);
}

/// Determina si un elemento del mapa es un lugar persistente (negocio, servicio, salud o consulado),
/// excluyendo reportes ciudadanos individuales de precio.
bool isPlaceMapItem(PriceMapItem item) =>
    item.sourceType == 'business' || item.category != PriceMapCategory.prices;

/// Función pura que filtra los elementos del mapa local (M08) por categoría y búsqueda sin tildes.
List<PriceMapItem> filterPriceMapItems(
  List<PriceMapItem> items, {
  PriceMapCategory? category,
  String? query,
}) {
  final normalizedQuery = normalizeForSearch(query ?? '');

  return items.where((item) {
    if (item.sourceType == 'business' && item.isDemo) {
      return false;
    }
    final matchesCategory = category == null || item.category == category;
    return matchesCategory && _matchesMapSearchQuery(item, normalizedQuery);
  }).toList();
}

/// Filtra los elementos visibles en la hoja inferior del mapa para listar únicamente
/// negocios, servicios y puntos institucionales (sin reportes históricos sueltos).
List<PriceMapItem> filterSheetPlaceItems(
  List<PriceMapItem> items, {
  PriceMapCategory? category,
  String? query,
  String? prioritizedId,
}) {
  final normalizedQuery = normalizeForSearch(query ?? '');

  final filtered = items.where((item) {
    if (item.sourceType == 'business' && item.isDemo) {
      return false;
    }
    if (!isPlaceMapItem(item)) {
      return false;
    }
    final matchesCategory =
        (category == PriceMapCategory.services ||
                category == PriceMapCategory.consulates)
            ? item.category == category
            : true;
    return matchesCategory && _matchesMapSearchQuery(item, normalizedQuery);
  }).toList();

  if (prioritizedId == null || prioritizedId.isEmpty) {
    return filtered;
  }
  final targetIndex = filtered.indexWhere((item) => item.id == prioritizedId);
  if (targetIndex <= 0) {
    return filtered;
  }
  final prioritized = filtered.removeAt(targetIndex);
  filtered.insert(0, prioritized);
  return filtered;
}

/// Busca un elemento por su identificador en la lista de lugares sin exponer lógica de búsqueda en la vista.
PriceMapItem? findMapItemById(List<PriceMapItem> items, String? id) {
  if (id == null || id.isEmpty) return null;
  for (final item in items) {
    if (item.id == id) return item;
  }
  return null;
}

/// Devuelve la clave de traducción del encabezado inferior según la categoría activa.
String sectionTitleKeyForMapCategory(PriceMapCategory? category) {
  switch (category) {
    case PriceMapCategory.prices:
      return 'price_map.section_prices';
    case PriceMapCategory.services:
      return 'price_map.section_services';
    case PriceMapCategory.consulates:
      return 'price_map.section_consulates';
    case null:
      return 'price_map.section_all';
  }
}
