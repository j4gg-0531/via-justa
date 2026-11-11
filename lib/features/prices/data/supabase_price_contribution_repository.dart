import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/prices/domain/price_contribution.dart';
import 'package:via_justa/features/prices/domain/price_contribution_repository.dart';

/// Implementación de [PriceContributionRepository] que registra aportes ciudadanos
/// reales mediante la función RPC `submit_price_report` en Supabase (VJ-11 / Paso 2).
///
/// No realiza fallback silencioso a datos falsos: cualquier error de red, cuota
/// o validación en base de datos se propaga para mostrarse en la interfaz.
class SupabasePriceContributionRepository
    implements PriceContributionRepository {
  SupabasePriceContributionRepository(this._client);

  final SupabaseClient _client;
  final List<PriceContributionRecord> _cachedContributions = [];

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
    String? destinationZoneId,
    double? originLatitude,
    double? originLongitude,
    double? destinationLatitude,
    double? destinationLongitude,
  }) async {
    final sanitizedNote =
        placeNote != null ? sanitizeContributionNote(placeNote) : null;
    final (defaultLat, defaultLng) = _coordinatesForZone(zoneId);
    final effectiveOrigLat = originLatitude ?? defaultLat;
    final effectiveOrigLng = originLongitude ?? defaultLng;

    final hasDestination =
        (destinationZoneId != null && destinationZoneId.trim().isNotEmpty) ||
        (destinationLatitude != null && destinationLongitude != null);

    final baseParams = <String, dynamic>{
      'p_category_id': categoryId,
      'p_municipality_code': municipalityCode,
      'p_zone_id': zoneId,
      'p_amount_cop': amountCop,
      'p_place_name': ?sanitizedNote,
      'p_latitude': effectiveOrigLat,
      'p_longitude': effectiveOrigLng,
    };

    final Map<String, dynamic> rpcParams = hasDestination
        ? <String, dynamic>{
            'p_category_id': categoryId,
            'p_municipality_code': municipalityCode,
            'p_zone_id': zoneId,
            'p_amount_cop': amountCop,
            'p_place_name': sanitizedNote,
            'p_source_note': sanitizedNote,
            'p_latitude': effectiveOrigLat,
            'p_longitude': effectiveOrigLng,
            'p_destination_zone_id': destinationZoneId,
            'p_destination_latitude': destinationLatitude,
            'p_destination_longitude': destinationLongitude,
          }
        : baseParams;

    dynamic response;
    try {
      response = await _client.rpc(
        'submit_price_report',
        params: rpcParams,
      );
    } on PostgrestException catch (error) {
      final isMissingOverload = error.code == 'PGRST202' ||
          error.message.contains('submit_price_report');
      if (hasDestination && isMissingOverload) {
        response = await _client.rpc(
          'submit_price_report',
          params: baseParams,
        );
      } else {
        rethrow;
      }
    }

    final map = Map<String, dynamic>.from(response as Map);
    final record = PriceContributionRecord(
      id: map['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      categoryId: map['category_id'] as String? ?? categoryId,
      municipalityCode: map['municipality_code'] as String? ?? municipalityCode,
      zoneId: map['zone_id'] as String? ?? zoneId,
      destinationZoneId:
          map['destination_zone_id'] as String? ?? destinationZoneId,
      originLatitude: effectiveOrigLat,
      originLongitude: effectiveOrigLng,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      distanceKm: (map['distance_km'] as num?)?.toDouble(),
      distanceRange: map['distance_range'] as String?,
      amountCop: map['amount_cop'] as int? ?? amountCop,
      placeNote: map['place_name'] as String? ?? sanitizedNote,
      createdAtIso:
          map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      isDemo: map['is_demo'] as bool? ?? false,
    );

    _cachedContributions.insert(0, record);
    return record;
  }

  @override
  Future<List<PriceContributionRecord>> getSubmittedContributions() async {
    if (_cachedContributions.isNotEmpty) {
      return List.unmodifiable(_cachedContributions);
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const [];
    }

    final response = await _client
        .from('price_reports')
        .select(
          'id, category_id, municipality_code, zone_id, destination_zone_id, distance_km, distance_range, amount_cop, place_name, created_at, is_demo',
        )
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
        destinationZoneId: map['destination_zone_id'] as String?,
        distanceKm: (map['distance_km'] as num?)?.toDouble(),
        distanceRange: map['distance_range'] as String?,
        amountCop: map['amount_cop'] as int? ?? 0,
        placeNote: map['place_name'] as String?,
        createdAtIso: map['created_at']?.toString() ?? '',
        isDemo: map['is_demo'] as bool? ?? false,
      );
    }).toList();

    _cachedContributions.addAll(remoteList);
    return List.unmodifiable(_cachedContributions);
  }

  @override
  void clearSessionContributions() {
    _cachedContributions.clear();
  }
}
