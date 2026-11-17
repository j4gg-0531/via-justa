import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/theme/app_theme.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/businesses/domain/business_draft.dart';
import 'package:via_justa/features/businesses/presentation/pages/register_business_page.dart';
import 'package:via_justa/features/businesses/presentation/state/register_business_provider.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_category.dart';
import 'package:via_justa/features/prices/domain/price_verdict.dart';
import 'package:via_justa/features/prices/domain/price_verdict_repository.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';

import 'register_business_provider_test.dart'
    show
        registrationContainer,
        FakeRegistrationRepository,
        TestBusinessAuth,
        fillRegistration,
        registrationZone;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : true,
        );
    await EasyLocalization.ensureInitialized();
  });
  for (final locale in ['es', 'en']) {
    testWidgets('cuatro pasos y publicación a 360 dp y texto 2x ($locale)', (
      tester,
    ) async {
      final translations = jsonDecode(
        File('assets/translations/$locale.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final repository = FakeRegistrationRepository();
      final container = registrationContainer(repository);
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      container.listen(registerBusinessProvider, (_, _) {});
      await container.read(municipalityZonesProvider.future);
      await container.read(priceCategoriesProvider.future);
      final notifier = container.read(registerBusinessProvider.notifier);
      fillRegistration(notifier);
      notifier.setHours('mon', const BusinessDayHours(enabled: true));
      notifier.addDish();
      notifier.setDish(0, name: 'Almuerzo de la casa', price: '15000');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: EasyLocalization(
            supportedLocales: [Locale(locale)],
            startLocale: Locale(locale),
            path: 'assets/translations',
            assetLoader: _TestTranslations(translations),
            child: Builder(
              builder: (context) => MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                theme: AppTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: const RegisterBusinessPage(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var step = 0; step < 4; step++) {
        expect(container.read(registerBusinessProvider).step, step);
        expect(
          find.text('businessRegistration.step$step'.tr()).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        if (step == 2) {
          final compareBtn = find.text(
            'businessRegistration.compareZonePrice'.tr(),
          );
          await tester.ensureVisible(compareBtn);
          await tester.pumpAndSettle();
          await tester.tap(compareBtn);
          await tester.pumpAndSettle();
          expect(
            find.text('businessRegistration.priceNoticeTitle'.tr()),
            findsOneWidget,
          );
          expect(
            find.text('businessRegistration.priceNoticePrivateHint'.tr()),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
        final action = find.text(
          (step == 3
                  ? 'businessRegistration.publish'
                  : 'businessRegistration.next')
              .tr(),
        );
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
      }
      expect(
        find.text('businessRegistration.publishedTitle'.tr()),
        findsOneWidget,
      );
      expect(repository.requests.length, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'al avanzar a Revisión compara automáticamente, muestra No pudimos comparar al fallar y permite reintentar o publicar',
    (tester) async {
      final translations = jsonDecode(
        File('assets/translations/es.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final repository = FakeRegistrationRepository();
      final verdictRepo = _WidgetVerdictRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(TestBusinessAuth.new),
          businessRegistrationRepositoryProvider.overrideWithValue(repository),
          priceVerdictRepositoryProvider.overrideWithValue(verdictRepo),
          municipalityZonesProvider.overrideWith(
            (ref) async => const [registrationZone],
          ),
          priceCategoriesProvider.overrideWith(
            (ref) async => const [
              PriceCategory(
                id: 'food_corrientazo',
                groupKey: 'food',
                nameEs: 'Almuerzo corriente',
                unitDescriptionEs: 'Por plato',
                nameEn: 'Daily lunch',
                unitDescriptionEn: 'Per meal',
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(selectedMunicipalityProvider.notifier)
          .select(
            const Municipality(
              code: '20001',
              name: 'Valledupar',
              departmentCode: '20',
              isPilot: true,
            ),
          );
      container.listen(registerBusinessProvider, (_, _) {});
      await container.read(municipalityZonesProvider.future);
      await container.read(priceCategoriesProvider.future);
      final notifier = container.read(registerBusinessProvider.notifier);
      fillRegistration(notifier);
      notifier.next(); // 0 -> 1
      notifier.next(); // 1 -> 2
      notifier.addDish();
      notifier.setDish(
        0,
        name: 'Bandeja especial',
        price: '28000',
        priceCategoryId: 'food_corrientazo',
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: EasyLocalization(
            supportedLocales: const [Locale('es')],
            startLocale: const Locale('es'),
            path: 'assets/translations',
            assetLoader: _TestTranslations(translations),
            child: Builder(
              builder: (context) => MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                theme: AppTheme.light(),
                home: const RegisterBusinessPage(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nextBtn = find.text('businessRegistration.next'.tr());
      await tester.ensureVisible(nextBtn);
      await tester.pumpAndSettle();
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      expect(container.read(registerBusinessProvider).step, 3);
      expect(
        find.text('businessRegistration.priceNoticeErrorTitle'.tr()),
        findsOneWidget,
      );
      expect(find.text('common.retry'.tr()), findsOneWidget);

      verdictRepo.fail = false;
      final retryBtn = find.text('common.retry'.tr());
      await tester.ensureVisible(retryBtn);
      await tester.pumpAndSettle();
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('businessRegistration.priceNoticeLevels.red'.tr()),
        findsOneWidget,
      );

      final publishBtn = find.text('businessRegistration.publish'.tr());
      await tester.ensureVisible(publishBtn);
      await tester.pumpAndSettle();
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('businessRegistration.publishedTitle'.tr()),
        findsOneWidget,
      );
      expect(repository.requests.length, 1);
    },
  );
}

class _WidgetVerdictRepository implements PriceVerdictRepository {
  bool fail = true;

  @override
  Future<PriceVerdict> evaluatePrice({
    required String categoryId,
    required String municipalityCode,
    String zoneId = 'vup_centro',
    String? destinationZoneId,
    double? originLatitude,
    double? originLongitude,
    double? destinationLatitude,
    double? destinationLongitude,
    required int submittedCop,
    bool includeEventContext = false,
  }) async {
    if (fail) throw Exception('offline');
    return PriceVerdict(
      categoryId: categoryId,
      municipalityCode: municipalityCode,
      zoneId: zoneId,
      level: PriceVerdictLevel.red,
      submittedCop: submittedCop,
      n: 8,
      referenceCop: 14000,
      deviationPct: 100.0,
    );
  }

  @override
  Future<MunicipalityZone> detectCurrentZoneByGps({
    String municipalityCode = '20001',
  }) => throw UnimplementedError();

  @override
  Future<List<PriceCategory>> getCategories() => throw UnimplementedError();

  @override
  Future<PriceVerdict> getScenarioFixture(
    DemoPriceScenario scenario, {
    String municipalityCode = '20001',
    String? zoneId,
    bool includeEventContext = false,
  }) => throw UnimplementedError();

  @override
  Future<List<MunicipalityZone>> getZones({String municipalityCode = '20001'}) =>
      throw UnimplementedError();
}

class _TestTranslations extends AssetLoader {
  const _TestTranslations(this.data);
  final Map<String, dynamic> data;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => data;
}
