import 'package:via_justa/features/activity/domain/user_activity.dart';

/// Persistencia local de consultas recientes y comercios favoritos del usuario.
abstract class UserActivityStorage {
  Future<UserActivityState> loadState();
  Future<void> saveState(UserActivityState state);
  Future<void> clear();
}

/// Repositorio de aportes de precios enviados por el usuario autenticado.
abstract class MyPriceContributionsRepository {
  Future<List<UserPriceContribution>> getMyContributions();
}
