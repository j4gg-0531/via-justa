import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_repository.dart';

/// Repositorio local sin comercios de demostración (los negocios demo se retiraron de la experiencia).
class LocalBusinessRepository implements BusinessRepository {
  const LocalBusinessRepository();

  @override
  Future<List<Business>> getBusinesses() async {
    return const <Business>[];
  }
}
