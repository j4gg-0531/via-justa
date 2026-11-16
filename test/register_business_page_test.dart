import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/theme/app_theme.dart';
import 'package:via_justa/features/businesses/domain/business_draft.dart';
import 'package:via_justa/features/businesses/presentation/pages/register_business_page.dart';
import 'package:via_justa/features/businesses/presentation/state/register_business_provider.dart';
import 'package:via_justa/features/prices/presentation/state/price_scan_provider.dart';

import 'register_business_provider_test.dart'
    show registrationContainer, FakeRegistrationRepository, fillRegistration;

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
}

class _TestTranslations extends AssetLoader {
  const _TestTranslations(this.data);
  final Map<String, dynamic> data;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => data;
}
