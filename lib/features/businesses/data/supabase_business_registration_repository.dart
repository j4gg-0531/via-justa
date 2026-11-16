import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/businesses/domain/business_draft.dart';
import 'package:via_justa/features/businesses/domain/business_registration_repository.dart';
import 'package:via_justa/features/businesses/domain/business_validator.dart';

/// El mismo borrador y requestId se conservan hasta publicar o descartar.
class SupabaseBusinessRegistrationRepository
    implements BusinessRegistrationRepository {
  const SupabaseBusinessRegistrationRepository(this._client);
  final SupabaseClient _client;

  void _checkOwner(String ownerId) {
    if (_client.auth.currentUser?.id != ownerId) {
      throw const BusinessRegistrationFailure('session');
    }
  }

  Map<String, dynamic> _hoursPayload(BusinessDraft draft) => {
    for (final day in BusinessDraft.days)
      day: draft.hours[day]?.enabled == true
          ? [
              {
                'open': draft.hours[day]!.open,
                'close': draft.hours[day]!.close,
              },
            ]
          : [],
  };

  List<Map<String, dynamic>> _dishesPayload(BusinessDraft draft) => [
    for (final dish in draft.dishes)
      {'name': dish.name.trim(), 'price_cop': int.parse(dish.price)},
  ];

  String _newEditPhotoPath({
    required String ownerId,
    required String businessId,
    required String requestId,
    required int index,
    required String extension,
  }) {
    final cleanToken = requestId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final suffix = cleanToken.isEmpty ? 'batch' : cleanToken.substring(0, cleanToken.length > 16 ? 16 : cleanToken.length);
    return '$ownerId/$businessId/edit_${suffix}_$index.$extension';
  }

  Future<void> _bestEffortRemoveStoragePaths(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _client.storage.from('business-media').remove(paths);
    } catch (_) {
      // Limpieza en segundo plano: la ficha en BD ya es consistente.
    }
  }

  @override
  Future<String> publish({
    required BusinessDraft draft,
    required String requestId,
    required String ownerId,
    required String municipalityCode,
    String? businessId,
  }) async {
    _checkOwner(ownerId);
    try {
      final phone = normalizeBusinessPhone(draft.text(BusinessField.phone));
      final whatsapp = normalizeBusinessPhone(
        draft.text(BusinessField.whatsapp),
        whatsapp: true,
      );
      final orderUrl = draft.text(BusinessField.orderUrl).trim();

      if (businessId != null) {
        final uploadedNewPaths = <String>[];
        final photoSpecs = <Map<String, dynamic>>[];

        try {
          for (var index = 0; index < draft.photos.length; index++) {
            _checkOwner(ownerId);
            final photo = draft.photos[index];
            final existingPath = photo.storagePath?.trim();
            final String targetPath;
            if (existingPath != null && existingPath.isNotEmpty) {
              targetPath = existingPath;
            } else {
              targetPath = _newEditPhotoPath(
                ownerId: ownerId,
                businessId: businessId,
                requestId: requestId,
                index: index,
                extension: photo.extension,
              );
              await _client.storage
                  .from('business-media')
                  .uploadBinary(
                    targetPath,
                    photo.bytes,
                    fileOptions: FileOptions(
                      contentType: photo.mimeType,
                      upsert: false,
                    ),
                  );
              uploadedNewPaths.add(targetPath);
            }
            photoSpecs.add({
              'storage_path': targetPath,
              'position': index,
              'is_cover': index == 0,
            });
          }

          _checkOwner(ownerId);
          final dynamic rawResult = await _client.rpc(
            'update_own_business',
            params: {
              'p_business_id': businessId,
              'p_name': draft.text(BusinessField.name).trim(),
              'p_description_es': draft.text(BusinessField.descriptionEs).trim(),
              'p_description_en': draft.text(BusinessField.descriptionEn).trim(),
              'p_latitude': draft.latitude,
              'p_longitude': draft.longitude,
              'p_address': draft.text(BusinessField.address).trim(),
              'p_phone': phone.isEmpty ? null : phone,
              'p_whatsapp': whatsapp.isEmpty ? null : whatsapp,
              'p_whatsapp_consent': whatsapp.isNotEmpty && draft.whatsappConsent,
              'p_order_url': orderUrl.isEmpty ? null : orderUrl,
              'p_hours': _hoursPayload(draft),
              'p_dishes': _dishesPayload(draft),
              'p_photos': photoSpecs,
            },
          );

          final result = rawResult is Map
              ? Map<String, dynamic>.from(rawResult)
              : const <String, dynamic>{};
          final removedRaw = result['removed_photo_paths'];
          final removedPaths = <String>[
            if (removedRaw is List)
              for (final item in removedRaw)
                if (item != null && item.toString().isNotEmpty) item.toString(),
          ];
          await _bestEffortRemoveStoragePaths(removedPaths);
          return businessId;
        } catch (_) {
          await _bestEffortRemoveStoragePaths(uploadedNewPaths);
          rethrow;
        }
      }

      final raw = await _client.rpc(
        'submit_business',
        params: {
          'p_client_request_id': requestId,
          'p_type': draft.type.name,
          'p_name': draft.text(BusinessField.name).trim(),
          'p_description_es': draft.text(BusinessField.descriptionEs).trim(),
          'p_description_en': draft.text(BusinessField.descriptionEn).trim(),
          'p_latitude': draft.latitude,
          'p_longitude': draft.longitude,
          'p_address': draft.text(BusinessField.address).trim(),
          'p_phone': phone,
          'p_whatsapp': whatsapp,
          'p_whatsapp_consent': draft.whatsappConsent,
          'p_publication_consent': draft.publicationConsent,
          'p_order_url': orderUrl,
          'p_hours': _hoursPayload(draft),
          'p_dishes': _dishesPayload(draft),
          'p_municipality_code': municipalityCode,
        },
      );
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['id'] as String;
      if (row['status'] == 'approved') return id;
      for (var index = 0; index < draft.photos.length; index++) {
        _checkOwner(ownerId);
        final photo = draft.photos[index];
        final path = '$ownerId/$id/photo_$index.${photo.extension}';
        await _client.storage
            .from('business-media')
            .uploadBinary(
              path,
              photo.bytes,
              fileOptions: FileOptions(
                contentType: photo.mimeType,
                upsert: true,
              ),
            );
        _checkOwner(ownerId);
        await _client.from('business_photos').upsert({
          'business_id': id,
          'storage_path': path,
          'position': index,
          'is_cover': index == 0,
        }, onConflict: 'business_id,position');
      }
      _checkOwner(ownerId);
      await _client.rpc(
        'publish_business',
        params: {
          'p_business_id': id,
          'p_expected_photo_count': draft.photos.length,
        },
      );
      return id;
    } on PostgrestException catch (error) {
      throw BusinessRegistrationFailure(_errorKey(error.message));
    }
  }

  @override
  Future<BusinessDraft> loadForEdit({
    required String businessId,
    required String ownerId,
  }) async {
    _checkOwner(ownerId);
    try {
      final raw = await _client.rpc(
        'get_business_detail',
        params: {
          'p_business_id': businessId,
          'p_locale': 'es',
          'p_include_demo': false,
        },
      );
      final detail = Map<String, dynamic>.from(raw as Map);
      final typeName = (detail['type'] as String?) ?? 'restaurant';
      final type = BusinessType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => BusinessType.restaurant,
      );
      final rawHours = detail['hours'];
      final hours = <String, BusinessDayHours>{};
      if (rawHours is Map) {
        for (final day in BusinessDraft.days) {
          final ranges = rawHours[day];
          if (ranges is List && ranges.isNotEmpty && ranges.first is Map) {
            final first = Map<String, dynamic>.from(ranges.first as Map);
            hours[day] = BusinessDayHours(
              enabled: true,
              open: (first['open'] as String?) ?? '08:00',
              close: (first['close'] as String?) ?? '18:00',
            );
          }
        }
      }
      final rawDishes = detail['dishes'];
      final dishes = <BusinessDishDraft>[
        if (rawDishes is List)
          for (final item in rawDishes.whereType<Map>())
            BusinessDishDraft(
              name: (item['name'] as String?) ?? '',
              price: (item['price_cop'] ?? '').toString(),
            ),
      ];
      final rawPhotos = detail['photos'];
      final photos = <BusinessPhoto>[];
      if (rawPhotos is List) {
        for (final item in rawPhotos.whereType<Map>()) {
          final storagePath = (item['storage_path'] as String?) ?? '';
          if (storagePath.isEmpty) continue;
          _checkOwner(ownerId);
          final Uint8List bytes = await _client.storage
              .from('business-media')
              .download(storagePath);
          final extension = businessImageExtension(bytes) ?? 'jpg';
          photos.add(
            BusinessPhoto(
              bytes: bytes,
              extension: extension,
              mimeType: extension == 'jpg'
                  ? 'image/jpeg'
                  : 'image/$extension',
              storagePath: storagePath,
            ),
          );
        }
      }
      final whatsapp = (detail['whatsapp'] as String?)?.trim() ?? '';
      return BusinessDraft(
        type: type,
        fields: {
          BusinessField.name: (detail['name'] as String?) ?? '',
          BusinessField.descriptionEs:
              (detail['description_es'] as String?) ?? '',
          BusinessField.descriptionEn:
              (detail['description_en'] as String?) ?? '',
          BusinessField.address: (detail['address'] as String?) ?? '',
          BusinessField.phone: (detail['phone'] as String?) ?? '',
          BusinessField.whatsapp: whatsapp,
          BusinessField.orderUrl: (detail['order_url'] as String?) ?? '',
        },
        latitude: (detail['latitude'] as num?)?.toDouble(),
        longitude: (detail['longitude'] as num?)?.toDouble(),
        whatsappConsent: whatsapp.isNotEmpty,
        publicationConsent: true,
        hours: hours,
        dishes: dishes,
        photos: photos,
      );
    } on PostgrestException catch (error) {
      throw BusinessRegistrationFailure(_errorKey(error.message));
    }
  }

  @override
  Future<void> withdraw({
    required String businessId,
    required String ownerId,
  }) async {
    _checkOwner(ownerId);
    final files = await _client.storage
        .from('business-media')
        .list(path: '$ownerId/$businessId');
    _checkOwner(ownerId);
    if (files.isNotEmpty) {
      await _client.storage.from('business-media').remove([
        for (final file in files) '$ownerId/$businessId/${file.name}',
      ]);
    }
    _checkOwner(ownerId);
    await _client
        .from('businesses')
        .delete()
        .eq('id', businessId)
        .eq('owner_id', ownerId);
  }

  @override
  Future<String?> discard({
    required String requestId,
    required String ownerId,
  }) async {
    _checkOwner(ownerId);
    final row = await _client
        .from('businesses')
        .select('id,status')
        .eq('owner_id', ownerId)
        .eq('client_request_id', requestId)
        .maybeSingle();
    if (row == null) return null;
    final id = row['id'] as String;
    if (row['status'] == 'approved') return id;
    final files = await _client.storage
        .from('business-media')
        .list(path: '$ownerId/$id');
    _checkOwner(ownerId);
    if (files.isNotEmpty) {
      await _client.storage.from('business-media').remove([
        for (final file in files) '$ownerId/$id/${file.name}',
      ]);
    }
    _checkOwner(ownerId);
    await _client
        .from('businesses')
        .delete()
        .eq('id', id)
        .eq('owner_id', ownerId)
        .eq('status', 'pending');
    return null;
  }

  String _errorKey(String message) {
    const codes = {
      'BUSINESS_DUPLICATE': 'duplicate',
      'BUSINESS_RATE_LIMITED': 'limit',
      'BUSINESS_LIMIT_REACHED': 'limit',
      'BUSINESS_INVALID_LOCATION': 'location',
      'BUSINESS_PHOTOS_INCOMPLETE': 'photoUpload',
      'BUSINESS_PHOTO_INVALID_PATH': 'photoUpload',
      'BUSINESS_PHOTO_NOT_UPLOADED': 'photoUpload',
      'BUSINESS_AUTH_REQUIRED': 'session',
      'BUSINESS_INVALID_ORDER_URL': 'url',
    };
    for (final entry in codes.entries) {
      if (message.contains('[${entry.key}]')) return entry.value;
    }
    return 'server';
  }
}
