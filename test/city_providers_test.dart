import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/supabase/supabase_providers.dart';
import 'package:via_justa/features/city/domain/city_overview.dart';
import 'package:via_justa/features/city/domain/city_overview_rules.dart';
import 'package:via_justa/features/city/domain/city_repository.dart';
import 'package:via_justa/features/city/presentation/state/city_providers.dart';
import 'package:via_justa/features/municipality/domain/municipality.dart';
import 'package:via_justa/features/municipality/presentation/state/municipality_providers.dart';

class _FakeCityRepository implements CityRepository {
  _FakeCityRepository({
    this.overviewResult,
    this.eventsResult,
    this.errorToThrow,
  });

  final CityOverview? overviewResult;
  final List<CityEvent>? eventsResult;
  final Object? errorToThrow;
  String? lastLocaleRequested;
  bool? lastIncludeDemoRequested;

  @override
  Future<CityOverview> getCityOverview({
    required String municipalityCode,
    required String localeCode,
    bool includeDemo = false,
  }) async {
    lastLocaleRequested = localeCode;
    lastIncludeDemoRequested = includeDemo;
    if (errorToThrow != null) throw errorToThrow!;
    return overviewResult!;
  }

  @override
  Future<List<CityEvent>> getCityEvents({
    required String municipalityCode,
    bool includeDemo = false,
  }) async {
    lastIncludeDemoRequested = includeDemo;
    if (errorToThrow != null) throw errorToThrow!;
    return eventsResult ?? const <CityEvent>[];
  }
}

void main() {
  const sampleOverview = CityOverview(
    municipalityCode: '20001',
    municipalityName: 'Valledupar',
    departmentCode: '20',
    isPilot: true,
    requestedLocale: 'es',
    hasLocaleFallback: false,
    content: <CityContentItem>[
      CityContentItem(
        id: '1',
        municipalityCode: '20001',
        slug: 'welcome',
        section: CityContentSection.welcome,
        requestedLocale: 'es',
        resolvedLocale: 'es',
        isLocaleFallback: false,
        title: 'Valledupar',
        body: 'Capital del Cesar.',
        sourceCitation: 'Alcaldía de Valledupar',
        sourceUrl: 'https://www.valledupar-cesar.gov.co',
        sortOrder: 1,
      ),
      CityContentItem(
        id: '2',
        municipalityCode: '20001',
        slug: 'culture',
        section: CityContentSection.culture,
        requestedLocale: 'es',
        resolvedLocale: 'es',
        isLocaleFallback: false,
        title: 'Música Vallenata',
        body: 'Patrimonio UNESCO.',
        sourceCitation: 'UNESCO',
        sourceUrl: 'https://ich.unesco.org',
        sortOrder: 3,
      ),
    ],
    events: <CityEvent>[],
  );

  test('cityOverviewProvider loads data and filters by selectedCitySectionProvider', () async {
    final repo = _FakeCityRepository(overviewResult: sampleOverview);
    final container = ProviderContainer(
      overrides: [
        isDemoModeProvider.overrideWithValue(false),
        cityRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    const request = (municipalityCode: '20001', localeCode: 'es_CO');
    final overview = await container.read(cityOverviewProvider(request).future);
    expect(overview.municipalityName, 'Valledupar');
    expect(repo.lastLocaleRequested, 'es');
    expect(repo.lastIncludeDemoRequested, isFalse);

    expect(
      container.read(cityAvailableSectionsProvider(request)),
      <CityContentSection>[
        CityContentSection.welcome,
        CityContentSection.culture,
      ],
    );

    expect(
      container.read(filteredCityContentProvider(request)).requireValue.length,
      2,
    );

    container
        .read(selectedCitySectionProvider.notifier)
        .select(CityContentSection.culture);
    final filtered =
        container.read(filteredCityContentProvider(request)).requireValue;
    expect(filtered.length, 1);
    expect(filtered.first.section, CityContentSection.culture);

    container.read(selectedCitySectionProvider.notifier).clear();
    expect(
      container.read(filteredCityContentProvider(request)).requireValue.length,
      2,
    );
  });

  test('cityOverviewProvider propagates error in LIVE mode without falling back to DEMO', () async {
    final repo = _FakeCityRepository(
      errorToThrow: const CityLoadException(
        CityLoadErrorKind.network,
        'Offline',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        isDemoModeProvider.overrideWithValue(false),
        cityRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    const request = (municipalityCode: '20001', localeCode: 'en');
    final sub = container.listen(cityOverviewProvider(request), (_, _) {});
    addTearDown(sub.close);

    await expectLater(
      container.read(cityOverviewProvider(request).future),
      throwsA(
        isA<CityLoadException>().having(
          (e) => e.kind,
          'kind',
          CityLoadErrorKind.network,
        ),
      ),
    );
    expect(container.read(cityOverviewProvider(request)).hasError, isTrue);
  });

  test('homeCityEventBannerProvider reacts to active municipality and LIVE vs DEMO events', () async {
    final activeReal = CityEvent(
      id: 'ev-active',
      municipalityCode: '20001',
      name: 'Festival Vallenato',
      startsAt: DateTime.parse('2027-04-28T00:00:00-05:00'),
      endsAt: DateTime.parse('2027-05-02T23:59:59-05:00'),
      temporalStatus: CityEventTemporalStatus.active,
      isCurrentlyActive: true,
      isDemo: false,
    );
    final demoOnly = CityEvent(
      id: 'ev-demo',
      municipalityCode: '20001',
      name: 'Evento DEMO',
      startsAt: DateTime.parse('2026-11-20T00:00:00-05:00'),
      endsAt: DateTime.parse('2026-11-25T23:59:59-05:00'),
      temporalStatus: CityEventTemporalStatus.active,
      isCurrentlyActive: true,
      isDemo: true,
    );

    final liveRepo = _FakeCityRepository(
      eventsResult: <CityEvent>[demoOnly, activeReal],
    );
    final container = ProviderContainer(
      overrides: [
        isDemoModeProvider.overrideWithValue(false),
        cityRepositoryProvider.overrideWithValue(liveRepo),
      ],
    );
    addTearDown(container.dispose);

    container.read(selectedMunicipalityProvider.notifier).select(
          const Municipality(
            code: '20001',
            name: 'Valledupar',
            departmentCode: '20',
            isPilot: true,
          ),
        );

    final events = await container.read(cityEventsProvider('20001').future);
    expect(events.length, 2);

    final decision = container.read(homeCityEventBannerProvider).requireValue;
    expect(decision.mode, CityBannerMode.activeEvent);
    expect(decision.event?.id, 'ev-active');
    expect(decision.isDemo, isFalse);
  });
}
