import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/scan/presentation/pages/scan_page.dart';

Widget _buildScanPage() {
  return const ProviderScope(
    child: MaterialApp(
      home: ScanPage(),
    ),
  );
}

void main() {
  testWidgets(
      'renders clean price form without receipt OCR box or [DEMO] category prefixes, and toggles to contract mode',
      (tester) async {
    await tester.pumpWidget(_buildScanPage());
    await tester.pumpAndSettle();

    // Default mode: price
    expect(find.text('scan.headline'), findsOneWidget);
    expect(find.text('scan.tab_price'), findsOneWidget);
    expect(find.text('scan.tab_contract'), findsOneWidget);
    expect(find.text('price_verdict.evaluate_cta'), findsOneWidget);

    // Receipt/menu OCR box must NOT appear in price mode
    expect(find.text('scan.price_header'), findsNothing);
    expect(find.text('scan.action_photo'), findsNothing);

    // Categories must not have [DEMO] prefix
    expect(find.text('Taxi — Minimum urban ride'), findsOneWidget);
    expect(find.text('Standard daily lunch'), findsOneWidget);
    expect(find.textContaining('[DEMO]'), findsNothing);

    // Switch to contract mode -> upload box and camera button appear there
    await tester.tap(find.text('scan.tab_contract'));
    await tester.pumpAndSettle();

    expect(find.text('scan.upload_box_title'), findsOneWidget);
    expect(find.text('scan.action_take_photo_now'), findsOneWidget);

    // Switch back to price mode
    await tester.tap(find.text('scan.tab_price'));
    await tester.pumpAndSettle();

    expect(find.text('price_verdict.evaluate_cta'), findsOneWidget);
  });

  testWidgets(
      'taxi category shows origin and destination, blocks evaluation without destination, and opens map bottom sheet',
      (tester) async {
    await tester.pumpWidget(_buildScanPage());
    await tester.pumpAndSettle();

    // Taxi is selected by default -> shows both Origin and Destination
    expect(find.text('price_verdict.taxi_origin_label'), findsOneWidget);
    expect(find.text('price_verdict.taxi_destination_label'), findsOneWidget);
    expect(
      find.text('price_verdict.establishment_location_label'),
      findsNothing,
    );

    // Tapping evaluate without destination shows destination required error
    await tester.ensureVisible(find.text('price_verdict.evaluate_cta'));
    await tester.tap(find.text('price_verdict.evaluate_cta'));
    await tester.pumpAndSettle();
    expect(
      find.text('price_contribute.error_destination_required'),
      findsOneWidget,
    );

    // Tapping pick destination opens the modal bottom sheet
    await tester.ensureVisible(find.text('price_verdict.pick_point_on_map_btn'));
    await tester.tap(find.text('price_verdict.pick_point_on_map_btn'));
    await tester.pumpAndSettle();
    expect(find.text('price_verdict.confirm_map_point_cta'), findsOneWidget);

    // Confirm destination in bottom sheet -> clears error
    await tester.tap(find.text('price_verdict.confirm_map_point_cta'));
    await tester.pumpAndSettle();
    expect(
      find.text('price_contribute.error_destination_required'),
      findsNothing,
    );

    // Switching to Almuerzo shows single establishment location
    await tester.ensureVisible(find.text('Standard daily lunch'));
    await tester.tap(find.text('Standard daily lunch'));
    await tester.pumpAndSettle();
    expect(
      find.text('price_verdict.establishment_location_label'),
      findsOneWidget,
    );
    expect(find.text('price_verdict.taxi_destination_label'), findsNothing);
  });

  testWidgets(
      'contract mode shows dashed upload box with PDF coming soon chip, camera button, manual text review, and no synthetic sample list',
      (tester) async {
    await tester.pumpWidget(_buildScanPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('scan.tab_contract'));
    await tester.pumpAndSettle();

    expect(find.text('scan.upload_box_title'), findsOneWidget);
    expect(find.text('scan.upload_box_hint'), findsOneWidget);
    expect(find.text('contract_capture.pdf_coming_soon_chip'), findsOneWidget);
    expect(find.text('scan.action_take_photo_now'), findsOneWidget);
    expect(find.text('scan.manual_text_toggle'), findsOneWidget);

    // No synthetic sample list in ScanPage
    expect(find.text('contract_capture.samples_title'), findsNothing);

    // Tapping PDF coming soon chip displays the notice
    await tester.tap(find.text('contract_capture.pdf_coming_soon_chip'));
    await tester.pumpAndSettle();
    expect(find.text('contract_capture.error_pdf_coming_soon'), findsOneWidget);

    // Tapping manual text toggle opens the editable text review box
    await tester.ensureVisible(find.text('scan.manual_text_toggle'));
    await tester.tap(find.text('scan.manual_text_toggle'));
    await tester.pumpAndSettle();

    expect(find.text('contract_capture.editor_label'), findsOneWidget);
    expect(find.text('contract_analysis.analyze_cta'), findsOneWidget);
  });
}
