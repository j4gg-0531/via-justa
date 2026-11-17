import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:via_justa/features/prices/data/supabase_price_map_repository.dart';
import 'package:via_justa/features/prices/data/supabase_price_verdict_repository.dart';
import 'package:via_justa/features/prices/domain/device_location.dart';
import 'package:via_justa/features/prices/domain/price_map_item.dart';
import 'package:via_justa/features/prices/domain/price_map_repository.dart';
import 'package:via_justa/features/prices/presentation/state/price_map_providers.dart';

class _FakePriceMapRepository implements PriceMapRepository {
  const _FakePriceMapRepository();

  @override
  Future<List<PriceMapItem>> getMapItems({
    String municipalityCode = '20001',
  }) async {
    return const [
      PriceMapItem(
        id: 'fake_1',
        name: 'Clínica del Cesar',
        description: 'Urgencias médicas',
        category: PriceMapCategory.services,
        pinKind: PriceMapPinKind.hospital,
        status: PricePinStatus.info,
        pinLabel: '',
        badgeText: '1.0 km',
        normalizedX: 0.4,
        normalizedY: 0.6,
        latitude: 10.4755,
        longitude: -73.2495,
        phone: '6055700000',
        sourceType: 'business',
        municipalityCode: '20001',
        isDemo: false,
      ),
      PriceMapItem(
        id: 'fake_2',
        name: '[DEMO] Taxi urbano',
        description: 'Carrera diurna',
        category: PriceMapCategory.prices,
        pinKind: PriceMapPinKind.transport,
        status: PricePinStatus.fair,
        pinLabel: r'$12k',
        badgeText: r'$12.000',
        normalizedX: 0.5,
        normalizedY: 0.4,
        latitude: 10.4742,
        longitude: -73.2436,
        sourceType: 'price_report',
        municipalityCode: '20001',
      ),
    ];
  }
}

