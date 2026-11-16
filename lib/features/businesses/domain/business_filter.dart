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
