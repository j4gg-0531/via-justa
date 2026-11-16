import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/prices/domain/price_map_item.dart';
import 'package:via_justa/features/prices/domain/price_map_repository.dart';
import 'package:via_justa/features/prices/presentation/pages/price_map_page.dart';
import 'package:via_justa/features/prices/presentation/state/price_map_providers.dart';

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

      // Los comercios demo ya no aparecen en el mapa
      expect(find.text('[DEMO] Hospital Rosario Pumarejo'), findsNothing);
      expect(find.text('[DEMO] Almuerzo corriente · Centro'), findsOneWidget);

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
      await tester.scrollUntilVisible(
        find.text('common.retry'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('common.retry'));
      await tester.pumpAndSettle();

      expect(repo.calls, greaterThan(callsBeforeRetry));
      expect(find.text('Cocina del Patio'), findsOneWidget);
    },
  );
}
