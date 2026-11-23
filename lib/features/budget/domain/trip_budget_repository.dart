import 'package:via_justa/features/budget/domain/trip_budget.dart';

/// Repositorio que provee las medianas reales de referencia para el estimador de viaje.
abstract class TripBudgetRepository {
  Future<TripBudgetMedians> getMedians({required String municipalityCode});
}
