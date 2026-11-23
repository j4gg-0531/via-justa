import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/currency/currency_formatter.dart';
import 'package:via_justa/core/currency/currency_providers.dart';
import 'package:via_justa/core/currency/currency_storage.dart';
import 'package:via_justa/core/security/external_uri_guard.dart';
import 'package:via_justa/core/theme/app_theme.dart';
import 'package:via_justa/features/activity/domain/user_activity.dart';
import 'package:via_justa/features/activity/domain/user_activity_repository.dart';
import 'package:via_justa/features/activity/presentation/pages/user_activity_page.dart';
import 'package:via_justa/features/activity/presentation/state/user_activity_providers.dart';
import 'package:via_justa/features/budget/domain/trip_budget.dart';
import 'package:via_justa/features/budget/domain/trip_budget_repository.dart';
import 'package:via_justa/features/budget/presentation/pages/trip_budget_page.dart';
import 'package:via_justa/features/budget/presentation/state/trip_budget_providers.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/city/domain/emergency_contact.dart';
import 'package:via_justa/features/prices/data/demo_price_verdict_repository.dart';
import 'package:via_justa/features/prices/domain/price_category_filter.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';

class _FakeCurrencyStorage implements CurrencyPreferenceStorage {
  CurrencyDisplayMode? saved;

  @override
  Future<CurrencyDisplayMode?> loadOverride() async => saved;

  @override
  Future<void> saveOverride(CurrencyDisplayMode? mode) async {
    saved = mode;
  }
}

class _FakeActivityStorage implements UserActivityStorage {
  UserActivityState state = const UserActivityState();

  @override
  Future<UserActivityState> loadState() async => state;

  @override
  Future<void> saveState(UserActivityState next) async {
    state = next;
  }

  @override
  Future<void> clear() async {
    state = const UserActivityState();
  }
}

class _FakeTripBudgetRepository implements TripBudgetRepository {
  const _FakeTripBudgetRepository(this.medians);

  final TripBudgetMedians medians;

  @override
  Future<TripBudgetMedians> getMedians({required String municipalityCode}) async {
    return medians;
  }
}

class _FakeContributionsRepository implements MyPriceContributionsRepository {
  const _FakeContributionsRepository(this.items);

  final List<UserPriceContribution> items;

  @override
  Future<List<UserPriceContribution>> getMyContributions() async => items;
}

