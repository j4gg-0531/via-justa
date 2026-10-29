import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/features/contracts/presentation/state/contract_analysis_provider.dart';
import 'package:via_justa/features/contracts/domain/contract_analysis.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/prices/data/demo_price_verdict_repository.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';
import 'package:via_justa/features/prices/domain/price_verdict_repository.dart';

/// Proveedor del repositorio de veredictos de precio (Ãºnico lugar que conoce la implementaciÃ³n concreta).
final priceVerdictRepositoryProvider = Provider<PriceVerdictRepository>((ref) {
  return const DemoPriceVerdictRepository();
});

/// CatÃ¡logo de zonas del municipio activo para segmentar las medianas estadÃ­sticas (ej. Norte, Centro, Sur, Oriente, Occidente en Valledupar).
final municipalityZonesProvider = FutureProvider<List<MunicipalityZone>>((ref) {
  final municipality = ref.watch(selectedMunicipalityProvider);
  final code = municipality?.code ?? '20001';
  return ref
      .watch(priceVerdictRepositoryProvider)
      .getZones(municipalityCode: code);
});

/// CatÃ¡logo de categorÃ­as comparables obtenido desde el repositorio.
final priceCategoriesProvider = FutureProvider<List<PriceCategory>>((ref) {
  return ref.watch(priceVerdictRepositoryProvider).getCategories();
});


/// Ejemplo demostrativo de anÃ¡lisis de contrato para la pestaÃ±a Contratos.
final demoContractAnalysisProvider = FutureProvider<ContractAnalysis>((ref) {
  return ref.watch(contractAnalysisRepositoryProvider).getDemoSampleAnalysis();
});

/// Estado del formulario y evaluaciÃ³n del semÃ¡foro de precios por zona del municipio (M06 / M07 / M20).
class PriceScanState {
  const PriceScanState({
    this.selectedZoneId = 'vup_centro',
    this.locationPermission = LocationPermissionStatus.prompt,
    this.isManualMapOpen = false,
    this.pinNormalizedX = 0.50,
    this.pinNormalizedY = 0.50,
    this.selectedCategoryId = 'transport_taxi_minimal',
    this.rawAmount = '12500',
    this.includeEventContext = false,
    this.selectedScenario = DemoPriceScenario.yellowModerate,
    this.amountError = false,
    this.verdictAsync = const AsyncData<PriceVerdict?>(null),
  });

  final String selectedZoneId;
  final LocationPermissionStatus locationPermission;
  final bool isManualMapOpen;
  final double pinNormalizedX;
  final double pinNormalizedY;
  final String selectedCategoryId;
  final String rawAmount;
  final bool includeEventContext;
  final DemoPriceScenario? selectedScenario;
  final bool amountError;
  final AsyncValue<PriceVerdict?> verdictAsync;

  /// Monto formateado listo para mostrar en controles auxiliares.
  int? get parsedAmount => parseCopAmount(rawAmount);

  /// Coordenada horizontal del pin del usuario en rango de alineaciÃ³n [-1.0, 1.0].
  double get pinAlignmentX => (pinNormalizedX * 2) - 1;

  /// Coordenada vertical del pin del usuario en rango de alineaciÃ³n [-1.0, 1.0].
  double get pinAlignmentY => (pinNormalizedY * 2) - 1;

  /// Indica si se debe mostrar el mapa manual para elegir zona (cuando se deniega permiso o se abre manualmente).
  bool get shouldShowMapPicker =>
      locationPermission == LocationPermissionStatus.denied || isManualMapOpen;

