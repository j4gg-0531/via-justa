import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_filter.dart';
import 'package:via_justa/features/businesses/domain/business_repository.dart';

/// Repositorio conectado a Supabase que consulta `public.get_business_catalog` (VJ-17)
/// excluyendo comercios de demostración y propagando fallos de conexión.
class SupabaseBusinessRepository implements BusinessRepository {
  const SupabaseBusinessRepository({
    required this.client,
    this.municipalityCode = '20001',
  });

  final SupabaseClient client;
  final String municipalityCode;

  static BusinessCategory _mapTypeToCategory(
    String? type,
    String? categoryGroup,
  ) {
    switch (categoryGroup ?? type) {
      case 'food':
      case 'restaurant':
        return BusinessCategory.food;
      case 'transport':
        return BusinessCategory.transport;
      case 'lodging':
      case 'hotel':
        return BusinessCategory.lodging;
      case 'services':
      case 'service':
      case 'handicraft':
      case 'hospital':
      case 'consulate':
      default:
        return BusinessCategory.services;
    }
  }

  /// Convierte filas de `public.get_business_catalog` o `public.businesses` excluyendo demos.
  static List<Business> parseRows(
    List<dynamic> rows, {
    String municipalityCode = '20001',
    String? currentOwnerId,
    Set<String> ownedBusinessIds = const <String>{},
  }) {
    final result = <Business>[];
    for (final dynamic raw in rows) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final isDemo = (row['is_demo'] as bool?) ?? false;
      final status = (row['status'] as String?) ?? 'approved';
      if (isDemo || status != 'approved') continue;

      final id = (row['id'] ?? '').toString();
      final explicitOwner = (row['owner_id'] as String?)?.trim();
      final ownerId =
          explicitOwner ??
          (currentOwnerId != null && ownedBusinessIds.contains(id)
              ? currentOwnerId
              : null);
      final type = (row['type'] as String?)?.trim() ?? 'service';
      final categoryGroup = (row['category_group'] as String?)?.trim();
      final phone = (row['phone'] as String?)?.trim();
      final whatsapp = (row['whatsapp'] as String?)?.trim();
      final resolvedDesc = (row['description'] as String?)?.trim() ?? '';
      final descEs =
          (row['description_es'] as String?)?.trim() ?? resolvedDesc;
      final descEn =
          (row['description_en'] as String?)?.trim() ?? resolvedDesc;

      result.add(
        Business(
          id: id,
          ownerId: ownerId,
          name: (row['name'] as String?) ?? '',
          type: type,
          category: _mapTypeToCategory(type, categoryGroup),
          address: (row['address'] as String?) ?? 'Valledupar, Cesar',
          phone: (phone != null && phone.isNotEmpty) ? phone : (whatsapp ?? ''),
          municipalityCode:
              (row['municipality_code'] as String?) ?? municipalityCode,
          isVerified: true,
          description: resolvedDesc.isNotEmpty ? resolvedDesc : descEs,
          descriptionEs: descEs,
          descriptionEn: descEn.isEmpty ? descEs : descEn,
          latitude: (row['latitude'] as num?)?.toDouble(),
          longitude: (row['longitude'] as num?)?.toDouble(),
          whatsapp: whatsapp,
          hasWhatsapp:
              (row['has_whatsapp'] as bool?) ??
              (whatsapp != null && whatsapp.isNotEmpty),
          whatsappUrl: (row['whatsapp_url'] as String?)?.trim(),
          telUrl: (row['tel_url'] as String?)?.trim(),
          mapsUrl: (row['maps_url'] as String?)?.trim(),
          orderUrl: (row['order_url'] as String?)?.trim(),
          hasExternalOrder:
              (row['has_external_order'] as bool?) ??
              ((row['order_url'] as String?)?.trim().isNotEmpty ?? false),
          coverPhotoPath: (row['cover_photo_path'] as String?)?.trim(),
          photosCount: (row['photos_count'] as num?)?.toInt() ?? 0,
          dishesCount: (row['dishes_count'] as num?)?.toInt() ?? 0,
          minDishPriceCop: (row['min_dish_price_cop'] as num?)?.toInt(),
        ),
      );
    }
    return result;
  }

  @override
  Future<List<Business>> getBusinesses({
    BusinessCategory? category,
    String? searchQuery,
    String localeCode = 'es',
    int limit = kBusinessCatalogPageSize,
    int offset = 0,
  }) async {
    final cleanSearch = searchQuery?.trim() ?? '';
    final dynamic rawCatalog = await client.rpc(
      'get_business_catalog',
      params: <String, dynamic>{
        'p_municipality_code': municipalityCode,
        'p_type': category?.catalogFilterValue,
        'p_search': cleanSearch.isEmpty ? null : cleanSearch,
        'p_locale': localeCode,
        'p_include_demo': false,
        'p_limit': limit,
        'p_offset': offset,
      },
    );

    final currentOwnerId = client.auth.currentUser?.id;
    final ownedIds = <String>{};
    if (currentOwnerId != null) {
      try {
        final dynamic myRows = await client.rpc('get_my_businesses');
        if (myRows is List) {
          for (final dynamic item in myRows) {
            if (item is Map && item['id'] != null) {
              ownedIds.add(item['id'].toString());
            }
          }
        }
      } catch (_) {
        // Si la consulta de propios falla no bloquea el catálogo público.
      }
    }

    if (rawCatalog is List) {
      return parseRows(
        rawCatalog,
        municipalityCode: municipalityCode,
        currentOwnerId: currentOwnerId,
        ownedBusinessIds: ownedIds,
      );
    }
    return const <Business>[];
  }
}
