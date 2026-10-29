import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/prices/data/demo_price_contribution_repository.dart';
import 'package:via_justa/features/prices/domain/price_contribution.dart';
import 'package:via_justa/features/prices/domain/price_contribution_repository.dart';

/// Implementación de [PriceContributionRepository] que registra aportes ciudadanos
/// reales mediante la función RPC `submit_price_report` en Supabase (VJ-11).
class SupabasePriceContributionRepository implements PriceContributionRepository {
  SupabasePriceContributionRepository(
    this._client, {
    PriceContributionRepository? fallback,
  }) : _fallback = fallback ?? DemoPriceContributionRepository();

  final SupabaseClient _client;
  final PriceContributionRepository _fallback;
  final List<PriceContributionRecord> _cachedContributions = [];

  @override
  Future<PriceContributionRecord> submitContribution({
    required String categoryId,
    required String municipalityCode,
    required String zoneId,
    required int amountCop,
    String? placeNote,
  }) async {
    try {
      final sanitizedNote = placeNote != null ? sanitizeContributionNote(placeNote) : null;
      final response = await _client.rpc(
        'submit_price_report',
        params: {
          'p_category_id': categoryId,
          'p_municipality_code': municipalityCode,
          'p_zone_id': zoneId,
          'p_amount_cop': amountCop,
          'p_place_name': ?sanitizedNote,
        },
      );

      final map = Map<String, dynamic>.from(response as Map);
      final record = PriceContributionRecord(
        id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        categoryId: map['category_id'] as String? ?? categoryId,
        municipalityCode: map['municipality_code'] as String? ?? municipalityCode,
        zoneId: map['zone_id'] as String? ?? zoneId,
        amountCop: map['amount_cop'] as int? ?? amountCop,
        placeNote: map['place_name'] as String? ?? sanitizedNote,
        createdAtIso: map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        isDemo: map['is_demo'] as bool? ?? false,
      );

      _cachedContributions.insert(0, record);
      return record;
    } catch (_) {
      final fallbackRecord = await _fallback.submitContribution(
        categoryId: categoryId,
        municipalityCode: municipalityCode,
        zoneId: zoneId,
        amountCop: amountCop,
        placeNote: placeNote,
      );
      _cachedContributions.insert(0, fallbackRecord);
      return fallbackRecord;
    }
  }

  @override
  Future<List<PriceContributionRecord>> getSubmittedContributions() async {
    if (_cachedContributions.isNotEmpty) {
      return List.unmodifiable(_cachedContributions);
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return await _fallback.getSubmittedContributions();
    }

    try {
      final response = await _client
          .from('price_reports')
          .select('id, category_id, municipality_code, zone_id, amount_cop, place_name, created_at, is_demo')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      final remoteList = (response as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        return PriceContributionRecord(
          id: map['id']?.toString() ?? '',
          categoryId: map['category_id'] as String? ?? '',
          municipalityCode: map['municipality_code'] as String? ?? '',
          zoneId: map['zone_id'] as String? ?? '',
          amountCop: map['amount_cop'] as int? ?? 0,
          placeNote: map['place_name'] as String?,
          createdAtIso: map['created_at']?.toString() ?? '',
          isDemo: map['is_demo'] as bool? ?? false,
        );
      }).toList();

      _cachedContributions.addAll(remoteList);
      return List.unmodifiable(_cachedContributions);
    } catch (_) {
      return await _fallback.getSubmittedContributions();
    }
  }

  @override
  void clearSessionContributions() {
    _cachedContributions.clear();
    _fallback.clearSessionContributions();
  }
}