  PriceScanState copyWith({
    String? selectedZoneId,
    LocationPermissionStatus? locationPermission,
    bool? isManualMapOpen,
    double? pinNormalizedX,
    double? pinNormalizedY,
    String? selectedCategoryId,
    String? rawAmount,
    bool? includeEventContext,
    DemoPriceScenario? selectedScenario,
    bool clearScenario = false,
    bool? amountError,
    AsyncValue<PriceVerdict?>? verdictAsync,
  }) {
    return PriceScanState(
      selectedZoneId: selectedZoneId ?? this.selectedZoneId,
      locationPermission: locationPermission ?? this.locationPermission,
      isManualMapOpen: isManualMapOpen ?? this.isManualMapOpen,
      pinNormalizedX: pinNormalizedX ?? this.pinNormalizedX,
      pinNormalizedY: pinNormalizedY ?? this.pinNormalizedY,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      rawAmount: rawAmount ?? this.rawAmount,
      includeEventContext: includeEventContext ?? this.includeEventContext,
      selectedScenario:
          clearScenario ? null : (selectedScenario ?? this.selectedScenario),
      amountError: amountError ?? this.amountError,
      verdictAsync: verdictAsync ?? this.verdictAsync,
    );
  }
}

/// Controlador de escaneo y evaluaciÃ³n de precios por zona del municipio.
/// Gestiona concurrencia mediante `_requestToken` para descartar respuestas obsoletas
/// y limpiar resultados previos al iniciar una nueva bÃºsqueda.
class PriceScanNotifier extends Notifier<PriceScanState> {
  int _requestToken = 0;

  @override
  PriceScanState build() => const PriceScanState();

  /// Concede permiso de ubicaciÃ³n del telÃ©fono y autodetecta la zona actual por GPS.
  Future<void> grantLocationPermissionAndDetect({
    String municipalityCode = '20001',
  }) async {
    _requestToken++;
    final repository = ref.read(priceVerdictRepositoryProvider);
    final detectedZone = await repository.detectCurrentZoneByGps(
      municipalityCode: municipalityCode,
    );
    state = state.copyWith(
      locationPermission: LocationPermissionStatus.granted,
      isManualMapOpen: false,
      selectedZoneId: detectedZone.id,
      pinNormalizedX: detectedZone.normalizedX,
      pinNormalizedY: detectedZone.normalizedY,
      clearScenario: true,
      amountError: false,
      verdictAsync: const AsyncData<PriceVerdict?>(null),
    );
  }

  /// Deniega el permiso de ubicaciÃ³n del telÃ©fono y habilita el mapa interactivo para selecciÃ³n manual.
  void denyLocationPermissionAndOpenMap() {
    _requestToken++;
    state = state.copyWith(
      locationPermission: LocationPermissionStatus.denied,
      isManualMapOpen: true,
      verdictAsync: const AsyncData<PriceVerdict?>(null),
    );
  }

  /// Abre o cierra el mapa interactivo de selecciÃ³n manual de zona.
  void toggleManualMapPicker(bool open) {
    state = state.copyWith(isManualMapOpen: open);
  }

  /// Cambia la zona del municipio seleccionada directamente y descarta cualquier veredicto anterior.
  void selectZone(String zoneId) {
    _requestToken++;
    final zones = ref.read(municipalityZonesProvider).value;
    double? nextX;
    double? nextY;
    if (zones != null) {
      for (final z in zones) {
        if (z.id == zoneId) {
          nextX = z.normalizedX;
          nextY = z.normalizedY;
          break;
        }
      }
    }
    state = state.copyWith(
      selectedZoneId: zoneId,
      pinNormalizedX: nextX,
      pinNormalizedY: nextY,
      clearScenario: true,
      amountError: false,
      verdictAsync: const AsyncData<PriceVerdict?>(null),
    );
  }

  /// Selecciona una zona al tocar un punto `(normalizedX, normalizedY)` en el mapa del municipio.
  /// Usa la funciÃ³n pura `resolveNearestZoneByNormalizedPoint` en `domain/`.
  void selectPointOnMap({
    required double normalizedX,
    required double normalizedY,
    required List<MunicipalityZone> zones,
  }) {
    final resolvedZone = resolveNearestZoneByNormalizedPoint(
      zones: zones,
      normalizedX: normalizedX,
      normalizedY: normalizedY,
    );
    if (resolvedZone == null) return;

    _requestToken++;
    final clampedX = normalizedX.clamp(0.08, 0.92);
    final clampedY = normalizedY.clamp(0.10, 0.90);

    state = state.copyWith(
      selectedZoneId: resolvedZone.id,
      pinNormalizedX: clampedX,
      pinNormalizedY: clampedY,
      isManualMapOpen: true,
      clearScenario: true,
      amountError: false,
      verdictAsync: const AsyncData<PriceVerdict?>(null),
    );
  }

