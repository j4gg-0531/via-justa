import 'package:via_justa/features/prices/domain/price_category.dart';

/// Audiencia de filtrado para las categorías de precio en la vista de evaluación.
enum PriceCategoryAudience {
  all,
  travel,
  living,
}

/// Indica si una categoría corresponde principalmente al costo de vida (migrantes / residentes).
bool isLivingPriceCategory(PriceCategory category) {
  final group = category.groupKey.trim().toLowerCase();
  if (group == 'housing' || group == 'groceries' || group == 'services') {
    return true;
  }
  return category.id.startsWith('housing_') ||
      category.id.startsWith('groceries_') ||
      category.id == 'services_laundry_load';
}

/// Indica si una categoría corresponde principalmente a gastos de viaje / turismo.
bool isTravelPriceCategory(PriceCategory category) {
  final group = category.groupKey.trim().toLowerCase();
  return group == 'transport' || group == 'food' || group == 'lodging';
}

/// Filtra el catálogo de categorías según la audiencia seleccionada.
List<PriceCategory> filterPriceCategoriesByAudience(
  List<PriceCategory> categories,
  PriceCategoryAudience audience,
) {
  switch (audience) {
    case PriceCategoryAudience.all:
      return List<PriceCategory>.unmodifiable(categories);
    case PriceCategoryAudience.travel:
      return List<PriceCategory>.unmodifiable(
        categories.where(isTravelPriceCategory),
      );
    case PriceCategoryAudience.living:
      return List<PriceCategory>.unmodifiable(
        categories.where(isLivingPriceCategory),
      );
  }
}

/// Indica si el catálogo activo contiene categorías tanto de viaje como de costo de vida.
bool hasMultiplePriceAudiences(List<PriceCategory> categories) {
  final hasTravel = categories.any(isTravelPriceCategory);
  final hasLiving = categories.any(isLivingPriceCategory);
  return hasTravel && hasLiving;
}
