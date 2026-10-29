import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/prices/data/local_price_map_repository.dart';
import 'package:via_justa/features/prices/domain/price_map_item.dart';
import 'package:via_justa/features/prices/domain/price_map_repository.dart';

/// Repositorio conectado a Supabase que consulta `public.get_municipality_map_items` (VJ-12).
/// Combina en tiempo real:
///   1) Reportes de precios (`public.price_reports`) con coordenadas redondeadas a 3 decimales y veredicto.
///   2) Negocios y servicios aprobados (`public.businesses` con `status = 'approved'`).
class SupabasePriceMapRepository implements PriceMapRepository {
  const SupabasePriceMapRepository({
    required SupabaseClient client,
    this.includeDemo = true,
    this.bounds,
    this.localeCode = 'es',
    this.fallbackRepository = const LocalPriceMapRepository(),
  }) : _client = client;

  final SupabaseClient _client;
  final bool includeDemo;
  final MapViewportBounds? bounds;
  final String localeCode;
  final PriceMapRepository fallbackRepository;

  static PriceMapCategory _parseCategory(String? raw) {
    switch (raw) {
      case 'prices':
        return PriceMapCategory.prices;
      case 'consulates':
        return PriceMapCategory.consulates;
      case 'services':
      default:
        return PriceMapCategory.services;
    }
  }

  static PriceMapPinKind _parsePinKind(String? raw) {
    switch (raw) {
      case 'food':
        return PriceMapPinKind.food;
      case 'transport':
        return PriceMapPinKind.transport;
      case 'lodging':
        return PriceMapPinKind.lodging;
      case 'hospital':
        return PriceMapPinKind.hospital;
      case 'consulate':
        return PriceMapPinKind.consulate;
      case 'assistance':
      default:
        return PriceMapPinKind.assistance;
    }
  }

  static PricePinStatus _parsePinStatus(String? raw) {
    switch (raw) {
      case 'fair':
        return PricePinStatus.fair;
      case 'moderate':
        return PricePinStatus.moderate;
      case 'alert':
        return PricePinStatus.alert;
      case 'info':
      default:
        return PricePinStatus.info;
    }
  }

  /// Parsea una lista de filas JSON devueltas por `public.get_municipality_map_items`.
  static List<PriceMapItem> parseRows(
    List<dynamic> response, {
    String municipalityCode = '20001',
    String localeCode = 'es',
  }) {
    final isEnglish = localeCode.toLowerCase().startsWith('en');

    return response.whereType<Map<String, dynamic>>().map((row) {
      final nameEs = (row['name_es'] as String?) ?? '';
      final nameEn = (row['name_en'] as String?) ?? nameEs;
      final descEs = (row['description_es'] as String?) ?? '';
      final descEn = (row['description_en'] as String?) ?? descEs;

      return PriceMapItem(
        id: (row['id'] ?? '').toString(),
        name: isEnglish && nameEn.isNotEmpty ? nameEn : nameEs,
        description: isEnglish && descEn.isNotEmpty ? descEn : descEs,
        category: _parseCategory(row['map_category'] as String?),
        pinKind: _parsePinKind(row['pin_kind'] as String?),
        status: _parsePinStatus(row['pin_status'] as String?),
        pinLabel: (row['pin_label'] as String?) ?? '',
        badgeText: (row['badge_text'] as String?) ?? '',
        normalizedX: (row['normalized_x'] as num?)?.toDouble() ?? 0.5,
        normalizedY: (row['normalized_y'] as num?)?.toDouble() ?? 0.5,
        latitude: (row['latitude'] as num?)?.toDouble() ?? kValleduparCenterLat,
        longitude:
            (row['longitude'] as num?)?.toDouble() ?? kValleduparCenterLng,
        phone: row['phone'] as String?,
        whatsapp: row['whatsapp'] as String?,
        address: row['address'] as String?,
        sourceType: (row['source_type'] as String?) ?? 'price_report',
        municipalityCode:
            (row['municipality_code'] as String?) ?? municipalityCode,
        isDemo: (row['is_demo'] as bool?) ?? false,
      );
    }).toList();
  }

  @override
  Future<List<PriceMapItem>> getMapItems({
    String municipalityCode = '20001',
  }) async {
    try {
      final dynamic response = await _client.rpc(
        'get_municipality_map_items',
        params: <String, dynamic>{
          'p_municipality_code': municipalityCode,
          'p_category': null,
          'p_min_lat': bounds?.minLat,
          'p_max_lat': bounds?.maxLat,
          'p_min_lng': bounds?.minLng,
          'p_max_lng': bounds?.maxLng,
          'p_include_demo': includeDemo,
          'p_limit': 200,
        },
      );

      if (response is List && response.isNotEmpty) {
        return parseRows(
          response,
          municipalityCode: municipalityCode,
          localeCode: localeCode,
        );
      }
      return fallbackRepository.getMapItems(municipalityCode: municipalityCode);
    } catch (_) {
      return fallbackRepository.getMapItems(municipalityCode: municipalityCode);
    }
  }
}
