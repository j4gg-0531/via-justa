import 'package:via_justa/features/businesses/domain/business.dart';

/// Interfaz abstracta del repositorio de negocios.
abstract interface class BusinessRepository {
  /// Obtiene la lista de comercios registrados para el piloto.
  Future<List<Business>> getBusinesses();
}
