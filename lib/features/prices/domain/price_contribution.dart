import 'package:via_justa/features/prices/domain/price_verdict.dart';

/// Errores tipados de validación para el monto de un aporte ciudadano de precio.
enum PriceContributionAmountError {
  /// El campo de monto está vacío.
  empty,

  /// El valor ingresado no es un número entero positivo válido.
  notPositiveNumber,

  /// El monto es inferior al mínimo razonable en COP ($500 COP).
  belowMinimum,

  /// El monto supera el tope máximo razonable por reporte ($20.000.000 COP).
  aboveMaximum,
}

/// Monto mínimo razonable para un reporte ciudadano en pesos colombianos ($500 COP).
const int kMinContributionCop = 500;

/// Monto máximo razonable para un reporte ciudadano en pesos colombianos ($20.000.000 COP).
const int kMaxContributionCop = 20000000;

/// Longitud máxima permitida para la nota o referencia opcional del lugar.
const int kMaxPlaceNoteLength = 120;

/// Valida que el identificador de categoría no esté vacío (Paso 1 del wizard M10).
bool isValidContributionCategory(String categoryId) {
  return categoryId.trim().isNotEmpty;
}

/// Valida el monto en COP ingresado en el Paso 2 del wizard M10.
/// Retorna `null` si el monto es válido, o el `PriceContributionAmountError` correspondiente.
PriceContributionAmountError? validateContributionAmount(String rawInput) {
  if (rawInput.trim().isEmpty) {
    return PriceContributionAmountError.empty;
  }
  final parsed = parseCopAmount(rawInput);
  if (parsed == null) {
    return PriceContributionAmountError.notPositiveNumber;
  }
  if (parsed < kMinContributionCop) {
    return PriceContributionAmountError.belowMinimum;
  }
  if (parsed > kMaxContributionCop) {
    return PriceContributionAmountError.aboveMaximum;
  }
  return null;
}

/// Valida que el identificador de zona del municipio no esté vacío (Paso 3 del wizard M10).
bool isValidContributionZone(String zoneId) {
  return zoneId.trim().isNotEmpty;
}

/// Limpia y recorta la nota opcional de referencia del lugar (máximo 120 caracteres).
/// Retorna `null` si queda vacía.
String? sanitizeContributionNote(String rawNote) {
  final trimmed = rawNote.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.length <= kMaxPlaceNoteLength) return trimmed;
  return trimmed.substring(0, kMaxPlaceNoteLength);
}

/// Registro inmutable de un aporte ciudadano de precio (M10).
/// Conciliado con la tabla `public.price_reports` en `docs/contrato-datos-v1.md`.
class PriceContributionRecord {
  const PriceContributionRecord({
    required this.id,
    required this.categoryId,
    required this.municipalityCode,
    required this.zoneId,
    required this.amountCop,
    required this.createdAtIso,
    this.placeNote,
    this.isDemo = true,
  });

  final String id;
  final String categoryId;
  final String municipalityCode;
  final String zoneId;
  final int amountCop;
  final String? placeNote;
  final String createdAtIso;
  final bool isDemo;

  /// Convierte el aporte al formato de inserción de `public.price_reports`.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'category_id': categoryId,
      'municipality_code': municipalityCode,
      'zone_id': zoneId,
      'amount_cop': amountCop,
      'place_name': placeNote,
      'is_demo': isDemo,
      'created_at': createdAtIso,
    };
  }
}
