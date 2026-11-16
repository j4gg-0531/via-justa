import 'package:via_justa/features/businesses/domain/business_detail.dart';
import 'package:via_justa/features/businesses/domain/business_draft.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';

/// Devuelve el grupo de catálogo de precios (`group_key`) equivalente al tipo de negocio.
String priceGroupKeyForBusinessType(BusinessType type) {
  switch (type) {
    case BusinessType.restaurant:
      return 'food';
    case BusinessType.hotel:
      return 'lodging';
    case BusinessType.transport:
      return 'transport';
    case BusinessType.service:
    case BusinessType.handicraft:
      return 'services';
  }
}

/// Filtra las categorías comparables activas del catálogo de precios que aplican al tipo de negocio.
List<PriceCategory> comparableCategoriesForBusinessType(
  BusinessType businessType,
  List<PriceCategory> allCategories,
) {
  final groupKey = priceGroupKeyForBusinessType(businessType);
  return allCategories
      .where((cat) => cat.isActive && cat.groupKey == groupKey)
      .toList();
}

/// Aviso privado y orientativo de comparación de precio por zona para el dueño del negocio.
class BusinessPriceNotice {
  const BusinessPriceNotice({
    required this.categoryId,
    required this.categoryNameEs,
    required this.categoryNameEn,
    required this.unitDescriptionEs,
    required this.unitDescriptionEn,
    required this.zoneId,
    required this.level,
    required this.enteredCop,
    required this.sampleCount,
    this.medianCop,
    this.differenceCop,
    this.deviationPct,
  });

  final String categoryId;
  final String categoryNameEs;
  final String categoryNameEn;
  final String unitDescriptionEs;
  final String unitDescriptionEn;
  final String zoneId;
  final PriceVerdictLevel level;
  final int enteredCop;
  final int? medianCop;
  final int? differenceCop;
  final double? deviationPct;
  final int sampleCount;

  bool get isInsufficient =>
      level == PriceVerdictLevel.insufficient || medianCop == null;

  String get formattedEnteredCop => formatCopAmount(enteredCop);

  String get formattedMedianCop =>
      medianCop == null ? '' : formatCopAmount(medianCop!);

  /// Diferencia con signo respecto a la mediana zonal (ej. `+$3.000 COP`, `-$2.000 COP` o `$0 COP`).
  String get formattedDifferenceCop {
    final diff = differenceCop;
    if (diff == null) return '';
    if (diff == 0) return formatCopAmount(0);
    final sign = diff > 0 ? '+' : '-';
    return '$sign${formatCopAmount(diff.abs())}';
  }

  /// Porcentaje de desviación con signo (ej. `+25,0 %`).
  String get formattedDeviationPct {
    final pct = deviationPct;
    if (pct == null) return '';
    final sign = pct > 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1).replaceAll('.', ',')} %';
  }

  String localizedCategoryName(String languageCode) =>
      languageCode.toLowerCase().startsWith('en')
      ? categoryNameEn
      : categoryNameEs;

  String localizedUnitDescription(String languageCode) =>
      languageCode.toLowerCase().startsWith('en')
      ? unitDescriptionEn
      : unitDescriptionEs;
}

/// Construye el aviso orientativo para el dueño a partir del veredicto del semáforo por zona.
BusinessPriceNotice buildBusinessPriceNotice({
  required PriceCategory category,
  required PriceVerdict verdict,
}) {
  final median = verdict.isInsufficient ? null : verdict.referenceCop;
  final diff = median == null ? null : verdict.submittedCop - median;

  return BusinessPriceNotice(
    categoryId: category.id,
    categoryNameEs: category.nameEs,
    categoryNameEn: category.nameEn,
    unitDescriptionEs: category.unitDescriptionEs,
    unitDescriptionEn: category.unitDescriptionEn,
    zoneId: verdict.zoneId,
    level: verdict.level,
    enteredCop: verdict.submittedCop,
    medianCop: median,
    differenceCop: diff,
    deviationPct: verdict.isInsufficient ? null : verdict.deviationPct,
    sampleCount: verdict.n,
  );
}
