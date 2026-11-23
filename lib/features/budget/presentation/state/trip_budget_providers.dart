import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/budget/data/trip_budget_repository_impl.dart';
import 'package:via_justa/features/budget/domain/trip_budget.dart';
import 'package:via_justa/features/budget/domain/trip_budget_repository.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';

final tripBudgetRepositoryProvider = Provider<TripBudgetRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client != null) {
    return SupabaseTripBudgetRepository(client);
  }
  return const DemoTripBudgetRepository();
});

/// Medianas reales del municipio activo para alimentar la calculadora de viaje.
final tripBudgetMediansProvider = FutureProvider<TripBudgetMedians>((ref) {
  final code = ref.watch(selectedMunicipalityProvider)?.code ?? '20001';
  return ref
      .watch(tripBudgetRepositoryProvider)
      .getMedians(municipalityCode: code);
});

/// Controlador del formulario del estimador de presupuesto (se reinicia al salir).
class TripBudgetInputNotifier extends Notifier<TripBudgetInput> {
  @override
  TripBudgetInput build() => const TripBudgetInput();

  void changeDays(int delta) {
    state = state.copyWith(days: state.days + delta);
  }

  void changeTravelers(int delta) {
    state = state.copyWith(travelers: state.travelers + delta);
  }

  void selectStyle(TripStyle style) {
    state = state.copyWith(style: style);
  }

  void setIncludeLodging(bool value) {
    state = state.copyWith(includeLodging: value);
  }

  void setEventSeason(bool value) {
    state = state.copyWith(isEventSeason: value);
  }

  void setAvailableBudget(int? amountCop) {
    if (amountCop == null || amountCop <= 0) {
      state = state.copyWith(clearAvailableBudget: true);
    } else {
      state = state.copyWith(availableBudgetCop: amountCop);
    }
  }
}

final tripBudgetInputProvider =
    NotifierProvider.autoDispose<TripBudgetInputNotifier, TripBudgetInput>(
      TripBudgetInputNotifier.new,
    );

/// Desglose determinístico vivo que combina los parámetros del usuario con las medianas reales.
final tripBudgetBreakdownProvider = Provider.autoDispose<TripBudgetBreakdown>((
  ref,
) {
  final input = ref.watch(tripBudgetInputProvider);
  final medians =
      ref.watch(tripBudgetMediansProvider).asData?.value ??
      TripBudgetMedians.valleduparBaseline;
  return calculateTripBudget(input, medians);
});

/// Comercios reales del directorio que se ajustan al viaje planificado.
final tripBudgetBusinessesProvider = Provider.autoDispose<List<Business>>((
  ref,
) {
  final input = ref.watch(tripBudgetInputProvider);
  final allBusinesses =
      ref.watch(allBusinessesProvider).asData?.value ?? const <Business>[];
  return selectTripRelevantBusinesses(
    allBusinesses,
    includeLodging: input.includeLodging,
  );
});
