import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';

/// Escenarios rápidos de demostración para probar los 4 estados del semáforo y alertas por zona.
enum DemoPriceScenario {
  /// Precio dentro del rango justo en la zona (verde)
  greenFair,

  /// Precio moderadamente por encima de la mediana de la zona (ámbar)
  yellowModerate,

  /// Precio con sobrecobro significativo en la zona (rojo)
  redOvercharge,

  /// Categoría con menos de 3 reportes comunitarios en la zona (gris neutro M20)
  insufficientSample,

  /// Precio más de 40% por debajo de la mediana de la zona (verde con advertencia de precio bajo)
  lowPriceAlert,
}

/// Contrato abstracto para la evaluación del semáforo de precios segmentado por zonas del municipio.
/// En VJ-04 utiliza fixtures DEMO; en VJ-10 se reemplaza por llamadas RPC a `calculate_price_verdict` en Supabase.
abstract class PriceVerdictRepository {
  /// Obtiene las zonas activas de un municipio para segmentar las medianas (ej. Norte, Centro, Sur, Oriente, Occidente en Valledupar).
  Future<List<MunicipalityZone>> getZones({String municipalityCode = '20001'});

  /// Detecta automáticamente la zona actual del usuario mediante la ubicación del teléfono (GPS).
  Future<MunicipalityZone> detectCurrentZoneByGps({
    String municipalityCode = '20001',
  });

  /// Obtiene las categorías comparables activas (`public.price_categories`).
  Future<List<PriceCategory>> getCategories();

  /// Evalúa un monto observado para una categoría, municipio y zona específica.
  Future<PriceVerdict> evaluatePrice({
    required String categoryId,
    required String municipalityCode,
    String zoneId = 'vup_centro',
    required int submittedCop,
    bool includeEventContext = false,
  });

  /// Retorna una fixture explícita de demostración para el escenario solicitado.
  Future<PriceVerdict> getScenarioFixture(
    DemoPriceScenario scenario, {
    String municipalityCode = '20001',
    String? zoneId,
    bool includeEventContext = false,
  });
}
