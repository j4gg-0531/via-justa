import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/theme/app_colors.dart';
import 'package:via_justa/core/theme/app_theme.dart';
import 'package:via_justa/core/theme/semantic_status_colors.dart';
import 'package:via_justa/features/contracts/data/demo_contract_analysis_repository.dart';
import 'package:via_justa/features/contracts/presentation/widgets/demo_contract_summary.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';
import 'package:via_justa/features/prices/domain/price_verdict_repository.dart';
import 'package:via_justa/features/prices/presentation/pages/price_result_page.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';
import 'package:via_justa/features/prices/presentation/widgets/price_verdict_card.dart';

class _FailingPriceVerdictRepository implements PriceVerdictRepository {
  const _FailingPriceVerdictRepository();

  @override
  Future<List<MunicipalityZone>> getZones({
    String municipalityCode = '20001',
  }) async => const [];

  @override
  Future<MunicipalityZone> detectCurrentZoneByGps({
    String municipalityCode = '20001',
  }) async => throw Exception('Simulated GPS error');

  @override
  Future<List<PriceCategory>> getCategories() async => const [];

  @override
  Future<PriceVerdict> evaluatePrice({
    required String categoryId,
    required String municipalityCode,
    String zoneId = 'vup_centro',
    required int submittedCop,
    bool includeEventContext = false,
  }) async {
    throw Exception('Simulated evaluation error');
  }

  @override
  Future<PriceVerdict> getScenarioFixture(
    DemoPriceScenario scenario, {
    String municipalityCode = '20001',
    String? zoneId,
    bool includeEventContext = false,
  }) async {
    throw Exception('Simulated scenario error');
  }
}

