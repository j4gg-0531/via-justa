import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/auth/domain/auth_session.dart';
import 'package:via_justa/features/auth/presentation/state/auth_controller.dart';
import 'package:via_justa/features/auth/presentation/state/auth_state.dart';
import 'package:via_justa/features/businesses/domain/business.dart';
import 'package:via_justa/features/businesses/domain/business_detail.dart';
import 'package:via_justa/features/businesses/domain/business_filter.dart';
import 'package:via_justa/features/businesses/domain/business_rating.dart';
import 'package:via_justa/features/businesses/domain/business_repository.dart';
import 'package:via_justa/features/businesses/presentation/pages/business_detail_page.dart';
import 'package:via_justa/features/businesses/presentation/pages/businesses_page.dart';
import 'package:via_justa/features/businesses/presentation/state/business_providers.dart';
import 'package:via_justa/features/prices/domain/price_map_item.dart';
import 'package:via_justa/features/prices/domain/price_map_repository.dart';
import 'package:via_justa/features/prices/presentation/pages/price_map_page.dart';
import 'package:via_justa/features/prices/presentation/state/price_map_providers.dart';

import 'business_external_actions_test.dart' show FakeBusinessExternalLauncher;

class _VoterAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    session: AuthSession(userId: 'voter-1'),
    usesDemoData: false,
  );
}

class _OwnerAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    session: AuthSession(userId: 'owner-1'),
    usesDemoData: false,
  );
}

class _DetailTestBusinessRepository implements BusinessRepository {
  _DetailTestBusinessRepository({required this.detail});

  BusinessDetail detail;
  final submittedRatings = <int>[];

  @override
  Future<List<Business>> getBusinesses({
    BusinessCategory? category,
    String? searchQuery,
    String localeCode = 'es',
    int limit = kBusinessCatalogPageSize,
    int offset = 0,
  }) async {
    return [
      Business(
        id: detail.id,
        ownerId: detail.ownerId,
        name: detail.name,
        type: detail.type,
        category: detail.category,
        address: detail.address,
        phone: detail.phone ?? '',
        municipalityCode: detail.municipalityCode,
        isVerified: true,
        description: detail.description,
        descriptionEs: detail.descriptionEs,
        descriptionEn: detail.descriptionEn,
      ),
    ];
  }

  @override
  Future<BusinessDetail> getBusinessDetail(
    String businessId, {
    String localeCode = 'es',
  }) async {
    if (businessId != detail.id) {
      throw StateError('Unknown business $businessId');
    }
    return detail;
  }

  @override
  Future<BusinessRatingSummary> rateBusiness({
    required String businessId,
    required int stars,
  }) async {
    submittedRatings.add(stars);
    detail = BusinessDetail(
      id: detail.id,
      ownerId: detail.ownerId,
      name: detail.name,
      type: detail.type,
      category: detail.category,
      municipalityCode: detail.municipalityCode,
      description: detail.description,
      descriptionEs: detail.descriptionEs,
      descriptionEn: detail.descriptionEn,
      address: detail.address,
      latitude: detail.latitude,
      longitude: detail.longitude,
      phone: detail.phone,
      whatsapp: detail.whatsapp,
      orderUrl: detail.orderUrl,
      whatsappUrl: detail.whatsappUrl,
      mapsUrl: detail.mapsUrl,
      canCall: detail.canCall,
      canWhatsapp: detail.canWhatsapp,
      canDirections: detail.canDirections,
      canOrderExternal: detail.canOrderExternal,
      externalOrderDisclaimer: detail.externalOrderDisclaimer,
      schedule: detail.schedule,
      dishes: detail.dishes,
      ratingAverage: stars.toDouble(),
      ratingCount: 1,
      myRating: stars,
    );
    return BusinessRatingSummary(
      businessId: businessId,
      myRating: stars,
      ratingAverage: stars.toDouble(),
      ratingCount: 1,
    );
  }

  @override
  Future<List<Business>> getMyBusinesses() async => const <Business>[];
}

class _DetailTestMapRepository implements PriceMapRepository {
  const _DetailTestMapRepository({required this.detail});

  final BusinessDetail detail;

