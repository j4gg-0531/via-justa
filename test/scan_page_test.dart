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
  testWidgets('renders scan selector and toggles between price and contract',
      (tester) async {
    await tester.pumpWidget(_buildScanPage());
    await tester.pumpAndSettle();

    // Default mode: price
    expect(find.text('scan.title'), findsOneWidget);
    expect(find.text('scan.tab_price'), findsOneWidget);
    expect(find.text('scan.tab_contract'), findsOneWidget);
    expect(find.text('scan.price_header'), findsOneWidget);
    expect(find.text('scan.price_description'), findsOneWidget);

    // Switch to contract mode
    await tester.tap(find.text('scan.tab_contract'));
    await tester.pumpAndSettle();

    expect(find.text('scan.contract_header'), findsOneWidget);
    expect(find.text('scan.contract_description'), findsOneWidget);

    // Switch back to price mode
    await tester.tap(find.text('scan.tab_price'));
    await tester.pumpAndSettle();

    expect(find.text('scan.price_header'), findsOneWidget);
  });

  testWidgets('tapping photo or file action triggers info dialog', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScanPage());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('scan.action_photo'));
    await tester.tap(find.text('scan.action_photo'));
    await tester.pumpAndSettle();

    expect(find.text('scan.dialog_title'), findsOneWidget);
    expect(find.text('scan.dialog_body'), findsOneWidget);

    await tester.tap(find.text('common.close'));
    await tester.pumpAndSettle();
    expect(find.text('scan.dialog_title'), findsNothing);
  });
}
