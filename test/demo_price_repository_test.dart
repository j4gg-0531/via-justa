import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/prices/data/demo_price_verdict_repository.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';
import 'package:via_justa/features/prices/domain/price_verdict_repository.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';

class _DelayedFakeVerdictRepository implements PriceVerdictRepository {
  final List<Completer<PriceVerdict>> completers = <Completer<PriceVerdict>>[];

  @override
  Future<List<MunicipalityZone>> getZones({
    String municipalityCode = '20001',
  }) async => DemoPriceVerdictRepository.demoZonesValledupar;

  @override
  Future<MunicipalityZone> detectCurrentZoneByGps({
    String municipalityCode = '20001',
  }) async => DemoPriceVerdictRepository.demoZonesValledupar[1];

  @override
  Future<List<PriceCategory>> getCategories() async =>
      DemoPriceVerdictRepository.demoCategories;

  @override
  Future<PriceVerdict> evaluatePrice({
    required String categoryId,
    required String municipalityCode,
    String zoneId = 'vup_centro',
    required int submittedCop,
    bool includeEventContext = false,
  }) {
    final completer = Completer<PriceVerdict>();
    completers.add(completer);
    return completer.future;
  }

  @override
  Future<PriceVerdict> getScenarioFixture(
    DemoPriceScenario scenario, {
    String municipalityCode = '20001',
    String? zoneId,
    bool includeEventContext = false,
  }) {
    final completer = Completer<PriceVerdict>();
    completers.add(completer);
    return completer.future;
  }
}

