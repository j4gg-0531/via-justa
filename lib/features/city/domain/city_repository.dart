import 'package:via_justa/features/city/domain/city_overview.dart';

/// Tipos de error controlados al cargar la ficha cultural y los eventos.
enum CityLoadErrorKind {
  /// El municipio existe en DIVIPOLA pero aún no es piloto.
  notPilot,

  /// El código DIVIPOLA no existe en el catálogo oficial.
  notFound,

  /// Fallo de red o tiempo de espera agotado al consultar el servidor.
  network,

  /// Error inesperado de backend o de formato de respuesta.
  unknown,
}

/// Excepción de dominio tipada para fallos de carga en `CityRepository`.
class CityLoadException implements Exception {
  const CityLoadException(this.kind, [this.message = '']);

  final CityLoadErrorKind kind;
  final String message;

  @override
  String toString() => 'CityLoadException($kind, $message)';
}

/// Contrato abstracto para consultar el panorama cultural y los eventos de un municipio.
abstract interface class CityRepository {
  /// Obtiene la ficha cultural curada y los eventos de un municipio piloto.
  Future<CityOverview> getCityOverview({
    required String municipalityCode,
    required String localeCode,
    bool includeDemo = false,
  });

  /// Obtiene el estado temporal de los eventos de un municipio piloto.
  Future<List<CityEvent>> getCityEvents({
    required String municipalityCode,
    bool includeDemo = false,
  });
}
