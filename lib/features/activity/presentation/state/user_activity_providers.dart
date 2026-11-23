import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/activity/data/local_user_activity_storage.dart';
import 'package:via_justa/features/activity/domain/user_activity.dart';
import 'package:via_justa/features/activity/domain/user_activity_repository.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';

final userActivityStorageProvider = Provider<UserActivityStorage>((ref) {
  return const SecureUserActivityStorage();
});

final myPriceContributionsRepositoryProvider =
    Provider<MyPriceContributionsRepository>((ref) {
      final client = ref.watch(supabaseClientProvider);
      if (client != null) {
        return SupabaseMyPriceContributionsRepository(client);
      }
      return const DemoMyPriceContributionsRepository();
    });

/// Controlador de la memoria local del usuario (consultas recientes y favoritos).
class UserActivityNotifier extends Notifier<UserActivityState> {
  Future<void>? _hydrationFuture;
  bool _clearedExplicitly = false;

  @override
  UserActivityState build() {
    _clearedExplicitly = false;
    _hydrationFuture ??= _hydrate();
    return const UserActivityState();
  }

  Future<void> _hydrate() async {
    final loaded = await ref.read(userActivityStorageProvider).loadState();
    if (_clearedExplicitly || !ref.mounted) return;
    if (state.recentChecks.isEmpty && state.favoriteBusinessIds.isEmpty) {
      state = loaded;
    }
  }

  /// Garantiza que la lectura cifrada inicial termine antes de mutar y persistir,
  /// evitando sobrescribir favoritos o consultas previas tras un reinicio en frío.
  Future<void> _ensureHydrated() async {
    final pending = _hydrationFuture;
    if (pending != null) {
      await pending;
    }
  }

  Future<void> recordPriceCheck(RecentPriceCheck check) async {
    await _ensureHydrated();
    if (!ref.mounted) return;
    _clearedExplicitly = false;
    final updated = UserActivityState(
      recentChecks: prependRecentPriceCheck(state.recentChecks, check),
      favoriteBusinessIds: state.favoriteBusinessIds,
    );
    state = updated;
    await ref.read(userActivityStorageProvider).saveState(updated);
  }

  Future<void> toggleFavoriteBusiness(String businessId) async {
    await _ensureHydrated();
    if (!ref.mounted) return;
    _clearedExplicitly = false;
    final updated = UserActivityState(
      recentChecks: state.recentChecks,
      favoriteBusinessIds: toggleFavoriteBusinessId(
        state.favoriteBusinessIds,
        businessId,
      ),
    );
    state = updated;
    await ref.read(userActivityStorageProvider).saveState(updated);
  }

  Future<void> clearRecentChecks() async {
    await _ensureHydrated();
    if (!ref.mounted) return;
    final updated = UserActivityState(
      recentChecks: const <RecentPriceCheck>[],
      favoriteBusinessIds: state.favoriteBusinessIds,
    );
    state = updated;
    await ref.read(userActivityStorageProvider).saveState(updated);
  }

  Future<void> clearAll() async {
    _clearedExplicitly = true;
    state = const UserActivityState();
    await ref.read(userActivityStorageProvider).clear();
  }
}

final userActivityProvider =
    NotifierProvider<UserActivityNotifier, UserActivityState>(
      UserActivityNotifier.new,
    );

/// Aportes de precio enviados por el usuario autenticado.
final myPriceContributionsProvider =
    FutureProvider<List<UserPriceContribution>>((ref) async {
      final authState = ref.watch(authControllerProvider);
      if (!authState.isAuthenticated) {
        return const <UserPriceContribution>[];
      }
      return ref
          .watch(myPriceContributionsRepositoryProvider)
          .getMyContributions();
    });

/// Comercios del directorio marcados como favoritos por el usuario.
final favoriteBusinessesProvider = Provider<List<Business>>((ref) {
  final activity = ref.watch(userActivityProvider);
  final allBusinesses =
      ref.watch(allBusinessesProvider).asData?.value ?? const <Business>[];
  return resolveFavoriteBusinesses(allBusinesses, activity.favoriteBusinessIds);
});

/// Total agregado de elementos en "Mi actividad" para la insignia de Perfil.
final userActivityTotalCountProvider = Provider<int>((ref) {
  final activity = ref.watch(userActivityProvider);
  final contributions =
      ref.watch(myPriceContributionsProvider).asData?.value ??
      const <UserPriceContribution>[];
  return computeActivityTotalCount(
    checksCount: activity.recentChecks.length,
    favoritesCount: activity.favoriteBusinessIds.length,
    contributionsCount: contributions.length,
  );
});
