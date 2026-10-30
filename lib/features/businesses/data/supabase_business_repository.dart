import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/businesses/data/local_business_repository.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_repository.dart';

/// Repositorio conectado a Supabase que consulta los negocios aprobados de `public.businesses`
/// (y a través de `public.get_municipality_map_items`) para mostrarlos también en el directorio.
class SupabaseBusinessRepository implements BusinessRepository {
  const SupabaseBusinessRepository({
    required this._client,
    this.municipalityCode = '20001',
    this.fallbackRepository = const LocalBusinessRepository(),
  });

  final SupabaseClient _client;
  final String municipalityCode;
  final BusinessRepository fallbackRepository;

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

  @override
  Future<List<Business>> getBusinesses() async {
    try {
      final rows = await _client
          .from('businesses')
          .select(
            'id, name, type, description_es, address, phone, whatsapp, municipality_code, status, is_demo',
          )
          .eq('municipality_code', municipalityCode)
          .eq('status', 'approved')
          .order('is_demo', ascending: true)
          .order('created_at', ascending: false)
          .limit(100);

      final realAndApproved = <Business>[];
      for (final dynamic raw in rows) {
        if (raw is! Map<String, dynamic>) continue;
        final isDemo = (raw['is_demo'] as bool?) ?? false;
        final phone = (raw['phone'] as String?)?.trim();
        final whatsapp = (raw['whatsapp'] as String?)?.trim();
        realAndApproved.add(
          Business(
            id: (raw['id'] ?? '').toString(),
            name: (raw['name'] as String?) ?? '',
            category: _mapTypeToCategory(raw['type'] as String?),
            address:
                (raw['address'] as String?) ?? 'Valledupar, Cesar',
            phone: (phone != null && phone.isNotEmpty)
                ? phone
                : (whatsapp ?? ''),
            municipalityCode:
                (raw['municipality_code'] as String?) ?? municipalityCode,
            isVerified: !isDemo,
            description: (raw['description_es'] as String?) ?? '',
          ),
        );
      }

      final fallbackItems = await fallbackRepository.getBusinesses();
      if (realAndApproved.isEmpty) {
        return fallbackItems;
      }
      return <Business>[...realAndApproved, ...fallbackItems];
    } catch (_) {
      return fallbackRepository.getBusinesses();
    }
  }
}
