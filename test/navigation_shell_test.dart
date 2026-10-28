import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/features/businesses/presentation/pages/businesses_page.dart';
import 'package:via_justa/features/home/presentation/pages/home_page.dart';
import 'package:via_justa/features/map_colombia/presentation/pages/map_page.dart';
import 'package:via_justa/features/prices/presentation/pages/price_map_page.dart';
import 'package:via_justa/features/profile/presentation/pages/profile_page.dart';
import 'package:via_justa/features/scan/presentation/pages/scan_page.dart';

void main() {
  testWidgets('renders all five navigation destinations in bottom bar', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(
              routerConfig: router,
            );
          },
        ),
      ),
    );

    // Initial route is splash; navigate directly to /home
    container.read(routerProvider).go(AppRoutes.home);
    await tester.pumpAndSettle();

    // Verify all 5 tab labels in the NavigationBar
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('nav.home'), findsOneWidget);
    expect(find.text('nav.map'), findsOneWidget);
    expect(find.text('nav.scan'), findsOneWidget);
    expect(find.text('nav.businesses'), findsOneWidget);
    expect(find.text('nav.profile'), findsOneWidget);

    // Initial page is HomePage
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('switching tabs navigates to corresponding pages (PriceMapPage on Mapa tab)', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(
              routerConfig: router,
            );
          },
        ),
      ),
    );

    container.read(routerProvider).go(AppRoutes.home);
    await tester.pumpAndSettle();

    // 1. Tap Mapa -> shows local municipality PriceMapPage (M08)
    await tester.tap(find.text('nav.map'));
    await tester.pumpAndSettle();
    expect(find.byType(PriceMapPage), findsOneWidget);
    expect(find.byType(MapPage), findsNothing);

    // 2. Tap Escanear
    await tester.tap(find.text('nav.scan'));
    await tester.pumpAndSettle();
    expect(find.byType(ScanPage), findsOneWidget);

    // 3. Tap Negocios
    await tester.tap(find.text('nav.businesses'));
    await tester.pumpAndSettle();
    expect(find.byType(BusinessesPage), findsOneWidget);

    // 4. Tap Perfil
    await tester.tap(find.text('nav.profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);

    // 5. Tap Inicio
    await tester.tap(find.text('nav.home'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('department map route (/departments) renders MapPage without bottom NavigationBar', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(
              routerConfig: router,
            );
          },
        ),
      ),
    );

    container.read(routerProvider).go(AppRoutes.departmentMap);
    await tester.pumpAndSettle();

    expect(find.byType(MapPage), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('back button on non-home tab returns to home tab', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(
              routerConfig: router,
            );
          },
        ),
      ),
    );

    container.read(routerProvider).go(AppRoutes.businesses);
    await tester.pumpAndSettle();
    expect(find.byType(BusinessesPage), findsOneWidget);

    // Simulate system pop (Android back)
    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await tester.pumpAndSettle();

    // Should return to HomePage
    expect(find.byType(HomePage), findsOneWidget);
  });
}
