import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_detail.dart';
import 'package:via_justa/features/businesses/domain/business_filter.dart';
import 'package:via_justa/features/businesses/domain/business_repository.dart';

/// Repositorio conectado a Supabase que consulta `public.get_business_catalog` y
/// `public.get_business_detail` (VJ-17), excluyendo comercios de demostración.
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

  /// Convierte el JSON devuelto por `public.get_business_detail` en `BusinessDetail`.
  static BusinessDetail parseDetail(
    Map<String, dynamic> row, {
    String municipalityCode = '20001',
    String? ownerId,
    Map<String, Uint8List> photoBytesByPath = const <String, Uint8List>{},
  }) {
    final type = (row['type'] as String?)?.trim() ?? 'service';
    final categoryGroup = (row['category_group'] as String?)?.trim();
    final descEs = (row['description_es'] as String?)?.trim() ?? '';
    final descEn = (row['description_en'] as String?)?.trim() ?? '';
    final resolvedDesc = (row['description'] as String?)?.trim() ?? descEs;

    final rawActions = row['actions'];
    final actions = rawActions is Map
        ? Map<String, dynamic>.from(rawActions)
        : const <String, dynamic>{};

    final rawHours = row['hours'];
    final hoursMap = rawHours is Map
        ? Map<String, dynamic>.from(rawHours)
        : null;

    final rawPhotos = row['photos'];
    final photos = <BusinessPhotoItem>[];
    if (rawPhotos is List) {
      for (final dynamic item in rawPhotos) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final storagePath = (map['storage_path'] as String?)?.trim() ?? '';
        if (storagePath.isEmpty) continue;
        photos.add(
          BusinessPhotoItem(
            id: (map['id'] ?? storagePath).toString(),
            storagePath: storagePath,
            position: (map['position'] as num?)?.toInt() ?? 0,
            isCover: (map['is_cover'] as bool?) ?? false,
            bytes: photoBytesByPath[storagePath],
          ),
        );
      }
    }

    final rawDishes = row['dishes'];
    final dishes = <BusinessDishItem>[];
    if (rawDishes is List) {
      for (final dynamic item in rawDishes) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final name = (map['name'] as String?)?.trim() ?? '';
        final priceCop = (map['price_cop'] as num?)?.toInt() ?? 0;
        if (name.isEmpty || priceCop <= 0) continue;
        dishes.add(
          BusinessDishItem(
            id: (map['id'] ?? name).toString(),
            name: name,
            priceCop: priceCop,
            description: (map['description'] as String?)?.trim(),
          ),
        );
      }
    }

    final orderUrl =
        (actions['order_url'] as String?)?.trim() ??
        (row['order_url'] as String?)?.trim();
    final whatsappUrl = (actions['whatsapp_url'] as String?)?.trim();
    final telUrl = (actions['tel_url'] as String?)?.trim();
    final mapsUrl = (actions['maps_url'] as String?)?.trim();

    return BusinessDetail(
      id: (row['id'] ?? '').toString(),
      ownerId: ownerId ?? (row['owner_id'] as String?)?.trim(),
      name: (row['name'] as String?)?.trim() ?? '',
      type: type,
      category: _mapTypeToCategory(type, categoryGroup),
      municipalityCode:
          (row['municipality_code'] as String?) ?? municipalityCode,
      description: resolvedDesc,
      descriptionEs: descEs.isNotEmpty ? descEs : resolvedDesc,
      descriptionEn: descEn.isNotEmpty ? descEn : resolvedDesc,
      address: (row['address'] as String?)?.trim() ?? 'Valledupar, Cesar',
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      phone: (row['phone'] as String?)?.trim(),
      whatsapp: (row['whatsapp'] as String?)?.trim(),
      orderUrl: orderUrl,
      whatsappUrl: whatsappUrl,
      telUrl: telUrl,
      mapsUrl: mapsUrl,
      canCall: (actions['can_call'] as bool?) ?? (telUrl != null),
      canWhatsapp: (actions['can_whatsapp'] as bool?) ?? (whatsappUrl != null),
      canDirections: (actions['can_directions'] as bool?) ?? (mapsUrl != null),
      canOrderExternal:
          (actions['can_order_external'] as bool?) ??
          (orderUrl != null && orderUrl.isNotEmpty),
      externalOrderDisclaimer:
          (actions['external_order_disclaimer'] as String?)?.trim() ?? '',
      schedule: buildBusinessSchedule(hoursMap),
      photos: photos,
      dishes: dishes,
      ratingAverage: (row['rating_average'] as num?)?.toDouble(),
      ratingCount: (row['rating_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Set<String>> _fetchOwnedBusinessIds() async {
    final currentOwnerId = client.auth.currentUser?.id;
    final ownedIds = <String>{};
    if (currentOwnerId == null) return ownedIds;
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
      // Si la consulta de propios falla no bloquea las vistas públicas.
    }
    return ownedIds;
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

    final ownedIds = await _fetchOwnedBusinessIds();

    if (rawCatalog is List) {
      return parseRows(
        rawCatalog,
        municipalityCode: municipalityCode,
        currentOwnerId: client.auth.currentUser?.id,
        ownedBusinessIds: ownedIds,
      );
    }
    return const <Business>[];
  }

  @override
  Future<BusinessDetail> getBusinessDetail(
    String businessId, {
    String localeCode = 'es',
  }) async {
    final dynamic raw = await client.rpc(
      'get_business_detail',
      params: <String, dynamic>{
        'p_business_id': businessId,
        'p_locale': localeCode,
        'p_include_demo': false,
      },
    );
    final detailMap = Map<String, dynamic>.from(raw as Map);
    final isDemo = (detailMap['is_demo'] as bool?) ?? false;
    if (isDemo) {
      throw StateError('Demo business is excluded');
    }

    final currentOwnerId = client.auth.currentUser?.id;
    final ownedIds = await _fetchOwnedBusinessIds();
    final ownerId =
        currentOwnerId != null && ownedIds.contains(businessId)
            ? currentOwnerId
            : null;

    final photoBytesByPath = <String, Uint8List>{};
    final rawPhotos = detailMap['photos'];
    if (rawPhotos is List) {
      for (final dynamic item in rawPhotos) {
        if (item is! Map) continue;
        final storagePath = (item['storage_path'] as String?)?.trim() ?? '';
        if (storagePath.isEmpty) continue;
        try {
          photoBytesByPath[storagePath] = await client.storage
              .from('business-media')
              .download(storagePath);
        } catch (_) {
          // Si una imagen no se descarga se muestra el marcador visual sin romper la ficha.
        }
      }
    }

    return parseDetail(
      detailMap,
      municipalityCode: municipalityCode,
      ownerId: ownerId,
      photoBytesByPath: photoBytesByPath,
    );
  }
}