  @override
  Future<List<PriceMapItem>> getMapItems({
    String municipalityCode = '20001',
  }) async {
    return [
      PriceMapItem(
        id: detail.id,
        name: detail.name,
        description: detail.description,
        category: PriceMapCategory.services,
        pinKind: PriceMapPinKind.food,
        status: PricePinStatus.info,
        pinLabel: '',
        badgeText: detail.address,
        normalizedX: 0.5,
        normalizedY: 0.5,
        latitude: detail.latitude ?? kValleduparCenterLat,
        longitude: detail.longitude ?? kValleduparCenterLng,
        address: detail.address,
        sourceType: 'business',
        municipalityCode: detail.municipalityCode,
        isDemo: false,
      ),
    ];
  }
}

BusinessDetail _sampleDetail({
  bool canOrder = true,
  bool canWhatsapp = true,
  bool canDirections = true,
  double? ratingAverage,
  int ratingCount = 0,
}) {
  return BusinessDetail(
    id: 'biz-cocina-1',
    ownerId: 'owner-1',
    name: 'Cocina del Patio',
    type: 'restaurant',
    category: BusinessCategory.food,
    municipalityCode: '20001',
    description: 'Almuerzos y comida casera.',
    descriptionEs: 'Almuerzos y comida casera.',
    descriptionEn: 'Home-style lunches.',
    address: 'Sector Centro, Valledupar',
    latitude: 10.4742,
    longitude: -73.2436,
    phone: '6055712345',
    whatsapp: canWhatsapp ? '573001234567' : null,
    orderUrl: canOrder ? 'https://vinapp.co/cocina' : null,
    whatsappUrl: canWhatsapp ? 'https://wa.me/573001234567' : null,
    mapsUrl: canDirections
        ? 'https://www.google.com/maps/dir/?api=1&destination=10.474200,-73.243600'
        : null,
    canCall: true,
    canWhatsapp: canWhatsapp,
    canDirections: canDirections,
    canOrderExternal: canOrder,
    externalOrderDisclaimer:
        'Los pedidos y pagos se realizan directamente con el comercio fuera de Vía Justa.',
    schedule: buildBusinessSchedule({
      'mon': [
        {'open': '11:30', 'close': '16:00'},
      ],
      'sun': <Map<String, dynamic>>[],
    }),
    dishes: const [
      BusinessDishItem(
        id: 'd1',
        name: 'Sancocho de gallina',
        priceCop: 22000,
      ),
    ],
    ratingAverage: ratingAverage,
    ratingCount: ratingCount,
  );
}

