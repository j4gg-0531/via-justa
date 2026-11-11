import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/theme/app_theme.dart';
import 'package:via_justa/features/prices/data/demo_price_contribution_repository.dart';
import 'package:via_justa/features/prices/data/demo_price_verdict_repository.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_contribution.dart';
import 'package:via_justa/features/prices/domain/price_contribution_repository.dart';
import 'package:via_justa/features/prices/presentation/pages/contribute_price_page.dart';
import 'package:via_justa/features/prices/presentation/state/price_contribution_provider.dart';

class _FakePriceContributionRepository implements PriceContributionRepository {
  final List<PriceContributionRecord> records = [];

  @override
  Future<PriceContributionRecord> submitContribution({
    required String categoryId,
    required String municipalityCode,
    required String zoneId,
    required int amountCop,
    String? placeNote,
    String? destinationZoneId,
    double? originLatitude,
    double? originLongitude,
    double? destinationLatitude,
    double? destinationLongitude,
  }) async {
    final record = PriceContributionRecord(
      id: 'fake-${records.length + 1}',
      categoryId: categoryId,
      municipalityCode: municipalityCode,
      zoneId: zoneId,
      destinationZoneId: destinationZoneId,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      amountCop: amountCop,
      placeNote: sanitizeContributionNote(placeNote ?? ''),
      createdAtIso: '2026-10-28T12:00:00Z',
    );
    records.add(record);
    return record;
  }

  @override
  Future<List<PriceContributionRecord>> getSubmittedContributions() async =>
      List.unmodifiable(records);

  @override
  void clearSessionContributions() {
    records.clear();
  }
}

