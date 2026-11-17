import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/prices/domain/device_location.dart';
import 'package:via_justa/features/prices/domain/municipality_zone.dart';
import 'package:via_justa/features/prices/domain/price_map_item.dart';
import 'package:via_justa/features/prices/domain/price_map_repository.dart';
import 'package:via_justa/features/prices/presentation/pages/price_map_page.dart';
import 'package:via_justa/features/prices/presentation/state/price_map_providers.dart';
import 'package:via_justa/features/prices/presentation/widgets/map_point_picker_sheet.dart';

class _ConfigurableMapRepository implements PriceMapRepository {
  _ConfigurableMapRepository({this.fail = false, this.items = const []});

  bool fail;
  List<PriceMapItem> items;
  int calls = 0;

  @override
  Future<List<PriceMapItem>> getMapItems({
    String municipalityCode = '20001',
  }) async {
    calls++;
    if (fail) throw Exception('map connection failed');
    return items;
  }
}

void main() {
  testWidgets(
    'PriceMapPage renders filter chips, excludes demo businesses, and shows empty zone message for services without overflow at 360dp and 1.5x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(1.5),
            ),
            child: const MaterialApp(
              home: PriceMapPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('price_map.filter_prices'), findsOneWidget);
      expect(find.text('price_map.filter_services'), findsOneWidget);
      expect(find.text('price_map.filter_consulates'), findsOneWidget);
      expect(find.text('price_map.contribute_cta'), findsOneWidget);

      // Los comercios demo y los reportes sueltos de precio no aparecen en la hoja inferior
      expect(find.text('[DEMO] Hospital Rosario Pumarejo'), findsNothing);
      expect(find.text('[DEMO] Almuerzo corriente · Centro'), findsNothing);

      // Al filtrar por Servicios en una zona sin negocios reales muestra «Aún no hay negocios en esta zona»
      await tester.ensureVisible(find.text('price_map.filter_services'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('price_map.filter_services'));
      await tester.pumpAndSettle();

      expect(find.text('price_map.section_services'), findsOneWidget);
      expect(find.text('businesses.no_results'), findsOneWidget);
    },
  );

  testWidgets(
    'PriceMapPage muestra fallo de conexión y permite reintentar mostrando el negocio publicado',
    (tester) async {
      final repo = _ConfigurableMapRepository(
        fail: true,
        items: const [
          PriceMapItem(
            id: 'biz-real-1',
            name: 'Cocina del Patio',
            description: 'Almuerzos y comida casera.',
            category: PriceMapCategory.services,
            pinKind: PriceMapPinKind.food,
            status: PricePinStatus.info,
            pinLabel: '',
            badgeText: 'Sector Centro',
            normalizedX: 0.5,
            normalizedY: 0.5,
            latitude: 10.4742,
            longitude: -73.2436,
            address: 'Sector Centro, Valledupar',
            sourceType: 'business',
            municipalityCode: '20001',
            isDemo: false,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [priceMapRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: PriceMapPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('municipality.load_error'), findsOneWidget);
      expect(find.text('common.retry'), findsOneWidget);

      repo.fail = false;
      final callsBeforeRetry = repo.calls;
      await tester.tap(find.text('common.retry'));
      await tester.pumpAndSettle();

      expect(repo.calls, greaterThan(callsBeforeRetry));
      expect(find.text('price_map.view_list'), findsOneWidget);
      await tester.tap(find.text('price_map.view_list'));
      await tester.pumpAndSettle();
      expect(find.text('Cocina del Patio'), findsOneWidget);
    },
  );

  testWidgets(
    'PriceMapPage oculta la etiqueta de datos en vivo cuando isDemoMapModeProvider es false y MapPointPickerSheet avisa si GPS está apagado',
    (tester) async {
      final repo = _ConfigurableMapRepository();
      final gpsGateway = _DisabledLocationGateway();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            priceMapRepositoryProvider.overrideWithValue(repo),
            isDemoMapModeProvider.overrideWithValue(false),
            deviceLocationGatewayProvider.overrideWithValue(gpsGateway),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Column(
                children: [
                  const Expanded(child: PriceMapPage()),
                  TextButton(
                    onPressed: () => showMapPointPickerSheet(
                      context: context,
                      title: 'picker',
                      subtitle: 'sub',
                      zones: const [
                        MunicipalityZone(
                          id: 'vup_centro',
                          municipalityCode: '20001',
                          nameEs: 'Zona Centro',
                          nameEn: 'Downtown',
                          sectorHintEs: '',
                          sectorHintEn: '',
                        ),
                      ],
                      initialZoneId: 'vup_centro',
                      languageCode: 'es',
                    ),
                    child: const Text('open-picker'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('price_map.live_label'), findsNothing);
      expect(find.text('price_map.demo_label'), findsNothing);

      await tester.tap(find.text('open-picker'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('price_verdict.use_gps_cta'));
      await tester.pumpAndSettle();

      expect(find.text('price_map.gps_errors.gps_disabled'), findsOneWidget);
    },
  );

  testWidgets(
    'Opción A inicia con píldora compacta, abre tarjeta flotante sin reportes de taxi ni botón Llamar y flota la tarjeta del pin seleccionado',
    (tester) async {
      final repo = _ConfigurableMapRepository(
        items: const [
          PriceMapItem(
            id: 'biz-with-phone',
            name: 'Asadero Central',
            description: 'Carnes al carbón.',
            category: PriceMapCategory.services,
            pinKind: PriceMapPinKind.food,
            status: PricePinStatus.info,
            pinLabel: '',
            badgeText: 'Calle 10',
            normalizedX: 0.25,
            normalizedY: 0.45,
            latitude: 10.4742,
            longitude: -73.2436,
            phone: '3001234567',
            sourceType: 'business',
            municipalityCode: '20001',
            isDemo: false,
          ),
          PriceMapItem(
            id: 'rep-taxi-1',
            name: 'Taxi · Plaza → Terminal',
            description: 'Carrera urbana',
            category: PriceMapCategory.prices,
            pinKind: PriceMapPinKind.transport,
            status: PricePinStatus.fair,
            pinLabel: r'$10k',
            badgeText: r'$10.000',
            normalizedX: 0.75,
            normalizedY: 0.65,
            latitude: 10.4750,
            longitude: -73.2450,
            sourceType: 'price_report',
            municipalityCode: '20001',
            isDemo: false,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [priceMapRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: PriceMapPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Inicialmente el mapa está despejado con la píldora compacta y sin lista desplegada
      expect(find.text('price_map.view_list'), findsOneWidget);
      expect(find.text('Asadero Central'), findsNothing);
      expect(find.text('Taxi · Plaza → Terminal'), findsNothing);

      // Al tocar "Ver lista" abre la tarjeta flotante con lugares reales sin reportes de taxi ni botón Llamar
      await tester.tap(find.text('price_map.view_list'));
      await tester.pumpAndSettle();

      expect(find.text('Asadero Central'), findsOneWidget);
      expect(find.text('Taxi · Plaza → Terminal'), findsNothing);
      expect(find.text('price_map.action_details'), findsOneWidget);
      expect(find.text('price_map.action_route'), findsOneWidget);
      expect(find.text('businesses.action_call'), findsNothing);

      // Al tocar el botón de cierre vuelve a colapsar a la píldora compacta
      await tester.tap(find.byTooltip('price_map.show_map'));
      await tester.pumpAndSettle();
      expect(find.text('price_map.view_list'), findsOneWidget);
      expect(find.text('Asadero Central'), findsNothing);

      // Al tocar un pin sobre el mapa flota la tarjeta completa y cerrarla regresa a la píldora
      await tester.tap(find.byIcon(Icons.restaurant).first);
      await tester.pumpAndSettle();
      expect(find.text('Asadero Central'), findsOneWidget);
      expect(find.text('businesses.action_call'), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('price_map.view_list'), findsOneWidget);
      expect(find.text('Asadero Central'), findsNothing);
    },
  );
}

class _DisabledLocationGateway implements DeviceLocationGateway {
  @override
  Future<DeviceLocationResult> fetchCurrentPosition() async =>
      const DeviceLocationResult(status: DeviceLocationStatus.serviceDisabled);
}
