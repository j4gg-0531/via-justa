import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/prices/data/demo_price_verdict_repository.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';
import 'package:via_justa/features/prices/domain/price_verdict_repository.dart';

/// Implementación de [PriceVerdictRepository] que consulta la función SQL
/// `calculate_price_verdict` y los catálogos oficiales en Supabase (VJ-10 / VJ-11).
///
/// Dispone de un [fallback] hacia [DemoPriceVerdictRepository] para mantener
/// la funcionalidad ante pérdida de red o ausencia de credenciales compiladas.
class SupabasePriceVerdictRepository implements PriceVerdictRepository {
  SupabasePriceVerdictRepository(
    this._client, {
    PriceVerdictRepository? fallback,
  }) : _fallback = fallback ?? const DemoPriceVerdictRepository();

  final SupabaseClient _client;
  final PriceVerdictRepository _fallback;

  @override
  Future<List<MunicipalityZone>> getZones({
    String municipalityCode = '20001',
  }) async {
    try {
      final response = await _client
          .from('municipality_zones')
          .select('id, municipality_code, name_es, name_en, sector_hint_es, sector_hint_en, normalized_x, normalized_y, sort_order')
          .eq('municipality_code', municipalityCode)
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final list = (response as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        return MunicipalityZone(
          id: map['id'] as String,
          municipalityCode: map['municipality_code'] as String,
          nameEs: map['name_es'] as String,
          nameEn: map['name_en'] as String,
          sectorHintEs: map['sector_hint_es'] as String? ?? '',
          sectorHintEn: map['sector_hint_en'] as String? ?? '',
          normalizedX: (map['normalized_x'] as num?)?.toDouble() ?? 0.5,
          normalizedY: (map['normalized_y'] as num?)?.toDouble() ?? 0.5,
          sortOrder: map['sort_order'] as int? ?? 0,
        );
      }).toList();

      if (list.isEmpty) {
        return await _fallback.getZones(municipalityCode: municipalityCode);
      }
      return list;
    } catch (_) {
      return await _fallback.getZones(municipalityCode: municipalityCode);
    }
  }

  @override
  Future<MunicipalityZone> detectCurrentZoneByGps({
    String municipalityCode = '20001',
  }) async {
    return await _fallback.detectCurrentZoneByGps(
      municipalityCode: municipalityCode,
    );
  }

  @override
  Future<List<PriceCategory>> getCategories() async {
    try {
      final response = await _client
          .from('price_categories')
          .select('id, group_key, name_es, name_en, unit_description_es, unit_description_en, sort_order')
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
        return await _fallback.getCategories();
      }
      return list;
    } catch (_) {
      return await _fallback.getCategories();
    }
  }

  @override
  Future<PriceVerdict> evaluatePrice({
    required String categoryId,
    required String municipalityCode,
    String zoneId = 'vup_centro',
    required int submittedCop,
    bool includeEventContext = false,
  }) async {
    try {
      final response = await _client.rpc(
        'calculate_price_verdict',
        params: {
          'p_category_id': categoryId,
          'p_municipality_code': municipalityCode,
          'p_zone_id': zoneId,
          'p_amount_cop': submittedCop,
        },
      );

      final map = Map<String, dynamic>.from(response as Map);
      return PriceVerdict.fromMap(
        map,
        categoryId: categoryId,
        municipalityCode: municipalityCode,
        zoneId: zoneId,
      );
    } catch (_) {
      return await _fallback.evaluatePrice(
        categoryId: categoryId,
        municipalityCode: municipalityCode,
        zoneId: zoneId,
        submittedCop: submittedCop,
        includeEventContext: includeEventContext,
      );
    }
  }

  @override
  Future<PriceVerdict> getScenarioFixture(
    DemoPriceScenario scenario, {
    String municipalityCode = '20001',
    String? zoneId,
    bool includeEventContext = false,
  }) async {
    return await _fallback.getScenarioFixture(
      scenario,
      municipalityCode: municipalityCode,
      zoneId: zoneId,
      includeEventContext: includeEventContext,
    );
  }
}