void main() {
  test('filteredPriceMapItemsProvider filters items from fake repository', () async {
    final container = ProviderContainer(
      overrides: [
        priceMapRepositoryProvider.overrideWithValue(
          const _FakePriceMapRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Wait for initial load
    final allItems = await container.read(allPriceMapItemsProvider.future);
    expect(allItems.length, 2);

    // Filter by category (toggleCategory)
    container
        .read(priceMapCategoryProvider.notifier)
        .toggleCategory(PriceMapCategory.prices);
    expect(container.read(priceMapCategoryProvider), PriceMapCategory.prices);
    expect(
      container.read(priceMapSectionTitleKeyProvider),
      'price_map.section_prices',
    );

    final filteredByCat = container.read(filteredPriceMapItemsProvider).value!;
    expect(filteredByCat.length, 1);
    expect(filteredByCat.first.id, 'fake_2');

    // Toggling same category resets to null
    container
        .read(priceMapCategoryProvider.notifier)
        .toggleCategory(PriceMapCategory.prices);
    expect(container.read(priceMapCategoryProvider), isNull);

    // Filter by search query
    container.read(priceMapSearchQueryProvider.notifier).updateQuery('clinica');
    final filteredByQuery =
        container.read(filteredPriceMapItemsProvider).value!;
    expect(filteredByQuery.length, 1);
    expect(filteredByQuery.first.id, 'fake_1');

    // Sheet places excludes price reports (fake_2) and prioritizes selected place
    final sheetPlaces = container.read(sheetPlaceItemsProvider).value!;
    expect(sheetPlaces.map((e) => e.id).toList(), ['fake_1']);

    // Selecting a pin resolves selectedMapPlaceItemProvider and clearing resets it
    expect(container.read(selectedMapPlaceItemProvider), isNull);
    container.read(selectedMapItemIdProvider.notifier).select('fake_1');
    expect(container.read(selectedMapPlaceItemProvider)?.name, 'Clínica del Cesar');
    container.read(selectedMapItemIdProvider.notifier).clear();
    expect(container.read(selectedMapPlaceItemProvider), isNull);

    // PriceMapListOpenNotifier toggles list expansion without setState in views
    expect(container.read(priceMapListOpenProvider), isFalse);
    container.read(priceMapListOpenProvider.notifier).open();
    expect(container.read(priceMapListOpenProvider), isTrue);
    container.read(priceMapListOpenProvider.notifier).close();
    expect(container.read(priceMapListOpenProvider), isFalse);
  });

  test('SupabasePriceMapRepository.parseRows maps price_report and business RPC rows with WGS84 coordinates', () {
    final rows = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'rep-1',
        'source_type': 'price_report',
        'name_es': 'Almuerzo ejecutivo · Zona Norte',
        'name_en': 'Standard lunch · North Zone',
        'description_es': 'Reporte ciudadano en Zona Norte',
        'description_en': 'Community report in North Zone',
        'map_category': 'prices',
        'pin_kind': 'food',
        'pin_status': 'fair',
        'pin_label': r'$15k',
        'badge_text': r'$15.000',
        'latitude': 10.488,
        'longitude': -73.253,
        'normalized_x': 0.5,
        'normalized_y': 0.2,
        'phone': null,
        'whatsapp': null,
        'address': 'Asadero Guatapurí',
        'municipality_code': '20001',
        'zone_id': 'vup_norte',
        'amount_cop': 15000,
        'is_demo': false,
      },
      <String, dynamic>{
        'id': 'biz-demo',
        'source_type': 'business',
        'name_es': '[DEMO] Restaurante El Pilón',
        'name_en': '[DEMO] El Pilón Restaurant',
        'description_es': 'Muestra demo',
        'description_en': 'Demo sample',
        'map_category': 'services',
        'pin_kind': 'food',
        'pin_status': 'info',
        'pin_label': '',
        'badge_text': 'Centro',
        'latitude': 10.47,
        'longitude': -73.24,
        'normalized_x': 0.5,
        'normalized_y': 0.5,
        'municipality_code': '20001',
        'is_demo': true,
      },
      <String, dynamic>{
        'id': 'biz-1',
        'source_type': 'business',
        'name_es': 'Clínica Médicos Valledupar',
        'name_en': 'Clínica Médicos Valledupar',
        'description_es': 'Urgencias y hospitalización 24 horas',
        'description_en': '24h emergency and hospital care',
        'map_category': 'services',
        'pin_kind': 'hospital',
        'pin_status': 'info',
        'pin_label': '',
        'badge_text': 'Calle 16B #19-75',
        'latitude': 10.4718,
        'longitude': -73.2562,
        'normalized_x': 0.34,
        'normalized_y': 0.72,
        'phone': '6055748400',
        'whatsapp': '576055748400',
        'address': 'Calle 16B #19-75',
        'municipality_code': '20001',
        'zone_id': 'vup_centro',
        'amount_cop': null,
        'is_demo': false,
      },
    ];

    final parsedEs = SupabasePriceMapRepository.parseRows(
      rows,
      municipalityCode: '20001',
      localeCode: 'es',
    );

    expect(parsedEs.length, 2);
    expect(parsedEs[0].category, PriceMapCategory.prices);
    expect(parsedEs[0].status, PricePinStatus.fair);
    expect(parsedEs[0].latitude, closeTo(10.488, 0.0001));
    expect(parsedEs[0].longitude, closeTo(-73.253, 0.0001));
    expect(parsedEs[0].isDemo, isFalse);
    expect(parsedEs[0].hasCallableContact, isFalse);

    expect(parsedEs[1].category, PriceMapCategory.services);
    expect(parsedEs[1].pinKind, PriceMapPinKind.hospital);
    expect(parsedEs[1].status, PricePinStatus.info);
    expect(parsedEs[1].latitude, closeTo(10.4718, 0.0001));
    expect(parsedEs[1].longitude, closeTo(-73.2562, 0.0001));
    expect(parsedEs[1].hasCallableContact, isTrue);
    expect(parsedEs[1].sourceType, 'business');
  });

  test(
    'UserMapLocationNotifier expone errorKey claro cuando GPS está desactivado, denegado o activo',
    () async {
      final gateway = _FakeLocationGateway(
        const DeviceLocationResult(status: DeviceLocationStatus.serviceDisabled),
      );
      final container = ProviderContainer(
        overrides: [deviceLocationGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);

      var coords = await container
          .read(userMapLocationProvider.notifier)
          .requestAndFetchLocation();
      expect(coords, isNull);
      expect(
        container.read(userMapLocationProvider).errorKey,
        'gps_disabled',
      );
      expect(container.read(userMapLocationProvider).permissionGranted, isFalse);

      gateway.next = const DeviceLocationResult(
        status: DeviceLocationStatus.permissionDenied,
      );
      coords = await container
          .read(userMapLocationProvider.notifier)
          .requestAndFetchLocation();
      expect(coords, isNull);
      expect(
        container.read(userMapLocationProvider).errorKey,
        'gps_permission_denied',
      );

      gateway.next = const DeviceLocationResult(
        status: DeviceLocationStatus.granted,
        latitude: 10.489,
        longitude: -73.253,
      );
      coords = await container
          .read(userMapLocationProvider.notifier)
          .requestAndFetchLocation();
      expect(coords, (10.489, -73.253));
      expect(container.read(userMapLocationProvider).errorKey, isNull);
      expect(container.read(userMapLocationProvider).permissionGranted, isTrue);
    },
  );

  test(
    'SupabasePriceVerdictRepository.detectCurrentZoneByGps resuelve la zona más cercana según GPS real y falla si GPS falla',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode([
            {
              'id': 'vup_centro',
              'municipality_code': '20001',
              'name_es': 'Zona Centro',
              'name_en': 'Downtown Zone',
              'sector_hint_es': '',
              'sector_hint_en': '',
              'normalized_x': 0.5,
              'normalized_y': 0.5,
              'center_lat': 10.4742,
              'center_lng': -73.2436,
              'sort_order': 1,
            },
            {
              'id': 'vup_norte',
              'municipality_code': '20001',
              'name_es': 'Zona Norte',
              'name_en': 'North Zone',
              'sector_hint_es': '',
              'sector_hint_en': '',
              'normalized_x': 0.45,
              'normalized_y': 0.2,
              'center_lat': 10.4950,
              'center_lng': -73.2535,
              'sort_order': 2,
            },
          ]),
        );
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'local-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);

      final gateway = _FakeLocationGateway(
        const DeviceLocationResult(
          status: DeviceLocationStatus.granted,
          latitude: 10.494,
          longitude: -73.253,
        ),
      );
      final repo = SupabasePriceVerdictRepository(
        client,
        locationGateway: gateway,
      );

      final zone = await repo.detectCurrentZoneByGps();
      expect(zone.id, 'vup_norte');

      gateway.next = const DeviceLocationResult(
        status: DeviceLocationStatus.permissionDenied,
      );
      await expectLater(repo.detectCurrentZoneByGps(), throwsStateError);
    },
  );
}

class _FakeLocationGateway implements DeviceLocationGateway {
  _FakeLocationGateway(this.next);
  DeviceLocationResult next;

  @override
  Future<DeviceLocationResult> fetchCurrentPosition() async => next;
}
