import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/city/domain/city_external_launcher.dart';
import 'package:via_justa/features/city/domain/city_overview.dart';
import 'package:via_justa/features/city/domain/city_repository.dart';
import 'package:via_justa/features/city/presentation/pages/city_overview_page.dart';
import 'package:via_justa/features/city/presentation/state/city_providers.dart';
import 'package:via_justa/features/city/presentation/widgets/city_editorial_photo_hero.dart';

class _FakeCityRepository implements CityRepository {
  _FakeCityRepository({
    this.overview,
    this.errorToThrow,
  });

  CityOverview? overview;
  Object? errorToThrow;

  @override
  Future<CityOverview> getCityOverview({
    required String municipalityCode,
    required String localeCode,
    bool includeDemo = false,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return overview!;
  }

  @override
  Future<List<CityEvent>> getCityEvents({
    required String municipalityCode,
    bool includeDemo = false,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return overview?.events ?? const <CityEvent>[];
  }
}

class _FakeCityExternalLauncher implements CityExternalLauncher {
  _FakeCityExternalLauncher({this.result = true});

  final bool result;
  final List<Uri> launchedUris = <Uri>[];

  @override
  Future<bool> launchExternalUri(Uri uri) async {
    launchedUris.add(uri);
    return result;
  }
}

CityOverview _buildSampleOverview({
  String locale = 'es',
  bool hasLocaleFallback = false,
  String? sourceUrl = 'https://ich.unesco.org',
  String? imagePath,
  String? imageLicense,
}) {
  return CityOverview(
    municipalityCode: '20001',
    municipalityName: 'Valledupar',
    departmentCode: '20',
    isPilot: true,
    requestedLocale: locale,
    hasLocaleFallback: hasLocaleFallback,
    content: <CityContentItem>[
      CityContentItem(
        id: 'c1',
        municipalityCode: '20001',
        slug: 'vallenato_unesco',
        section: CityContentSection.culture,
        requestedLocale: locale,
        resolvedLocale: hasLocaleFallback ? 'es' : locale,
        isLocaleFallback: hasLocaleFallback,
        title: 'Música Vallenata Tradicional',
        body: 'Patrimonio cultural inmaterial.',
        imagePath: imagePath,
        imageLicense: imageLicense,
        sourceCitation: 'UNESCO (2015)',
        sourceUrl: sourceUrl,
        sortOrder: 3,
      ),
      const CityContentItem(
        id: 'c2',
        municipalityCode: '20001',
        slug: 'gastronomia',
        section: CityContentSection.gastronomy,
        requestedLocale: 'es',
        resolvedLocale: 'es',
        isLocaleFallback: false,
        title: 'Sancocho de gallina criolla',
        body: 'Plato tradicional de la región.',
        sourceCitation: 'Mincultura',
        sourceUrl: 'https://www.mincultura.gov.co',
        sortOrder: 5,
      ),
    ],
    events: <CityEvent>[
      CityEvent(
        id: 'e1',
        municipalityCode: '20001',
        name: 'Festival de la Leyenda Vallenata',
        descriptionEs: 'Certamen folclórico anual.',
        descriptionEn: 'Annual folkloric contest.',
        venue: 'Parque de la Leyenda Vallenata',
        startsAt: DateTime.parse('2027-04-28T00:00:00-05:00'),
        endsAt: DateTime.parse('2027-05-02T23:59:59-05:00'),
        temporalStatus: CityEventTemporalStatus.upcoming,
        isCurrentlyActive: false,
        isDemo: false,
        sourceCitation: 'Fundación Festival de la Leyenda Vallenata',
      ),
    ],
  );
}

void main() {
  testWidgets('renders curated city content, events and section filter chips', (
    tester,
  ) async {
    final repo = _FakeCityRepository(overview: _buildSampleOverview());
    final launcher = _FakeCityExternalLauncher();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isDemoModeProvider.overrideWithValue(false),
          cityRepositoryProvider.overrideWithValue(repo),
          cityExternalLauncherProvider.overrideWithValue(launcher),
        ],
        child: const MaterialApp(
          home: CityOverviewPage(municipalityCode: '20001'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CityEditorialPhotoHero), findsOneWidget);
    expect(find.text('Valledupar'), findsOneWidget);
    expect(find.text('Cesar'), findsOneWidget);
    expect(find.text('city.verified_badge'), findsOneWidget);
    expect(find.text('city.event_status_upcoming'), findsOneWidget);
    expect(find.text('city.event_not_active_note'), findsOneWidget);
    expect(find.text('Música Vallenata Tradicional'), findsOneWidget);
    expect(find.text('Sancocho de gallina criolla'), findsOneWidget);

    // Filtrar por Gastronomía oculta el ítem de Cultura.
    final gastroChip = find.text('city.section_gastronomy').first;
    await tester.ensureVisible(gastroChip);
    await tester.tap(gastroChip);
    await tester.pumpAndSettle();

    expect(find.text('Sancocho de gallina criolla'), findsOneWidget);
    expect(find.text('Música Vallenata Tradicional'), findsNothing);

    // Volver a Todas restaura ambas fichas.
    final allChip = find.text('city.section_all');
    await tester.ensureVisible(allChip);
    await tester.tap(allChip);
    await tester.pumpAndSettle();

    expect(find.text('Música Vallenata Tradicional'), findsOneWidget);
    expect(find.text('Sancocho de gallina criolla'), findsOneWidget);
  });

  testWidgets('shows honest locale fallback notice when English falls back to Spanish', (
    tester,
  ) async {
    final repo = _FakeCityRepository(
      overview: _buildSampleOverview(locale: 'en', hasLocaleFallback: true),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isDemoModeProvider.overrideWithValue(false),
          cityRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          home: CityOverviewPage(municipalityCode: '20001'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('city.locale_fallback_notice'), findsOneWidget);
    expect(find.text('city.item_fallback_badge'), findsOneWidget);
  });

  testWidgets('opens valid https source, shows snackbar on launch failure, and hides unsafe URI', (
    tester,
  ) async {
    final okLauncher = _FakeCityExternalLauncher(result: true);
    final repo = _FakeCityRepository(
      overview: _buildSampleOverview(sourceUrl: 'javascript:alert(1)'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isDemoModeProvider.overrideWithValue(false),
          cityRepositoryProvider.overrideWithValue(repo),
          cityExternalLauncherProvider.overrideWithValue(okLauncher),
        ],
        child: const MaterialApp(
          home: CityOverviewPage(municipalityCode: '20001'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Solo c2 tiene sourceUrl https:// válido; c1 tenía javascript: y no muestra botón.
    expect(find.text('city.open_source_cta'), findsOneWidget);

    await tester.ensureVisible(find.text('city.open_source_cta'));
    await tester.tap(find.text('city.open_source_cta'));
    await tester.pumpAndSettle();

    expect(okLauncher.launchedUris.single.toString(), 'https://www.mincultura.gov.co');

    // Ahora probar fallo controlado del launcher externo con SnackBar.
    final failingLauncher = _FakeCityExternalLauncher(result: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isDemoModeProvider.overrideWithValue(false),
          cityRepositoryProvider.overrideWithValue(repo),
          cityExternalLauncherProvider.overrideWithValue(failingLauncher),
        ],
        child: const MaterialApp(
          home: CityOverviewPage(municipalityCode: '20001'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('city.open_source_cta'));
    await tester.tap(find.text('city.open_source_cta'));
    await tester.pumpAndSettle();

    expect(find.text('city.source_open_error'), findsOneWidget);
  });

  testWidgets('error states never fall back to demo data and support retry', (
    tester,
  ) async {
    final repo = _FakeCityRepository(
      errorToThrow: const CityLoadException(
        CityLoadErrorKind.network,
        'No network',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isDemoModeProvider.overrideWithValue(false),
          cityRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: CityOverviewPage(municipalityCode: '20001'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('city.error_network'), findsOneWidget);
    expect(find.text('city.demo_badge'), findsNothing);
    expect(find.text('common.retry'), findsOneWidget);

    // Al resolver la red y pulsar reintentar, carga los datos reales.
    repo.errorToThrow = null;
    repo.overview = _buildSampleOverview();
    await tester.tap(find.text('common.retry'));
    await tester.pumpAndSettle();

    expect(find.text('Valledupar'), findsOneWidget);
    expect(find.text('Música Vallenata Tradicional'), findsOneWidget);

    // Error específico de municipio no piloto.
    final notPilotRepo = _FakeCityRepository(
      errorToThrow: const CityLoadException(CityLoadErrorKind.notPilot),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isDemoModeProvider.overrideWithValue(false),
          cityRepositoryProvider.overrideWithValue(notPilotRepo),
        ],
        child: const MaterialApp(
          home: CityOverviewPage(municipalityCode: '20011'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('city.error_not_pilot'), findsOneWidget);
    expect(find.text('common.back'), findsOneWidget);
  });

  testWidgets('renders image license attribution when imagePath and imageLicense are provided', (
    tester,
  ) async {
    final repo = _FakeCityRepository(
      overview: _buildSampleOverview(
        imagePath: 'licensed/valledupar_plaza.jpg',
        imageLicense: 'CC BY-SA 4.0 — Archivo Municipal',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isDemoModeProvider.overrideWithValue(false),
          cityRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: CityOverviewPage(municipalityCode: '20001'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('city.image_license_label'), findsOneWidget);
  });

  testWidgets('hides image license when license is missing and respects 360dp @ 2.0x text scale', (
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

    final repo = _FakeCityRepository(
      overview: _buildSampleOverview(
        hasLocaleFallback: true,
        imagePath: 'assets/images/unlicensed.jpg',
        imageLicense: null,
      ),
    );

    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isDemoModeProvider.overrideWithValue(false),
          cityRepositoryProvider.overrideWithValue(repo),
        ],
        child: EasyLocalization(
          supportedLocales: const <Locale>[Locale('es')],
          startLocale: const Locale('es'),
          path: 'assets/translations',
          assetLoader: _CityTestTranslations(translations),
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
                home: const CityOverviewPage(municipalityCode: '20001'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Valledupar'), findsOneWidget);
    expect(find.textContaining('Licencia de imagen'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _CityTestTranslations extends AssetLoader {
  const _CityTestTranslations(this.data);
  final Map<String, dynamic> data;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => data;
}
