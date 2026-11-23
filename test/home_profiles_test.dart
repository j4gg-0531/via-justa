import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/city/domain/city_overview.dart';
import 'package:via_justa/features/city/domain/city_repository.dart';
import 'package:via_justa/features/city/presentation/state/city_providers.dart';
import 'package:via_justa/features/city/presentation/widgets/home_city_event_banner.dart';
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

class _FakeHomeCityRepository implements CityRepository {
  _FakeHomeCityRepository({
    this.events = const <CityEvent>[],
    this.errorToThrow,
  });

  final List<CityEvent> events;
  final Object? errorToThrow;

  @override
  Future<CityOverview> getCityOverview({
    required String municipalityCode,
    required String localeCode,
    bool includeDemo = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<CityEvent>> getCityEvents({
    required String municipalityCode,
    bool includeDemo = false,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return events;
  }
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

  testWidgets(
    'renders live pilot badge for visitor view when connected to Supabase',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isDemoModeProvider.overrideWithValue(false),
            profileTypeProvider.overrideWith(
              () => _FakeProfileTypeNotifier(ProfileType.visitor),
            ),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('home.visitor_banner_live_badge'), findsOneWidget);
      expect(find.text('home.visitor_banner_badge'), findsNothing);
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

  testWidgets('quick action opens city overview route for active municipality', (
    tester,
  ) async {
    String? pushedCode;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        GoRoute(
          path: AppRoutes.cityOverview,
          builder: (_, state) {
            pushedCode = state.pathParameters['code'];
            return Scaffold(
              body: Text('city-overview-${state.pathParameters['code']}'),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileTypeProvider.overrideWith(
            () => _FakeProfileTypeNotifier(ProfileType.visitor),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final cityGuideTile = find.text('home.city_guide_action_title');
    await tester.ensureVisible(cityGuideTile);
    await tester.tap(cityGuideTile);
    await tester.pumpAndSettle();

    expect(pushedCode, '20001');
    expect(find.text('city-overview-20001'), findsOneWidget);
  });

  testWidgets('HomeCityEventBanner renders active, upcoming, and hidden states honestly', (
    tester,
  ) async {
    final activeEvent = CityEvent(
      id: 'ev-active',
      municipalityCode: '20001',
      name: 'Festival de la Leyenda Vallenata (En vivo)',
      descriptionEs: 'Evento oficial activo.',
      descriptionEn: 'Active official event.',
      venue: 'Parque de la Leyenda Vallenata',
      startsAt: DateTime.parse('2027-04-28T00:00:00-05:00'),
      endsAt: DateTime.parse('2027-05-02T23:59:59-05:00'),
      temporalStatus: CityEventTemporalStatus.active,
      isCurrentlyActive: true,
      isDemo: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isDemoModeProvider.overrideWithValue(false),
          cityRepositoryProvider.overrideWithValue(
            _FakeHomeCityRepository(events: <CityEvent>[activeEvent]),
          ),
          profileTypeProvider.overrideWith(
            () => _FakeProfileTypeNotifier(ProfileType.visitor),
          ),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeCityEventBanner), findsOneWidget);
    expect(find.text('city.event_status_active'), findsOneWidget);
    expect(
      find.text('Festival de la Leyenda Vallenata (En vivo)'),
      findsOneWidget,
    );
    expect(find.text('city.event_not_active_note'), findsNothing);

    final upcomingEvent = CityEvent(
      id: 'ev-upcoming',
      municipalityCode: '20001',
      name: 'Festival de la Leyenda Vallenata 2027',
      startsAt: DateTime.parse('2027-04-28T00:00:00-05:00'),
      endsAt: DateTime.parse('2027-05-02T23:59:59-05:00'),
      temporalStatus: CityEventTemporalStatus.upcoming,
      isCurrentlyActive: false,
      isDemo: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isDemoModeProvider.overrideWithValue(false),
          cityRepositoryProvider.overrideWithValue(
            _FakeHomeCityRepository(events: <CityEvent>[upcomingEvent]),
          ),
          profileTypeProvider.overrideWith(
            () => _FakeProfileTypeNotifier(ProfileType.visitor),
          ),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('city.event_status_upcoming'), findsOneWidget);
    expect(find.text('city.event_not_active_note'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isDemoModeProvider.overrideWithValue(false),
          cityRepositoryProvider.overrideWithValue(
            _FakeHomeCityRepository(
              errorToThrow: const CityLoadException(CityLoadErrorKind.network),
            ),
          ),
          profileTypeProvider.overrideWith(
            () => _FakeProfileTypeNotifier(ProfileType.visitor),
          ),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('city.event_banner_cta'), findsNothing);
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

  testWidgets('HomePage with active event banner has zero overflow at 360dp @ 2.0x', (
    tester,
  ) async {
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

    final activeEvent = CityEvent(
      id: 'ev-active-responsive',
      municipalityCode: '20001',
      name: 'Festival de la Leyenda Vallenata (Edición Anual Oficial)',
      descriptionEs: 'Certamen folclórico oficial en Valledupar.',
      venue: 'Parque de la Leyenda Vallenata Consuelo Araujonoguera',
      startsAt: DateTime.parse('2027-04-28T00:00:00-05:00'),
      endsAt: DateTime.parse('2027-05-02T23:59:59-05:00'),
      temporalStatus: CityEventTemporalStatus.active,
      isCurrentlyActive: true,
      isDemo: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isDemoModeProvider.overrideWithValue(false),
          cityRepositoryProvider.overrideWithValue(
            _FakeHomeCityRepository(events: <CityEvent>[activeEvent]),
          ),
          selectedLocationLabelProvider.overrideWithValue('Valledupar, Cesar'),
          profileTypeProvider.overrideWith(
            () => _FakeProfileTypeNotifier(ProfileType.visitor),
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

    expect(
      find.text('Festival de la Leyenda Vallenata (Edición Anual Oficial)'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _HomeTestTranslations extends AssetLoader {
  const _HomeTestTranslations(this.data);
  final Map<String, dynamic> data;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => data;
}