void main() {
  testWidgets(
    'BusinessDetailPage renderiza secciones de la ficha sin overflow a 360dp y escala 2x y muestra Sin valoraciones cuando es nuevo',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final detail = _sampleDetail();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessRepositoryProvider.overrideWithValue(
              _DetailTestBusinessRepository(detail: detail),
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(2.0),
            ),
            child: const MaterialApp(
              locale: Locale('es'),
              home: BusinessDetailPage(businessId: 'biz-cocina-1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cocina del Patio'), findsWidgets);
      expect(find.text('business_detail.photo_placeholder'), findsOneWidget);
      expect(find.text('business_detail.no_ratings'), findsOneWidget);
      expect(find.text('business_detail.action_order'), findsOneWidget);
      expect(find.text('business_detail.action_whatsapp'), findsOneWidget);
      expect(find.text('business_detail.section_info'), findsOneWidget);
      expect(find.text('Almuerzos y comida casera.'), findsOneWidget);
      expect(find.text('Sancocho de gallina'), findsOneWidget);
      expect(find.text(r'$22.000 COP'), findsOneWidget);
      expect(find.text('business_detail.section_hours'), findsOneWidget);
      expect(find.text('business_detail.section_location'), findsOneWidget);
      expect(find.text('Sector Centro, Valledupar'), findsOneWidget);
      expect(find.text('business_detail.action_directions'), findsOneWidget);
      expect(find.text('business_detail.section_ratings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'BusinessDetailPage deshabilita botones cuando faltan enlace o WhatsApp registrados',
    (tester) async {
      final detail = _sampleDetail(
        canOrder: false,
        canWhatsapp: false,
        canDirections: true,
        ratingAverage: 4.3,
        ratingCount: 12,
      );
      var orderTapped = false;
      var whatsappTapped = false;
      var directionsTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessRepositoryProvider.overrideWithValue(
              _DetailTestBusinessRepository(detail: detail),
            ),
          ],
          child: MaterialApp(
            home: BusinessDetailPage(
              businessId: 'biz-cocina-1',
              onOrderTap: (_) => orderTapped = true,
              onWhatsappTap: (_) => whatsappTapped = true,
              onDirectionsTap: (_) => directionsTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('business_detail.action_order'));
      await tester.tap(find.text('business_detail.action_whatsapp'));
      await tester.scrollUntilVisible(
        find.text('business_detail.action_directions'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('business_detail.action_directions'));
      await tester.pumpAndSettle();

      expect(orderTapped, isFalse);
      expect(whatsappTapped, isFalse);
      expect(directionsTapped, isTrue);
    },
  );

  testWidgets(
    'seleccionar un negocio desde el directorio o desde el mapa abre la misma ficha compartida',
    (tester) async {
      final detail = _sampleDetail();
      final bizRepo = _DetailTestBusinessRepository(detail: detail);
      final mapRepo = _DetailTestMapRepository(detail: detail);

      // 1. Desde el directorio (BusinessesPage)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [businessRepositoryProvider.overrideWithValue(bizRepo)],
          child: const MaterialApp(home: BusinessesPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cocina del Patio'));
      await tester.pumpAndSettle();

      expect(find.byType(BusinessDetailPage), findsOneWidget);
      expect(find.text('business_detail.section_info'), findsOneWidget);

      // 2. Desde el mapa (PriceMapPage)
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('map-scope'),
          overrides: [
            businessRepositoryProvider.overrideWithValue(bizRepo),
            priceMapRepositoryProvider.overrideWithValue(mapRepo),
          ],
          child: const MaterialApp(
            key: ValueKey('map-app'),
            home: PriceMapPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('price_map.view_list'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cocina del Patio').first);
      await tester.pumpAndSettle();

      expect(find.byType(BusinessDetailPage), findsOneWidget);
      expect(find.text('business_detail.section_info'), findsOneWidget);
    },
  );

  testWidgets(
    'botones de la ficha lanzan enlaces de menú, WhatsApp con mensaje sugerido y Google Maps',
    (tester) async {
      final detail = _sampleDetail();
      final launcher = FakeBusinessExternalLauncher();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessRepositoryProvider.overrideWithValue(
              _DetailTestBusinessRepository(detail: detail),
            ),
            businessExternalLauncherProvider.overrideWithValue(launcher),
          ],
          child: const MaterialApp(
            home: BusinessDetailPage(businessId: 'biz-cocina-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('business_detail.action_order'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('business_detail.action_whatsapp'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('business_detail.action_directions'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('business_detail.action_directions'));
      await tester.pumpAndSettle();

      expect(launcher.launchedUris.length, 3);
      expect(launcher.launchedUris[0].toString(), 'https://vinapp.co/cocina');
      expect(launcher.launchedUris[1].host, 'wa.me');
      expect(
        launcher.launchedUris[1].queryParameters['text'],
        contains('Cocina del Patio'),
      );
      expect(launcher.launchedUris[2].host, 'www.google.com');
    },
  );

  testWidgets(
    'usuario autenticado puede votar y modificar su voto de 1 a 5 estrellas, mientras que el dueño está bloqueado',
    (tester) async {
      final repo = _DetailTestBusinessRepository(detail: _sampleDetail());

      // 1. Usuario autenticado distinto al dueño vota 4 estrellas y luego modifica a 5
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('voter-scope'),
          overrides: [
            authControllerProvider.overrideWith(_VoterAuthController.new),
            businessRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            key: ValueKey('voter-app'),
            home: BusinessDetailPage(businessId: 'biz-cocina-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('business_detail.save_rating'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('rate-star-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('business_detail.save_rating'));
      await tester.pumpAndSettle();

      expect(repo.submittedRatings, [4]);
      expect(find.text('business_detail.rating_saved'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('rate-star-5')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('business_detail.save_rating'));
      await tester.pumpAndSettle();

      expect(repo.submittedRatings, [4, 5]);

      // 2. El dueño del negocio ve el aviso y no puede autovalorarse
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('owner-scope'),
          overrides: [
            authControllerProvider.overrideWith(_OwnerAuthController.new),
            businessRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            key: ValueKey('owner-app'),
            home: BusinessDetailPage(businessId: 'biz-cocina-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('business_detail.owner_cannot_rate'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('business_detail.owner_cannot_rate'), findsOneWidget);
      expect(find.byKey(const ValueKey('rate-star-5')), findsNothing);
    },
  );
}
