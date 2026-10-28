/// Categoría comparable del catálogo de precios (`public.price_categories`).
class PriceCategory {
  const PriceCategory({
    required this.id,
    required this.groupKey,
    required this.nameEs,
    required this.nameEn,
    required this.unitDescriptionEs,
    required this.unitDescriptionEn,
    this.sortOrder = 0,
    this.isActive = true,
  });

  /// Identificador técnico estable (ej. `transport_taxi_minimal`).
  final String id;

  /// Grupo temático (`transport`, `food`, `lodging`, `services`).
  final String groupKey;

  /// Nombre de la categoría en español.
  final String nameEs;

  /// Nombre de la categoría en inglés.
  final String nameEn;

  /// Unidad comparable en español (ej. "Carrera mínima diurna urbana").
  final String unitDescriptionEs;

  /// Unidad comparable en inglés (ej. "Standard urban daytime ride").
  final String unitDescriptionEn;

  final int sortOrder;
  final bool isActive;

  /// Retorna el nombre según el código de idioma activo (`es` o `en`).
  String localizedName(String languageCode) {
    return languageCode == 'en' ? nameEn : nameEs;
  }

  /// Retorna la descripción de unidad comparable según el idioma activo (`es` o `en`).
  String localizedUnit(String languageCode) {
    return languageCode == 'en' ? unitDescriptionEn : unitDescriptionEs;
  }
}
