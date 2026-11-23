import 'package:via_justa/features/businesses/domain/business.dart';

/// Estilo de gasto para la estimación determinística de presupuesto de viaje.
enum TripStyle {
  economy,
  standard,
  comfort,
}

/// Estado del semáforo de viabilidad cuando el usuario ingresa su presupuesto disponible.
enum BudgetFeasibility {
  comfortable,
  tight,
  short,
}

/// Claves de recomendaciones prácticas generadas por reglas determinísticas.
enum TripBudgetAdviceKey {
  shortBudget,
  eventSeason,
  centralLodging,
  verifyPrices,
}

/// Parámetros de entrada del estimador de viaje.
class TripBudgetInput {
  const TripBudgetInput({
    this.days = 3,
    this.travelers = 1,
    this.style = TripStyle.standard,
    this.includeLodging = true,
    this.isEventSeason = false,
    this.availableBudgetCop,
  });

  final int days;
  final int travelers;
  final TripStyle style;
  final bool includeLodging;
  final bool isEventSeason;
  final int? availableBudgetCop;

  TripBudgetInput copyWith({
    int? days,
    int? travelers,
    TripStyle? style,
    bool? includeLodging,
    bool? isEventSeason,
    int? availableBudgetCop,
    bool clearAvailableBudget = false,
  }) {
    return TripBudgetInput(
      days: (days ?? this.days).clamp(1, 15),
      travelers: (travelers ?? this.travelers).clamp(1, 6),
      style: style ?? this.style,
      includeLodging: includeLodging ?? this.includeLodging,
      isEventSeason: isEventSeason ?? this.isEventSeason,
      availableBudgetCop: clearAvailableBudget
          ? null
          : (availableBudgetCop ?? this.availableBudgetCop),
    );
  }
}

/// Medianas base en COP usadas por el estimador de viaje.
class TripBudgetMedians {
  const TripBudgetMedians({
    required this.lodgingNightCop,
    required this.lunchCop,
    required this.breakfastCop,
    required this.taxiRideCop,
    required this.airportTransferCop,
  });

  /// Referencia base documentada para Valledupar (20001) cuando alguna categoría aún tiene N < 3.
  static const TripBudgetMedians valleduparBaseline = TripBudgetMedians(
    lodgingNightCop: 95000,
    lunchCop: 15000,
    breakfastCop: 12000,
    taxiRideCop: 12000,
    airportTransferCop: 22000,
  );

  final int lodgingNightCop;
  final int lunchCop;
  final int breakfastCop;
  final int taxiRideCop;
  final int airportTransferCop;
}

/// Resultado determinístico del cálculo de presupuesto de viaje.
class TripBudgetBreakdown {
  const TripBudgetBreakdown({
    required this.nights,
    required this.rooms,
    required this.lodgingCop,
    required this.foodCop,
    required this.transportCop,
    required this.bufferCop,
    required this.totalCop,
    required this.perDayCop,
    required this.minRangeCop,
    required this.maxRangeCop,
    required this.lodgingPct,
    required this.foodPct,
    required this.transportPct,
    required this.bufferPct,
    required this.adviceKeys,
    this.feasibility,
    this.differenceCop,
  });

  final int nights;
  final int rooms;
  final int lodgingCop;
  final int foodCop;
  final int transportCop;
  final int bufferCop;
  final int totalCop;
  final int perDayCop;
  final int minRangeCop;
  final int maxRangeCop;
  final int lodgingPct;
  final int foodPct;
  final int transportPct;
  final int bufferPct;
  final List<TripBudgetAdviceKey> adviceKeys;
  final BudgetFeasibility? feasibility;
  final int? differenceCop;
}

/// Calcula la mediana estadística exacta de una lista de montos en COP (retorna null si N < 3).
int? computeStatisticalMedianCop(List<int> amounts) {
  if (amounts.length < 3) return null;
  final sorted = List<int>.from(amounts)..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[mid];
  }
  return ((sorted[mid - 1] + sorted[mid]) / 2).round();
}

