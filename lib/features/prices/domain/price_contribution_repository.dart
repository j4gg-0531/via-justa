import 'package:via_justa/features/prices/domain/price_contribution.dart';

/// Contrato abstracto para el envío y consulta de aportes ciudadanos de precios (M10).
/// En VJ-05 almacena los aportes en memoria rotulados como DEMO;
/// en VJ-11 se reemplaza por inserciones reales en `public.price_reports` (Supabase).
abstract class PriceContributionRepository {
  /// Guarda un nuevo aporte de precio para una categoría, municipio y zona.
  Future<PriceContributionRecord> submitContribution({
    required String categoryId,
    required String municipalityCode,
    required String zoneId,
    required int amountCop,
    String? placeNote,
  });

  /// Retorna los aportes guardados localmente durante la sesión actual.
  Future<List<PriceContributionRecord>> getSubmittedContributions();

  /// Limpia los aportes temporales en memoria al cerrar sesión.
  void clearSessionContributions();
}
