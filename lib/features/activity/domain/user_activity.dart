import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';

/// Registro local de una consulta reciente del semáforo de precios.
class RecentPriceCheck {
  const RecentPriceCheck({
    required this.id,
    required this.categoryId,
    required this.categoryNameEs,
    required this.categoryNameEn,
    required this.zoneName,
    required this.observedCop,
    required this.level,
    required this.checkedAt,
    this.medianCop,
    this.recommendedCapCop,
    this.deviationPct,
  });

  final String id;
  final String categoryId;
  final String categoryNameEs;
  final String categoryNameEn;
  final String zoneName;
  final int observedCop;
  final PriceVerdictLevel level;
  final DateTime checkedAt;
  final int? medianCop;
  final int? recommendedCapCop;
  final double? deviationPct;

  String localizedCategoryName(String languageCode) {
    return languageCode.toLowerCase().startsWith('en')
        ? categoryNameEn
        : categoryNameEs;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'categoryId': categoryId,
    'categoryNameEs': categoryNameEs,
    'categoryNameEn': categoryNameEn,
    'zoneName': zoneName,
    'observedCop': observedCop,
    'level': level.name,
    'checkedAt': checkedAt.toIso8601String(),
    'medianCop': medianCop,
    'recommendedCapCop': recommendedCapCop,
    'deviationPct': deviationPct,
  };

  static RecentPriceCheck? fromMap(Map<String, dynamic> map) {
    final id = map['id'] as String?;
    final categoryId = map['categoryId'] as String?;
    final categoryNameEs = map['categoryNameEs'] as String?;
    final categoryNameEn = map['categoryNameEn'] as String?;
    final zoneName = map['zoneName'] as String?;
    final observedCop = (map['observedCop'] as num?)?.toInt();
    final levelName = map['level'] as String?;
    final checkedAtRaw = map['checkedAt'] as String?;
    if (id == null ||
        categoryId == null ||
        categoryNameEs == null ||
        categoryNameEn == null ||
        zoneName == null ||
        observedCop == null ||
        levelName == null ||
        checkedAtRaw == null) {
      return null;
    }

    final checkedAt = DateTime.tryParse(checkedAtRaw);
    if (checkedAt == null) return null;

    PriceVerdictLevel? parsedLevel;
    for (final value in PriceVerdictLevel.values) {
      if (value.name == levelName) {
        parsedLevel = value;
        break;
      }
    }
    if (parsedLevel == null) return null;

    return RecentPriceCheck(
      id: id,
      categoryId: categoryId,
      categoryNameEs: categoryNameEs,
      categoryNameEn: categoryNameEn,
      zoneName: zoneName,
      observedCop: observedCop,
      level: parsedLevel,
      checkedAt: checkedAt,
      medianCop: (map['medianCop'] as num?)?.toInt(),
      recommendedCapCop: (map['recommendedCapCop'] as num?)?.toInt(),
      deviationPct: (map['deviationPct'] as num?)?.toDouble(),
    );
  }
}

/// Aporte de precio publicado por el usuario actual (`public.price_reports`).
class UserPriceContribution {
  const UserPriceContribution({
    required this.id,
    required this.categoryId,
    required this.categoryNameEs,
    required this.categoryNameEn,
    required this.zoneName,
    required this.amountCop,
    required this.createdAt,
    this.placeName,
  });

  final String id;
  final String categoryId;
  final String categoryNameEs;
  final String categoryNameEn;
  final String zoneName;
  final int amountCop;
  final DateTime createdAt;
  final String? placeName;

  String localizedCategoryName(String languageCode) {
    return languageCode.toLowerCase().startsWith('en')
        ? categoryNameEn
        : categoryNameEs;
  }
}

/// Estado local de memoria del usuario: consultas recientes y negocios favoritos.
class UserActivityState {
  const UserActivityState({
    this.recentChecks = const <RecentPriceCheck>[],
    this.favoriteBusinessIds = const <String>{},
  });

  final List<RecentPriceCheck> recentChecks;
  final Set<String> favoriteBusinessIds;

  bool isFavorite(String businessId) => favoriteBusinessIds.contains(businessId);
}

/// Inserta una consulta reciente al inicio de la lista manteniendo un máximo acotado.
List<RecentPriceCheck> prependRecentPriceCheck(
  List<RecentPriceCheck> current,
  RecentPriceCheck next, {
  int maxItems = 20,
}) {
  final updated = <RecentPriceCheck>[
    next,
    for (final item in current)
      if (item.id != next.id) item,
  ];
  if (updated.length > maxItems) {
    return List<RecentPriceCheck>.unmodifiable(updated.sublist(0, maxItems));
  }
  return List<RecentPriceCheck>.unmodifiable(updated);
}

/// Alterna un negocio dentro del conjunto inmutable de favoritos del usuario.
Set<String> toggleFavoriteBusinessId(
  Set<String> current,
  String businessId,
) {
  final cleanId = businessId.trim();
  if (cleanId.isEmpty) return Set<String>.unmodifiable(current);
  final next = Set<String>.from(current);
  if (!next.remove(cleanId)) {
    next.add(cleanId);
  }
  return Set<String>.unmodifiable(next);
}

/// Resuelve los objetos [Business] que el usuario marcó como favoritos preservando orden.
List<Business> resolveFavoriteBusinesses(
  List<Business> allBusinesses,
  Set<String> favoriteIds,
) {
  if (favoriteIds.isEmpty || allBusinesses.isEmpty) {
    return const <Business>[];
  }
  return List<Business>.unmodifiable(
    allBusinesses.where((business) => favoriteIds.contains(business.id)),
  );
}

/// Suma total de elementos en "Mi actividad" para el contador de Perfil.
int computeActivityTotalCount({
  required int checksCount,
  required int favoritesCount,
  required int contributionsCount,
}) {
  return checksCount + favoritesCount + contributionsCount;
}