/// Calcula el presupuesto estimado de viaje a partir de las medianas reales del municipio.
TripBudgetBreakdown calculateTripBudget(
  TripBudgetInput input,
  TripBudgetMedians medians,
) {
  final safeDays = input.days.clamp(1, 15);
  final safeTravelers = input.travelers.clamp(1, 6);
  final nights = safeDays > 1 ? safeDays - 1 : 0;
  final rooms = (safeTravelers + 1) ~/ 2;

  final styleFactor = switch (input.style) {
    TripStyle.economy => 0.80,
    TripStyle.standard => 1.00,
    TripStyle.comfort => 1.35,
  };
  final eventLodgingFactor = input.isEventSeason ? 1.25 : 1.00;
  final eventFoodFactor = input.isEventSeason ? 1.12 : 1.00;
  final eventTransportFactor = input.isEventSeason ? 1.15 : 1.00;

  // Alimentación diaria por persona: desayuno + almuerzo + cena (1.4x almuerzo).
  final dailyFoodPerPerson =
      medians.breakfastCop + medians.lunchCop + (medians.lunchCop * 1.4);

  // Transporte diario por grupo (habitación): 2 carreras urbanas + traslado llegada/salida.
  final dailyTaxiPerGroup =
      medians.taxiRideCop * 2 * (input.style == TripStyle.economy ? 0.75 : 1.0);
  final arrivalAndDeparture = medians.airportTransferCop * 2;

  final lodgingCop = input.includeLodging
      ? (nights * rooms * medians.lodgingNightCop * styleFactor * eventLodgingFactor)
          .round()
      : 0;
  final foodCop =
      (safeDays * safeTravelers * dailyFoodPerPerson * styleFactor * eventFoodFactor)
          .round();
  final transportCop =
      (((safeDays * dailyTaxiPerGroup) + arrivalAndDeparture) *
              rooms *
              eventTransportFactor)
          .round();

  final subtotal = lodgingCop + foodCop + transportCop;
  final bufferCop = (subtotal * 0.10).round();
  final totalCop = subtotal + bufferCop;
  final perDayCop = (totalCop / safeDays).round();
  final minRangeCop = (totalCop * 0.86).round();
  final maxRangeCop = (totalCop * 1.22).round();

  final lodgingPct = totalCop > 0 ? ((lodgingCop / totalCop) * 100).round() : 0;
  final foodPct = totalCop > 0 ? ((foodCop / totalCop) * 100).round() : 0;
  final transportPct =
      totalCop > 0 ? ((transportCop / totalCop) * 100).round() : 0;
  final bufferPct = (100 - lodgingPct - foodPct - transportPct).clamp(0, 100);

  BudgetFeasibility? feasibility;
  int? differenceCop;
  final available = input.availableBudgetCop;
  if (available != null && available > 0) {
    differenceCop = available - totalCop;
    if (differenceCop >= (totalCop * 0.08).round()) {
      feasibility = BudgetFeasibility.comfortable;
    } else if (differenceCop >= -(totalCop * 0.12).round()) {
      feasibility = BudgetFeasibility.tight;
    } else {
      feasibility = BudgetFeasibility.short;
    }
  }

  final advice = <TripBudgetAdviceKey>[];
  if (feasibility == BudgetFeasibility.short) {
    advice.add(TripBudgetAdviceKey.shortBudget);
  }
  if (input.isEventSeason) {
    advice.add(TripBudgetAdviceKey.eventSeason);
  }
  if (input.includeLodging) {
    advice.add(TripBudgetAdviceKey.centralLodging);
  }
  advice.add(TripBudgetAdviceKey.verifyPrices);

  return TripBudgetBreakdown(
    nights: nights,
    rooms: rooms,
    lodgingCop: lodgingCop,
    foodCop: foodCop,
    transportCop: transportCop,
    bufferCop: bufferCop,
    totalCop: totalCop,
    perDayCop: perDayCop,
    minRangeCop: minRangeCop,
    maxRangeCop: maxRangeCop,
    lodgingPct: lodgingPct,
    foodPct: foodPct,
    transportPct: transportPct,
    bufferPct: bufferPct,
    adviceKeys: List<TripBudgetAdviceKey>.unmodifiable(advice),
    feasibility: feasibility,
    differenceCop: differenceCop,
  );
}

/// Selecciona comercios publicados del directorio relevantes para un viaje (hospedaje y comida).
List<Business> selectTripRelevantBusinesses(
  List<Business> allBusinesses, {
  required bool includeLodging,
  int maxResults = 4,
}) {
  final lodging = <Business>[];
  final food = <Business>[];
  for (final business in allBusinesses) {
    if (!business.isApproved) continue;
    if (business.category == BusinessCategory.lodging) {
      lodging.add(business);
    } else if (business.category == BusinessCategory.food) {
      food.add(business);
    }
  }

  final selected = <Business>[];
  if (includeLodging) {
    selected.addAll(lodging.take(2));
  }
  selected.addAll(food.take(maxResults - selected.length));
  if (selected.length < maxResults && includeLodging) {
    for (final b in lodging.skip(2)) {
      if (selected.length >= maxResults) break;
      selected.add(b);
    }
  }
  return List<Business>.unmodifiable(selected);
}
