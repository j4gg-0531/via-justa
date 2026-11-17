import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_repository.dart';

/// Repositorio conectado a Supabase que consulta los negocios publicados (`status = 'approved'`)
/// y reales (`is_demo = false`) de `public.businesses`, sin reemplazo automático por ejemplos.
class SupabaseBusinessRepository implements BusinessRepository {
  const SupabaseBusinessRepository({
    required this.client,
    this.municipalityCode = '20001',
  });

  final SupabaseClient client;
  final String municipalityCode;

  static BusinessCategory _mapTypeToCategory(String? type) {
    switch (type) {
      case 'restaurant':
        return BusinessCategory.food;
      case 'transport':
        return BusinessCategory.transport;
      case 'hotel':
        return BusinessCategory.lodging;
      case 'service':
      case 'handicraft':
      case 'hospital':
      case 'consulate':
      default:
        return BusinessCategory.services;
    }
  }

  /// Convierte filas de `public.businesses` excluyendo cualquier registro de demostración.
  static List<Business> parseRows(
    List<dynamic> rows, {
    String municipalityCode = '20001',
  }) {
    final result = <Business>[];
    for (final dynamic raw in rows) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final isDemo = (row['is_demo'] as bool?) ?? false;
      final status = (row['status'] as String?) ?? 'approved';
      if (isDemo || status != 'approved') continue;

      final phone = (row['phone'] as String?)?.trim();
      final whatsapp = (row['whatsapp'] as String?)?.trim();
      final descEs = (row['description_es'] as String?)?.trim() ?? '';
      final descEn = (row['description_en'] as String?)?.trim() ?? '';

      result.add(
        Business(
          id: (row['id'] ?? '').toString(),
          ownerId: (row['owner_id'] as String?)?.trim(),
          name: (row['name'] as String?) ?? '',
          category: _mapTypeToCategory(row['type'] as String?),
          address: (row['address'] as String?) ?? 'Valledupar, Cesar',
          phone: (phone != null && phone.isNotEmpty) ? phone : (whatsapp ?? ''),
          municipalityCode:
              (row['municipality_code'] as String?) ?? municipalityCode,
          isVerified: true,
          description: descEs,
          descriptionEs: descEs,
          descriptionEn: descEn.isEmpty ? descEs : descEn,
        ),
      );
    }
    return result;
  }

  @override
  Future<List<Business>> getBusinesses() async {
    final rows = await client
        .from('businesses')
        .select(
          'id, owner_id, name, type, description_es, description_en, address, phone, whatsapp, municipality_code, status, is_demo',
        )
        .eq('municipality_code', municipalityCode)
        .eq('status', 'approved')
        .eq('is_demo', false)
        .order('created_at', ascending: false)
        .limit(100);

    return parseRows(rows, municipalityCode: municipalityCode);
  }
}