void main() {
  group('DemoPriceVerdictRepository explicit fixtures & zones', () {
    const repo = DemoPriceVerdictRepository();

    test('returns 5 Valledupar zones (Norte, Centro, Sur, Oriente, Occidente)',
        () async {
      final zones = await repo.getZones(municipalityCode: '20001');
      expect(zones.length, 5);
      expect(
        zones.map((z) => z.id).toList(),
        containsAll([
          'vup_norte',
          'vup_centro',
          'vup_sur',
          'vup_oriente',
          'vup_occidente',
        ]),
      );
      expect(zones.first.localizedName('es'), 'Zona Norte');
      expect(zones.first.localizedName('en'), 'North Zone');
    });

    test('resolveNearestZoneByNormalizedPoint resolves closest Valledupar zone from map tap coordinates',
        () {
      const zones = DemoPriceVerdictRepository.demoZonesValledupar;

      // Tap near North (0.50, 0.15) -> vup_norte
      final north = resolveNearestZoneByNormalizedPoint(
        zones: zones,
        normalizedX: 0.50,
        normalizedY: 0.15,
      );
      expect(north?.id, 'vup_norte');

      // Tap near South / Bus Terminal (0.55, 0.85) -> vup_sur
      final south = resolveNearestZoneByNormalizedPoint(
        zones: zones,
        normalizedX: 0.55,
        normalizedY: 0.85,
      );
      expect(south?.id, 'vup_sur');

      // Tap near Hurtado / East (0.85, 0.35) -> vup_oriente
      final east = resolveNearestZoneByNormalizedPoint(
        zones: zones,
        normalizedX: 0.85,
        normalizedY: 0.35,
      );
      expect(east?.id, 'vup_oriente');

      // Tap near La Nevada / West (0.15, 0.50) -> vup_occidente
      final west = resolveNearestZoneByNormalizedPoint(
        zones: zones,
        normalizedX: 0.15,
        normalizedY: 0.50,
      );
      expect(west?.id, 'vup_occidente');
    });

    test('evaluates medians per zone of Valledupar instead of a single municipal average',
        () async {
      // Same amount ($14.500 COP for daily lunch) evaluated in three different zones of Valledupar:
      // 1. Zona Norte (median $16.000) -> Green (-9.38%)
      final northVerdict = await repo.evaluatePrice(
        categoryId: 'food_corrientazo',
        municipalityCode: '20001',
        zoneId: 'vup_norte',
        submittedCop: 14500,
      );
      expect(northVerdict.zoneId, 'vup_norte');
      expect(northVerdict.referenceCop, 16000);
      expect(northVerdict.level, PriceVerdictLevel.green);

      // 2. Zona Centro (median $12.000) -> Yellow (+20.83%)
      final downtownVerdict = await repo.evaluatePrice(
        categoryId: 'food_corrientazo',
        municipalityCode: '20001',
        zoneId: 'vup_centro',
        submittedCop: 14500,
      );
      expect(downtownVerdict.zoneId, 'vup_centro');
      expect(downtownVerdict.referenceCop, 12000);
      expect(downtownVerdict.level, PriceVerdictLevel.yellow);

      // 3. Zona Occidente (median $10.000) -> Red (+45.0%)
      final westVerdict = await repo.evaluatePrice(
        categoryId: 'food_corrientazo',
        municipalityCode: '20001',
        zoneId: 'vup_occidente',
        submittedCop: 14500,
      );
      expect(westVerdict.zoneId, 'vup_occidente');
      expect(westVerdict.referenceCop, 10000);
      expect(westVerdict.level, PriceVerdictLevel.red);
    });

    test('returns green, yellow, red, insufficient, and lowPriceAlert fixtures with zoneId',
        () async {
      final green = await repo.getScenarioFixture(DemoPriceScenario.greenFair);
      expect(green.level, PriceVerdictLevel.green);
      expect(green.zoneId, 'vup_centro');
      expect(green.isInsufficient, isFalse);
      expect(green.referenceCop, 12000);
      expect(green.deviationPct, 0.0);
      expect(green.n, greaterThanOrEqualTo(3));
      expect(green.isDemo, isTrue);

      final yellow = await repo.getScenarioFixture(
        DemoPriceScenario.yellowModerate,
      );
      expect(yellow.level, PriceVerdictLevel.yellow);
      expect(yellow.zoneId, 'vup_centro');
      expect(yellow.deviationPct, 25.0);

      final red = await repo.getScenarioFixture(
        DemoPriceScenario.redOvercharge,
      );
      expect(red.level, PriceVerdictLevel.red);
      expect(red.zoneId, 'vup_sur');
      expect(red.deviationPct, 350.0);

      final insufficient = await repo.getScenarioFixture(
        DemoPriceScenario.insufficientSample,
      );
      expect(insufficient.level, PriceVerdictLevel.insufficient);
      expect(insufficient.zoneId, 'vup_occidente');
      expect(insufficient.isInsufficient, isTrue);
      expect(insufficient.referenceCop, isNull);
      expect(insufficient.deviationPct, isNull);
      expect(insufficient.recommendedCapCop, isNull);
      expect(insufficient.n, lessThan(3));

      final lowPrice = await repo.getScenarioFixture(
        DemoPriceScenario.lowPriceAlert,
      );
      expect(lowPrice.level, PriceVerdictLevel.green);
      expect(lowPrice.zoneId, 'vup_norte');
      expect(lowPrice.lowPriceWarning, isTrue);
      expect(lowPrice.deviationPct, lessThan(-40.0));
    });

    test('attaches eventContext only when requested and sample is sufficient',
        () async {
      final withoutEvent = await repo.getScenarioFixture(
        DemoPriceScenario.yellowModerate,
        includeEventContext: false,
      );
      expect(withoutEvent.eventContext, isNull);

      final withEvent = await repo.getScenarioFixture(
        DemoPriceScenario.yellowModerate,
        includeEventContext: true,
      );
      expect(withEvent.eventContext, isNotNull);
      expect(withEvent.eventContext!.isDemo, isTrue);
      expect(withEvent.eventContext!.eventName, contains('[DEMO]'));

      final insufficientWithEventFlag = await repo.getScenarioFixture(
        DemoPriceScenario.insufficientSample,
        includeEventContext: true,
      );
      expect(insufficientWithEventFlag.eventContext, isNull);
    });
  });

  group('demoVerdictMirror boundary rules (Contrato de Datos Section 3.4)', () {
    test('1. deviation = 0.0% -> green', () {
      final v = demoVerdictMirror(
        categoryId: 'cat',
        municipalityCode: '20001',
        zoneId: 'vup_centro',
        submittedCop: 10000,
        referenceCop: 10000,
        sampleCount: 5,
      );
      expect(v.level, PriceVerdictLevel.green);
      expect(v.zoneId, 'vup_centro');
      expect(v.deviationPct, 0.0);
      expect(v.lowPriceWarning, isFalse);
    });

    test('2. deviation = 15.0% -> green (upper boundary)', () {
      final v = demoVerdictMirror(
        categoryId: 'cat',
        municipalityCode: '20001',
        submittedCop: 11500,
        referenceCop: 10000,
        sampleCount: 5,
      );
      expect(v.level, PriceVerdictLevel.green);
      expect(v.deviationPct, 15.0);
    });

    test('3. deviation = 15.01% -> yellow (lower boundary)', () {
      final v = demoVerdictMirror(
        categoryId: 'cat',
        municipalityCode: '20001',
        submittedCop: 11501,
        referenceCop: 10000,
        sampleCount: 5,
      );
      expect(v.level, PriceVerdictLevel.yellow);
      expect(v.deviationPct, 15.01);
    });

    test('4. deviation = 40.0% -> yellow (upper boundary)', () {
      final v = demoVerdictMirror(
        categoryId: 'cat',
        municipalityCode: '20001',
        submittedCop: 14000,
        referenceCop: 10000,
        sampleCount: 5,
      );
      expect(v.level, PriceVerdictLevel.yellow);
      expect(v.deviationPct, 40.0);
    });

    test('5. deviation = 40.01% -> red (lower boundary)', () {
      final v = demoVerdictMirror(
        categoryId: 'cat',
        municipalityCode: '20001',
        submittedCop: 14001,
        referenceCop: 10000,
        sampleCount: 5,
      );
      expect(v.level, PriceVerdictLevel.red);
      expect(v.deviationPct, 40.01);
    });

    test('6. sampleCount < 3 -> insufficient without thresholds', () {
      final v = demoVerdictMirror(
        categoryId: 'cat',
        municipalityCode: '20001',
        submittedCop: 50000,
        referenceCop: 10000,
        sampleCount: 2,
      );
      expect(v.level, PriceVerdictLevel.insufficient);
      expect(v.isInsufficient, isTrue);
      expect(v.referenceCop, isNull);
      expect(v.deviationPct, isNull);
      expect(v.recommendedCapCop, isNull);
    });

    test('7. deviation = -40.01% -> green with lowPriceWarning = true', () {
      final v = demoVerdictMirror(
        categoryId: 'cat',
        municipalityCode: '20001',
        submittedCop: 5999,
        referenceCop: 10000,
        sampleCount: 5,
      );
      expect(v.level, PriceVerdictLevel.green);
      expect(v.lowPriceWarning, isTrue);
    });
  });

  group('PriceVerdict parsing and domain formatters', () {
    test('parseCopAmount validates positive COP integers', () {
      expect(parseCopAmount(''), isNull);
      expect(parseCopAmount('0'), isNull);
      expect(parseCopAmount('-5000'), isNull);
      expect(parseCopAmount('abc'), isNull);
      expect(parseCopAmount('12.500'), 12500);
      expect(parseCopAmount(r'$ 45,000'), 45000);
    });

    test('formatCop and formatDeviationPct format deterministically', () {
      expect(formatCop(12000), r'$12.000 COP');
      expect(formatDeviationPct(25.0), '+25.0%');
      expect(formatDeviationPct(-10.5), '-10.5%');
      expect(formatDeviationPct(0.0), '0.0%');
    });

    test('PriceVerdict.fromMap validates wire format and preserves zone_id',
        () {
      expect(
        () => PriceVerdict.fromMap(
          const {'level': 'purple', 'amount_cop': 10000, 'sample_count': 5},
          categoryId: 'cat',
          municipalityCode: '20001',
        ),
        throwsFormatException,
      );

      final parsed = PriceVerdict.fromMap(
        const {
          'level': 'yellow',
          'zone_id': 'vup_norte',
          'amount_cop': 15000,
          'reference_cop': 12000,
          'deviation_percent': 25.0,
          'recommended_cap_cop': 13800,
          'sample_count': 8,
          'underpriced_alert': false,
        },
        categoryId: 'food_corrientazo',
        municipalityCode: '20001',
      );
      expect(parsed.level, PriceVerdictLevel.yellow);
      expect(parsed.zoneId, 'vup_norte');
      expect(parsed.referenceCop, 12000);
      expect(parsed.n, 8);
    });
  });

  group('PriceScanNotifier stale result prevention & zone selection', () {
    test('starting a new search or changing zone clears previous verdict and ignores stale responses',
        () async {
      final fakeRepo = _DelayedFakeVerdictRepository();
      final container = ProviderContainer(
        overrides: [
          priceVerdictRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(priceScanProvider.notifier);

      // First request starts
      final firstFuture = notifier.evaluateScenario(DemoPriceScenario.redOvercharge);
      expect(container.read(priceScanProvider).verdictAsync.isLoading, isTrue);

      // User changes zone before first request finishes -> must clear loading/previous state
      notifier.selectZone('vup_norte');
      expect(container.read(priceScanProvider).selectedZoneId, 'vup_norte');
      expect(container.read(priceScanProvider).verdictAsync.value, isNull);
      expect(container.read(priceScanProvider).verdictAsync.isLoading, isFalse);

      // Now complete the stale first request -> must be ignored!
      fakeRepo.completers.first.complete(
        const PriceVerdict(
          categoryId: 'transport_taxi_minimal',
          municipalityCode: '20001',
          zoneId: 'vup_sur',
          level: PriceVerdictLevel.red,
          submittedCop: 45000,
          referenceCop: 10000,
          deviationPct: 350.0,
          recommendedCapCop: 11500,
          n: 14,
        ),
      );
      final firstResult = await firstFuture;
      expect(firstResult, isFalse);
      expect(container.read(priceScanProvider).verdictAsync.value, isNull);
    });

    test('handles GPS location permission grant, denial fallback to map, and map point tap',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(priceScanProvider.notifier);
      expect(
        container.read(priceScanProvider).locationPermission,
        LocationPermissionStatus.prompt,
      );
      expect(container.read(priceScanProvider).shouldShowMapPicker, isFalse);

      // 1. User denies GPS permission -> opens manual map picker
      notifier.denyLocationPermissionAndOpenMap();
      expect(
        container.read(priceScanProvider).locationPermission,
        LocationPermissionStatus.denied,
      );
      expect(container.read(priceScanProvider).shouldShowMapPicker, isTrue);

      // 2. User taps on the North sector of the map -> selects vup_norte
      notifier.selectPointOnMap(
        normalizedX: 0.50,
        normalizedY: 0.18,
        zones: DemoPriceVerdictRepository.demoZonesValledupar,
      );
      expect(container.read(priceScanProvider).selectedZoneId, 'vup_norte');

      // 3. User later grants GPS permission -> auto-detects vup_centro and closes manual map
      await notifier.grantLocationPermissionAndDetect();
      expect(
        container.read(priceScanProvider).locationPermission,
        LocationPermissionStatus.granted,
      );
      expect(container.read(priceScanProvider).selectedZoneId, 'vup_centro');
      expect(container.read(priceScanProvider).shouldShowMapPicker, isFalse);
    });
  });
}