void main() {
  group('Currency domain & providers', () {
    test('defaultCurrencyModeForLocale usa COP en español y COP + USD en inglés', () {
      expect(defaultCurrencyModeForLocale('es'), CurrencyDisplayMode.copOnly);
      expect(defaultCurrencyModeForLocale('es_CO'), CurrencyDisplayMode.copOnly);
      expect(defaultCurrencyModeForLocale('en'), CurrencyDisplayMode.copAndUsd);
      expect(defaultCurrencyModeForLocale('en_US'), CurrencyDisplayMode.copAndUsd);
    });

    test('formatMoney formatea COP, COP + USD y USD con tasa orientativa', () {
      final copOnly = formatMoney(
        amountCop: 410000,
        mode: CurrencyDisplayMode.copOnly,
        copPerUsd: 4100,
      );
      expect(copOnly.primary, r'$410.000');
      expect(copOnly.secondary, isNull);

      final both = formatMoney(
        amountCop: 410000,
        mode: CurrencyDisplayMode.copAndUsd,
        copPerUsd: 4100,
      );
      expect(both.primary, r'$410.000');
      expect(both.secondary, r'≈ US$100');

      final usdOnly = formatMoney(
        amountCop: 20500,
        mode: CurrencyDisplayMode.usdOnly,
        copPerUsd: 4100,
      );
      expect(usdOnly.primary, r'US$5.0');
      expect(usdOnly.secondary, r'≈ $20.500');
    });

    test('parseValidCopPerUsdRate valida rango seguro y aplica fallback', () {
      expect(parseValidCopPerUsdRate(4250), 4250);
      expect(parseValidCopPerUsdRate('3950'), 3950);
      expect(parseValidCopPerUsdRate(50), kDefaultCopPerUsd);
      expect(parseValidCopPerUsdRate(null), kDefaultCopPerUsd);
    });

    test('currencyOverrideProvider persiste y respeta preferencia sobre idioma', () async {
      final fakeStorage = _FakeCurrencyStorage();
      final container = ProviderContainer(
        overrides: [
          currencyPreferenceStorageProvider.overrideWithValue(fakeStorage),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(effectiveCurrencyModeProvider('es')),
        CurrencyDisplayMode.copOnly,
      );
      expect(
        container.read(effectiveCurrencyModeProvider('en')),
        CurrencyDisplayMode.copAndUsd,
      );

      await container
          .read(currencyOverrideProvider.notifier)
          .select(CurrencyDisplayMode.usdOnly);

      expect(fakeStorage.saved, CurrencyDisplayMode.usdOnly);
      expect(
        container.read(effectiveCurrencyModeProvider('es')),
        CurrencyDisplayMode.usdOnly,
      );
    });
  });

  group('Expanded price categories audience filter', () {
    test('separa categorías de turismo y de costo de vida (migrante)', () {
      const categories = DemoPriceVerdictRepository.demoCategories;
      expect(categories.length, 9);
      expect(hasMultiplePriceAudiences(categories), isTrue);

      final travel = filterPriceCategoriesByAudience(
        categories,
        PriceCategoryAudience.travel,
      );
      final living = filterPriceCategoriesByAudience(
        categories,
        PriceCategoryAudience.living,
      );

      expect(
        travel.map((c) => c.id),
        containsAll(<String>[
          'transport_taxi_minimal',
          'transport_airport_transfer',
          'food_corrientazo',
          'food_breakfast',
          'lodging_standard_night',
        ]),
      );
      expect(
        living.map((c) => c.id),
        containsAll(<String>[
          'housing_room_monthly',
          'housing_studio_monthly',
          'groceries_basic_weekly',
          'services_laundry_load',
        ]),
      );
    });
  });

  group('Trip budget domain & providers', () {
    test('computeStatisticalMedianCop exige N >= 3 y calcula mediana exacta', () {
      expect(computeStatisticalMedianCop(const [10000, 12000]), isNull);
      expect(computeStatisticalMedianCop(const [16000, 12000, 14000]), 14000);
      expect(
        computeStatisticalMedianCop(const [10000, 14000, 12000, 20000]),
        13000,
      );
    });

    test('calculateTripBudget calcula totales, porcentajes 100%, temporada y semáforo', () {
      const medians = TripBudgetMedians.valleduparBaseline;
      final standard = calculateTripBudget(
        const TripBudgetInput(
          days: 3,
          travelers: 1,
          style: TripStyle.standard,
          includeLodging: true,
          availableBudgetCop: 1200000,
        ),
        medians,
      );

      expect(standard.nights, 2);
      expect(standard.rooms, 1);
      expect(standard.lodgingCop, greaterThan(0));
      expect(
        standard.lodgingPct +
            standard.foodPct +
            standard.transportPct +
            standard.bufferPct,
        100,
      );
      expect(standard.feasibility, BudgetFeasibility.comfortable);
      expect(standard.differenceCop, greaterThan(0));

      final noLodging = calculateTripBudget(
        const TripBudgetInput(
          days: 3,
          travelers: 1,
          includeLodging: false,
          isEventSeason: true,
          availableBudgetCop: 150000,
        ),
        medians,
      );
      expect(noLodging.lodgingCop, 0);
      expect(noLodging.feasibility, BudgetFeasibility.short);
      expect(noLodging.adviceKeys, contains(TripBudgetAdviceKey.shortBudget));
      expect(noLodging.adviceKeys, contains(TripBudgetAdviceKey.eventSeason));
    });

    test('selectTripRelevantBusinesses filtra hospedaje y comida aprobados', () {
      const list = <Business>[
        Business(
          id: 'b1',
          name: 'Hotel A',
          category: BusinessCategory.lodging,
          description: 'Desc',
          address: 'Calle 1',
          phone: '3000000001',
          municipalityCode: '20001',
        ),
        Business(
          id: 'b2',
          name: 'Restaurante B',
          category: BusinessCategory.food,
          description: 'Desc',
          address: 'Calle 2',
          phone: '3000000002',
          municipalityCode: '20001',
        ),
        Business(
          id: 'b3',
          name: 'Taxi C',
          category: BusinessCategory.transport,
          description: 'Desc',
          address: 'Calle 3',
          phone: '3000000003',
          municipalityCode: '20001',
        ),
      ];

      final withLodging = selectTripRelevantBusinesses(
        list,
        includeLodging: true,
      );
      expect(withLodging.map((b) => b.id), ['b1', 'b2']);

      final withoutLodging = selectTripRelevantBusinesses(
        list,
        includeLodging: false,
      );
      expect(withoutLodging.map((b) => b.id), ['b2']);
    });

    test('tripBudgetBreakdownProvider usa medianas del repositorio inyectado', () async {
      final container = ProviderContainer(
        overrides: [
          tripBudgetRepositoryProvider.overrideWithValue(
            const _FakeTripBudgetRepository(
              TripBudgetMedians(
                lodgingNightCop: 100000,
                lunchCop: 20000,
                breakfastCop: 10000,
                taxiRideCop: 10000,
                airportTransferCop: 20000,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(tripBudgetMediansProvider.future);
      final breakdown = container.read(tripBudgetBreakdownProvider);
      expect(breakdown.lodgingCop, 200000); // 2 noches * 100k
      expect(breakdown.totalCop, greaterThan(200000));
    });
  });

  group('User activity domain & providers', () {
    test('prependRecentPriceCheck limita a 20 elementos y deduplica por id', () {
      var list = const <RecentPriceCheck>[];
      for (var i = 0; i < 25; i++) {
        list = prependRecentPriceCheck(
          list,
          RecentPriceCheck(
            id: 'check_$i',
            categoryId: 'food_corrientazo',
            categoryNameEs: 'Almuerzo',
            categoryNameEn: 'Lunch',
            zoneName: 'Zona Centro',
            observedCop: 15000 + i,
            level: PriceVerdictLevel.green,
            checkedAt: DateTime(2026, 11, 23),
          ),
        );
      }
      expect(list.length, 20);
      expect(list.first.id, 'check_24');
    });

    test('UserActivityNotifier guarda consultas, favoritos y limpia historial', () async {
      final fakeStorage = _FakeActivityStorage();
      final container = ProviderContainer(
        overrides: [
          userActivityStorageProvider.overrideWithValue(fakeStorage),
        ],
      );
      addTearDown(container.dispose);

      await container.read(userActivityProvider.notifier).recordPriceCheck(
            RecentPriceCheck(
              id: 'c1',
              categoryId: 'transport_taxi_minimal',
              categoryNameEs: 'Taxi',
              categoryNameEn: 'Taxi',
              zoneName: 'Centro',
              observedCop: 12000,
              level: PriceVerdictLevel.green,
              checkedAt: DateTime(2026, 11, 23),
            ),
          );
      await container
          .read(userActivityProvider.notifier)
          .toggleFavoriteBusiness('biz_1');

      expect(container.read(userActivityProvider).recentChecks.length, 1);
      expect(container.read(userActivityProvider).isFavorite('biz_1'), isTrue);

      await container.read(userActivityProvider.notifier).clearRecentChecks();
      expect(container.read(userActivityProvider).recentChecks, isEmpty);
      expect(container.read(userActivityProvider).isFavorite('biz_1'), isTrue);
    });

    test('UserActivityNotifier espera hidratación inicial y no sobrescribe favoritos previos', () async {
      final prePopulatedStorage = _FakeActivityStorage()
        ..state = const UserActivityState(
          favoriteBusinessIds: <String>{'hotel_sicarare'},
        );
      final container = ProviderContainer(
        overrides: [
          userActivityStorageProvider.overrideWithValue(prePopulatedStorage),
        ],
      );
      addTearDown(container.dispose);

      // Simula una consulta en frío antes de abrir Perfil o Favoritos.
      await container.read(userActivityProvider.notifier).recordPriceCheck(
            RecentPriceCheck(
              id: 'cold_check',
              categoryId: 'food_corrientazo',
              categoryNameEs: 'Almuerzo',
              categoryNameEn: 'Lunch',
              zoneName: 'Zona Centro',
              observedCop: 15000,
              level: PriceVerdictLevel.green,
              checkedAt: DateTime(2026, 11, 23),
            ),
          );

      final state = container.read(userActivityProvider);
      expect(state.recentChecks.length, 1);
      expect(state.favoriteBusinessIds, contains('hotel_sicarare'));
      expect(prePopulatedStorage.state.favoriteBusinessIds, contains('hotel_sicarare'));
    });
  });

  group('Emergency contacts & ExternalUriGuard', () {
    test('permite líneas cortas oficiales (123) solo en vía de emergencia y rechaza USSD o códigos arbitrarios', () {
      expect(ExternalUriGuard.buildSafeTelUri('123'), isNull);
      expect(
        ExternalUriGuard.buildSafeEmergencyTelUri('123')?.toString(),
        'tel:123',
      );
      expect(ExternalUriGuard.buildSafeEmergencyTelUri('*123#'), isNull);
      expect(ExternalUriGuard.buildSafeEmergencyTelUri('999'), isNull);

      for (final contact in kValleduparEmergencyContacts) {
        expect(contact.safeTelUri, isNotNull);
        expect(
          ExternalUriGuard.isAllowedExternalUri(contact.safeTelUri),
          isTrue,
        );
      }
    });
  });

  group('Widget accessibility (360dp @ 2.0x)', () {
    testWidgets('TripBudgetPage renderiza e interactúa sin overflow a 360dp 2.0x', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyPreferenceStorageProvider.overrideWithValue(
              _FakeCurrencyStorage(),
            ),
            userActivityStorageProvider.overrideWithValue(
              _FakeActivityStorage(),
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const TripBudgetPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('budget.page_title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('UserActivityPage cambia pestañas y abre diálogo de limpieza sin overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = _FakeActivityStorage()
        ..state = UserActivityState(
          recentChecks: [
            RecentPriceCheck(
              id: 'c1',
              categoryId: 'food_corrientazo',
              categoryNameEs: 'Almuerzo',
              categoryNameEn: 'Lunch',
              zoneName: 'Zona Centro',
              observedCop: 15000,
              medianCop: 14000,
              level: PriceVerdictLevel.green,
              checkedAt: DateTime(2026, 11, 23, 12, 30),
            ),
          ],
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyPreferenceStorageProvider.overrideWithValue(
              _FakeCurrencyStorage(),
            ),
            userActivityStorageProvider.overrideWithValue(storage),
            myPriceContributionsRepositoryProvider.overrideWithValue(
              const _FakeContributionsRepository(<UserPriceContribution>[]),
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const UserActivityPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('activity.page_title'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Abre el diálogo de limpieza y verifica que no desborda en 360dp @ 2.0x.
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      final clearBtn = find.text('activity.clear_history_cta');
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();
      expect(find.text('activity.clear_history_title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
