import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/prices/presentation/pages/price_map_page.dart';

void main() {
  testWidgets(
    'PriceMapPage renders filter chips, contribute button, and sample items without overflow at 360dp and 1.5x text scale',
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
      expect(find.text('[DEMO] Hospital Rosario Pumarejo'), findsOneWidget);

      // Filter by Precios chip
      await tester.tap(find.text('price_map.filter_prices'));
      await tester.pumpAndSettle();

      expect(find.text('price_map.section_prices'), findsOneWidget);
      expect(find.text('[DEMO] Almuerzo corriente · Centro'), findsOneWidget);
      expect(find.text('[DEMO] Hospital Rosario Pumarejo'), findsNothing);
    },
  );
}
