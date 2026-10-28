import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/theme/app_theme.dart';
import 'package:via_justa/features/prices/data/demo_price_contribution_repository.dart';
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
  }) async {
    final record = PriceContributionRecord(
      id: 'fake-${records.length + 1}',
      categoryId: categoryId,
      municipalityCode: municipalityCode,
      zoneId: zoneId,
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
  group('Domain rules: price_contribution.dart', () {
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

    test('isValidContributionCategory and isValidContributionZone validate non-empty ids', () {
      expect(isValidContributionCategory(''), isFalse);
      expect(isValidContributionCategory('   '), isFalse);
      expect(isValidContributionCategory('taxi_urbano_corto'), isTrue);

      expect(isValidContributionZone(''), isFalse);
      expect(isValidContributionZone('   '), isFalse);
      expect(isValidContributionZone('vup_centro'), isTrue);
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

    test('PriceContributionRecord serializes toMap with is_demo=true', () {
      const record = PriceContributionRecord(
        id: 'demo-1',
        categoryId: 'almuerzo_corriente',
        municipalityCode: '20001',
        zoneId: 'vup_norte',
        amountCop: 16000,
        placeNote: 'Parque Novalito',
        createdAtIso: '2026-10-28T10:00:00Z',
      );

      final map = record.toMap();
      expect(map['id'], 'demo-1');
      expect(map['category_id'], 'almuerzo_corriente');
      expect(map['municipality_code'], '20001');
      expect(map['zone_id'], 'vup_norte');
      expect(map['amount_cop'], 16000);
      expect(map['place_name'], 'Parque Novalito');
      expect(map['is_demo'], isTrue);
    });
  });

  group('DemoPriceContributionRepository', () {
    test('stores and clears demo contributions in memory during session', () async {
      final repo = DemoPriceContributionRepository();
      expect(await repo.getSubmittedContributions(), isEmpty);

      final saved = await repo.submitContribution(
        categoryId: 'taxi_urbano_corto',
        municipalityCode: '20001',
        zoneId: 'vup_centro',
        amountCop: 10000,
        placeNote: '  Terminal  ',
      );

      expect(saved.id, 'demo_contrib_1');
      expect(saved.placeNote, 'Terminal');
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
      notifier.selectCategory('almuerzo_corriente');
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
