import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/city/data/demo_city_repository.dart';
import 'package:via_justa/features/city/data/supabase_city_repository.dart';
import 'package:via_justa/features/city/domain/city_overview.dart';
import 'package:via_justa/features/city/domain/city_overview_rules.dart';
import 'package:via_justa/features/city/domain/city_repository.dart';

void main() {
  group('CityOverview domain rules', () {
    test('normalizeCityLocale normalizes es and en locales safely', () {
      expect(normalizeCityLocale('en'), 'en');
      expect(normalizeCityLocale('EN_US'), 'en');
      expect(normalizeCityLocale('en-CO'), 'en');
      expect(normalizeCityLocale('es'), 'es');
      expect(normalizeCityLocale('es_CO'), 'es');
      expect(normalizeCityLocale('fr'), 'es');
      expect(normalizeCityLocale(null), 'es');
      expect(normalizeCityLocale('   '), 'es');
    });

    test('resolveSafeCitySourceUri allows only clean https URIs', () {
      expect(
        resolveSafeCitySourceUri('https://www.valledupar-cesar.gov.co')?.host,
        'www.valledupar-cesar.gov.co',
      );
      expect(
        resolveSafeCitySourceUri(
          '  HTTPS://ich.unesco.org/es/USL/vallenato  ',
        )?.scheme,
        'https',
      );
      expect(resolveSafeCitySourceUri('http://valledupar.gov.co'), isNull);
      expect(resolveSafeCitySourceUri('javascript:alert(1)'), isNull);
      expect(resolveSafeCitySourceUri('file:///etc/passwd'), isNull);
      expect(
        resolveSafeCitySourceUri('https://user:pass@example.com'),
        isNull,
      );
      expect(resolveSafeCitySourceUri('   '), isNull);
      expect(resolveSafeCitySourceUri(null), isNull);
    });

    test('CityContentItem requires imageLicense before exposing image', () {
      const missingLicense = CityContentItem(
        id: '1',
        municipalityCode: '20001',
        slug: 'plaza',
        section: CityContentSection.places,
        requestedLocale: 'es',
        resolvedLocale: 'es',
        isLocaleFallback: false,
        title: 'Plaza Alfonso López',
        body: 'Centro histórico',
        imagePath: 'https://example.com/plaza.jpg',
        imageLicense: '   ',
        sourceCitation: 'Mincultura',
      );
      expect(missingLicense.hasLicensedImage, isFalse);
      expect(missingLicense.safeLicensedImageUri, isNull);

      const validLicensed = CityContentItem(
        id: '2',
        municipalityCode: '20001',
        slug: 'plaza',
        section: CityContentSection.places,
        requestedLocale: 'es',
        resolvedLocale: 'es',
        isLocaleFallback: false,
        title: 'Plaza Alfonso López',
        body: 'Centro histórico',
        imagePath: 'https://example.com/plaza.jpg',
        imageLicense: 'CC BY-SA 4.0 — Archivo Municipal',
        sourceCitation: 'Mincultura',
      );
      expect(validLicensed.hasLicensedImage, isTrue);
      expect(
        validLicensed.safeLicensedImageUri.toString(),
        'https://example.com/plaza.jpg',
      );
    });

    test('filterCityContentBySection and availableCitySections keep canonical order', () {
      const items = <CityContentItem>[
        CityContentItem(
          id: 'b',
          municipalityCode: '20001',
          slug: 'b',
          section: CityContentSection.gastronomy,
          requestedLocale: 'es',
          resolvedLocale: 'es',
          isLocaleFallback: false,
          title: 'Gastronomía',
          body: 'Sancocho',
          sourceCitation: 'Mincultura',
          sortOrder: 5,
        ),
        CityContentItem(
          id: 'a',
          municipalityCode: '20001',
          slug: 'a',
          section: CityContentSection.welcome,
          requestedLocale: 'es',
          resolvedLocale: 'es',
          isLocaleFallback: false,
          title: 'Bienvenida',
          body: 'Capital',
          sourceCitation: 'Alcaldía',
          sortOrder: 1,
        ),
        CityContentItem(
          id: 'c',
          municipalityCode: '20001',
          slug: 'c',
          section: CityContentSection.gastronomy,
          requestedLocale: 'es',
          resolvedLocale: 'es',
          isLocaleFallback: false,
          title: 'Amasijos',
          body: 'Almojábanas',
          sourceCitation: 'Mincultura',
          sortOrder: 5,
        ),
      ];

      final all = filterCityContentBySection(items, null);
      expect(all.map((e) => e.id).toList(), <String>['a', 'c', 'b']);

      final onlyGastronomy = filterCityContentBySection(
        items,
        CityContentSection.gastronomy,
      );
      expect(onlyGastronomy.map((e) => e.id).toList(), <String>['c', 'b']);

      expect(
        availableCitySections(items),
        <CityContentSection>[
          CityContentSection.welcome,
          CityContentSection.gastronomy,
        ],
      );
    });

    test('selectCityEventBanner enforces LIVE separation and temporal priority', () {
      final demoActive = CityEvent(
        id: 'demo-active',
        municipalityCode: '20001',
        name: 'Evento DEMO (no real)',
        startsAt: DateTime.parse('2026-11-20T00:00:00-05:00'),
        endsAt: DateTime.parse('2026-11-25T23:59:59-05:00'),
        temporalStatus: CityEventTemporalStatus.active,
        isCurrentlyActive: true,
        isDemo: true,
      );
      final realUpcoming = CityEvent(
        id: 'real-upcoming',
        municipalityCode: '20001',
        name: 'Festival de la Leyenda Vallenata',
        startsAt: DateTime.parse('2027-04-28T00:00:00-05:00'),
        endsAt: DateTime.parse('2027-05-02T23:59:59-05:00'),
        temporalStatus: CityEventTemporalStatus.upcoming,
        isCurrentlyActive: false,
        isDemo: false,
      );
      final realActive = CityEvent(
        id: 'real-active',
        municipalityCode: '20001',
        name: 'Festival Vallenato en Vivo',
        startsAt: DateTime.parse('2027-04-28T00:00:00-05:00'),
        endsAt: DateTime.parse('2027-05-02T23:59:59-05:00'),
        temporalStatus: CityEventTemporalStatus.active,
        isCurrentlyActive: true,
        isDemo: false,
      );
      final realPast = CityEvent(
        id: 'real-past',
        municipalityCode: '20001',
        name: 'Edición Anterior',
        startsAt: DateTime.parse('2026-04-28T00:00:00-05:00'),
        endsAt: DateTime.parse('2026-05-02T23:59:59-05:00'),
        temporalStatus: CityEventTemporalStatus.past,
        isCurrentlyActive: false,
        isDemo: false,
      );

      // En modo LIVE nunca se muestra un evento DEMO aunque sea activo.
      final liveWithDemoOnly = selectCityEventBanner(
        <CityEvent>[demoActive],
        isDemoMode: false,
      );
      expect(liveWithDemoOnly.mode, CityBannerMode.noActiveEvent);
      expect(liveWithDemoOnly.event, isNull);

      // En modo LIVE sin evento activo, elige el próximo evento real.
      final liveUpcoming = selectCityEventBanner(
        <CityEvent>[demoActive, realUpcoming],
        isDemoMode: false,
      );
      expect(liveUpcoming.mode, CityBannerMode.upcomingEvent);
      expect(liveUpcoming.event?.id, 'real-upcoming');
      expect(liveUpcoming.isDemo, isFalse);

      // Si existe evento real activo, prioriza real sobre DEMO y próximo.
      final demoWithRealActive = selectCityEventBanner(
        <CityEvent>[demoActive, realUpcoming, realActive],
        isDemoMode: true,
      );
      expect(demoWithRealActive.mode, CityBannerMode.activeEvent);
      expect(demoWithRealActive.event?.id, 'real-active');
      expect(demoWithRealActive.isDemo, isFalse);

      // Solo eventos pasados oculta el banner.
      final pastOnly = selectCityEventBanner(
        <CityEvent>[realPast],
        isDemoMode: false,
      );
      expect(pastOnly.mode, CityBannerMode.noActiveEvent);
    });

    test('CityEvent localized description and Colombia date formatting', () {
      final event = CityEvent(
        id: 'ev-1',
        municipalityCode: '20001',
        name: 'Festival de la Leyenda Vallenata',
        descriptionEs: 'Descripción oficial en español.',
        descriptionEn: null,
        startsAt: DateTime.parse('2027-04-28T00:00:00-05:00'),
        endsAt: DateTime.parse('2027-05-02T23:59:59-05:00'),
        temporalStatus: CityEventTemporalStatus.upcoming,
        isCurrentlyActive: false,
      );

      expect(event.descriptionForLocale('es'), 'Descripción oficial en español.');
      expect(event.descriptionForLocale('en'), 'Descripción oficial en español.');
      expect(event.isDescriptionFallbackForLocale('en'), isTrue);
      expect(event.isDescriptionFallbackForLocale('es'), isFalse);

      expect(event.formattedDateRange(localeCode: 'es'), '28 abr – 2 may 2027');
      expect(event.formattedDateRange(localeCode: 'en'), 'Apr 28 – May 2, 2027');

      final sameMonthEvent = CityEvent(
        id: 'ev-2',
        municipalityCode: '20001',
        name: 'Feria',
        startsAt: DateTime.parse('2027-06-10T00:00:00-05:00'),
        endsAt: DateTime.parse('2027-06-12T23:59:59-05:00'),
        temporalStatus: CityEventTemporalStatus.upcoming,
        isCurrentlyActive: false,
      );
      expect(
        sameMonthEvent.formattedDateRange(localeCode: 'es'),
        '10–12 jun 2027',
      );
      expect(
        sameMonthEvent.formattedDateRange(localeCode: 'en'),
        'Jun 10–12, 2027',
      );
    });
  });

  group('SupabaseCityRepository parsing and error mapping', () {
    test('parseOverview parses curated JSONB payload and drops demo items in LIVE mode', () {
      final payload = <String, dynamic>{
        'municipality_code': '20001',
        'municipality_name': 'Valledupar',
        'department_code': '20',
        'is_pilot': true,
        'requested_locale': 'en',
        'has_locale_fallback': true,
        'content': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'c1',
            'municipality_code': '20001',
            'slug': 'vallenato_unesco',
            'section': 'culture',
            'requested_locale': 'en',
            'resolved_locale': 'es',
            'is_locale_fallback': true,
            'title': 'Música Vallenata Tradicional',
            'body': 'Patrimonio UNESCO.',
            'image_path': null,
            'image_license': null,
            'source_citation': 'UNESCO (2015)',
            'source_url': 'https://ich.unesco.org',
            'sort_order': 3,
            'is_demo': false,
          },
          <String, dynamic>{
            'id': 'c-demo',
            'municipality_code': '20001',
            'slug': 'demo_card',
            'section': 'places',
            'requested_locale': 'en',
            'resolved_locale': 'en',
            'is_locale_fallback': false,
            'title': 'DEMO Card',
            'body': 'No mostrar en vivo',
            'source_citation': 'DEMO',
            'sort_order': 9,
            'is_demo': true,
          },
        ],
        'events': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'e-real',
            'municipality_code': '20001',
            'name': 'Festival de la Leyenda Vallenata',
            'description_es': 'En abril.',
            'description_en': 'In April.',
            'venue': 'Parque de la Leyenda',
            'starts_at': '2027-04-28T00:00:00-05:00',
            'ends_at': '2027-05-02T23:59:59-05:00',
            'temporal_status': 'upcoming',
            'is_currently_active': false,
            'is_demo': false,
            'source_citation': 'Fundación Festival',
          },
          <String, dynamic>{
            'id': 'e-demo',
            'municipality_code': '20001',
            'name': 'Evento DEMO',
            'starts_at': '2026-11-15T00:00:00-05:00',
            'ends_at': '2026-11-20T23:59:59-05:00',
            'temporal_status': 'active',
            'is_currently_active': true,
            'is_demo': true,
          },
        ],
      };

      final live = SupabaseCityRepository.parseOverview(
        payload,
        includeDemo: false,
      );
      expect(live.municipalityName, 'Valledupar');
      expect(live.hasLocaleFallback, isTrue);
      expect(live.content.length, 1);
      expect(live.content.first.id, 'c1');
      expect(live.content.first.isLocaleFallback, isTrue);
      expect(live.events.length, 1);
      expect(live.events.first.id, 'e-real');

      final withDemo = SupabaseCityRepository.parseOverview(
        payload,
        includeDemo: true,
      );
      expect(withDemo.content.length, 2);
      expect(withDemo.events.length, 2);
    });

    test('mapError translates RPC and network exceptions', () {
      expect(
        SupabaseCityRepository.mapError(
          const PostgrestException(
            message: '[CITY_MUNICIPALITY_NOT_FOUND] Not found',
            code: 'P0002',
          ),
        ).kind,
        CityLoadErrorKind.notFound,
      );
      expect(
        SupabaseCityRepository.mapError(
          const PostgrestException(
            message: '[CITY_MUNICIPALITY_NOT_PILOT] Not pilot',
            code: '22023',
          ),
        ).kind,
        CityLoadErrorKind.notPilot,
      );
      expect(
        SupabaseCityRepository.mapError(
          const SocketException('Connection failed'),
        ).kind,
        CityLoadErrorKind.network,
      );
      expect(
        SupabaseCityRepository.mapError(TimeoutException('Timed out')).kind,
        CityLoadErrorKind.network,
      );
      expect(
        SupabaseCityRepository.mapError(StateError('unexpected')).kind,
        CityLoadErrorKind.unknown,
      );
    });
  });

  group('DemoCityRepository', () {
    test('marks all demo items and evaluates festival window accurately', () async {
      final outsideRepo = DemoCityRepository(
        nowProvider: () => DateTime.parse('2026-11-22T12:00:00-05:00'),
      );
      final overviewOutside = await outsideRepo.getCityOverview(
        municipalityCode: '20001',
        localeCode: 'es',
        includeDemo: true,
      );
      expect(overviewOutside.content.length, 6);
      expect(overviewOutside.content.every((c) => c.isDemo), isTrue);
      expect(
        overviewOutside.events.single.temporalStatus,
        CityEventTemporalStatus.upcoming,
      );
      expect(overviewOutside.events.single.isCurrentlyActive, isFalse);

      final insideRepo = DemoCityRepository(
        nowProvider: () => DateTime.parse('2027-04-30T15:00:00-05:00'),
      );
      final eventsInside = await insideRepo.getCityEvents(
        municipalityCode: '20001',
        includeDemo: true,
      );
      expect(eventsInside.single.temporalStatus, CityEventTemporalStatus.active);
      expect(eventsInside.single.isCurrentlyActive, isTrue);

      await expectLater(
        outsideRepo.getCityOverview(
          municipalityCode: '20011',
          localeCode: 'es',
        ),
        throwsA(
          isA<CityLoadException>().having(
            (e) => e.kind,
            'kind',
            CityLoadErrorKind.notPilot,
          ),
        ),
      );
    });
  });
}
