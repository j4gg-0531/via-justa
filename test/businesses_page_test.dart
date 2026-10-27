import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/presentation/pages/businesses_page.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';

Widget _buildBusinessesPage() {
  return const ProviderScope(
    child: MaterialApp(
      home: BusinessesPage(),
    ),
  );
}

void main() {
  testWidgets('renders businesses directory header, categories and sample cards',
      (tester) async {
    await tester.pumpWidget(_buildBusinessesPage());
    await tester.pumpAndSettle();

    expect(find.text('businesses.title'), findsOneWidget);
    expect(find.text('businesses.subtitle'), findsOneWidget);
    expect(find.text('businesses.demo_banner'), findsOneWidget);

    // Verify categories
    expect(find.text('businesses.category_all'), findsOneWidget);
    expect(find.text('businesses.category_food'), findsOneWidget);
    expect(find.text('businesses.category_transport'), findsOneWidget);
    expect(find.text('businesses.category_lodging'), findsOneWidget);
    expect(find.text('businesses.category_services'), findsOneWidget);

    // Verify sample business items rendered with DEMO tag and no fake verified badge
    expect(find.text('[DEMO] Restaurante El Pilón Vallenato'), findsOneWidget);
    expect(find.text('businesses.demo_badge'), findsWidgets);
    expect(find.text('businesses.verified_badge'), findsNothing);
  });

  testWidgets('filter by category updates displayed items', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: BusinessesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Select category via provider
    container
        .read(businessCategoryProvider.notifier)
        .selectCategory(BusinessCategory.transport);
    await tester.pumpAndSettle();

    expect(find.text('[DEMO] Cooperativa Taxis Cacique Upar'), findsOneWidget);
    expect(find.text('[DEMO] Restaurante El Pilón Vallenato'), findsNothing);

    // Switch to food
    container
        .read(businessCategoryProvider.notifier)
        .selectCategory(BusinessCategory.food);
    await tester.pumpAndSettle();

    expect(find.text('[DEMO] Restaurante El Pilón Vallenato'), findsOneWidget);
    expect(find.text('[DEMO] Cooperativa Taxis Cacique Upar'), findsNothing);
  });

  testWidgets('tapping register business card triggers dialog', (tester) async {
    await tester.pumpWidget(_buildBusinessesPage());
    await tester.pumpAndSettle();

    // Scroll down to the register business section
    await tester.scrollUntilVisible(
      find.text('businesses.register_action'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('businesses.register_action'), findsOneWidget);
    await tester.tap(find.text('businesses.register_action'));
    await tester.pumpAndSettle();

    expect(find.text('businesses.register_dialog_title'), findsOneWidget);
    expect(find.text('businesses.register_dialog_body'), findsOneWidget);
    await tester.tap(find.text('common.close'));
    await tester.pumpAndSettle();
  });
}
