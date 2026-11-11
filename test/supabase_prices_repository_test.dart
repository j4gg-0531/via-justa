import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/prices/data/demo_price_contribution_repository.dart';
import 'package:via_justa/features/prices/data/demo_price_verdict_repository.dart';
import 'package:via_justa/features/prices/data/supabase_price_contribution_repository.dart';
import 'package:via_justa/features/prices/data/supabase_price_verdict_repository.dart';
import 'package:via_justa/features/prices/domain/price_verdict_repository.dart';
import 'package:via_justa/features/prices/presentation/state/price_contribution_provider.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Prices Providers Configuration (Paso 1)', () {
    test('defaults to Demo repositories and isDemoMode = true when client is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isDemoModeProvider), isTrue);
      expect(
        container.read(priceVerdictRepositoryProvider),
        isA<DemoPriceVerdictRepository>(),
      );
      expect(
        container.read(priceContributionRepositoryProvider),
        isA<DemoPriceContributionRepository>(),
      );
    });

    test('uses Supabase repositories and isDemoMode = false when client is provided', () {
      final dummyClient = SupabaseClient('http://127.0.0.1:59999', 'fake-anon-key');
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(dummyClient),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(isDemoModeProvider), isFalse);
      expect(
        container.read(priceVerdictRepositoryProvider),
        isA<SupabasePriceVerdictRepository>(),
      );
      expect(
        container.read(priceContributionRepositoryProvider),
        isA<SupabasePriceContributionRepository>(),
      );
    });
  });

  group('SupabasePriceVerdictRepository No Silent Fallback (Paso 1)', () {
    test('propagates network/RPC error instead of falling back to Demo data', () async {
      final unreachableClient = SupabaseClient(
        'http://127.0.0.1:59999',
        'fake-anon-key',
      );
      final repo = SupabasePriceVerdictRepository(unreachableClient);

      await expectLater(
        repo.evaluatePrice(
          categoryId: 'food_corrientazo',
          municipalityCode: '20001',
          zoneId: 'vup_centro',
          submittedCop: 12500,
        ),
        throwsA(anything),
      );

      await expectLater(
        repo.getCategories(),
        throwsA(anything),
      );

      await expectLater(
        repo.getZones(municipalityCode: '20001'),
        throwsA(anything),
      );

      expect(
        () => repo.getScenarioFixture(DemoPriceScenario.greenFair),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('SupabasePriceContributionRepository No Silent Fallback (Paso 1)', () {
    test('propagates network/RPC error instead of saving fake demo contribution', () async {
      final unreachableClient = SupabaseClient(
        'http://127.0.0.1:59999',
        'fake-anon-key',
      );
      final repo = SupabasePriceContributionRepository(unreachableClient);

      await expectLater(
        repo.submitContribution(
          categoryId: 'food_corrientazo',
          municipalityCode: '20001',
          zoneId: 'vup_centro',
          amountCop: 15000,
          placeNote: 'Restaurante',
        ),
        throwsA(anything),
      );
    });
  });
}
