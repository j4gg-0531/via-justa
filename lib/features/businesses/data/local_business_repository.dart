import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_detail.dart';
import 'package:via_justa/features/businesses/domain/business_filter.dart';
import 'package:via_justa/features/businesses/domain/business_rating.dart';
import 'package:via_justa/features/businesses/domain/business_repository.dart';

/// Repositorio local sin comercios de demostración (los negocios demo se retiraron de la experiencia).
class LocalBusinessRepository implements BusinessRepository {
  const LocalBusinessRepository();

  @override
  Future<List<Business>> getBusinesses({
    BusinessCategory? category,
    String? searchQuery,
    String localeCode = 'es',
    int limit = kBusinessCatalogPageSize,
    int offset = 0,
  }) async {
    return const <Business>[];
  }

  @override
  Future<BusinessDetail> getBusinessDetail(
    String businessId, {
    String localeCode = 'es',
  }) async {
    throw StateError('Business not found: $businessId');
  }

  @override
  Future<BusinessRatingSummary> rateBusiness({
    required String businessId,
    required int stars,
  }) async {
    throw StateError('Rating requires Supabase connection: $businessId');
  }

  @override
  Future<List<Business>> getMyBusinesses() async => const <Business>[];
}
