import 'package:via_justa/core/utils/text_normalizer.dart';
import 'package:via_justa/features/businesses/domain/business.dart';

/// Tamaño de página por defecto del directorio de negocios.
const int kBusinessCatalogPageSize = 20;

/// Función pura que filtra una lista de negocios por consulta sin tildes y/o categoría.
List<Business> filterBusinesses(
  List<Business> businesses, {
  String? query,
  BusinessCategory? category,
}) {
  final normalizedQuery = normalizeForSearch(query ?? '');

  return businesses.where((business) {
    final matchesCategory = category == null || business.category == category;
    final matchesQuery =
        normalizedQuery.isEmpty ||
        normalizeForSearch(business.name).contains(normalizedQuery) ||
        normalizeForSearch(business.description).contains(normalizedQuery) ||
        normalizeForSearch(business.descriptionEs).contains(normalizedQuery) ||
        normalizeForSearch(business.descriptionEn).contains(normalizedQuery) ||
        normalizeForSearch(business.address).contains(normalizedQuery);

    return matchesCategory && matchesQuery;
  }).toList();
}

/// Función pura que aplica ventana de paginación (`offset` y `limit`) sobre la lista.
List<Business> paginateBusinesses(
  List<Business> businesses, {
  int limit = kBusinessCatalogPageSize,
  int offset = 0,
}) {
  final safeOffset = offset < 0 ? 0 : offset;
  final safeLimit = limit < 1 ? 1 : limit;
  if (safeOffset >= businesses.length) return const <Business>[];
  final end = (safeOffset + safeLimit).clamp(0, businesses.length);
  return businesses.sublist(safeOffset, end);
}

/// Indica si puede solicitarse una página adicional según los resultados actuales.
bool canLoadMoreBusinesses({
  required int currentCount,
  required int currentLimit,
}) {
  return currentLimit > 0 && currentCount >= currentLimit;
}

/// Combina una página recién recibida con la lista acumulada sin duplicar identificadores.
({List<Business> items, int addedCount}) mergeBusinessPage(
  List<Business> currentItems,
  List<Business> nextPage,
) {
  if (nextPage.isEmpty) {
    return (items: currentItems, addedCount: 0);
  }
  final seenIds = <String>{
    for (final item in currentItems) item.id,
  };
  final merged = List<Business>.of(currentItems);
  var added = 0;
  for (final item in nextPage) {
    if (seenIds.add(item.id)) {
      merged.add(item);
      added++;
    }
  }
  return (items: List<Business>.unmodifiable(merged), addedCount: added);
}
