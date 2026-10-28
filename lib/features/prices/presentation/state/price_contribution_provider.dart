import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:via_justa/features/prices/data/demo_price_contribution_repository.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_contribution.dart';
import 'package:via_justa/features/prices/domain/price_contribution_repository.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';

/// Proveedor del repositorio de aportes de precio (único punto que referencia la clase concreta).
final priceContributionRepositoryProvider =
    Provider<PriceContributionRepository>((ref) {
      return DemoPriceContributionRepository();
    });

/// Estado inmutable del asistente de 4 pasos para aportar un precio (M10).
class PriceContributionWizardState {
  const PriceContributionWizardState({
    this.currentStep = 0,
    this.selectedCategoryId = 'food_corrientazo',
    this.rawAmount = '',
    this.amountError,
    this.selectedZoneId = 'vup_centro',
    this.locationPermission = LocationPermissionStatus.prompt,
    this.isManualMapOpen = false,
    this.pinNormalizedX = 0.50,
    this.pinNormalizedY = 0.50,
    this.rawPlaceNote = '',
    this.isSubmitting = false,
    this.submitError = false,
    this.submittedRecord,
  });

  /// Paso actual del wizard (0 = Categoría, 1 = Monto, 2 = Zona/Ubicación, 3 = Resumen y confirmación).
  final int currentStep;
  final String selectedCategoryId;
  final String rawAmount;
  final PriceContributionAmountError? amountError;
  final String selectedZoneId;
  final LocationPermissionStatus locationPermission;
  final bool isManualMapOpen;
  final double pinNormalizedX;
  final double pinNormalizedY;
  final String rawPlaceNote;
  final bool isSubmitting;
  final bool submitError;
  final PriceContributionRecord? submittedRecord;

  /// Número de paso visible para el usuario (1 a 4).
  int get displayStepNumber => currentStep + 1;

  /// Monto entero positivo parseado desde `rawAmount` (o `null` si no es válido).
  int? get parsedAmount => parseCopAmount(rawAmount);

  /// Nota opcional saneada lista para previsualizar o enviar.
  String? get sanitizedNote => sanitizeContributionNote(rawPlaceNote);

  /// Coordenada horizontal del pin en rango [-1.0, 1.0].
  double get pinAlignmentX => (pinNormalizedX * 2) - 1;

  /// Coordenada vertical del pin en rango [-1.0, 1.0].
  double get pinAlignmentY => (pinNormalizedY * 2) - 1;

  /// Indica si se debe desplegar el mapa interactivo de zonas.
  bool get shouldShowMapPicker =>
      locationPermission == LocationPermissionStatus.denied || isManualMapOpen;

  /// Indica si el aporte ya fue confirmado y guardado en el paso 4.
  bool get isCompleted => submittedRecord != null;

  PriceContributionWizardState copyWith({
    int? currentStep,
    String? selectedCategoryId,
    String? rawAmount,
    PriceContributionAmountError? amountError,
    bool clearAmountError = false,
    String? selectedZoneId,
    LocationPermissionStatus? locationPermission,
    bool? isManualMapOpen,
    double? pinNormalizedX,
    double? pinNormalizedY,
    String? rawPlaceNote,
    bool? isSubmitting,
    bool? submitError,
    PriceContributionRecord? submittedRecord,
    bool clearSubmittedRecord = false,
  }) {
    return PriceContributionWizardState(
      currentStep: currentStep ?? this.currentStep,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      rawAmount: rawAmount ?? this.rawAmount,
      amountError: clearAmountError ? null : (amountError ?? this.amountError),
      selectedZoneId: selectedZoneId ?? this.selectedZoneId,
      locationPermission: locationPermission ?? this.locationPermission,
      isManualMapOpen: isManualMapOpen ?? this.isManualMapOpen,
      pinNormalizedX: pinNormalizedX ?? this.pinNormalizedX,
      pinNormalizedY: pinNormalizedY ?? this.pinNormalizedY,
      rawPlaceNote: rawPlaceNote ?? this.rawPlaceNote,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: submitError ?? this.submitError,
      submittedRecord: clearSubmittedRecord
          ? null
          : (submittedRecord ?? this.submittedRecord),
    );
  }
}

/// Controlador Riverpod del wizard de 4 pasos para aportar un precio (M10).
class PriceContributionNotifier extends Notifier<PriceContributionWizardState> {
  @override
  PriceContributionWizardState build() => const PriceContributionWizardState();

  /// Paso 1: Selecciona la categoría comparable.
  void selectCategory(String categoryId) {
    state = state.copyWith(
      selectedCategoryId: categoryId,
      submitError: false,
    );
  }

  /// Paso 2: Actualiza el monto escrito por el usuario y limpia errores previos de edición.
  void setRawAmount(String value) {
    state = state.copyWith(
      rawAmount: value,
      clearAmountError: true,
      submitError: false,
    );
  }

  /// Paso 3: Concede permiso de ubicación del teléfono y autodetecta la zona actual por GPS.
  Future<void> grantLocationPermissionAndDetect({
    String municipalityCode = '20001',
  }) async {
    final verdictRepo = ref.read(priceVerdictRepositoryProvider);
    final detectedZone = await verdictRepo.detectCurrentZoneByGps(
      municipalityCode: municipalityCode,
    );
    state = state.copyWith(
      locationPermission: LocationPermissionStatus.granted,
      isManualMapOpen: false,
      selectedZoneId: detectedZone.id,
      pinNormalizedX: detectedZone.normalizedX,
      pinNormalizedY: detectedZone.normalizedY,
      submitError: false,
    );
  }

