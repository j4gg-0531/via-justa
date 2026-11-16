import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_filter.dart';

/// Interfaz abstracta del repositorio de negocios.
abstract interface class BusinessRepository {
  /// Obtiene la lista paginada y filtrada de comercios publicados para el municipio.
  Future<List<Business>> getBusinesses({
    BusinessCategory? category,
    String? searchQuery,
    String localeCode = 'es',
    int limit = kBusinessCatalogPageSize,
    int offset = 0,
  });
}
