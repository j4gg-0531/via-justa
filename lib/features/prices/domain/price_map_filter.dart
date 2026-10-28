import 'package:via_justa/core/utils/text_normalizer.dart';
import 'package:via_justa/features/prices/domain/price_map_item.dart';

/// Función pura que filtra los elementos del mapa local (M08) por categoría y búsqueda sin tildes.
List<PriceMapItem> filterPriceMapItems(
  List<PriceMapItem> items, {
  PriceMapCategory? category,
  String? query,
}) {
  final normalizedQuery = normalizeForSearch(query ?? '');

  return items.where((item) {
    final matchesCategory = category == null || item.category == category;
    final matchesQuery = normalizedQuery.isEmpty ||
        normalizeForSearch(item.name).contains(normalizedQuery) ||
        normalizeForSearch(item.description).contains(normalizedQuery) ||
        normalizeForSearch(item.pinLabel).contains(normalizedQuery) ||
        normalizeForSearch(item.badgeText).contains(normalizedQuery);

    return matchesCategory && matchesQuery;
  }).toList();
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
