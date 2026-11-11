import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';
import 'package:via_justa/features/prices/domain/price_verdict_repository.dart';

/// Implementación de [PriceVerdictRepository] que consulta la función SQL
/// `calculate_price_verdict` y los catálogos oficiales en Supabase (VJ-10 / VJ-11 / Paso 2).
///
/// Cuando el cliente de Supabase está activo, nunca oculta errores devolviendo
/// datos de prueba: si la red o la RPC fallan, la excepción se propaga para que
/// la interfaz muestre el estado de error con acción de reintento.
class SupabasePriceVerdictRepository implements PriceVerdictRepository {
  const SupabasePriceVerdictRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<MunicipalityZone>> getZones({
    String municipalityCode = '20001',
  }) async {
    final response = await _client
        .from('municipality_zones')
        .select(
          'id, municipality_code, name_es, name_en, sector_hint_es, sector_hint_en, normalized_x, normalized_y, center_lat, center_lng, sort_order',
        )
        .eq('municipality_code', municipalityCode)
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    final list = (response as List<dynamic>).map((row) {
      final map = row as Map<String, dynamic>;
      return MunicipalityZone.fromMap(map);
    }).toList();

    if (list.isEmpty) {
      throw StateError(
        'No se encontraron zonas activas para el municipio $municipalityCode.',
      );
    }
    return list;
  }

  @override
  Future<MunicipalityZone> detectCurrentZoneByGps({
    String municipalityCode = '20001',
  }) async {
    final zones = await getZones(municipalityCode: municipalityCode);
    for (final zone in zones) {
      if (zone.id == 'vup_centro') {
        return zone;
      }
    }
    return zones.first;
  }

  @override
  Future<List<PriceCategory>> getCategories() async {
    final response = await _client
        .from('price_categories')
        .select(
          'id, group_key, name_es, name_en, unit_description_es, unit_description_en, sort_order',
        )
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    final list = (response as List<dynamic>).map((row) {
      final map = row as Map<String, dynamic>;
      return PriceCategory(
        id: map['id'] as String,
        groupKey: map['group_key'] as String? ?? 'general',
        nameEs: map['name_es'] as String,
        nameEn: map['name_en'] as String,
        unitDescriptionEs: map['unit_description_es'] as String? ?? '',
        unitDescriptionEn: map['unit_description_en'] as String? ?? '',
        sortOrder: map['sort_order'] as int? ?? 0,
      );
    }).toList();

    if (list.isEmpty) {
      throw StateError('No se encontraron categorías activas en Supabase.');
    }
    return list;
  }

  @override
  Future<PriceVerdict> evaluatePrice({
    required String categoryId,
    required String municipalityCode,
    String zoneId = 'vup_centro',
    String? destinationZoneId,
    double? originLatitude,
    double? originLongitude,
    double? destinationLatitude,
    double? destinationLongitude,
    required int submittedCop,
    bool includeEventContext = false,
  }) async {
    final hasDestination =
        (destinationZoneId != null && destinationZoneId.trim().isNotEmpty) ||
        (destinationLatitude != null && destinationLongitude != null);

    final baseParams = <String, dynamic>{
      'p_category_id': categoryId,
      'p_municipality_code': municipalityCode,
      'p_zone_id': zoneId,
      'p_amount_cop': submittedCop,
    };

    final Map<String, dynamic> rpcParams = hasDestination
        ? <String, dynamic>{
            ...baseParams,
            'p_destination_zone_id': destinationZoneId,
            'p_origin_lat': originLatitude,
            'p_origin_lng': originLongitude,
            'p_destination_lat': destinationLatitude,
            'p_destination_lng': destinationLongitude,
          }
        : baseParams;

    dynamic response;
    try {
      response = await _client.rpc(
        'calculate_price_verdict',
        params: rpcParams,
      );
    } on PostgrestException catch (error) {
      final isMissingOverload = error.code == 'PGRST202' ||
          error.message.contains('calculate_price_verdict');
      if (hasDestination && isMissingOverload) {
        response = await _client.rpc(
          'calculate_price_verdict',
          params: baseParams,
        );
      } else {
        rethrow;
      }
    }

    final map = Map<String, dynamic>.from(response as Map);
    if (destinationZoneId != null && map['destination_zone_id'] == null) {
      map['destination_zone_id'] = destinationZoneId;
    }
    return PriceVerdict.fromMap(
      map,
      categoryId: categoryId,
      municipalityCode: municipalityCode,
      zoneId: zoneId,
    );
  }

  @override
  Future<PriceVerdict> getScenarioFixture(
    DemoPriceScenario scenario, {
    String municipalityCode = '20001',
    String? zoneId,
    bool includeEventContext = false,
  }) {
    throw UnsupportedError(
      'Los escenarios DEMO no están disponibles cuando se usa Supabase real.',
    );
  }
}