  /// Paso 3: Deniega el permiso de ubicación del teléfono y abre el mapa interactivo de zonas.
  void denyLocationPermissionAndOpenMap() {
    state = state.copyWith(
      locationPermission: LocationPermissionStatus.denied,
      isManualMapOpen: true,
      submitError: false,
    );
  }

  /// Paso 3: Abre o cierra el mapa interactivo para selección manual de punto/zona.
  void toggleManualMapPicker(bool open) {
    state = state.copyWith(isManualMapOpen: open);
  }

  /// Paso 3: Selecciona directamente una zona en el mapa.
  void selectZone(String zoneId) {
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
      submitError: false,
    );
  }

  /// Paso 3: Selecciona la zona más cercana al punto `(normalizedX, normalizedY)` tocado en el mapa.
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

    final clampedX = normalizedX.clamp(0.08, 0.92);
    final clampedY = normalizedY.clamp(0.10, 0.90);

    state = state.copyWith(
      selectedZoneId: resolvedZone.id,
      pinNormalizedX: clampedX,
      pinNormalizedY: clampedY,
      isManualMapOpen: true,
      submitError: false,
    );
  }

  /// Paso 3: Actualiza la nota o referencia opcional del lugar.
  void setRawPlaceNote(String value) {
    state = state.copyWith(
      rawPlaceNote: value,
      submitError: false,
    );
  }

  /// Valida el paso actual y avanza al siguiente paso del wizard (0 -> 1 -> 2 -> 3).
  /// Retorna `true` si pudo avanzar, o `false` si la validación del paso falló.
  bool nextStep() {
    switch (state.currentStep) {
      case 0:
        if (!isValidContributionCategory(state.selectedCategoryId)) {
          return false;
        }
        state = state.copyWith(currentStep: 1, submitError: false);
        return true;
      case 1:
        final error = validateContributionAmount(state.rawAmount);
        if (error != null) {
          state = state.copyWith(amountError: error);
          return false;
        }
        state = state.copyWith(
          currentStep: 2,
          clearAmountError: true,
          submitError: false,
        );
        return true;
      case 2:
        if (!isValidContributionZone(state.selectedZoneId)) {
          return false;
        }
        state = state.copyWith(currentStep: 3, submitError: false);
        return true;
      default:
        return false;
    }
  }

  /// Retrocede al paso anterior del wizard (si `currentStep > 0`).
  bool previousStep() {
    if (state.currentStep <= 0) return false;
    state = state.copyWith(
      currentStep: state.currentStep - 1,
      submitError: false,
    );
    return true;
  }

  /// Permite regresar a un paso específico desde el resumen del Paso 4.
  void goToStep(int step) {
    if (step < 0 || step > 3) return;
    state = state.copyWith(currentStep: step, submitError: false);
  }

  /// Paso 4: Valida y guarda el aporte ciudadano en el repositorio DEMO.
  Future<bool> submitContribution({String municipalityCode = '20001'}) async {
    if (!isValidContributionCategory(state.selectedCategoryId)) return false;
    final amountError = validateContributionAmount(state.rawAmount);
    final parsedAmount = state.parsedAmount;
    if (amountError != null || parsedAmount == null) {
      state = state.copyWith(
        currentStep: 1,
        amountError: amountError ?? PriceContributionAmountError.notPositiveNumber,
      );
      return false;
    }
    if (!isValidContributionZone(state.selectedZoneId)) return false;

    state = state.copyWith(isSubmitting: true, submitError: false);

    try {
      final repository = ref.read(priceContributionRepositoryProvider);
      final saved = await repository.submitContribution(
        categoryId: state.selectedCategoryId,
        municipalityCode: municipalityCode,
        zoneId: state.selectedZoneId,
        amountCop: parsedAmount,
        placeNote: state.sanitizedNote,
      );
      state = state.copyWith(
        isSubmitting: false,
        submitError: false,
        submittedRecord: saved,
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        submitError: true,
      );
      return false;
    }
  }

  /// Reinicia el formulario para realizar otro aporte.
  void startNewContribution() {
    state = const PriceContributionWizardState();
  }

  /// Limpia todo el estado y los aportes de la sesión (al cerrar sesión).
  void resetSession() {
    ref.read(priceContributionRepositoryProvider).clearSessionContributions();
    state = const PriceContributionWizardState();
  }
}

final priceContributionProvider =
    NotifierProvider<PriceContributionNotifier, PriceContributionWizardState>(
      PriceContributionNotifier.new,
    );

/// Categoría comparable seleccionada en el wizard de aporte de precios.
final activeContributionCategoryProvider = Provider<PriceCategory?>((ref) {
  final categories = ref.watch(priceCategoriesProvider).value;
  final wizard = ref.watch(priceContributionProvider);
  if (categories == null) return null;
  final targetId =
      wizard.submittedRecord?.categoryId ?? wizard.selectedCategoryId;
  for (final cat in categories) {
    if (cat.id == targetId) return cat;
  }
  return null;
});

/// Zona del municipio seleccionada en el wizard de aporte de precios.
final activeContributionZoneProvider = Provider<MunicipalityZone?>((ref) {
  final zones = ref.watch(municipalityZonesProvider).value;
  final wizard = ref.watch(priceContributionProvider);
  if (zones == null) return null;
  final targetZoneId = wizard.submittedRecord?.zoneId ?? wizard.selectedZoneId;
  for (final zone in zones) {
    if (zone.id == targetZoneId) return zone;
  }
  return null;
});
