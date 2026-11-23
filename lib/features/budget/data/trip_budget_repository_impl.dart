import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/budget/domain/trip_budget.dart';
import 'package:via_justa/features/budget/domain/trip_budget_repository.dart';

/// Repositorio local/DEMO con las medianas base de referencia de Valledupar.
class DemoTripBudgetRepository implements TripBudgetRepository {
  const DemoTripBudgetRepository();

  @override
  Future<TripBudgetMedians> getMedians({
    required String municipalityCode,
  }) async {
    return TripBudgetMedians.valleduparBaseline;
  }
}

/// Consulta reportes públicos vigentes en `public.price_reports` y calcula las
/// medianas estadísticas reales por categoría para el estimador de viaje.
class SupabaseTripBudgetRepository implements TripBudgetRepository {
  const SupabaseTripBudgetRepository(this._client);

  final SupabaseClient _client;

  static const List<String> _targetCategories = <String>[
    'lodging_standard_night',
    'food_corrientazo',
    'food_breakfast',
    'transport_taxi_minimal',
    'transport_airport_transfer',
  ];

  @override
  Future<TripBudgetMedians> getMedians({
    required String municipalityCode,
  }) async {
    try {
      final rows = await _client
          .from('price_reports')
          .select('category_id, amount_cop')
          .eq('municipality_code', municipalityCode)
          .eq('is_hidden', false)
          .eq('is_demo', false)
          .inFilter('category_id', _targetCategories)
          .limit(300);

      final grouped = <String, List<int>>{};
      for (final raw in (rows as List<dynamic>)) {
        final map = raw as Map<String, dynamic>;
        final categoryId = map['category_id'] as String?;
        final amount = (map['amount_cop'] as num?)?.toInt();
        if (categoryId == null || amount == null || amount <= 0) continue;
        grouped.putIfAbsent(categoryId, () => <int>[]).add(amount);
      }

      const fallback = TripBudgetMedians.valleduparBaseline;
      return TripBudgetMedians(
        lodgingNightCop:
            computeStatisticalMedianCop(
              grouped['lodging_standard_night'] ?? const <int>[],
            ) ??
            fallback.lodgingNightCop,
        lunchCop:
            computeStatisticalMedianCop(
              grouped['food_corrientazo'] ?? const <int>[],
            ) ??
            fallback.lunchCop,
        breakfastCop:
            computeStatisticalMedianCop(
              grouped['food_breakfast'] ?? const <int>[],
            ) ??
            fallback.breakfastCop,
        taxiRideCop:
            computeStatisticalMedianCop(
              grouped['transport_taxi_minimal'] ?? const <int>[],
            ) ??
            fallback.taxiRideCop,
        airportTransferCop:
            computeStatisticalMedianCop(
              grouped['transport_airport_transfer'] ?? const <int>[],
            ) ??
            fallback.airportTransferCop,
      );
    } catch (_) {
      return TripBudgetMedians.valleduparBaseline;
    }
  }
}