void main() {
  group('Domain rules: price_contribution.dart & municipality_zone.dart', () {
    test('validateContributionAmount validates empty, non-positive, below min, above max, and valid COP', () {
      expect(
        validateContributionAmount('   '),
        PriceContributionAmountError.empty,
      );
      expect(
        validateContributionAmount('abc'),
        PriceContributionAmountError.notPositiveNumber,
      );
      expect(
        validateContributionAmount('0'),
        PriceContributionAmountError.notPositiveNumber,
      );
      expect(
        validateContributionAmount('-5000'),
        PriceContributionAmountError.notPositiveNumber,
      );
      expect(
        validateContributionAmount('400'),
        PriceContributionAmountError.belowMinimum,
      );
      expect(
        validateContributionAmount('25000000'),
        PriceContributionAmountError.aboveMaximum,
      );

      expect(validateContributionAmount(r'$ 12.500'), isNull);
    });

    test('isValidContributionCategory, isValidContributionZone, and isValidContributionLocation enforce taxi destination rule', () {
      expect(isValidContributionCategory(''), isFalse);
      expect(isValidContributionCategory('   '), isFalse);
      expect(isValidContributionCategory('transport_taxi_minimal'), isTrue);

      expect(isValidContributionZone(''), isFalse);
      expect(isValidContributionZone('   '), isFalse);
      expect(isValidContributionZone('vup_centro'), isTrue);

      expect(categoryRequiresDestination('transport_taxi_minimal'), isTrue);
      expect(categoryRequiresDestination('food_corrientazo'), isFalse);

      // Non-taxi requires only zoneId
      expect(
        isValidContributionLocation(
          categoryId: 'food_corrientazo',
          zoneId: 'vup_centro',
        ),
        isTrue,
      );

      // Taxi requires destination (either destinationZoneId or destination coordinates)
      expect(
        isValidContributionLocation(
          categoryId: 'transport_taxi_minimal',
          zoneId: 'vup_centro',
        ),
        isFalse,
      );
      expect(
        isValidContributionLocation(
          categoryId: 'transport_taxi_minimal',
          zoneId: 'vup_centro',
          destinationZoneId: 'vup_sur',
        ),
        isTrue,
      );
      expect(
        isValidContributionLocation(
          categoryId: 'transport_taxi_minimal',
          zoneId: 'vup_centro',
          destinationLatitude: 10.4452,
          destinationLongitude: -73.2468,
        ),
        isTrue,
      );
    });

    test('resolveNearestZoneByCoordinates resolves closest Valledupar zone from WGS84 lat/lng', () {
      const zones = DemoPriceVerdictRepository.demoZonesValledupar;
      final nearSur = resolveNearestZoneByCoordinates(
        zones: zones,
        latitude: 10.4440,
        longitude: -73.2450,
      );
      expect(nearSur?.id, 'vup_sur');

      final nearNorte = resolveNearestZoneByCoordinates(
        zones: zones,
        latitude: 10.4890,
        longitude: -73.2530,
      );
      expect(nearNorte?.id, 'vup_norte');
    });

    test('sanitizeContributionNote trims, returns null on empty, and truncates at 120 chars', () {
      expect(sanitizeContributionNote(''), isNull);
      expect(sanitizeContributionNote('    '), isNull);
      expect(
        sanitizeContributionNote('  Plaza Alfonso López  '),
        'Plaza Alfonso López',
      );

      final longText = 'A' * 150;
      final sanitized = sanitizeContributionNote(longText);
      expect(sanitized, isNotNull);
      expect(sanitized!.length, kMaxPlaceNoteLength);
    });

    test('PriceContributionRecord serializes toMap with optional taxi route fields', () {
      const record = PriceContributionRecord(
        id: 'demo-1',
        categoryId: 'transport_taxi_minimal',
        municipalityCode: '20001',
        zoneId: 'vup_centro',
        destinationZoneId: 'vup_sur',
        distanceKm: 3.24,
        distanceRange: '2_5_km',
        amountCop: 13000,
        placeNote: 'Terminal',
        createdAtIso: '2026-10-28T10:00:00Z',
      );

      final map = record.toMap();
      expect(map['id'], 'demo-1');
      expect(map['category_id'], 'transport_taxi_minimal');
      expect(map['municipality_code'], '20001');
      expect(map['zone_id'], 'vup_centro');
      expect(map['destination_zone_id'], 'vup_sur');
      expect(map['distance_km'], 3.24);
      expect(map['distance_range'], '2_5_km');
      expect(map['amount_cop'], 13000);
      expect(map['place_name'], 'Terminal');
      expect(map['is_demo'], isTrue);
    });
  });

  group('DemoPriceContributionRepository', () {
    test('stores and clears demo contributions in memory during session', () async {
      final repo = DemoPriceContributionRepository();
      expect(await repo.getSubmittedContributions(), isEmpty);

      final saved = await repo.submitContribution(
        categoryId: 'transport_taxi_minimal',
        municipalityCode: '20001',
        zoneId: 'vup_centro',
        destinationZoneId: 'vup_sur',
        amountCop: 10000,
        placeNote: '  Terminal  ',
      );

      expect(saved.id, 'demo_contrib_1');
      expect(saved.placeNote, 'Terminal');
      expect(saved.destinationZoneId, 'vup_sur');
      expect((await repo.getSubmittedContributions()).length, 1);

      repo.clearSessionContributions();
      expect(await repo.getSubmittedContributions(), isEmpty);
    });
  });

  group('PriceContributionNotifier (Riverpod 3 + fake repository)', () {
    test('enforces step validation and submits contribution to repository', () async {
      final fakeRepo = _FakePriceContributionRepository();
      final container = ProviderContainer(
        overrides: [
          priceContributionRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(priceContributionProvider.notifier);

      // Step 1 (index 0) -> Step 2 (index 1)
      expect(container.read(priceContributionProvider).currentStep, 0);
      notifier.selectCategory('food_corrientazo');
      expect(notifier.nextStep(), isTrue);
      expect(container.read(priceContributionProvider).currentStep, 1);

      // Step 2 (index 1): empty amount blocks advancing to Step 3
      expect(notifier.nextStep(), isFalse);
      expect(container.read(priceContributionProvider).currentStep, 1);
      expect(
        container.read(priceContributionProvider).amountError,
        PriceContributionAmountError.empty,
      );

      // Step 2: below minimum amount blocks advancing
      notifier.setRawAmount('200');
      expect(notifier.nextStep(), isFalse);
      expect(
        container.read(priceContributionProvider).amountError,
        PriceContributionAmountError.belowMinimum,
      );

      // Step 2: valid amount advances to Step 3 (index 2)
      notifier.setRawAmount('15500');
      expect(notifier.nextStep(), isTrue);
      expect(container.read(priceContributionProvider).currentStep, 2);

      // Step 3 (index 2): select zone on map and optional note -> Step 4 (index 3)
      notifier.denyLocationPermissionAndOpenMap();
      notifier.selectPointOnMap(
        normalizedX: 0.50,
        normalizedY: 0.18,
        zones: const [
          MunicipalityZone(
            id: 'vup_norte',
            municipalityCode: '20001',
            nameEs: 'Zona Norte',
            nameEn: 'North Zone',
            sectorHintEs: 'Novalito',
            sectorHintEn: 'Novalito',
            normalizedX: 0.50,
            normalizedY: 0.18,
          ),
          MunicipalityZone(
            id: 'vup_centro',
            municipalityCode: '20001',
            nameEs: 'Zona Centro',
            nameEn: 'Downtown Zone',
            sectorHintEs: 'Plaza',
            sectorHintEn: 'Plaza',
            normalizedX: 0.48,
            normalizedY: 0.48,
          ),
        ],
      );
      notifier.setRawPlaceNote('Cerca del parque');
      expect(
        container.read(priceContributionProvider).selectedZoneId,
        'vup_norte',
      );
      expect(notifier.nextStep(), isTrue);
      expect(container.read(priceContributionProvider).currentStep, 3);

      // Step 4: submit contribution
      final ok = await notifier.submitContribution(municipalityCode: '20001');
      expect(ok, isTrue);

      final finalState = container.read(priceContributionProvider);
      expect(finalState.isCompleted, isTrue);
      expect(finalState.submittedRecord?.amountCop, 15500);
      expect(finalState.submittedRecord?.zoneId, 'vup_norte');
      expect(fakeRepo.records.length, 1);

      // Reset session clears repository and wizard
      notifier.resetSession();
      expect(container.read(priceContributionProvider).currentStep, 0);
      expect(container.read(priceContributionProvider).isCompleted, isFalse);
      expect(fakeRepo.records, isEmpty);
    });

    test('requires destination point on map when category is transport_taxi_minimal', () async {
      final fakeRepo = _FakePriceContributionRepository();
      final container = ProviderContainer(
        overrides: [
          priceContributionRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(priceContributionProvider.notifier);

      notifier.selectCategory('transport_taxi_minimal');
      expect(
        container.read(priceContributionProvider).requiresDestination,
        isTrue,
      );
      expect(notifier.nextStep(), isTrue);

      notifier.setRawAmount('13000');
      expect(notifier.nextStep(), isTrue);
      expect(container.read(priceContributionProvider).currentStep, 2);

      // Attempt to advance from Step 3 without destination -> blocked with destinationError
      expect(notifier.nextStep(), isFalse);
      expect(
        container.read(priceContributionProvider).destinationError,
        isTrue,
      );
      expect(container.read(priceContributionProvider).currentStep, 2);

      // Select precise destination on map -> advances to Step 4
      notifier.selectPreciseDestination(
        destinationZoneId: 'vup_sur',
        latitude: 10.4452,
        longitude: -73.2468,
      );
      expect(
        container.read(priceContributionProvider).destinationError,
        isFalse,
      );
      expect(notifier.nextStep(), isTrue);
      expect(container.read(priceContributionProvider).currentStep, 3);

      final ok = await notifier.submitContribution(municipalityCode: '20001');
      expect(ok, isTrue);
      expect(fakeRepo.records.single.destinationZoneId, 'vup_sur');
      expect(fakeRepo.records.single.destinationLatitude, 10.4452);
      expect(fakeRepo.records.single.destinationLongitude, -73.2468);
    });
  });

  group('ContributePricePage widget tests (M10)', () {
    testWidgets('completes 4-step wizard, blocks on invalid amount, and shows DEMO disclaimer at 360x780 @ 1.5x text scale',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(1.5),
            ),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const ContributePricePage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 visible
      expect(find.text('price_contribute.step1_title'), findsOneWidget);

      // Advance to Step 2
      final nextBtn = find.text('price_contribute.next_step_cta');
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      expect(find.text('price_contribute.step2_title'), findsOneWidget);

      // Try advancing with empty amount -> stays on Step 2 and shows error
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      expect(find.text('price_contribute.step2_title'), findsOneWidget);
      expect(find.text('price_contribute.error_amount_empty'), findsOneWidget);

      // Tap quick preset $12.000 COP and advance to Step 3
      final presetChip = find.text(r'$12.000 COP');
      await tester.ensureVisible(presetChip);
      await tester.tap(presetChip);
      await tester.pumpAndSettle();

      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      // Step 3 visible (zone + optional note)
      expect(find.text('price_contribute.step3_title'), findsOneWidget);

      // Advance to Step 4
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      // Step 4 visible with DEMO disclaimer
      expect(find.text('price_contribute.step4_title'), findsOneWidget);
      expect(find.text('price_contribute.demo_sync_disclaimer'), findsOneWidget);

      // Confirm contribution
      final confirmBtn = find.text('price_contribute.confirm_submit_cta');
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Completed view shown with DEMO disclaimer and zero overflow
      expect(find.text('price_contribute.success_title'), findsOneWidget);
      expect(find.text('price_contribute.demo_sync_disclaimer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
