import 'package:via_justa/features/businesses/domain/business.dart';

/// Función pura que filtra una lista de negocios por consulta textual y/o categoría.
List<Business> filterBusinesses(
  List<Business> businesses, {
  String? query,
  BusinessCategory? category,
}) {
  final cleanQuery = query?.trim().toLowerCase() ?? '';

  return businesses.where((business) {
    final matchesCategory =
        category == null || business.category == category;
    final matchesQuery = cleanQuery.isEmpty ||
        business.name.toLowerCase().contains(cleanQuery) ||
        business.description.toLowerCase().contains(cleanQuery) ||
        business.address.toLowerCase().contains(cleanQuery);

    return matchesCategory && matchesQuery;
  }).toList();
}
