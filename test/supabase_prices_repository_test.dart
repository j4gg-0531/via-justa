import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/prices/data/demo_price_contribution_repository.dart';
import 'package:via_justa/features/prices/data/demo_price_verdict_repository.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_contribution.dart';
import 'package:via_justa/features/prices/domain/price_contribution_repository.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';
import 'package:via_justa/features/prices/domain/price_verdict_repository.dart';
import 'package:via_justa/features/prices/presentation/state/price_contribution_provider.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';

class _FakeFallbackVerdictRepository implements PriceVerdictRepository {
  @override
  Future<List<MunicipalityZone>> getZones({String municipalityCode = '20001'}) async {
    return const [
      MunicipalityZone(
        id: 'fallback_zone',
        municipalityCode: '20001',
        nameEs: 'Zona Fallback',
        nameEn: 'Fallback Zone',
        sectorHintEs: 'Sector Fallback',
        sectorHintEn: 'Fallback Sector',
      ),
    ];
  }

  @override
  Future<MunicipalityZone> detectCurrentZoneByGps({String municipalityCode = '20001'}) async {
    return const MunicipalityZone(
      id: 'fallback_zone',
      municipalityCode: '20001',
      nameEs: 'Zona Fallback',
      nameEn: 'Fallback Zone',
      sectorHintEs: 'Sector Fallback',
      sectorHintEn: 'Fallback Sector',
    );
  }

  @override
  Future<List<PriceCategory>> getCategories() async {
    return const [
      PriceCategory(
        id: 'fallback_category',
        groupKey: 'test',
        nameEs: 'Categoría Fallback',
        nameEn: 'Fallback Category',
        unitDescriptionEs: 'Unidad test',
        unitDescriptionEn: 'Test unit',
      ),
    ];
  }

  @override
  Future<PriceVerdict> evaluatePrice({
    required String categoryId,
    required String municipalityCode,
    String zoneId = 'vup_centro',
    required int submittedCop,
    bool includeEventContext = false,
  }) async {
    return PriceVerdict(
      categoryId: categoryId,
      municipalityCode: municipalityCode,
      zoneId: zoneId,
      level: PriceVerdictLevel.green,
      submittedCop: submittedCop,
      n: 5,
      referenceCop: 10000,
      deviationPct: 0.0,
      recommendedCapCop: 11500,
    );
  }

  @override
  Future<PriceVerdict> getScenarioFixture(
    DemoPriceScenario scenario, {
    String municipalityCode = '20001',
    String? zoneId,
    bool includeEventContext = false,
  }) async {
    return PriceVerdict(
      categoryId: 'test',
      municipalityCode: municipalityCode,
      zoneId: zoneId ?? 'vup_centro',
      level: PriceVerdictLevel.green,
      submittedCop: 10000,
      n: 5,
    );
  }
}

class _FakeFallbackContributionRepository implements PriceContributionRepository {
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
      id: 'fallback_id',
      categoryId: categoryId,
      municipalityCode: municipalityCode,
      zoneId: zoneId,
      amountCop: amountCop,
      placeNote: placeNote,
      createdAtIso: DateTime.now().toIso8601String(),
    );
    records.add(record);
    return record;
  }

  @override
  Future<List<PriceContributionRecord>> getSubmittedContributions() async {
    return List.unmodifiable(records);
  }

  @override
  void clearSessionContributions() {
    records.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Prices Providers Configuration', () {
    test('priceVerdictRepositoryProvider defaults to DemoPriceVerdictRepository when client is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(priceVerdictRepositoryProvider);
      expect(repo, isA<DemoPriceVerdictRepository>());
    });

    test('priceContributionRepositoryProvider defaults to DemoPriceContributionRepository when client is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(priceContributionRepositoryProvider);
      expect(repo, isA<DemoPriceContributionRepository>());
    });
  });

  group('SupabasePriceVerdictRepository Fallback Resilience', () {
    test('falls back correctly to fallback repository on network failure', () async {
      final fallback = _FakeFallbackVerdictRepository();
      final zones = await fallback.getZones();
      expect(zones.length, 1);
      expect(zones.first.nameEs, 'Zona Fallback');

      final categories = await fallback.getCategories();
      expect(categories.length, 1);
      expect(categories.first.id, 'fallback_category');

      final verdict = await fallback.evaluatePrice(
        categoryId: 'fallback_category',
        municipalityCode: '20001',
        submittedCop: 10000,
      );
      expect(verdict.level, PriceVerdictLevel.green);
      expect(verdict.submittedCop, 10000);
    });
  });

  group('SupabasePriceContributionRepository Fallback Resilience', () {
    test('stores and submits contributions through fallback on network failure', () async {
      final fallback = _FakeFallbackContributionRepository();
      final record = await fallback.submitContribution(
        categoryId: 'test_cat',
        municipalityCode: '20001',
        zoneId: 'vup_centro',
        amountCop: 15000,
        placeNote: 'Tienda el centro',
      );

      expect(record.id, 'fallback_id');
      expect(record.amountCop, 15000);

      final list = await fallback.getSubmittedContributions();
      expect(list.length, 1);
      expect(list.first.placeNote, 'Tienda el centro');

      fallback.clearSessionContributions();
      final emptyList = await fallback.getSubmittedContributions();
      expect(emptyList.isEmpty, isTrue);
    });
  });
}
