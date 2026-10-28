import 'package:flutter/foundation.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';
import 'package:via_justa/features/prices/domain/price_verdict_repository.dart';

/// Espejo educativo, no decide veredicto real.
/// En producción la única fuente de verdad es la función SQL `calculate_price_verdict` en Supabase (`docs/contrato-datos-v1.md`).
@visibleForTesting
PriceVerdict demoVerdictMirror({
  required String categoryId,
  required String municipalityCode,
  String zoneId = 'vup_centro',
  required int submittedCop,
  required int sampleCount,
  required int referenceCop,
  PriceEventContext? eventContext,
}) {
  if (sampleCount < 3) {
    return PriceVerdict(
      categoryId: categoryId,
      municipalityCode: municipalityCode,
      zoneId: zoneId,
      level: PriceVerdictLevel.insufficient,
      submittedCop: submittedCop,
      n: sampleCount,
      referenceCop: null,
      deviationPct: null,
      recommendedCapCop: null,
      eventContext: null,
      lowPriceWarning: false,
      isDemo: true,
    );
  }

  final rawDeviation = ((submittedCop - referenceCop) / referenceCop) * 100.0;
  final roundedDeviation = double.parse(rawDeviation.toStringAsFixed(2));
  final recommendedCap = (referenceCop * 1.15).round();

  final PriceVerdictLevel level;
  if (roundedDeviation <= 15.0) {
    level = PriceVerdictLevel.green;
  } else if (roundedDeviation <= 40.0) {
    level = PriceVerdictLevel.yellow;
  } else {
    level = PriceVerdictLevel.red;
  }

  final lowPriceWarning = roundedDeviation < -40.0;

  return PriceVerdict(
    categoryId: categoryId,
    municipalityCode: municipalityCode,
    zoneId: zoneId,
    level: level,
    submittedCop: submittedCop,
    referenceCop: referenceCop,
    deviationPct: roundedDeviation,
    recommendedCapCop: recommendedCap,
    n: sampleCount,
    eventContext: eventContext,
    lowPriceWarning: lowPriceWarning,
    isDemo: true,
  );
}

/// Implementación DEMO del repositorio de veredictos de precios segmentado por zonas del municipio (piloto Valledupar).
class DemoPriceVerdictRepository implements PriceVerdictRepository {
  const DemoPriceVerdictRepository();

  /// Zonas del municipio piloto Valledupar (`20001`) para el cálculo de medianas zonales y selección en mapa.
  static const List<MunicipalityZone> demoZonesValledupar = <MunicipalityZone>[
    MunicipalityZone(
      id: 'vup_norte',
      municipalityCode: '20001',
      nameEs: 'Zona Norte',
      nameEn: 'North Zone',
      sectorHintEs: 'Novalito, San Joaquín, CC Guatapurí',
      sectorHintEn: 'Novalito, San Joaquín, Guatapurí Mall',
      normalizedX: 0.50,
      normalizedY: 0.20,
      sortOrder: 1,
    ),
    MunicipalityZone(
      id: 'vup_centro',
      municipalityCode: '20001',
      nameEs: 'Zona Centro',
      nameEn: 'Downtown Zone',
      sectorHintEs: 'Centro Histórico, Plaza Alfonso López, Galería',
      sectorHintEn: 'Historic Center, Alfonso López Square, Market',
      normalizedX: 0.50,
      normalizedY: 0.50,
      sortOrder: 2,
    ),
    MunicipalityZone(
      id: 'vup_sur',
      municipalityCode: '20001',
      nameEs: 'Zona Sur',
      nameEn: 'South Zone',
      sectorHintEs: 'Terminal de Transporte, Fundadores, Mayales',
      sectorHintEn: 'Bus Terminal, Fundadores, Mayales',
      normalizedX: 0.52,
      normalizedY: 0.82,
      sortOrder: 3,
    ),
    MunicipalityZone(
      id: 'vup_oriente',
      municipalityCode: '20001',
      nameEs: 'Zona Oriente',
      nameEn: 'East Zone',
      sectorHintEs: 'Balneario Hurtado, Ribera del Río, San Fernando',
      sectorHintEn: 'Hurtado Riverfront, San Fernando',
      normalizedX: 0.80,
      normalizedY: 0.36,
      sortOrder: 4,
    ),
    MunicipalityZone(
      id: 'vup_occidente',
      municipalityCode: '20001',
      nameEs: 'Zona Occidente',
      nameEn: 'West Zone',
      sectorHintEs: 'La Nevada, Ciudadela 450 Años, Los Cortijos',
      sectorHintEn: 'La Nevada, Ciudadela 450 Años, Los Cortijos',
      normalizedX: 0.20,
      normalizedY: 0.52,
      sortOrder: 5,
    ),
  ];

