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

  @override
  Future<String> publish({
    required BusinessDraft draft,
    required String requestId,
    required String ownerId,
    required String municipalityCode,
  }) async {
    _checkOwner(ownerId);
    try {
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
          'p_phone': normalizeBusinessPhone(draft.text(BusinessField.phone)),
          'p_whatsapp': normalizeBusinessPhone(
            draft.text(BusinessField.whatsapp),
            whatsapp: true,
          ),
          'p_whatsapp_consent': draft.whatsappConsent,
          'p_publication_consent': draft.publicationConsent,
          'p_order_url': draft.text(BusinessField.orderUrl).trim(),
          'p_hours': {
            for (final day in BusinessDraft.days)
              day: draft.hours[day]?.enabled == true
                  ? [
                      {
                        'open': draft.hours[day]!.open,
                        'close': draft.hours[day]!.close,
                      },
                    ]
                  : [],
          },
          'p_dishes': [
            for (final dish in draft.dishes)
              {'name': dish.name.trim(), 'price_cop': int.parse(dish.price)},
          ],
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
      'BUSINESS_AUTH_REQUIRED': 'session',
      'BUSINESS_INVALID_ORDER_URL': 'url',
    };
    for (final entry in codes.entries) {
      if (message.contains('[${entry.key}]')) return entry.value;
    }
    return 'server';
  }
}
