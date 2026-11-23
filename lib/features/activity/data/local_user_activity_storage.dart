import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/activity/domain/user_activity.dart';
import 'package:via_justa/features/activity/domain/user_activity_repository.dart';

/// Implementación local segura (cifrada en dispositivo) del historial y favoritos del usuario.
class SecureUserActivityStorage implements UserActivityStorage {
  const SecureUserActivityStorage([
    this._storage = const FlutterSecureStorage(),
  ]);

  static const String _checksKey = 'via_justa.recent_price_checks_v1';
  static const String _favoritesKey = 'via_justa.favorite_business_ids_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<UserActivityState> loadState() async {
    try {
      final rawChecks = await _storage.read(key: _checksKey);
      final checks = <RecentPriceCheck>[];
      if (rawChecks != null && rawChecks.isNotEmpty) {
        final decoded = jsonDecode(rawChecks);
        if (decoded is List<dynamic>) {
          for (final entry in decoded) {
            if (entry is Map<String, dynamic>) {
              final item = RecentPriceCheck.fromMap(entry);
              if (item != null) checks.add(item);
            }
          }
        }
      }

      final rawFavs = await _storage.read(key: _favoritesKey);
      final favs = <String>{};
      if (rawFavs != null && rawFavs.isNotEmpty) {
        final decoded = jsonDecode(rawFavs);
        if (decoded is List<dynamic>) {
          for (final entry in decoded) {
            if (entry is String && entry.trim().isNotEmpty) {
              favs.add(entry.trim());
            }
          }
        }
      }

      return UserActivityState(
        recentChecks: List<RecentPriceCheck>.unmodifiable(checks),
        favoriteBusinessIds: Set<String>.unmodifiable(favs),
      );
    } catch (_) {
      return const UserActivityState();
    }
  }

  @override
  Future<void> saveState(UserActivityState state) async {
    try {
      final encodedChecks = jsonEncode(
        state.recentChecks.map((item) => item.toMap()).toList(),
      );
      final encodedFavs = jsonEncode(state.favoriteBusinessIds.toList());
      await _storage.write(key: _checksKey, value: encodedChecks);
      await _storage.write(key: _favoritesKey, value: encodedFavs);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _checksKey);
      await _storage.delete(key: _favoritesKey);
    } catch (_) {}
  }
}

/// Repositorio en memoria/DEMO cuando no hay backend Supabase conectado.
class DemoMyPriceContributionsRepository
    implements MyPriceContributionsRepository {
  const DemoMyPriceContributionsRepository();

  @override
  Future<List<UserPriceContribution>> getMyContributions() async {
    return const <UserPriceContribution>[];
  }
}

/// Consulta los aportes de precio propios del usuario autenticado (`price_reports_select_own`).
class SupabaseMyPriceContributionsRepository
    implements MyPriceContributionsRepository {
  const SupabaseMyPriceContributionsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<UserPriceContribution>> getMyContributions() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const <UserPriceContribution>[];

    final rows = await _client
        .from('price_reports')
        .select(
          'id, category_id, zone_id, amount_cop, place_name, created_at, '
          'price_categories(name_es, name_en)',
        )
        .eq('user_id', userId)
        .eq('is_demo', false)
        .order('created_at', ascending: false)
        .limit(30);

    final result = <UserPriceContribution>[];
    for (final raw in (rows as List<dynamic>)) {
      final map = raw as Map<String, dynamic>;
      final cat = map['price_categories'] as Map<String, dynamic>?;
      final categoryId = map['category_id'] as String? ?? '';
      final createdAt =
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now();
      result.add(
        UserPriceContribution(
          id: map['id'] as String? ?? '',
          categoryId: categoryId,
          categoryNameEs: cat?['name_es'] as String? ?? categoryId,
          categoryNameEn: cat?['name_en'] as String? ?? categoryId,
          zoneName: _zoneLabelFromId(map['zone_id'] as String? ?? ''),
          amountCop: (map['amount_cop'] as num?)?.toInt() ?? 0,
          createdAt: createdAt,
          placeName: map['place_name'] as String?,
        ),
      );
    }
    return List<UserPriceContribution>.unmodifiable(result);
  }

  static String _zoneLabelFromId(String zoneId) {
    return switch (zoneId) {
      'vup_norte' => 'Zona Norte',
      'vup_centro' => 'Zona Centro',
      'vup_sur' => 'Zona Sur',
      'vup_oriente' => 'Zona Oriente',
      'vup_occidente' => 'Zona Occidente',
      _ => zoneId,
    };
  }
}
