import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_detail.dart';
import 'package:via_justa/features/businesses/domain/business_filter.dart';
import 'package:via_justa/features/businesses/domain/business_rating.dart';

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

  /// Obtiene la ficha completa de un comercio publicado por su identificador.
  Future<BusinessDetail> getBusinessDetail(
    String businessId, {
    String localeCode = 'es',
  });

  /// Registra o modifica la valoración de 1 a 5 estrellas del usuario autenticado.
  Future<BusinessRatingSummary> rateBusiness({
    required String businessId,
    required int stars,
  });

  /// Obtiene todos los comercios registrados por el usuario autenticado (todos los estados).
  Future<List<Business>> getMyBusinesses();
}