  static const List<PriceCategory> demoCategories = <PriceCategory>[
    PriceCategory(
      id: 'transport_taxi_minimal',
      groupKey: 'transport',
      nameEs: '[DEMO] Taxi — Carrera mínima urbana',
      nameEn: '[DEMO] Taxi — Minimum urban ride',
      unitDescriptionEs: 'Trayecto diurno dentro de la zona seleccionada',
      unitDescriptionEn: 'Daytime trip within the selected zone',
      sortOrder: 1,
    ),
    PriceCategory(
      id: 'food_corrientazo',
      groupKey: 'food',
      nameEs: '[DEMO] Almuerzo ejecutivo / corriente',
      nameEn: '[DEMO] Standard daily lunch',
      unitDescriptionEs: 'Plato del día con sopa, seco y bebida en la zona',
      unitDescriptionEn: 'Daily lunch menu with soup, main dish, and drink in the zone',
      sortOrder: 2,
    ),
    PriceCategory(
      id: 'lodging_standard_night',
      groupKey: 'lodging',
      nameEs: '[DEMO] Habitación estándar (1 noche)',
      nameEn: '[DEMO] Standard room (1 night)',
      unitDescriptionEs: 'Habitación sencilla o doble con ventilador/A.C. en la zona',
      unitDescriptionEn: 'Single or double room with fan/A.C. in the zone',
      sortOrder: 3,
    ),
    PriceCategory(
      id: 'services_laundry_load',
      groupKey: 'services',
      nameEs: '[DEMO] Lavandería por tanda (Muestra insuficiente)',
      nameEn: '[DEMO] Laundry per load (Insufficient sample)',
      unitDescriptionEs: 'Lavado y secado básico hasta 5 kg (zona con N < 3)',
      unitDescriptionEn: 'Basic wash & dry up to 5 kg (zone with N < 3)',
      sortOrder: 4,
    ),
  ];

  /// Medianas estadísticas DEMO y tamaños de muestra segmentados por (zona, categoría) en Valledupar.
  static const Map<
    String,
    Map<String, ({int referenceCop, int n, int eventReferenceCop})>
  > _zoneCategoryBenchmarks = {
    'vup_norte': {
      'transport_taxi_minimal': (
        referenceCop: 11000,
        n: 13,
        eventReferenceCop: 13500,
      ),
      'food_corrientazo': (
        referenceCop: 16000,
        n: 15,
        eventReferenceCop: 20000,
      ),
      'lodging_standard_night': (
        referenceCop: 110000,
        n: 10,
        eventReferenceCop: 150000,
      ),
      'services_laundry_load': (
        referenceCop: 22000,
        n: 2, // N < 3 -> estado insufficient (M20)
        eventReferenceCop: 22000,
      ),
    },
    'vup_centro': {
      'transport_taxi_minimal': (
        referenceCop: 10000,
        n: 14,
        eventReferenceCop: 12000,
      ),
      'food_corrientazo': (
        referenceCop: 12000,
        n: 19,
        eventReferenceCop: 15000,
      ),
      'lodging_standard_night': (
        referenceCop: 80000,
        n: 9,
        eventReferenceCop: 110000,
      ),
      'services_laundry_load': (
        referenceCop: 18000,
        n: 1, // N < 3 -> estado insufficient (M20)
        eventReferenceCop: 18000,
      ),
    },
    'vup_sur': {
      'transport_taxi_minimal': (
        referenceCop: 10000,
        n: 16,
        eventReferenceCop: 13000,
      ),
      'food_corrientazo': (
        referenceCop: 11000,
        n: 12,
        eventReferenceCop: 14000,
      ),
      'lodging_standard_night': (
        referenceCop: 70000,
        n: 8,
        eventReferenceCop: 95000,
      ),
      'services_laundry_load': (
        referenceCop: 16000,
        n: 1,
        eventReferenceCop: 16000,
      ),
    },
    'vup_oriente': {
      'transport_taxi_minimal': (
        referenceCop: 12000,
        n: 9,
        eventReferenceCop: 15000,
      ),
      'food_corrientazo': (
        referenceCop: 15000,
        n: 11,
        eventReferenceCop: 19000,
      ),
      'lodging_standard_night': (
        referenceCop: 95000,
        n: 7,
        eventReferenceCop: 130000,
      ),
      'services_laundry_load': (
        referenceCop: 19000,
        n: 1,
        eventReferenceCop: 19000,
      ),
    },
    'vup_occidente': {
      'transport_taxi_minimal': (
        referenceCop: 9500,
        n: 11,
        eventReferenceCop: 11500,
      ),
      'food_corrientazo': (
        referenceCop: 10000,
        n: 10,
        eventReferenceCop: 12500,
      ),
      'lodging_standard_night': (
        referenceCop: 65000,
        n: 6,
        eventReferenceCop: 85000,
      ),
      'services_laundry_load': (
        referenceCop: 15000,
        n: 1,
        eventReferenceCop: 15000,
      ),
    },
  };

  static PriceEventContext _buildDemoEventContext({
    required int submittedCop,
    required int eventReferenceCop,
  }) {
    final rawDev =
        ((submittedCop - eventReferenceCop) / eventReferenceCop) * 100.0;
    return PriceEventContext(
      eventName: '[DEMO] Festival de la Leyenda Vallenata (Temporada simulada)',
      eventReferenceCop: eventReferenceCop,
      eventDeviationPct: double.parse(rawDev.toStringAsFixed(1)),
      isDemo: true,
    );
  }

