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

/// Resultado inmutable de separar los comercios propios del usuario del resto del directorio.
class PartitionedBusinesses {
  const PartitionedBusinesses({
    this.owned = const <Business>[],
    this.others = const <Business>[],
  });

  final List<Business> owned;
  final List<Business> others;

  bool get isEmpty => owned.isEmpty && others.isEmpty;
  bool get hasOwned => owned.isNotEmpty;
  bool get hasOthers => others.isNotEmpty;
}

/// Función pura que separa los negocios propios (incluyendo los que caen fuera de la primera página)
/// del resto del directorio, sin duplicados y respetando búsqueda, categoría y municipio activo.
PartitionedBusinesses partitionOwnedBusinesses({
  required List<Business> catalog,
  List<Business> ownedBusinesses = const <Business>[],
  String? currentOwnerId,
  String? municipalityCode,
  String? query,
  BusinessCategory? category,
}) {
  final filteredCatalog = filterBusinesses(
    catalog,
    query: query,
    category: category,
  );
  final cleanOwnerId = currentOwnerId?.trim() ?? '';
  if (cleanOwnerId.isEmpty) {
    return PartitionedBusinesses(
      others: List<Business>.unmodifiable(filteredCatalog),
    );
  }

  // Preferimos los registros del catálogo cuando ya están cargados porque incluyen
  // metadatos completos (precio mínimo de platos, descripciones bilingües).
  final ownedById = <String, Business>{};
  for (final item in catalog) {
    if (item.ownerId == cleanOwnerId && item.isApproved) {
      ownedById[item.id] = item;
    }
  }
  for (final item in ownedBusinesses) {
    if (!item.isApproved) continue;
    if (municipalityCode != null &&
        municipalityCode.isNotEmpty &&
        item.municipalityCode != municipalityCode) {
      continue;
    }
    ownedById.putIfAbsent(item.id, () => item);
  }

  final filteredOwned = filterBusinesses(
    ownedById.values.toList(),
    query: query,
    category: category,
  );
  final ownedIds = <String>{for (final item in ownedById.values) item.id};
  final others = filteredCatalog
      .where((item) => !ownedIds.contains(item.id))
      .toList();

  return PartitionedBusinesses(
    owned: List<Business>.unmodifiable(filteredOwned),
    others: List<Business>.unmodifiable(others),
  );
}

/// Regla pura: el acceso "Mis negocios" en Perfil solo aparece si el usuario tiene al menos
/// un negocio registrado o seleccionó el perfil Residente/Local.
bool shouldShowMyBusinessesInProfile({
  required int ownedCount,
  required bool isResidentProfile,
}) {
  return ownedCount > 0 || isResidentProfile;
}