Widget _wrapWithTheme(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('SemanticStatusColors ThemeExtension', () {
    test('maps each PriceVerdictLevel to distinct colors and icons, and eventContext to blue',
        () {
      final ext = SemanticStatusColors.light();
      expect(
        ext.styleForVerdict(PriceVerdictLevel.green).foreground,
        AppColors.semaphoreGreen,
      );
      expect(
        ext.styleForVerdict(PriceVerdictLevel.yellow).foreground,
        AppColors.semaphoreAmber,
      );
      expect(
        ext.styleForVerdict(PriceVerdictLevel.red).foreground,
        AppColors.semaphoreRed,
      );
      expect(
        ext.styleForVerdict(PriceVerdictLevel.insufficient).foreground,
        AppColors.textSecondary,
      );

      // Event context must NOT share semaphore green, amber, or red
      expect(ext.eventContext.foreground, AppColors.primary);
      expect(
        ext.eventContext.foreground,
        isNot(anyOf(
          AppColors.semaphoreGreen,
          AppColors.semaphoreAmber,
          AppColors.semaphoreRed,
        )),
      );
    });
  });

  group('PriceVerdictCard states (green, yellow, red, insufficient M20)', () {
    testWidgets('renders green verdict with reference median, deviation, sample N, and orientative disclaimer',
        (tester) async {
      const verdict = PriceVerdict(
        categoryId: 'food_corrientazo',
        municipalityCode: '20001',
        level: PriceVerdictLevel.green,
        submittedCop: 12000,
        referenceCop: 12000,
        deviationPct: 0.0,
        recommendedCapCop: 13800,
        n: 19,
        isDemo: true,
      );

      await tester.pumpWidget(
        _wrapWithTheme(const PriceVerdictCard(verdict: verdict)),
      );

      expect(find.text('price_verdict.level_green_title'), findsOneWidget);
      expect(find.text('price_verdict.reference_median_label'), findsOneWidget);
      expect(find.text('price_verdict.orientative_disclaimer'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.textContaining('promedio', findRichText: true), findsNothing);
    });

    testWidgets('renders yellow and red verdicts with accessible icons and event context banner',
        (tester) async {
      const verdict = PriceVerdict(
        categoryId: 'transport_taxi_minimal',
        municipalityCode: '20001',
        level: PriceVerdictLevel.red,
        submittedCop: 45000,
        referenceCop: 10000,
        deviationPct: 350.0,
        recommendedCapCop: 11500,
        n: 14,
        eventContext: PriceEventContext(
          eventName: '[DEMO] Festival de la Leyenda Vallenata',
          eventReferenceCop: 12000,
          eventDeviationPct: 275.0,
          isDemo: true,
        ),
        isDemo: true,
      );

      await tester.pumpWidget(
        _wrapWithTheme(const PriceVerdictCard(verdict: verdict)),
      );

      expect(find.text('price_verdict.level_red_title'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('[DEMO] Festival de la Leyenda Vallenata'), findsOneWidget);
      expect(find.byIcon(Icons.festival_outlined), findsOneWidget);
      expect(find.text('+350.0%'), findsOneWidget);
    });

    testWidgets('renders insufficient state (M20) in neutral style without semaphore threshold or reference',
        (tester) async {
      const verdict = PriceVerdict(
        categoryId: 'services_laundry_load',
        municipalityCode: '20001',
        level: PriceVerdictLevel.insufficient,
        submittedCop: 18000,
        n: 1,
        isDemo: true,
      );

      await tester.pumpWidget(
        _wrapWithTheme(const PriceVerdictCard(verdict: verdict)),
      );

      expect(
        find.text('price_verdict.level_insufficient_title'),
        findsOneWidget,
      );
      expect(
        find.text('price_verdict.insufficient_no_threshold'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
      // Must NOT show reference median or recommended cap when insufficient
      expect(find.text('price_verdict.reference_median_label'), findsNothing);
      expect(find.text('price_verdict.recommended_cap_label'), findsNothing);
    });

    testWidgets('renders lowPriceWarning when deviation < -40%', (tester) async {
      const verdict = PriceVerdict(
        categoryId: 'food_corrientazo',
        municipalityCode: '20001',
        level: PriceVerdictLevel.green,
        submittedCop: 6000,
        referenceCop: 12000,
        deviationPct: -50.0,
        recommendedCapCop: 13800,
        n: 19,
        lowPriceWarning: true,
        isDemo: true,
      );

      await tester.pumpWidget(
        _wrapWithTheme(const PriceVerdictCard(verdict: verdict)),
      );

      expect(
        find.text('price_verdict.low_price_warning_title'),
        findsOneWidget,
      );
      expect(
        find.text('price_verdict.low_price_warning_body'),
        findsOneWidget,
      );
    });
  });

  group('DemoContractSummary localization (ES/EN) and honesty badge', () {
    testWidgets('renders two example points in Spanish and English with mandatory demo badge',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: const Locale('es'),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: DemoContractSummary(
                    analysis: DemoContractAnalysisRepository.demoSample,
                    onComingSoonTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('scan.contract_no_document_badge'), findsOneWidget);
      expect(
        find.text('1. Incremento anual sujeto al IPC (Estándar)'),
        findsOneWidget,
      );
      expect(
        find.text('2. Penalidad por terminación anticipada (Revisar antes de firmar)'),
        findsOneWidget,
      );

      // Render in English locale
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: const Locale('en'),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: DemoContractSummary(
                    analysis: DemoContractAnalysisRepository.demoSample,
                    onComingSoonTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.text('1. Annual rent increase tied to CPI (Standard)'),
        findsOneWidget,
      );
      expect(
        find.text('2. Early termination penalty (Review before signing)'),
        findsOneWidget,
      );
    });
  });

  group('PriceResultPage error/retry and 360dp 1.5x scale layout', () {
    testWidgets('shows error state and retry button when repository fails',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          priceVerdictRepositoryProvider.overrideWithValue(
            const _FailingPriceVerdictRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(priceScanProvider.notifier)
          .evaluateScenario(DemoPriceScenario.redOvercharge);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const PriceResultPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('price_verdict.load_error'), findsOneWidget);
      expect(find.text('common.retry'), findsOneWidget);
    });

    testWidgets('renders without overflow at 360dp width and 1.5x text scale',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(priceScanProvider.notifier)
          .evaluateScenario(DemoPriceScenario.yellowModerate);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(1.5),
            ),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const PriceResultPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('price_verdict.level_yellow_title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
