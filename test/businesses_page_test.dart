import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:via_justa/core/router/app_router.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_repository.dart';
import 'package:via_justa/features/businesses/presentation/pages/businesses_page.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';

class _SeededBusinessRepository implements BusinessRepository {
  _SeededBusinessRepository({this.fail = false});

  bool fail;
  int calls = 0;

  static const items = <Business>[
    Business(
      id: 'biz-real-1',
      ownerId: 'owner-1',
      name: 'Cocina del Patio',
      category: BusinessCategory.food,
      address: 'Sector Centro, Valledupar',
      phone: '573001234567',
      municipalityCode: '20001',
      isVerified: true,
      description: 'Almuerzos y comida casera.',
      descriptionEs: 'Almuerzos y comida casera.',
      descriptionEn: 'Home-style lunches.',
    ),
    Business(
      id: 'biz-real-2',
      ownerId: 'owner-2',
      name: 'Taxis del Valle',
      category: BusinessCategory.transport,
      address: 'Sector Terminal, Valledupar',
      phone: '6055710000',
      municipalityCode: '20001',
      isVerified: true,
      description: 'Servicio de taxi urbano.',
      descriptionEs: 'Servicio de taxi urbano.',
    ),
  ];

  @override
  Future<List<Business>> getBusinesses() async {
    calls++;
    if (fail) throw Exception('connection failed');
    return items;
  }
}

void main() {
  testWidgets(
    'zona vacía no muestra comercios demo ni banner demo y muestra estado vacío',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: BusinessesPage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('businesses.title'), findsOneWidget);
      expect(find.text('businesses.subtitle'), findsOneWidget);
      expect(find.text('businesses.demo_banner'), findsNothing);
      expect(find.text('businesses.demo_badge'), findsNothing);
      expect(find.textContaining('[DEMO]'), findsNothing);
      expect(find.text('businesses.no_results'), findsOneWidget);
    },
  );

  testWidgets(
    'fallo de conexión muestra error y permite reintentar sin reemplazar por demos',
    (tester) async {
      final repo = _SeededBusinessRepository(fail: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [businessRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: BusinessesPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('municipality.load_error'), findsOneWidget);
      expect(find.text('common.retry'), findsOneWidget);
      expect(find.textContaining('[DEMO]'), findsNothing);

      repo.fail = false;
      final callsBeforeRetry = repo.calls;
      await tester.tap(find.text('common.retry'));
      await tester.pumpAndSettle();

      expect(repo.calls, greaterThan(callsBeforeRetry));
      expect(find.text('Cocina del Patio'), findsOneWidget);
      expect(find.text('businesses.verified_badge'), findsWidgets);
    },
  );

  testWidgets(
    'filtra por categoría y muestra acciones de editar y retirar solo al dueño',
    (tester) async {
      final repo = _SeededBusinessRepository();
      final container = ProviderContainer(
        overrides: [
          businessRepositoryProvider.overrideWithValue(repo),
          currentBusinessOwnerIdProvider.overrideWithValue('owner-1'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BusinessesPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cocina del Patio'), findsOneWidget);
      expect(find.text('Taxis del Valle'), findsOneWidget);
      expect(find.text('businesses.action_edit'), findsOneWidget);
      expect(find.text('businesses.action_withdraw'), findsOneWidget);

      container
          .read(businessCategoryProvider.notifier)
          .selectCategory(BusinessCategory.transport);
      await tester.pumpAndSettle();

      expect(find.text('Taxis del Valle'), findsOneWidget);
      expect(find.text('Cocina del Patio'), findsNothing);
      expect(find.text('businesses.action_edit'), findsNothing);
    },
  );

  testWidgets('tapping register business card opens registration', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const BusinessesPage()),
        GoRoute(
          path: AppRoutes.businessRegister,
          builder: (_, _) =>
              const Scaffold(body: Text('registration-destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('businesses.register_action'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('businesses.register_action'), findsOneWidget);
    await tester.tap(find.text('businesses.register_action'));
    await tester.pumpAndSettle();

    expect(find.text('registration-destination'), findsOneWidget);
  });
}