  /// Cambia la categorÃ­a comparable seleccionada y descarta cualquier veredicto anterior.
  void selectCategory(String categoryId) {
    _requestToken++;
    state = state.copyWith(
      selectedCategoryId: categoryId,
      clearScenario: true,
      amountError: false,
      verdictAsync: const AsyncData<PriceVerdict?>(null),
    );
  }

  /// Actualiza el monto escrito por el usuario y descarta cualquier veredicto anterior.
  void setRawAmount(String value) {
    _requestToken++;
    state = state.copyWith(
      rawAmount: value,
      clearScenario: true,
      amountError: false,
      verdictAsync: const AsyncData<PriceVerdict?>(null),
    );
  }

  /// Activa o desactiva la simulaciÃ³n de temporada de evento DEMO.
  void setIncludeEventContext(bool value) {
    _requestToken++;
    state = state.copyWith(
      includeEventContext: value,
      verdictAsync: const AsyncData<PriceVerdict?>(null),
    );
  }

  /// Selecciona un escenario rÃ¡pido de demostraciÃ³n sincronizando zona, pin en el mapa, categorÃ­a y monto.
  void selectPresetScenario(DemoPriceScenario scenario) {
    _requestToken++;
    switch (scenario) {
      case DemoPriceScenario.greenFair:
        state = state.copyWith(
          selectedScenario: scenario,
          selectedZoneId: 'vup_centro',
          pinNormalizedX: 0.50,
          pinNormalizedY: 0.50,
          selectedCategoryId: 'food_corrientazo',
          rawAmount: '12000',
          amountError: false,
          verdictAsync: const AsyncData<PriceVerdict?>(null),
        );
      case DemoPriceScenario.yellowModerate:
        state = state.copyWith(
          selectedScenario: scenario,
          selectedZoneId: 'vup_centro',
          pinNormalizedX: 0.50,
          pinNormalizedY: 0.50,
          selectedCategoryId: 'transport_taxi_minimal',
          rawAmount: '12500',
          amountError: false,
          verdictAsync: const AsyncData<PriceVerdict?>(null),
        );
      case DemoPriceScenario.redOvercharge:
        state = state.copyWith(
          selectedScenario: scenario,
          selectedZoneId: 'vup_sur',
          pinNormalizedX: 0.52,
          pinNormalizedY: 0.82,
          selectedCategoryId: 'transport_taxi_minimal',
          rawAmount: '45000',
          amountError: false,
          verdictAsync: const AsyncData<PriceVerdict?>(null),
        );
      case DemoPriceScenario.insufficientSample:
        state = state.copyWith(
          selectedScenario: scenario,
          selectedZoneId: 'vup_occidente',
          pinNormalizedX: 0.20,
          pinNormalizedY: 0.52,
          selectedCategoryId: 'services_laundry_load',
          rawAmount: '18000',
          amountError: false,
          verdictAsync: const AsyncData<PriceVerdict?>(null),
        );
      case DemoPriceScenario.lowPriceAlert:
        state = state.copyWith(
          selectedScenario: scenario,
          selectedZoneId: 'vup_norte',
          pinNormalizedX: 0.50,
          pinNormalizedY: 0.20,
          selectedCategoryId: 'food_corrientazo',
          rawAmount: '8000',
          amountError: false,
          verdictAsync: const AsyncData<PriceVerdict?>(null),
        );
    }
  }

