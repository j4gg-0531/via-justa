import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/features/home/presentation/pages/home_page.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';
import 'package:via_justa/features/onboarding/domain/profile_type.dart';
import 'package:via_justa/features/onboarding/presentation/state/profile_type_provider.dart';

class _FakeProfileTypeNotifier extends ProfileTypeNotifier {
  _FakeProfileTypeNotifier(this._initial);
  final ProfileType? _initial;

  @override
  ProfileType? build() => _initial;
}

Widget _buildHome(ProfileType? profile) {
  return ProviderScope(
    overrides: [
      profileTypeProvider.overrideWith(() => _FakeProfileTypeNotifier(profile)),
    ],
    child: const MaterialApp(home: HomePage()),
  );
}

void main() {
  testWidgets(
    'renders visitor view by default or when visitor profile is active',
    (tester) async {
      await tester.pumpWidget(_buildHome(ProfileType.visitor));
      await tester.pumpAndSettle();

      expect(find.text('home.visitor_banner_title'), findsOneWidget);
      expect(find.text('home.visitor_banner_badge'), findsOneWidget);
      expect(find.text('home.profile_tag_visitor'), findsOneWidget);
      expect(find.text('home.tools_title'), findsOneWidget);
    },
  );

  testWidgets('renders settler view with procedures and documents cards', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHome(ProfileType.settler));
    await tester.pumpAndSettle();

    expect(find.text('home.settler_card_title'), findsOneWidget);
    expect(find.text('home.settler_card_badge'), findsOneWidget);
    expect(find.text('home.profile_tag_settler'), findsOneWidget);
    expect(find.text('home.procedures_title'), findsOneWidget);
    expect(find.text('home.documents_title'), findsOneWidget);

    // Tapping procedures card opens feature dialog
    await tester.tap(find.text('home.procedures_title'));
    await tester.pumpAndSettle();

    expect(find.text('home.feature_dialog_body'), findsOneWidget);
    await tester.tap(find.text('common.close'));
    await tester.pumpAndSettle();
  });

  testWidgets('renders resident view with local business action', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        GoRoute(
          path: AppRoutes.businessRegister,
          builder: (_, _) =>
              const Scaffold(body: Text('registration-destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileTypeProvider.overrideWith(
            () => _FakeProfileTypeNotifier(ProfileType.resident),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('home.resident_card_title'), findsOneWidget);
    expect(find.text('home.resident_card_badge'), findsOneWidget);
    expect(find.text('home.profile_tag_resident'), findsOneWidget);
    expect(find.text('businesses.register_action'), findsOneWidget);

    // El acceso de residentes abre el formulario de registro.
    await tester.tap(find.text('businesses.register_action'));
    await tester.pumpAndSettle();

    expect(find.text('registration-destination'), findsOneWidget);
  });

  testWidgets('contribute price card opens demo dialog', (tester) async {
    await tester.pumpWidget(_buildHome(null));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('home.contribute_action_title'),
      200,
    );
    await tester.tap(find.text('home.contribute_action_title'));
    await tester.pumpAndSettle();

    expect(find.text('home.contribute_dialog_title'), findsOneWidget);
    expect(find.text('home.contribute_dialog_body'), findsOneWidget);
    await tester.tap(find.text('common.close'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'HomePage no produce overflow con texto 2.0x a 360dp y nombre de ciudad largo',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/shared_preferences'),
            (call) async => call.method == 'getAll' ? <String, Object>{} : true,
          );
      await EasyLocalization.ensureInitialized();
      final translations = jsonDecode(
        File('assets/translations/es.json').readAsStringSync(),
      ) as Map<String, dynamic>;

      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedLocationLabelProvider.overrideWithValue(
              'Valledupar, Cesar',
            ),
            profileTypeProvider.overrideWith(
              () => _FakeProfileTypeNotifier(ProfileType.resident),
            ),
          ],
          child: EasyLocalization(
            supportedLocales: const [Locale('es')],
            startLocale: const Locale('es'),
            path: 'assets/translations',
            assetLoader: _HomeTestTranslations(translations),
            child: Builder(
              builder: (context) => MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 780),
                  textScaler: TextScaler.linear(2.0),
                ),
                child: MaterialApp(
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  home: const HomePage(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Valledupar, Cesar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _HomeTestTranslations extends AssetLoader {
  const _HomeTestTranslations(this.data);
  final Map<String, dynamic> data;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => data;
}
