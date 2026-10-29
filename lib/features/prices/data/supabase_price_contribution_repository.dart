import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/prices/data/demo_price_contribution_repository.dart';
import 'package:via_justa/features/prices/domain/price_contribution.dart';
import 'package:via_justa/features/prices/domain/price_contribution_repository.dart';

/// Repositorio conectado a Supabase para enviar reportes reales de precios (`public.submit_price_report`).
/// Si no hay sesión autenticada activa, delega de forma segura al repositorio en memoria DEMO.
class SupabasePriceContributionRepository
    implements PriceContributionRepository {
  SupabasePriceContributionRepository({
    required SupabaseClient client,
    DemoPriceContributionRepository? fallback,
  }) : _client = client,
       _fallback = fallback ?? DemoPriceContributionRepository();

  final SupabaseClient _client;
  final DemoPriceContributionRepository _fallback;

  static (double, double) _coordinatesForZone(String zoneId) {
    switch (zoneId) {
      case 'vup_norte':
        return (10.4885, -73.2535);
      case 'vup_sur':
        return (10.4452, -73.2468);
      case 'vup_oriente':
        return (10.4980, -73.2610);
      case 'vup_occidente':
        return (10.4680, -73.2785);
      case 'vup_centro':
      default:
        return (10.4742, -73.2436);
    }
  }

  @override
  Future<PriceContributionRecord> submitContribution({
    required String categoryId,
    required String municipalityCode,
    required String zoneId,
    required int amountCop,
    String? placeNote,
  }) async {
    final sanitized = sanitizeContributionNote(placeNote ?? '');
    if (_client.auth.currentSession == null) {
      return _fallback.submitContribution(
        categoryId: categoryId,
        municipalityCode: municipalityCode,
        zoneId: zoneId,
        amountCop: amountCop,
        placeNote: sanitized,
      );
    }

    final (lat, lng) = _coordinatesForZone(zoneId);
    final dynamic response = await _client.rpc(
      'submit_price_report',
      params: <String, dynamic>{
        'p_category_id': categoryId,
        'p_municipality_code': municipalityCode,
        'p_zone_id': zoneId,
        'p_amount_cop': amountCop,
        'p_latitude': lat,
        'p_longitude': lng,
        'p_place_name': sanitized,
        'p_source_note': sanitized,
      },
    );

    final map = response is Map<String, dynamic>
        ? response
        : <String, dynamic>{};

    final record = PriceContributionRecord(
      id: (map['id'] ?? DateTime.now().millisecondsSinceEpoch).toString(),
      categoryId: categoryId,
      municipalityCode: municipalityCode,
      zoneId: zoneId,
      amountCop: amountCop,
      placeNote: sanitized,
      createdAtIso:
          (map['created_at'] as String?) ??
          DateTime.now().toUtc().toIso8601String(),
      isDemo: false,
    );
    return record;
  }

  @override
  Future<List<PriceContributionRecord>> getSubmittedContributions() {
    return _fallback.getSubmittedContributions();
  }

  @override
  void clearSessionContributions() {
    _fallback.clearSessionContributions();
  }
}