  @override
  Future<List<MunicipalityZone>> getZones({
    String municipalityCode = '20001',
  }) async {
    return demoZonesValledupar;
  }

  @override
  Future<MunicipalityZone> detectCurrentZoneByGps({
    String municipalityCode = '20001',
  }) async {
    // En modo DEMO simula la autodetección por GPS en el sector Centro de Valledupar;
    // en Fase B resuelve las coordenadas GPS reales del teléfono contra PostGIS.
    return demoZonesValledupar[1]; // vup_centro
  }

  @override
  Future<List<PriceCategory>> getCategories() async {
    return demoCategories;
  }

  @override
  Future<PriceVerdict> evaluatePrice({
    required String categoryId,
    required String municipalityCode,
    String zoneId = 'vup_centro',
    required int submittedCop,
    bool includeEventContext = false,
  }) async {
    final zoneMap =
        _zoneCategoryBenchmarks[zoneId] ??
        _zoneCategoryBenchmarks['vup_centro']!;
    final benchmark =
        zoneMap[categoryId] ??
        (referenceCop: 12000, n: 8, eventReferenceCop: 14000);

    final eventContext = includeEventContext && benchmark.n >= 3
        ? _buildDemoEventContext(
            submittedCop: submittedCop,
            eventReferenceCop: benchmark.eventReferenceCop,
          )
        : null;

    return demoVerdictMirror(
      categoryId: categoryId,
      municipalityCode: municipalityCode,
      zoneId: zoneId,
      submittedCop: submittedCop,
      sampleCount: benchmark.n,
      referenceCop: benchmark.referenceCop,
      eventContext: eventContext,
    );
  }

  @override
  Future<PriceVerdict> getScenarioFixture(
    DemoPriceScenario scenario, {
    String municipalityCode = '20001',
    String? zoneId,
    bool includeEventContext = false,
  }) async {
    switch (scenario) {
      case DemoPriceScenario.greenFair:
        return PriceVerdict(
          categoryId: 'food_corrientazo',
          municipalityCode: municipalityCode,
          zoneId: zoneId ?? 'vup_centro',
          level: PriceVerdictLevel.green,
          submittedCop: 12000,
          referenceCop: 12000,
          deviationPct: 0.0,
          recommendedCapCop: 13800,
          n: 19,
          eventContext: includeEventContext
              ? _buildDemoEventContext(
                  submittedCop: 12000,
                  eventReferenceCop: 15000,
                )
              : null,
          lowPriceWarning: false,
          isDemo: true,
        );
      case DemoPriceScenario.yellowModerate:
        return PriceVerdict(
          categoryId: 'transport_taxi_minimal',
          municipalityCode: municipalityCode,
          zoneId: zoneId ?? 'vup_centro',
          level: PriceVerdictLevel.yellow,
          submittedCop: 12500,
          referenceCop: 10000,
          deviationPct: 25.0,
          recommendedCapCop: 11500,
          n: 14,
          eventContext: includeEventContext
              ? _buildDemoEventContext(
                  submittedCop: 12500,
                  eventReferenceCop: 12000,
                )
              : null,
          lowPriceWarning: false,
          isDemo: true,
        );
      case DemoPriceScenario.redOvercharge:
        return PriceVerdict(
          categoryId: 'transport_taxi_minimal',
          municipalityCode: municipalityCode,
          zoneId: zoneId ?? 'vup_sur',
          level: PriceVerdictLevel.red,
          submittedCop: 45000,
          referenceCop: 10000,
          deviationPct: 350.0,
          recommendedCapCop: 11500,
          n: 16,
          eventContext: includeEventContext
              ? _buildDemoEventContext(
                  submittedCop: 45000,
                  eventReferenceCop: 13000,
                )
              : null,
          lowPriceWarning: false,
          isDemo: true,
        );
      case DemoPriceScenario.insufficientSample:
        return PriceVerdict(
          categoryId: 'services_laundry_load',
          municipalityCode: municipalityCode,
          zoneId: zoneId ?? 'vup_occidente',
          level: PriceVerdictLevel.insufficient,
          submittedCop: 18000,
          referenceCop: null,
          deviationPct: null,
          recommendedCapCop: null,
          n: 1,
          eventContext: null,
          lowPriceWarning: false,
          isDemo: true,
        );
      case DemoPriceScenario.lowPriceAlert:
        return PriceVerdict(
          categoryId: 'food_corrientazo',
          municipalityCode: municipalityCode,
          zoneId: zoneId ?? 'vup_norte',
          level: PriceVerdictLevel.green,
          submittedCop: 8000,
          referenceCop: 16000,
          deviationPct: -50.0,
          recommendedCapCop: 18400,
          n: 15,
          eventContext: includeEventContext
              ? _buildDemoEventContext(
                  submittedCop: 8000,
                  eventReferenceCop: 20000,
                )
              : null,
          lowPriceWarning: true,
          isDemo: true,
        );
    }
  }
}