  /// EvalÃºa un escenario DEMO explÃ­cito limpiando de inmediato el estado anterior.
  Future<bool> evaluateScenario(
    DemoPriceScenario scenario, {
    String municipalityCode = '20001',
  }) async {
    selectPresetScenario(scenario);
    final currentToken = ++_requestToken;
    state = state.copyWith(
      verdictAsync: const AsyncLoading<PriceVerdict?>(),
    );

    try {
      final repository = ref.read(priceVerdictRepositoryProvider);
      final verdict = await repository.getScenarioFixture(
        scenario,
        municipalityCode: municipalityCode,
        zoneId: state.selectedZoneId,
        includeEventContext: state.includeEventContext,
      );
      if (currentToken != _requestToken) return false;
      state = state.copyWith(
        verdictAsync: AsyncData<PriceVerdict?>(verdict),
      );
      return true;
    } catch (error, stackTrace) {
      if (currentToken != _requestToken) return false;
      state = state.copyWith(
        verdictAsync: AsyncError<PriceVerdict?>(error, stackTrace),
      );
      return false;
    }
  }

  /// Valida el monto y evalÃºa la consulta actual contra la mediana de la zona seleccionada.
  /// Limpia inmediatamente cualquier resultado previo para evitar mostrar datos obsoletos.
  Future<bool> submitEvaluation({String municipalityCode = '20001'}) async {
    final parsed = parseCopAmount(state.rawAmount);
    if (parsed == null) {
      _requestToken++;
      state = state.copyWith(
        amountError: true,
        verdictAsync: const AsyncData<PriceVerdict?>(null),
      );
      return false;
    }

    final activeScenario = state.selectedScenario;
    if (activeScenario != null) {
      return evaluateScenario(
        activeScenario,
        municipalityCode: municipalityCode,
      );
    }

    final currentToken = ++_requestToken;
    state = state.copyWith(
      amountError: false,
      verdictAsync: const AsyncLoading<PriceVerdict?>(),
    );

    try {
      final repository = ref.read(priceVerdictRepositoryProvider);
      final verdict = await repository.evaluatePrice(
        categoryId: state.selectedCategoryId,
        municipalityCode: municipalityCode,
        zoneId: state.selectedZoneId,
        submittedCop: parsed,
        includeEventContext: state.includeEventContext,
      );
      if (currentToken != _requestToken) return false;
      state = state.copyWith(
        verdictAsync: AsyncData<PriceVerdict?>(verdict),
      );
      return true;
    } catch (error, stackTrace) {
      if (currentToken != _requestToken) return false;
      state = state.copyWith(
        verdictAsync: AsyncError<PriceVerdict?>(error, stackTrace),
      );
      return false;
    }
  }

  /// Limpia el veredicto activo al iniciar una nueva consulta.
  void clearVerdict() {
    _requestToken++;
    state = state.copyWith(
      verdictAsync: const AsyncData<PriceVerdict?>(null),
    );
  }

  /// Restablece el estado completo del mÃ³dulo de escaneo de precios.
  void reset() {
    _requestToken++;
    state = const PriceScanState();
  }
}

final priceScanProvider = NotifierProvider<PriceScanNotifier, PriceScanState>(
  PriceScanNotifier.new,
);

/// CategorÃ­a comparable correspondiente al veredicto activo o a la selecciÃ³n actual.
final activeVerdictCategoryProvider = Provider<PriceCategory?>((ref) {
  final categoriesAsync = ref.watch(priceCategoriesProvider);
  final scanState = ref.watch(priceScanProvider);
  final categories = categoriesAsync.value;
  if (categories == null) return null;
  final targetId =
      scanState.verdictAsync.value?.categoryId ?? scanState.selectedCategoryId;
  for (final cat in categories) {
    if (cat.id == targetId) return cat;
  }
  return null;
});

/// Zona del municipio correspondiente al veredicto activo o a la selecciÃ³n actual.
final activeVerdictZoneProvider = Provider<MunicipalityZone?>((ref) {
  final zonesAsync = ref.watch(municipalityZonesProvider);
  final scanState = ref.watch(priceScanProvider);
  final zones = zonesAsync.value;
  if (zones == null) return null;
  final targetZoneId =
      scanState.verdictAsync.value?.zoneId ?? scanState.selectedZoneId;
  for (final zone in zones) {
    if (zone.id == targetZoneId) return zone;
  }
  return null;
});
